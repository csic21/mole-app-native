import AppKit
import Foundation
import SwiftUI

/// 一条真实的可用更新。
struct UpdateInfo: Identifiable, Sendable {
    enum Action: Sendable {
        case sparkle(app: URL)                  // 打开应用,由其内置 Sparkle 完成更新
        case brew(token: String, isCask: Bool)  // brew upgrade
    }

    let id: String
    let name: String
    let source: String
    let from: String
    let to: String
    let action: Action
}

/// 一次检查的结果:可用更新、未完成的来源,以及成功检查过的来源数。
struct UpdateCheckReport: Sendable {
    var updates: [UpdateInfo] = []
    var warnings: [String] = []
    var checkedSources = 0
}

struct SparkleCandidate: Sendable {
    let name: String
    let bundle: URL
    let installed: String
    let build: String?
    let feed: URL
}

struct CheckError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

@MainActor
final class UpdateStore: ObservableObject {
    @Published private(set) var updates: [UpdateInfo] = []
    @Published private(set) var checking = false
    @Published private(set) var progress = ""
    @Published private(set) var lastChecked: Date?
    @Published private(set) var messages: [String: String] = [:]
    @Published private(set) var commandLogs: [String: String] = [:]
    @Published private(set) var busyID: String?
    @Published private(set) var checkWarnings: [String] = []
    @Published private(set) var checkedSources = 0
    @Published private(set) var checkWasCancelled = false

    /// DEBUG snapshots cannot read bundles, access update feeds, or install updates.
    private(set) var allowsLiveOperations = true
    private var checkTask: Task<Void, Never>?
    private var operationID = UUID()
    private let brewChecker: @Sendable () async -> UpdateCheckReport

    init(brewChecker: @escaping @Sendable () async -> UpdateCheckReport = { await UpdateStore.checkBrew() }) {
        self.brewChecker = brewChecker
    }

#if DEBUG
    struct Snapshot {
        var updates: [UpdateInfo] = []
        var checking = false
        var progress = ""
        var lastChecked: Date? = nil
        var messages: [String: String] = [:]
        var busyID: String? = nil
        var checkWarnings: [String] = []
        var checkedSources = 0
        var checkWasCancelled = false
        var commandLogs: [String: String] = [:]
    }

    convenience init(snapshot: Snapshot) {
        self.init()
        precondition(snapshot.updates.allSatisfy { info in
            if case .sparkle(let app) = info.action {
                return app.standardizedFileURL.path.hasPrefix("/QiliPreview/")
            }
            return true
        }, "Snapshot fixtures must use synthetic /QiliPreview paths")
        allowsLiveOperations = false
        updates = snapshot.updates
        checking = snapshot.checking
        progress = snapshot.progress
        lastChecked = snapshot.lastChecked
        messages = snapshot.messages
        busyID = snapshot.busyID
        checkWarnings = snapshot.checkWarnings
        checkedSources = snapshot.checkedSources
        checkWasCancelled = snapshot.checkWasCancelled
        commandLogs = snapshot.commandLogs
    }
#endif

    var emptyCheckMessage: String {
        if checkWasCancelled { return "检查已停止，结果可能不完整" }
        if !checkWarnings.isEmpty { return "部分来源检查失败，暂时无法确认全部更新" }
        if lastChecked == nil { return "尚未检查" }
        if checkedSources == 0 { return "未找到可检查的更新来源" }
        return "在已成功检查的来源中未发现可用更新"
    }

    func stopChecking() { checkTask?.cancel() }

    func check(apps: [ScannedApp], force: Bool = false) async {
        guard allowsLiveOperations else { return }
        guard !checking, busyID == nil, !Task.isCancelled else { return }
        // 失败或取消不缓存检查时间,立即重试不再等待。
        if !force, !checkWasCancelled, checkWarnings.isEmpty,
           let last = lastChecked, Date().timeIntervalSince(last) < 300 { return }
        checking = true
        checkWasCancelled = false
        checkWarnings = []
        checkedSources = 0
        // 已有执行记录保留；检查停止时展示本次完成的来源。
        let task = Task { await collectCheck(apps: apps) }
        checkTask = task
        await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
        checkTask = nil
    }

    private func collectCheck(apps: [ScannedApp]) async {
        defer { checking = false; progress = "" }
        let candidates = Self.sparkleCandidates(apps)
        progress = candidates.isEmpty ? "跳过 Sparkle 检查" : "正在检查 \(candidates.count) 个 Sparkle 应用…"
        var report = await Self.checkSparkle(candidates) { [weak self] done, total in
            await self?.showSparkleProgress(done, total)
        }
        if !Task.isCancelled {
            progress = "正在检查 Homebrew…"
            let brew = await brewChecker()
            report.updates += brew.updates
            report.warnings += brew.warnings
            report.checkedSources += brew.checkedSources
        }
        updates = report.updates.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        checkedSources = report.checkedSources
        checkWarnings = report.warnings
        checkWasCancelled = Task.isCancelled
        if !checkWasCancelled { lastChecked = Date() }
    }

    private func showSparkleProgress(_ done: Int, _ total: Int) {
        progress = "Sparkle 检查中 \(done)/\(total)"
    }

    func perform(_ info: UpdateInfo) async {
        guard allowsLiveOperations else { return }
        switch info.action {
        case .sparkle(let app):
            messages[info.id] = NSWorkspace.shared.open(app)
                ? "已打开应用,更新由它自己完成" : "无法打开应用,请确认它仍在原位置"
        case .brew(let token, let isCask):
            guard busyID == nil, !checking else { return }
            let operation = UUID()
            operationID = operation
            busyID = info.id
            defer { busyID = nil }
            messages[info.id] = "正在更新,可能需要几分钟…"
            guard let brew = Self.brewPath else {
                messages[info.id] = "找不到 Homebrew"
                return
            }
            let args = ["upgrade", isCask ? "--cask" : "--formula", token]
            let result = await CommandRunner.run(brew, args, timeout: 900) { [weak self] line in
                Task { @MainActor in
                    guard let self, self.busyID == info.id, self.operationID == operation else { return }
                    self.messages[info.id] = "正在更新:\(line)"
                }
            }
            commandLogs[info.id] = result.combined
            if result.code == 0 {
                updates.removeAll { $0.id == info.id }
                messages[info.id] = nil
            } else {
                messages[info.id] = "更新未完成:\(result.failureMessage)"
            }
        }
    }

    func lastCheckedText() -> String {
        guard let last = lastChecked else { return "尚未检查" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm:ss"
        return "上次检查 \(formatter.string(from: last))"
    }

    // ---------------------------------------------------------- Sparkle

    nonisolated static func sparkleCandidates(_ apps: [ScannedApp]) -> [SparkleCandidate] {
        apps.compactMap { app in
            guard app.version != "—",
                  let bundle = Bundle(url: app.url),
                  let feedString = bundle.infoDictionary?["SUFeedURL"] as? String,
                  let feed = URL(string: feedString),
                  feed.scheme == "https" || feed.scheme == "http" else { return nil }
            return SparkleCandidate(
                name: app.name, bundle: app.url, installed: app.version,
                build: bundle.infoDictionary?["CFBundleVersion"] as? String, feed: feed
            )
        }
    }

    nonisolated static func checkSparkle(
        _ candidates: [SparkleCandidate],
        progress: @escaping @Sendable (Int, Int) async -> Void
    ) async -> UpdateCheckReport {
        var report = UpdateCheckReport()
        await withTaskGroup(of: UpdateCheckReport.self) { group in
            var next = 0
            var done = 0
            while next < min(4, candidates.count), !Task.isCancelled {
                let candidate = candidates[next]
                group.addTask { await fetchSparkle(candidate) }
                next += 1
            }
            for await item in group {
                done += 1
                await progress(done, candidates.count)
                report.updates += item.updates
                report.warnings += item.warnings
                report.checkedSources += item.checkedSources
                if next < candidates.count, !Task.isCancelled {
                    let candidate = candidates[next]
                    group.addTask { await fetchSparkle(candidate) }
                    next += 1
                }
            }
        }
        return report
    }

    /// 构建号与显示版本分别比较,绝不交叉;按系统版本与机型过滤不兼容条目。
    nonisolated private static func fetchSparkle(_ candidate: SparkleCandidate) async -> UpdateCheckReport {
        var request = URLRequest(url: candidate.feed)
        request.timeoutInterval = 12
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw CheckError("更新源返回异常响应")
            }
            let items = try AppcastParser.items(in: data)
            let version = ProcessInfo.processInfo.operatingSystemVersion
            let os = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
            let compatible = items.filter { $0.isCompatible(with: os) }
            let useBuild = candidate.build?.isEmpty == false && compatible.contains { $0.build != nil }
            let comparable = compatible.filter { useBuild ? $0.build != nil : $0.displayVersion != nil }
            let newest = comparable.filter {
                $0.isNewer(thanBuild: useBuild ? candidate.build : nil, displayVersion: candidate.installed)
            }
            .max { $0.comparisonVersion(buildAvailable: useBuild).compare(
                $1.comparisonVersion(buildAvailable: useBuild), options: .numeric) == .orderedAscending }
            let updates = newest.map {
                [UpdateInfo(id: candidate.bundle.path, name: candidate.name, source: "Sparkle",
                            from: candidate.installed, to: $0.displayVersion ?? $0.build ?? "—",
                            action: .sparkle(app: candidate.bundle))]
            } ?? []
            return UpdateCheckReport(updates: updates, checkedSources: 1)
        } catch {
            if Task.isCancelled { return UpdateCheckReport() }
            return UpdateCheckReport(warnings: ["\(candidate.name):\(error.localizedDescription)"])
        }
    }

    // ---------------------------------------------------------- Homebrew

    nonisolated static var brewPath: String? {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    nonisolated static func checkBrew() async -> UpdateCheckReport {
        guard let brew = brewPath, !Task.isCancelled else { return UpdateCheckReport() }
        let result = await CommandRunner.run(brew, ["outdated", "--json=v2"], timeout: 90)
        if Task.isCancelled { return UpdateCheckReport() }
        return parseBrew(result)
    }

    /// 失败、截断或格式异常的输出都记为未完成的来源,而不是"没有更新"。
    nonisolated static func parseBrew(_ result: CommandRunner.Result) -> UpdateCheckReport {
        guard result.code == 0 else {
            return UpdateCheckReport(warnings: ["Homebrew:\(result.failureMessage)"])
        }
        guard !result.truncated,
              let data = result.output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let formulae = json["formulae"] as? [[String: Any]],
              let casks = json["casks"] as? [[String: Any]] else {
            return UpdateCheckReport(warnings: ["Homebrew:更新数据不完整或格式无法识别"])
        }
        var infos: [UpdateInfo] = []
        for (items, isCask) in [(formulae, false), (casks, true)] {
            for item in items {
                guard let name = item["name"] as? String, !name.isEmpty,
                      let latest = item["current_version"] as? String else {
                    return UpdateCheckReport(warnings: ["Homebrew:更新条目缺少必要字段"])
                }
                let current = (item["installed_versions"] as? [String])?.last
                    ?? (item["installed_versions"] as? String) ?? "—"
                infos.append(UpdateInfo(
                    id: "brew-\(isCask ? "cask" : "formula")-\(name)", name: name,
                    source: isCask ? "Homebrew Cask" : "Homebrew",
                    from: current, to: latest, action: .brew(token: name, isCask: isCask)
                ))
            }
        }
        return UpdateCheckReport(updates: infos, checkedSources: 1)
    }
}

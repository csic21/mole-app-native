import AppKit
import Foundation
import SwiftUI

/// 一条真实的可用更新。
struct UpdateInfo: Identifiable {
    enum Action {
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

@MainActor
final class UpdateStore: ObservableObject {
    @Published private(set) var updates: [UpdateInfo] = []
    @Published private(set) var checking = false
    @Published private(set) var progress = ""
    @Published private(set) var lastChecked: Date?
    @Published private(set) var messages: [String: String] = [:]
    @Published private(set) var busyID: String?

    func check(apps: [ScannedApp], force: Bool = false) async {
        guard !checking else { return }
        if !force, let last = lastChecked, Date().timeIntervalSince(last) < 300 { return }
        checking = true
        updates = []
        messages = [:]

        let candidates = Self.sparkleCandidates(apps)
        progress = candidates.isEmpty ? "跳过 Sparkle 检查" : "正在检查 \(candidates.count) 个 Sparkle 应用…"
        let sparkleUpdates = await Self.checkSparkle(candidates) { [weak self] done, total in
            Task { @MainActor in
                self?.progress = "Sparkle 检查中 \(done)/\(total)"
            }
        }

        progress = "正在检查 Homebrew…"
        let brewUpdates = await Self.checkBrew()

        updates = (sparkleUpdates + brewUpdates)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        lastChecked = Date()
        checking = false
        progress = ""
    }

    func perform(_ info: UpdateInfo) async {
        switch info.action {
        case .sparkle(let app):
            NSWorkspace.shared.open(app)
            messages[info.id] = "已打开应用,更新由它自己完成"
        case .brew(let token, let isCask):
            guard busyID == nil else { return }
            busyID = info.id
            messages[info.id] = "正在更新,可能需要几分钟…"
            guard let brew = Self.brewPath else {
                messages[info.id] = "找不到 brew"
                busyID = nil
                return
            }
            let args = isCask ? ["upgrade", "--cask", token] : ["upgrade", token]
            let result = await CommandRunner.run(brew, args, timeout: 900)
            busyID = nil
            if result.code == 0 {
                updates.removeAll { $0.id == info.id }
                messages[info.id] = nil
            } else {
                let text = result.combined.split(separator: "\n").last.map(String.init) ?? "未知错误"
                messages[info.id] = "更新失败:\(text)"
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

    nonisolated static func sparkleCandidates(
        _ apps: [ScannedApp]
    ) -> [(name: String, bundle: URL, installed: String, feed: URL)] {
        apps.compactMap { app in
            guard app.version != "—",
                  let bundle = Bundle(url: app.url),
                  let feedString = bundle.infoDictionary?["SUFeedURL"] as? String,
                  let feed = URL(string: feedString),
                  feed.scheme == "https" || feed.scheme == "http" else { return nil }
            return (app.name, app.url, app.version, feed)
        }
    }

    nonisolated static func checkSparkle(
        _ candidates: [(name: String, bundle: URL, installed: String, feed: URL)],
        progress: @escaping @Sendable (Int, Int) -> Void
    ) async -> [UpdateInfo] {
        guard !candidates.isEmpty else { return [] }
        var results: [UpdateInfo] = []
        await withTaskGroup(of: UpdateInfo?.self) { group in
            var next = 0
            var done = 0
            let limit = 4
            while next < min(limit, candidates.count) {
                let candidate = candidates[next]
                group.addTask { await fetchSparkle(candidate) }
                next += 1
            }
            for await item in group {
                done += 1
                progress(done, candidates.count)
                if let item { results.append(item) }
                if next < candidates.count {
                    let candidate = candidates[next]
                    group.addTask { await fetchSparkle(candidate) }
                    next += 1
                }
            }
        }
        return results
    }

    nonisolated private static func fetchSparkle(
        _ candidate: (name: String, bundle: URL, installed: String, feed: URL)
    ) async -> UpdateInfo? {
        var request = URLRequest(url: candidate.feed)
        request.timeoutInterval = 12
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        let versions = AppcastParser.versions(in: data)
        guard let latest = versions.max(by: {
            $0.compare($1, options: .numeric) == .orderedAscending
        }), latest.compare(candidate.installed, options: .numeric) == .orderedDescending else {
            return nil
        }
        return UpdateInfo(
            id: candidate.bundle.path,
            name: candidate.name,
            source: "Sparkle",
            from: candidate.installed,
            to: latest,
            action: .sparkle(app: candidate.bundle)
        )
    }

    // ---------------------------------------------------------- Homebrew

    nonisolated static var brewPath: String? {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    nonisolated static func checkBrew() async -> [UpdateInfo] {
        guard let brew = brewPath else { return [] }
        let result = await CommandRunner.run(brew, ["outdated", "--json=v2"], timeout: 90)
        guard result.code == 0,
              let data = result.output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        var infos: [UpdateInfo] = []

        if let formulae = json["formulae"] as? [[String: Any]] {
            for item in formulae {
                guard let name = item["name"] as? String else { continue }
                let current = (item["installed_versions"] as? [String])?.last
                    ?? (item["installed_versions"] as? String)
                    ?? "—"
                let latest = item["current_version"] as? String ?? "—"
                infos.append(UpdateInfo(
                    id: "brew-formula-\(name)", name: name, source: "Homebrew",
                    from: current, to: latest, action: .brew(token: name, isCask: false)
                ))
            }
        }
        if let casks = json["casks"] as? [[String: Any]] {
            for item in casks {
                guard let name = item["name"] as? String else { continue }
                let current = (item["installed_versions"] as? String)
                    ?? ((item["installed_versions"] as? [String])?.last)
                    ?? "—"
                let latest = item["current_version"] as? String ?? "—"
                infos.append(UpdateInfo(
                    id: "brew-cask-\(name)", name: name, source: "Homebrew Cask",
                    from: current, to: latest, action: .brew(token: name, isCask: true)
                ))
            }
        }
        return infos
    }
}

/// 只收集"像版本号"的值:属性/元素名白名单,避免把 minimumSystemVersion 误当版本。
final class AppcastParser: NSObject, XMLParserDelegate {
    private var versions = Set<String>()
    private var capturing = false
    private var buffer = ""
    private var capturingName = ""

    static func versions(in data: Data) -> [String] {
        let delegate = AppcastParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return Array(delegate.versions)
    }

    private func isVersionKey(_ raw: String) -> Bool {
        let key = raw.lowercased()
        return key == "version"
            || key == "sparkle:version"
            || key.hasSuffix("shortversionstring")
            || key.hasSuffix("short_version_string")
            || key.hasSuffix("shortversion")
    }

    private func isPlausible(_ raw: String) -> Bool {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = text.first, first.isNumber else { return false }
        return text.contains(".") || Int(text) != nil
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        let element = qName ?? elementName
        for (key, value) in attributeDict where isVersionKey(key) {
            if isPlausible(value) { versions.insert(value.trimmingCharacters(in: .whitespaces)) }
        }
        if isVersionKey(element) {
            capturing = true
            capturingName = element
            buffer = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturing { buffer += string }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let element = qName ?? elementName
        if capturing && element == capturingName {
            if isPlausible(buffer) {
                versions.insert(buffer.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            capturing = false
            buffer = ""
        }
    }
}

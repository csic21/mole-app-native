import Foundation
import SwiftUI

/// 真实登录项(LaunchAgents / LaunchDaemons),来自系统公开机制。
struct LoginEntry: Identifiable {
    enum Scope {
        case user      // ~/Library/LaunchAgents:可启停
        case system    // /Library/...:只读
    }

    let id: String       // plist 路径
    let label: String
    let program: String?
    let scope: Scope
    var loaded = false
    var disabled = false
    var configuredDisabled = false
    var processID: Int32?
    var stateKnown = false

    /// 加载状态与真实运行状态分别描述;"停用"不排除仍在运行的实例。
    var stateText: String {
        if scope == .system { return "只读" }
        if !stateKnown { return "状态未知" }
        if disabled { return processID == nil ? "已停用" : "已停用 · 仍在运行" }
        if processID != nil { return "已启用 · 运行中" }
        return loaded ? "已启用 · 等待触发" : "已启用 · 未加载"
    }
}

@MainActor
final class LoginItemsStore: ObservableObject {
    @Published private(set) var entries: [LoginEntry] = []
    @Published private(set) var scanning = false
    @Published private(set) var errors: [String: String] = [:]
    @Published private(set) var busyIDs: Set<String> = []
    @Published private(set) var stateError: String?

    /// DEBUG snapshots never inspect or change the machine's launch services.
    private(set) var allowsLiveOperations = true
    private var scanTask: Task<Void, Never>?
    private var scanGeneration = UUID()
    private var stateGeneration = UUID()

    init() {}

#if DEBUG
    struct Snapshot {
        var entries: [LoginEntry] = []
        var scanning = false
        var errors: [String: String] = [:]
        var busyIDs: Set<String> = []
        var stateError: String? = nil
    }

    convenience init(snapshot: Snapshot) {
        self.init()
        precondition(snapshot.entries.allSatisfy { entry in
            URL(fileURLWithPath: entry.id).standardizedFileURL.path.hasPrefix("/QiliPreview/")
                && (entry.program.map {
                    URL(fileURLWithPath: $0).standardizedFileURL.path.hasPrefix("/QiliPreview/")
                } ?? true)
        }, "Snapshot fixtures must use synthetic /QiliPreview paths")
        allowsLiveOperations = false
        entries = snapshot.entries
        scanning = snapshot.scanning
        errors = snapshot.errors
        busyIDs = snapshot.busyIDs
        stateError = snapshot.stateError
    }
#endif

    func scan() {
        guard allowsLiveOperations else { return }
        guard busyIDs.isEmpty else { return }
        scanTask?.cancel()
        let generation = UUID()
        scanGeneration = generation
        scanning = true
        scanTask = Task { [weak self] in
            let discovered = await Task.detached(priority: .userInitiated) {
                Self.discover()
            }.value
            guard let self, !Task.isCancelled, generation == self.scanGeneration else { return }
            self.entries = discovered
            await self.refreshStates()
            if generation == self.scanGeneration { self.scanning = false }
        }
    }

    /// 加载状态与真实 PID 分别读取;读不到时明确标注,而不是当作"未运行"。
    func refreshStates() async {
        guard allowsLiveOperations else { return }
        let generation = UUID()
        stateGeneration = generation
        let uid = getuid()
        async let list = CommandRunner.run("/bin/launchctl", ["list"], timeout: 15)
        async let overrides = CommandRunner.run("/bin/launchctl", ["print-disabled", "gui/\(uid)"], timeout: 15)
        let (listResult, overrideResult) = await (list, overrides)
        guard generation == stateGeneration, !Task.isCancelled else { return }
        guard listResult.code == 0, overrideResult.code == 0,
              !listResult.truncated, !overrideResult.truncated else {
            let reason = listResult.truncated || overrideResult.truncated ? "状态输出过长"
                : (listResult.code != 0 ? listResult : overrideResult).failureMessage
            stateError = "无法读取启动项状态:\(reason)"
            entries = entries.map { var copy = $0; copy.stateKnown = false; return copy }
            return
        }
        stateError = nil
        let loaded = Self.parseLoaded(listResult.output)
        let disabled = Self.parseDisabled(overrideResult.output)
        entries = entries.map { entry in
            var next = entry
            next.loaded = loaded[entry.label] != nil
            next.processID = loaded[entry.label]?.processID
            next.disabled = disabled[entry.label] ?? entry.configuredDisabled
            next.stateKnown = true
            return next
        }
    }

    /// 用户级:enable/disable 持久生效;disable 时顺带停掉当前实例。
    func setEnabled(_ entry: LoginEntry, enabled: Bool) async {
        guard allowsLiveOperations else { return }
        guard entry.scope == .user else {
            errors[entry.id] = "系统级条目需要管理员权限,暂不支持"
            return
        }
        guard !scanning, entry.stateKnown, busyIDs.isEmpty else { return }
        busyIDs.insert(entry.id)
        defer { busyIDs.remove(entry.id) }
        let uid = getuid()
        let domain = "gui/\(uid)"
        errors[entry.id] = nil

        let toggle = await CommandRunner.run(
            "/bin/launchctl",
            [enabled ? "enable" : "disable", "\(domain)/\(entry.label)"],
            timeout: 15
        )
        guard toggle.code == 0 else {
            errors[entry.id] = firstLine(toggle.combined)
            await refreshStates()
            return
        }

        if enabled && !entry.loaded {
            let bootstrap = await CommandRunner.run(
                "/bin/launchctl", ["bootstrap", domain, entry.id], timeout: 15
            )
            if bootstrap.code != 0 {
                // 不依赖本地化的错误字符串判断是否已经加载。
                let state = await CommandRunner.run(
                    "/bin/launchctl", ["print", "\(domain)/\(entry.label)"], timeout: 15
                )
                if state.code != 0 { errors[entry.id] = bootstrap.failureMessage }
            }
        } else if !enabled && entry.loaded {
            let bootout = await CommandRunner.run(
                "/bin/launchctl", ["bootout", domain, entry.id], timeout: 15
            )
            if bootout.code != 0 {
                errors[entry.id] = "已请求停用,但卸载失败:\(bootout.failureMessage)"
            }
        }
        await refreshStates()
    }

    // ---------------------------------------------------------- 系统读取

    nonisolated static func discover() -> [LoginEntry] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let sources: [(URL, LoginEntry.Scope)] = [
            (home.appendingPathComponent("Library/LaunchAgents"), .user),
            (URL(fileURLWithPath: "/Library/LaunchAgents"), .system),
            (URL(fileURLWithPath: "/Library/LaunchDaemons"), .system),
        ]
        var entries: [LoginEntry] = []
        var seen = Set<String>()

        for (dir, scope) in sources {
            let files = (try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil
            )) ?? []
            for file in files where file.pathExtension == "plist" {
                guard !seen.contains(file.path) else { continue }
                seen.insert(file.path)
                guard let data = try? Data(contentsOf: file),
                      let plist = try? PropertyListSerialization.propertyList(
                          from: data, format: nil
                      ) as? [String: Any] else { continue }
                let label = (plist["Label"] as? String)
                    ?? file.deletingPathExtension().lastPathComponent
                let program = (plist["Program"] as? String)
                    ?? (plist["ProgramArguments"] as? [String])?.first
                entries.append(LoginEntry(
                    id: file.path, label: label, program: program, scope: scope,
                    configuredDisabled: (plist["Disabled"] as? Bool) ?? false
                ))
            }
        }
        return entries.sorted {
            $0.label.localizedStandardCompare($1.label) == .orderedAscending
        }
    }

    struct ServiceState {
        let processID: Int32?
        let lastExit: Int32
    }

    /// `launchctl list`:PID 为 "-" 表示已加载但未运行;最后一列才是标签。
    nonisolated static func parseLoaded(_ output: String) -> [String: ServiceState] {
        var labels: [String: ServiceState] = [:]
        for line in output.split(separator: "\n") {
            let tabs = line.split(separator: "\t", omittingEmptySubsequences: false)
            let parts = tabs.count == 3 ? tabs : line.split(maxSplits: 2, whereSeparator: { $0 == "\t" || $0 == " " })
            guard parts.count >= 3, let exit = Int32(parts[1]),
                  parts[0] == "-" || Int32(parts[0]) != nil else { continue }
            labels[String(parts[2]).trimmingCharacters(in: .whitespaces)] = ServiceState(
                processID: Int32(parts[0]), lastExit: exit
            )
        }
        return labels
    }

    /// `launchctl print-disabled` 的 true/false 都保留,显式启用覆盖 plist 的 Disabled。
    nonisolated static func parseDisabled(_ output: String) -> [String: Bool] {
        var labels: [String: Bool] = [:]
        for line in output.split(separator: "\n") {
            guard let arrow = line.range(of: "=>") else { continue }
            let value = line[arrow.upperBound...].trimmingCharacters(in: .whitespaces)
            let disabled: Bool
            if value.hasPrefix("true") { disabled = true }
            else if value.hasPrefix("false") { disabled = false }
            else { continue }
            let key = line[..<arrow.lowerBound]
                .trimmingCharacters(in: CharacterSet(charactersIn: " \t\""))
            if !key.isEmpty { labels[key] = disabled }
        }
        return labels
    }

    private func firstLine(_ text: String) -> String {
        text.split(separator: "\n").first.map(String.init) ?? text
    }
}

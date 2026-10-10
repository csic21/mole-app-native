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
}

@MainActor
final class LoginItemsStore: ObservableObject {
    @Published private(set) var entries: [LoginEntry] = []
    @Published private(set) var scanning = false
    @Published private(set) var errors: [String: String] = [:]

    func scan() {
        scanning = true
        Task { [weak self] in
            let discovered = await Task.detached(priority: .userInitiated) {
                Self.discover()
            }.value
            guard let self, !Task.isCancelled else { return }
            self.entries = discovered
            self.scanning = false
            await self.refreshStates()
        }
    }

    func refreshStates() async {
        let uid = getuid()
        let (loaded, disabled) = await Task.detached(priority: .utility) {
            (Self.loadedLabels(uid: uid), Self.disabledLabels(uid: uid))
        }.value
        entries = entries.map { entry in
            var next = entry
            next.loaded = loaded.contains(entry.label)
            next.disabled = disabled.contains(entry.label)
            return next
        }
    }

    /// 用户级:enable/disable 持久生效;disable 时顺带停掉当前实例。
    func setEnabled(_ entry: LoginEntry, enabled: Bool) async {
        guard entry.scope == .user else {
            errors[entry.id] = "系统级条目需要管理员权限,暂不支持"
            return
        }
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

        if enabled {
            let bootstrap = await CommandRunner.run(
                "/bin/launchctl", ["bootstrap", domain, entry.id], timeout: 15
            )
            if bootstrap.code != 0 && !bootstrap.combined.contains("already") {
                errors[entry.id] = firstLine(bootstrap.combined)
            }
        } else if entry.loaded {
            let bootout = await CommandRunner.run(
                "/bin/launchctl", ["bootout", domain, entry.id], timeout: 15
            )
            if bootout.code != 0 && !bootout.combined.contains("not found") {
                errors[entry.id] = firstLine(bootout.combined)
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
                    id: file.path, label: label, program: program, scope: scope
                ))
            }
        }
        return entries.sorted {
            $0.label.localizedStandardCompare($1.label) == .orderedAscending
        }
    }

    nonisolated static func loadedLabels(uid: uid_t) -> Set<String> {
        let result = CommandRunner.runSync("/bin/launchctl", ["list"], timeout: 15)
        var labels = Set<String>()
        for line in result.output.split(separator: "\n").dropFirst() {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            if let label = parts.last, !label.isEmpty {
                labels.insert(String(label).trimmingCharacters(in: .whitespaces))
            }
        }
        return labels
    }

    nonisolated static func disabledLabels(uid: uid_t) -> Set<String> {
        let result = CommandRunner.runSync(
            "/bin/launchctl", ["print-disabled", "gui/\(uid)"], timeout: 15
        )
        var labels = Set<String>()
        for line in result.output.split(separator: "\n") {
            guard let arrow = line.range(of: "=>") else { continue }
            let value = line[arrow.upperBound...].trimmingCharacters(in: .whitespaces)
            guard value.hasPrefix("true") else { continue }
            let key = line[..<arrow.lowerBound]
                .trimmingCharacters(in: CharacterSet(charactersIn: " \t\""))
            if !key.isEmpty { labels.insert(key) }
        }
        return labels
    }

    private func firstLine(_ text: String) -> String {
        text.split(separator: "\n").first.map(String.init) ?? text
    }
}

import AppKit
import SwiftUI

/// 一台机器上真实扫描到的应用。
struct ScannedApp: Identifiable {
    let id: String
    let url: URL
    let name: String
    let version: String
    let bundleID: String
    let modified: String
    var sizeBytes: Int64?
    var icon: NSImage?
}

/// 展开时按 Bundle ID / 名称找出的关联残留(存在才算)。
struct LeftoverItem: Identifiable {
    let id: String
    let kind: String
    let path: String
    let sizeBytes: Int64
}

@MainActor
final class AppsStore: ObservableObject {
    @Published private(set) var apps: [ScannedApp] = []
    @Published private(set) var scanning = false
    @Published private(set) var sizedCount = 0

    private var sizeTask: Task<Void, Never>?

    func refresh() {
        sizeTask?.cancel()
        scanning = true
        sizedCount = 0
        apps = []
        Task.detached(priority: .userInitiated) { [weak self] in
            let basic = Self.discoverApps()
            await self?.publish(basic)
            await self?.measureSizes()
        }
    }

    private func publish(_ basic: [ScannedApp]) {
        apps = basic.map { item in
            var app = item
            app.icon = NSWorkspace.shared.icon(forFile: item.url.path)
            return app
        }
        scanning = false
    }

    /// 只做轻量枚举:名称、版本、Bundle ID、修改时间。图标在 MainActor 上补。
    nonisolated private static func discoverApps() -> [ScannedApp] {
        var roots: [URL] = [URL(fileURLWithPath: "/Applications")]
        let userApps = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        if FileManager.default.fileExists(atPath: userApps.path) {
            roots.append(userApps)
        }

        var result: [ScannedApp] = []
        var seen = Set<String>()
        let keys: [URLResourceKey] = [.isDirectoryKey, .contentModificationDateKey]

        for root in roots {
            let entries = (try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            )) ?? []
            for entry in entries where entry.pathExtension == "app" {
                guard !seen.contains(entry.path) else { continue }
                seen.insert(entry.path)

                let bundle = Bundle(url: entry)
                let info = bundle?.infoDictionary
                let displayName = (info?["CFBundleDisplayName"] as? String)
                    ?? (info?["CFBundleName"] as? String)
                    ?? entry.deletingPathExtension().lastPathComponent
                let version = (info?["CFBundleShortVersionString"] as? String) ?? "—"
                let bundleID = bundle?.bundleIdentifier ?? ""
                let modified = (try? entry.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate
                result.append(ScannedApp(
                    id: entry.path,
                    url: entry,
                    name: displayName,
                    version: version,
                    bundleID: bundleID,
                    modified: Self.relativeDate(modified),
                    sizeBytes: nil,
                    icon: nil
                ))
            }
        }
        return result.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    /// 逐个测量体积:最多四个并发,按原始顺序回填。
    private func measureSizes() async {
        let snapshot = apps
        sizeTask = Task { [weak self] in
            await withTaskGroup(of: (Int, Int64).self) { group in
                var next = 0
                let limit = 4
                while next < min(limit, snapshot.count) {
                    let index = next
                    let url = snapshot[index].url
                    group.addTask { (index, Self.directorySize(url)) }
                    next += 1
                }
                for await (index, size) in group {
                    guard let self, !Task.isCancelled else { return }
                    if index < self.apps.count {
                        self.apps[index].sizeBytes = size
                        self.sizedCount += 1
                    }
                    if next < snapshot.count {
                        let nextIndex = next
                        let url = snapshot[nextIndex].url
                        group.addTask { (nextIndex, Self.directorySize(url)) }
                        next += 1
                    }
                }
            }
        }
        await sizeTask?.value
    }

    nonisolated static func directorySize(_ url: URL) -> Int64 {
        var total: Int64 = 0
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: keys),
                  values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return total
    }

    /// 按 Bundle ID / 名称找出真实存在的关联文件。
    nonisolated static func leftovers(for app: ScannedApp) -> [LeftoverItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var candidates: [(String, URL)] = [
            ("App", app.url),
        ]
        if !app.bundleID.isEmpty {
            candidates += [
                ("偏好设置", home.appendingPathComponent("Library/Preferences/\(app.bundleID).plist")),
                ("应用支持", home.appendingPathComponent("Library/Application Support/\(app.bundleID)")),
                ("缓存", home.appendingPathComponent("Library/Caches/\(app.bundleID)")),
                ("窗口状态", home.appendingPathComponent("Library/Saved Application State/\(app.bundleID).savedState")),
            ]
        }
        candidates.append(("应用支持", home.appendingPathComponent("Library/Application Support/\(app.name)")))

        var items: [LeftoverItem] = []
        var seen = Set<String>()
        for (kind, url) in candidates where !seen.contains(url.path) {
            seen.insert(url.path)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let size: Int64
            if url.pathExtension == "plist" {
                size = Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            } else {
                size = directorySize(url)
            }
            items.append(LeftoverItem(id: url.path, kind: kind, path: Self.tildePath(url), sizeBytes: size))
        }
        return items
    }

    nonisolated static func tildePath(_ url: URL) -> String {
        url.path.replacingOccurrences(
            of: FileManager.default.homeDirectoryForCurrentUser.path,
            with: "~"
        )
    }

    nonisolated static func relativeDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    nonisolated static func formatBytes(_ bytes: Int64?) -> String {
        guard let bytes else { return "测量中…" }
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        return "\(max(1, bytes / 1024)) KB"
    }
}

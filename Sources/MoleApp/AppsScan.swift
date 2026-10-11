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
    var partial = false
}

/// 展开时按 Bundle ID / 名称找出的关联残留(存在才算)。
struct LeftoverItem: Identifiable {
    let id: String
    let kind: String
    let path: String
    let sizeBytes: Int64
    var partial = false
}

@MainActor
final class AppsStore: ObservableObject {
    @Published private(set) var apps: [ScannedApp] = []
    @Published private(set) var scanning = false
    @Published private(set) var sizedCount = 0
    @Published private(set) var measuring = false
    @Published private(set) var generation = 0
    @Published private(set) var hasScanned = false
    @Published private(set) var stopped = false

    /// DEBUG snapshots keep every filesystem entry point inert, even from view tasks.
    private(set) var allowsLiveOperations = true
    private var sizeTask: Task<Void, Never>?

    init() {}

#if DEBUG
    struct Snapshot {
        var apps: [ScannedApp] = []
        var scanning = false
        var sizedCount = 0
        var measuring = false
        var generation = 0
        var hasScanned = true
        var stopped = false
    }

    convenience init(snapshot: Snapshot) {
        self.init()
        precondition(snapshot.apps.allSatisfy {
            $0.url.standardizedFileURL.path.hasPrefix("/QiliPreview/")
                && URL(fileURLWithPath: $0.id).standardizedFileURL.path.hasPrefix("/QiliPreview/")
        }, "Snapshot fixtures must use synthetic /QiliPreview paths")
        allowsLiveOperations = false
        apps = snapshot.apps
        scanning = snapshot.scanning
        sizedCount = snapshot.sizedCount
        measuring = snapshot.measuring
        generation = snapshot.generation
        hasScanned = snapshot.hasScanned
        stopped = snapshot.stopped
    }
#endif

    func refresh() {
        guard allowsLiveOperations else { return }
        sizeTask?.cancel()
        generation += 1
        stopped = false
        let revision = generation
        scanning = true
        measuring = true
        sizedCount = 0
        sizeTask = Task { [weak self] in
            let discovery = Task.detached(priority: .userInitiated) { Self.discoverApps() }
            let basic = await withTaskCancellationHandler { await discovery.value } onCancel: { discovery.cancel() }
            guard let self, !Task.isCancelled, self.generation == revision else { return }
            self.apps = basic
            self.hasScanned = true
            self.scanning = false
            await self.measureSizes(basic, revision: revision)
            guard !Task.isCancelled, self.generation == revision else { return }
            self.measuring = false
        }
    }

    func stopMeasuring() {
        guard allowsLiveOperations else { return }
        sizeTask?.cancel()
        stopped = true
        scanning = false
        measuring = false
    }

    func loadIcon(for id: String) {
        guard allowsLiveOperations else { return }
        guard let index = apps.firstIndex(where: { $0.id == id }), apps[index].icon == nil else { return }
        apps[index].icon = NSWorkspace.shared.icon(forFile: apps[index].url.path)
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
                if Task.isCancelled { return result }
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

    /// 单一父任务管理发现与测量；按路径回填，旧扫描不会污染新列表。
    private func measureSizes(_ snapshot: [ScannedApp], revision: Int) async {
        await withTaskGroup(of: (String, FileSizer.Measurement).self) { group in
            var next = 0
            func enqueue() {
                let item = snapshot[next]
                group.addTask { (item.id, FileSizer.measure(item.url)) }
                next += 1
            }
            while next < min(4, snapshot.count) { enqueue() }
            for await (id, size) in group {
                guard !Task.isCancelled, generation == revision else { group.cancelAll(); return }
                if let index = apps.firstIndex(where: { $0.id == id }) {
                    apps[index].sizeBytes = size.bytes
                    apps[index].partial = size.partial
                    sizedCount += 1
                }
                if next < snapshot.count { enqueue() }
            }
        }
    }

    nonisolated static func directorySize(_ url: URL) -> Int64 { FileSizer.measure(url).bytes }

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
            if Task.isCancelled { break }
            seen.insert(url.path)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let size: FileSizer.Measurement
            if url == app.url, let bytes = app.sizeBytes {
                size = FileSizer.Measurement(bytes: bytes, partial: app.partial)
            } else { size = FileSizer.measure(url) }
            items.append(LeftoverItem(id: url.path, kind: kind, path: Self.tildePath(url), sizeBytes: size.bytes, partial: size.partial))
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
        if bytes == 0 { return "0 B" }
        if bytes < 1024 { return "\(bytes) B" }
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        return "\(max(1, bytes / 1024)) KB"
    }
}

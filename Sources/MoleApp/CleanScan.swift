import AppKit
import SwiftUI

/// 一条可清理项(真实路径 + 真实体积)。
struct CleanItem: Identifiable {
    let id: String
    let name: String
    let sizeBytes: Int64
    var partial = false
}

/// 一个清理类别:固定白名单目录,绝不越界。
struct CleanCategory: Identifiable {
    enum Mode {
        case children   // 清理 root 下的一级子项
        case whole      // 清理 root 本身
    }

    let id: String
    let title: String
    let note: String
    let root: URL
    let mode: Mode
    var skipPrefixes: [String] = []
    var skipNames: Set<String> = []
    var partial = false
    var measured = false
    var sizeBytes: Int64 = 0
    var children: [CleanItem] = []
}

/// 清理方式:移到废纸篓(可从访达恢复,清空前仍占磁盘)或直接删除(立即释放空间,不可恢复)。
enum CleanupMode: Sendable {
    case trash
    case delete
}

/// 一次清理的结果,按真实计数汇报;不声称释放了多少空间。
struct CleanupResult {
    let mode: CleanupMode
    let cleaned: Int
    let failed: Int
    let cleanedBytes: Int64
    var failures: [String] = []

    init(mode: CleanupMode = .trash, cleaned: Int, failed: Int, cleanedBytes: Int64, failures: [String] = []) {
        self.mode = mode
        self.cleaned = cleaned
        self.failed = failed
        self.cleanedBytes = cleanedBytes
        self.failures = failures
    }
}

/// 清理过程的真实计数进度。只报项数,不预估时间。
struct CleanupProgress: Sendable {
    var completed = 0
    var total = 0
    var currentName = ""
    var cleanedBytes: Int64 = 0
}

@MainActor
final class CleanStore: ObservableObject {
    @Published private(set) var categories: [CleanCategory] = []
    @Published private(set) var scanning = false
    @Published private(set) var measuredCount = 0
    enum Phase { case ready, scanning, result, list, trashing, done }
    @Published var phase: Phase = .ready
    @Published var selected: Set<String> = []
    @Published var expanded: Set<String> = []
    @Published private(set) var result: CleanupResult?
    /// 当前或最近一次清理采用的方式,决定过程与结果文案。
    @Published private(set) var cleanupMode: CleanupMode = .trash
    /// 清理过程的计数进度,随每项完成更新。
    @Published private(set) var cleanupProgress = CleanupProgress()
    @Published private(set) var stopped = false
    @Published private(set) var currentCategory = ""
    @Published private(set) var hasScanned = false

    /// False only for isolated DEBUG fixtures. No preview can start filesystem work.
    private(set) var allowsLiveOperations = true

    init() {}

#if DEBUG
    /// Test-only state injection; constructing this never scans or creates files.
    struct Snapshot {
        var phase: Phase
        var categories: [CleanCategory] = []
        var scanning = false
        var measuredCount = 0
        var selected: Set<String> = []
        var expanded: Set<String> = []
        var result: CleanupResult? = nil
        var stopped = false
        var currentCategory = ""
        var hasScanned = true
        var cleanupMode: CleanupMode = .trash
        var cleanupProgress = CleanupProgress()
    }

    convenience init(snapshot: Snapshot) {
        self.init()
        // Keep even accidental fixture paths outside the user's home and live roots.
        precondition(snapshot.categories.allSatisfy { category in
            category.root.standardizedFileURL.path.hasPrefix("/QiliPreview/")
                && category.children.allSatisfy {
                    URL(fileURLWithPath: $0.id).standardizedFileURL.path.hasPrefix("/QiliPreview/")
                }
        }, "Snapshot fixtures must use synthetic /QiliPreview paths")
        allowsLiveOperations = false
        phase = snapshot.phase
        categories = snapshot.categories
        scanning = snapshot.scanning
        measuredCount = snapshot.measuredCount
        selected = snapshot.selected
        expanded = snapshot.expanded
        result = snapshot.result
        stopped = snapshot.stopped
        currentCategory = snapshot.currentCategory
        hasScanned = snapshot.hasScanned
        cleanupMode = snapshot.cleanupMode
        cleanupProgress = snapshot.cleanupProgress
    }
#endif

    var selectedItems: [CleanItem] {
        categories.flatMap(\.children).filter { selected.contains($0.id) }
    }

    func toggleCategory(_ category: CleanCategory) {
        let ids = Set(category.children.map(\.id))
        if ids.isSubset(of: selected) { selected.subtract(ids) }
        else { selected.formUnion(ids) }
    }

    func toggleItem(_ id: String) {
        if !selected.insert(id).inserted { selected.remove(id) }
    }

    func stop() {
        guard allowsLiveOperations else { return }
        scanTask?.cancel()
        scanning = false
        stopped = true
        for index in categories.indices where !categories[index].measured && !categories[index].children.isEmpty {
            categories[index].partial = true
            categories[index].measured = true
        }
        if phase == .scanning { phase = .result }
    }

    private var scanTask: Task<Void, Never>?

    static func defaultCategories() -> [CleanCategory] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            CleanCategory(
                id: "user-caches", title: "用户缓存", note: "应用缓存,删除后会自动重建",
                root: home.appendingPathComponent("Library/Caches"), mode: .children,
                skipPrefixes: ["com.apple."]
            ),
            CleanCategory(
                id: "user-logs", title: "用户日志", note: "诊断与运行日志",
                root: home.appendingPathComponent("Library/Logs"), mode: .children,
                skipNames: ["DiagnosticReports"]
            ),
            CleanCategory(
                id: "xcode-derived", title: "Xcode 构建缓存", note: "DerivedData,重新构建即可恢复",
                root: home.appendingPathComponent("Library/Developer/Xcode/DerivedData"), mode: .children
            ),
            CleanCategory(
                id: "xcode-device", title: "Xcode 设备支持", note: "设备符号,重新连接设备会恢复",
                root: home.appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport"), mode: .children
            ),
            CleanCategory(
                id: "npm", title: "npm 缓存", note: "_cacache,重新下载即可",
                root: home.appendingPathComponent(".npm/_cacache"), mode: .whole
            ),
        ]
    }

    func scan(showProgress: Bool = true) {
        guard allowsLiveOperations else { return }
        guard phase != .trashing else { return }
        scanTask?.cancel()
        hasScanned = true
        currentCategory = "准备扫描"
        if showProgress { phase = .scanning }
        selected = []
        expanded = []
        stopped = false
        categories = Self.defaultCategories().filter {
            FileManager.default.fileExists(atPath: $0.root.path)
        }
        scanning = true
        measuredCount = 0
        scanTask = Task { [weak self] in
            guard let self else { return }
            for (index, category) in self.categories.enumerated() {
                if Task.isCancelled { return }
                self.currentCategory = category.title
                let measured = await Self.measure(category) { [weak self] progress in
                    guard !Task.isCancelled, let self, index < self.categories.count else { return }
                    self.categories[index] = progress
                }
                guard !Task.isCancelled else { return }
                if index < self.categories.count {
                    self.categories[index] = measured
                    self.measuredCount += 1
                }
            }
            self.scanning = false
            if self.phase == .scanning { self.phase = .result }
        }
    }

    /// 枚举一级子项(跳过隐藏与符号链接),四并发测体积。
    nonisolated static func measure(_ category: CleanCategory, onProgress: (@MainActor (CleanCategory) -> Void)? = nil) async -> CleanCategory {
        var result = category
        let fm = FileManager.default
        var targets: [URL] = []
        guard !Task.isCancelled else { return result }

        switch category.mode {
        case .whole:
            targets = [category.root]
        case .children:
            let entries: [URL]
            do {
                entries = try fm.contentsOfDirectory(at: category.root,
                    includingPropertiesForKeys: [.isSymbolicLinkKey], options: [])
            } catch {
                result.measured = true
                result.partial = true
                return result
            }
            targets = entries.filter { url in
                let name = url.lastPathComponent
                if name.hasPrefix(".") { return false }
                if category.skipNames.contains(name) { return false }
                if category.skipPrefixes.contains(where: { name.hasPrefix($0) }) { return false }
                let isLink = (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) ?? false
                return isLink != true
            }
        }

        var items: [CleanItem] = []
        var lastProgress = ProcessInfo.processInfo.systemUptime
        await withTaskGroup(of: CleanItem.self) { group in
            var next = 0
            func enqueue() {
                let url = targets[next]
                group.addTask {
                    let size = FileSizer.measure(url)
                    return CleanItem(id: url.path, name: url.lastPathComponent, sizeBytes: size.bytes, partial: size.partial)
                }
                next += 1
            }
            while next < min(4, targets.count) { enqueue() }
            for await item in group {
                if Task.isCancelled { group.cancelAll(); return }
                items.append(item)
                let now = ProcessInfo.processInfo.systemUptime
                if now - lastProgress >= 0.15 {
                    var progress = category
                    progress.children = items.sorted { $0.sizeBytes > $1.sizeBytes }
                    progress.sizeBytes = items.reduce(0) { $0 + $1.sizeBytes }
                    progress.partial = true
                    await onProgress?(progress)
                    lastProgress = now
                }
                if next < targets.count { enqueue() }
            }
        }

        items.sort { $0.sizeBytes > $1.sizeBytes }
        result.children = items
        result.sizeBytes = items.reduce(0) { $0 + $1.sizeBytes }
        result.measured = true
        result.partial = items.contains { $0.partial }
        return result
    }

    /// 只处理已勾选的真实子项。清理放在后台，页面切换不会丢失结果。
    func cleanup(mode: CleanupMode = .trash) async {
        guard allowsLiveOperations else { return }
        guard phase != .trashing, !scanning, !selected.isEmpty else { return }
        let snapshot = categories
        let ids = selected
        cleanupMode = mode
        cleanupProgress = CleanupProgress(total: ids.count)
        phase = .trashing
        result = await Task.detached(priority: .userInitiated) { [weak self] in
            await Self.performCleanup(categories: snapshot, selected: ids, mode: mode) { [weak self] progress in
                guard let self else { return }
                self.cleanupProgress = progress
            }
        }.value
        phase = .done
        scan(showProgress: false)
    }

    nonisolated private static func performCleanup(categories: [CleanCategory], selected: Set<String>,
                                                   mode: CleanupMode,
                                                   onProgress: (@MainActor (CleanupProgress) -> Void)? = nil) async -> CleanupResult {
        let fm = FileManager.default
        var cleaned = 0
        var failures: [String] = []
        var bytes: Int64 = 0
        var completed = 0
        var lastReport = ProcessInfo.processInfo.systemUptime
        for category in categories {
            for item in category.children where selected.contains(item.id) {
                let url = URL(fileURLWithPath: item.id).standardizedFileURL
                // 检查整条路径，防止扫描后父目录被替换为符号链接。
                if !isValidCleanupTarget(url, category: category) {
                    failures.append("\(item.name)：路径已变化或不可访问")
                } else {
                    do {
                        switch mode {
                        case .trash:
                            try fm.trashItem(at: url, resultingItemURL: nil)
                        case .delete:
                            try fm.removeItem(at: url)
                        }
                        cleaned += 1
                        bytes += item.sizeBytes
                    } catch {
                        failures.append("\(item.name)：\(error.localizedDescription)")
                    }
                }
                completed += 1
                let now = ProcessInfo.processInfo.systemUptime
                if now - lastReport >= 0.1 || completed == selected.count {
                    lastReport = now
                    await onProgress?(CleanupProgress(completed: completed, total: selected.count,
                        currentName: item.name, cleanedBytes: bytes))
                }
            }
        }
        return CleanupResult(mode: mode, cleaned: cleaned, failed: failures.count,
                             cleanedBytes: bytes, failures: failures)
    }
    nonisolated static func isValidCleanupTarget(_ url: URL, category: CleanCategory) -> Bool {
        let root = category.root.standardizedFileURL
        let target = url.standardizedFileURL
        guard target.resolvingSymlinksInPath().path == target.path,
              root.resolvingSymlinksInPath().path == root.path,
              (category.mode == .whole ? target.path == root.path : target.deletingLastPathComponent().path == root.path),
              let values = try? target.resourceValues(forKeys: [.isSymbolicLinkKey]),
              values.isSymbolicLink != true else { return false }
        return true
    }

}

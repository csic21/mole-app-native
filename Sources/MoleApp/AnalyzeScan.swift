import AppKit
import SwiftUI

/// 分析页的一项:真实文件或目录,体积逐步测量。
struct AnalyzeItem: Identifiable {
    let id: String
    let url: URL
    let name: String
    let isDirectory: Bool
    var sizeBytes: Int64?
    var partial = false
}

@MainActor
final class AnalyzeStore: ObservableObject {
    @Published private(set) var path: [URL] = []
    @Published private(set) var items: [AnalyzeItem] = []
    @Published private(set) var sizing = false
    @Published private(set) var sizedCount = 0

    let home = FileManager.default.homeDirectoryForCurrentUser
    private var task: Task<Void, Never>?

    init() {
        path = [home]
    }

    var current: URL { path.last ?? home }

    var totalBytes: Int64 {
        items.compactMap { $0.sizeBytes }.reduce(0, +)
    }

    var totalText: String {
        if sizing { return "已测 \(sizedCount)/\(items.count) 项" }
        return AppsStore.formatBytes(totalBytes)
    }

    func enter(_ item: AnalyzeItem) {
        guard item.isDirectory else { return }
        path.append(item.url)
        rescan()
    }

    func goUp() {
        guard path.count > 1 else { return }
        path.removeLast()
        rescan()
    }

    func jump(to index: Int) {
        path = Array(path.prefix(index + 1))
        rescan()
    }

    func rescan() {
        task?.cancel()
        let root = current
        items = []
        sizing = true
        sizedCount = 0
        task = Task { [weak self] in
            let children = await Task.detached(priority: .userInitiated) {
                Self.listChildren(root)
            }.value
            guard let self, !Task.isCancelled else { return }
            self.items = children
            if children.isEmpty {
                self.sizing = false
                return
            }
            await self.measureAll(children)
            guard !Task.isCancelled else { return }
            self.items.sort { ($0.sizeBytes ?? -1) > ($1.sizeBytes ?? -1) }
            self.sizing = false
        }
    }

    /// 只列一级子项:目录与文件都保留;符号链接与隐藏项照旧跳过符号链接(隐藏项保留)。
    nonisolated static func listChildren(_ root: URL) -> [AnalyzeItem] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey]
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: keys,
            options: []
        )) ?? []

        var items: [AnalyzeItem] = []
        for entry in entries {
            guard let values = try? entry.resourceValues(forKeys: Set(keys)),
                  values.isSymbolicLink != true else { continue }
            let isDirectory = values.isDirectory == true
            var item = AnalyzeItem(
                id: entry.path,
                url: entry,
                name: entry.lastPathComponent,
                isDirectory: isDirectory,
                sizeBytes: nil
            )
            if !isDirectory {
                item.sizeBytes = Int64(values.fileSize ?? 0)
            }
            items.append(item)
        }
        return items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// 四并发测体积,谁先完成先填谁。
    private func measureAll(_ snapshot: [AnalyzeItem]) async {
        await withTaskGroup(of: (String, Int64).self) { group in
            var next = 0
            let limit = 4
            while next < min(limit, snapshot.count) {
                let item = snapshot[next]
                group.addTask { (item.id, Self.size(of: item)) }
                next += 1
            }
            for await (id, size) in group {
                if Task.isCancelled { return }
                if let index = items.firstIndex(where: { $0.id == id }) {
                    items[index].sizeBytes = size
                    sizedCount += 1
                }
                if next < snapshot.count {
                    let item = snapshot[next]
                    group.addTask { (item.id, Self.size(of: item)) }
                    next += 1
                }
            }
        }
    }

    nonisolated private static func size(of item: AnalyzeItem) -> Int64 {
        if item.isDirectory {
            return AppsStore.directorySize(item.url)
        }
        return item.sizeBytes ?? 0
    }
}

import AppKit
import SwiftUI

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
    @Published private(set) var error: String?
    @Published private(set) var stopped = false
    @Published private(set) var fromCache = false
    @Published private(set) var hasLoaded = false

    let home = FileManager.default.homeDirectoryForCurrentUser
    private var task: Task<Void, Never>?
    private struct Cached { let date: Date; let items: [AnalyzeItem] }
    private var cache: [URL: Cached] = [:]

    init() { path = [home] }
    var current: URL { path.last ?? home }
    var totalBytes: Int64 { items.compactMap(\.sizeBytes).reduce(0, +) }
    var totalText: String { AppsStore.formatBytes(totalBytes) }

    func enter(_ item: AnalyzeItem) {
        guard item.isDirectory else { return }
        path.append(item.url)
        load()
    }

    func goUp() {
        guard path.count > 1 else { return }
        path.removeLast()
        load()
    }

    func jump(to index: Int) {
        guard path.indices.contains(index), index != path.count - 1 else { return }
        path = Array(path.prefix(index + 1))
        load()
    }

    func open(_ url: URL) { path = [url]; load() }
    func rescan() { load(force: true) }
    func stop() {
        task?.cancel()
        sizing = false
        stopped = true
    }

    private func load(force: Bool = false) {
        task?.cancel()
        let root = current
        hasLoaded = true
        stopped = false
        fromCache = false
        error = nil
        if !force, let cached = cache[root], Date().timeIntervalSince(cached.date) < 120 {
            items = cached.items
            sizedCount = items.count
            sizing = false
            fromCache = true
            return
        }
        items = []
        sizing = true
        sizedCount = 0
        task = Task { [weak self] in
            let listing = Task.detached(priority: .userInitiated) { try Self.listChildren(root) }
            do {
                let children = try await withTaskCancellationHandler { try await listing.value } onCancel: { listing.cancel() }
                guard let self, !Task.isCancelled else { return }
                self.items = children
                self.sizedCount = children.filter { $0.sizeBytes != nil }.count
                await self.measureAll(children.filter { $0.isDirectory })
                guard !Task.isCancelled else { return }
                self.items.sort { ($0.sizeBytes ?? -1) > ($1.sizeBytes ?? -1) }
                self.sizing = false
                self.cache[root] = Cached(date: Date(), items: self.items)
                if self.cache.count > 12, let oldest = self.cache.min(by: { $0.value.date < $1.value.date })?.key {
                    self.cache.removeValue(forKey: oldest)
                }
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.error = error.localizedDescription
                self.sizing = false
            }
        }
    }

    nonisolated static func listChildren(_ root: URL) throws -> [AnalyzeItem] {
        let entries = try FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: Array(FileSizer.keys), options: []
        )
        var items: [AnalyzeItem] = []
        for entry in entries {
            if Task.isCancelled { break }
            guard let values = try? entry.resourceValues(forKeys: FileSizer.keys),
                  values.isSymbolicLink != true else { continue }
            let directory = values.isDirectory == true
            items.append(AnalyzeItem(id: entry.path, url: entry, name: entry.lastPathComponent,
                                     isDirectory: directory,
                                     sizeBytes: directory ? nil : Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)))
        }
        return items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func measureAll(_ snapshot: [AnalyzeItem]) async {
        await withTaskGroup(of: (String, FileSizer.Measurement).self) { group in
            var next = 0
            func enqueue() {
                let item = snapshot[next]
                group.addTask { (item.id, FileSizer.measure(item.url)) }
                next += 1
            }
            while next < min(4, snapshot.count) { enqueue() }
            for await (id, size) in group {
                guard !Task.isCancelled else { group.cancelAll(); return }
                if let index = items.firstIndex(where: { $0.id == id }) {
                    items[index].sizeBytes = size.bytes
                    items[index].partial = size.partial
                    sizedCount += 1
                }
                if next < snapshot.count { enqueue() }
            }
        }
    }
}

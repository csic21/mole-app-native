import AppKit
import SwiftUI

/// 一条可清理项(真实路径 + 真实体积)。
struct CleanItem: Identifiable {
    let id: String
    let name: String
    let sizeBytes: Int64
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
    var measured = false
    var sizeBytes: Int64 = 0
    var children: [CleanItem] = []
}

struct TrashResult {
    let moved: Int
    let failed: Int
    let freedBytes: Int64
}

@MainActor
final class CleanStore: ObservableObject {
    @Published private(set) var categories: [CleanCategory] = []
    @Published private(set) var scanning = false
    @Published private(set) var measuredCount = 0

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

    func scan() {
        scanTask?.cancel()
        categories = Self.defaultCategories().filter {
            FileManager.default.fileExists(atPath: $0.root.path)
        }
        scanning = true
        measuredCount = 0
        scanTask = Task { [weak self] in
            guard let self else { return }
            for (index, category) in self.categories.enumerated() {
                if Task.isCancelled { return }
                let measured = await Self.measure(category)
                guard !Task.isCancelled else { return }
                if index < self.categories.count {
                    self.categories[index] = measured
                    self.measuredCount += 1
                }
            }
            self.scanning = false
        }
    }

    /// 枚举一级子项(跳过隐藏与符号链接),四并发测体积。
    nonisolated private static func measure(_ category: CleanCategory) async -> CleanCategory {
        var result = category
        let fm = FileManager.default
        var targets: [URL] = []

        switch category.mode {
        case .whole:
            targets = [category.root]
        case .children:
            let entries = (try? fm.contentsOfDirectory(
                at: category.root,
                includingPropertiesForKeys: [.isSymbolicLinkKey],
                options: []
            )) ?? []
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
        await withTaskGroup(of: CleanItem.self) { group in
            var next = 0
            let limit = 4
            while next < min(limit, targets.count) {
                let url = targets[next]
                group.addTask {
                    CleanItem(id: url.path, name: url.lastPathComponent, sizeBytes: AppsStore.directorySize(url))
                }
                next += 1
            }
            for await item in group {
                items.append(item)
                if next < targets.count {
                    let url = targets[next]
                    group.addTask {
                        CleanItem(id: url.path, name: url.lastPathComponent, sizeBytes: AppsStore.directorySize(url))
                    }
                    next += 1
                }
            }
        }

        items.sort { $0.sizeBytes > $1.sizeBytes }
        result.children = items
        result.sizeBytes = items.reduce(0) { $0 + $1.sizeBytes }
        result.measured = true
        return result
    }

    /// 移到废纸篓;落闸前逐条重校验:仍是普通目录/文件、仍在既定 root 之下。
    func trash(selected ids: Set<String>) async -> TrashResult {
        let fm = FileManager.default
        var moved = 0
        var failed = 0
        var freed: Int64 = 0

        for category in categories where ids.contains(category.id) {
            let rootPath = category.root.standardizedFileURL.path
            for item in category.children {
                let url = URL(fileURLWithPath: item.id)
                guard let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]),
                      values.isSymbolicLink != true,
                      fm.fileExists(atPath: url.path) else {
                    failed += 1
                    continue
                }
                let standardized = url.standardizedFileURL.path
                guard standardized == rootPath || standardized.hasPrefix(rootPath + "/") else {
                    failed += 1
                    continue
                }
                do {
                    var resulting: NSURL?
                    try fm.trashItem(at: url, resultingItemURL: &resulting)
                    moved += 1
                    freed += item.sizeBytes
                } catch {
                    failed += 1
                }
            }
        }
        return TrashResult(moved: moved, failed: failed, freedBytes: freed)
    }
}

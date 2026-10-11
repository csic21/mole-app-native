// swiftc -O Sources/MoleApp/FileSizer.swift scripts/scan_benchmark.swift -o /tmp/qili-scan-benchmark
// /tmp/qili-scan-benchmark [directory]
import Foundation

@main
struct ScanBenchmark {
    static func main() throws {
        let fm = FileManager.default
        let generated = CommandLine.arguments.count == 1
        let root = generated ? fm.temporaryDirectory.appendingPathComponent("qili-benchmark-" + UUID().uuidString)
            : URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        if generated {
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
            let bytes = Data((0..<1024).map { UInt8(($0 * 13 + $0 / 256) % 251) })
            for index in 0..<100 {
                let folder = root.appendingPathComponent("folder-\(index)")
                try fm.createDirectory(at: folder, withIntermediateDirectories: true)
                for file in 0..<100 { try bytes.write(to: folder.appendingPathComponent("file-\(file)")) }
            }
        }
        defer { if generated { try? fm.removeItem(at: root) } }
        _ = baseline(root)
        _ = FileSizer.measure(root)
        var oldTimes: [Double] = []
        var newTimes: [Double] = []
        var oldBytes: Int64 = 0
        var newBytes: Int64 = 0
        for _ in 0..<5 {
            var start = ProcessInfo.processInfo.systemUptime
            oldBytes = baseline(root)
            oldTimes.append(ProcessInfo.processInfo.systemUptime - start)
            start = ProcessInfo.processInfo.systemUptime
            newBytes = FileSizer.measure(root).bytes
            newTimes.append(ProcessInfo.processInfo.systemUptime - start)
        }
        let old = oldTimes.sorted()[2]
        let new = newTimes.sorted()[2]
        print("Dataset: \(generated ? "10,000 files in 100 folders" : root.path)")
        print(String(format: "Foundation median: %.3f s; FTS median: %.3f s; speedup: %.2fx", old, new, old / new))
        print("Foundation bytes: \(oldBytes); FTS bytes: \(newBytes)")
        // 两种方式在资源叉/扩展属性丰富的目录中可能存在口径差异，需单独解释。
        if oldBytes != newBytes { print("Note: allocation methods differ on this dataset; inspect resource forks / extended attributes.") }
    }

    static func baseline(_ root: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: Array(keys), options: [], errorHandler: { _, _ in true }) else { return 0 }
        var bytes: Int64 = 0
        for case let url as URL in walker {
            guard let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true, values.isSymbolicLink != true else { continue }
            bytes += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return bytes
    }
}

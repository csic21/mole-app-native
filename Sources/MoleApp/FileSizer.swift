import Darwin
import Foundation

/// 统一使用实际分配大小；无法访问的内容标为不完整，不把权限错误当成空目录。
enum FileSizer {
    struct Measurement {
        var bytes: Int64 = 0
        var partial = false
    }

    static let keys: Set<URLResourceKey> = [
        .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey,
        .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
    ]

    /// FTS_PHYSICAL 不跟随符号链接，FTS_NOCHDIR 保证多路扫描不改变进程工作目录。
    /// 使用 stat 已提供的分配块数，避免为每个文件构造 URL 和读取多组资源属性。
    static func measure(_ url: URL) -> Measurement {
        guard !Task.isCancelled else { return Measurement(partial: true) }
        return url.withUnsafeFileSystemRepresentation { representation in
            guard let representation, let path = strdup(representation) else { return Measurement(partial: true) }
            defer { free(path) }
            var paths: [UnsafeMutablePointer<CChar>?] = [path, nil]
            return paths.withUnsafeMutableBufferPointer { buffer in
                guard let tree = fts_open(buffer.baseAddress, FTS_PHYSICAL | FTS_NOCHDIR, nil) else {
                    return Measurement(partial: true)
                }
                defer { fts_close(tree) }
                var result = Measurement()
                while true {
                    guard !Task.isCancelled else { result.partial = true; break }
                    errno = 0
                    guard let entry = fts_read(tree) else {
                        if errno != 0 { result.partial = true }
                        break
                    }
                    switch Int32(entry.pointee.fts_info) {
                    case FTS_F:
                        if let metadata = entry.pointee.fts_statp {
                            result.bytes += max(0, Int64(metadata.pointee.st_blocks)) * 512
                        } else { result.partial = true }
                    case FTS_DNR, FTS_ERR, FTS_NS, FTS_DC:
                        result.partial = true
                    default:
                        break
                    }
                }
                return result
            }
        }
    }
}

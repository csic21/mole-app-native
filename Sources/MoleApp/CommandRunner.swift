import Darwin
import Foundation

enum CommandRunner {
    struct Result {
        let code: Int32
        let output: String
        let error: String

        var combined: String {
            [output, error].filter { !$0.isEmpty }.joined(separator: "\n")
        }
    }

    private final class Cancellation: @unchecked Sendable {
        private let lock = NSLock()
        private var cancelled = false
        func cancel() { lock.lock(); cancelled = true; lock.unlock() }
        var isCancelled: Bool {
            lock.lock(); defer { lock.unlock() }
            return cancelled
        }
    }

    static func run(_ launchPath: String, _ arguments: [String], timeout: TimeInterval) async -> Result {
        let cancellation = Cancellation()
        return await withTaskCancellationHandler {
            await Task.detached(priority: .utility) {
                runSync(launchPath, arguments, timeout: timeout, isCancelled: { cancellation.isCancelled })
            }.value
        } onCancel: {
            cancellation.cancel()
        }
    }

    /// 临时文件避免 stdout / stderr 填满管道；只读取有限的输出。
    @discardableResult
    static func runSync(
        _ launchPath: String, _ arguments: [String], timeout: TimeInterval = 30,
        isCancelled: () -> Bool = { false }
    ) -> Result {
        guard !isCancelled() else { return Result(code: 130, output: "", error: "已取消") }
        guard FileManager.default.isExecutableFile(atPath: launchPath) else {
            return Result(code: -1, output: "", error: "找不到 \(launchPath)")
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            defer { try? FileManager.default.removeItem(at: directory) }
            let outURL = directory.appendingPathComponent("stdout")
            let errURL = directory.appendingPathComponent("stderr")
            _ = FileManager.default.createFile(atPath: outURL.path, contents: nil)
            _ = FileManager.default.createFile(atPath: errURL.path, contents: nil)
            let out = try FileHandle(forWritingTo: outURL)
            let err = try FileHandle(forWritingTo: errURL)
            defer { try? out.close(); try? err.close() }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: launchPath)
            process.arguments = arguments
            process.standardOutput = out
            process.standardError = err
            try process.run()
            let deadline = ProcessInfo.processInfo.systemUptime + timeout
            while process.isRunning && ProcessInfo.processInfo.systemUptime < deadline && !isCancelled() {
                Thread.sleep(forTimeInterval: 0.02)
            }
            let cancelled = isCancelled()
            let timedOut = process.isRunning && !cancelled
            if process.isRunning {
                process.terminate()
                let grace = ProcessInfo.processInfo.systemUptime + 0.25
                while process.isRunning && ProcessInfo.processInfo.systemUptime < grace {
                    Thread.sleep(forTimeInterval: 0.01)
                }
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            }
            process.waitUntilExit()
            let output = readOutput(outURL)
            let error = readOutput(errURL)
            if cancelled { return Result(code: 130, output: output, error: error + "\n已取消") }
            if timedOut { return Result(code: 124, output: output, error: error + "\n超时(\(Int(timeout))s)") }
            return Result(code: process.terminationStatus, output: output, error: error)
        } catch {
            return Result(code: -1, output: "", error: error.localizedDescription)
        }
    }

    private static func readOutput(_ url: URL) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
        defer { try? handle.close() }
        let limit = 1_048_576
        let data = (try? handle.read(upToCount: limit + 1)) ?? Data()
        let text = String(decoding: data.prefix(limit), as: UTF8.self)
        return data.count > limit ? text + "\n…输出过长，已截断" : text
    }
}

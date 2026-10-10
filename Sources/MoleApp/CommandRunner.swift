import Foundation

/// 共用的进程执行器:带超时,输出完整带回。
enum CommandRunner {
    struct Result {
        let code: Int32
        let output: String
        let error: String

        var combined: String {
            output.isEmpty ? error : output
        }
    }

    static func run(_ launchPath: String, _ arguments: [String], timeout: TimeInterval) async -> Result {
        await Task.detached(priority: .userInitiated) {
            runSync(launchPath, arguments, timeout: timeout)
        }.value
    }

    @discardableResult
    static func runSync(_ launchPath: String, _ arguments: [String], timeout: TimeInterval = 30) -> Result {
        guard FileManager.default.isExecutableFile(atPath: launchPath) else {
            return Result(code: -1, output: "", error: "找不到 \(launchPath)")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        do {
            try process.run()
        } catch {
            return Result(code: -1, output: "", error: error.localizedDescription)
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            return Result(code: 124, output: "", error: "超时(\(Int(timeout))s)")
        }
        let output = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return Result(code: process.terminationStatus, output: output, error: error)
    }
}

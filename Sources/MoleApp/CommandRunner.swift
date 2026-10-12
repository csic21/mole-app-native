import Darwin
import Foundation

enum CommandRunner {
    struct Result {
        let code: Int32
        let output: String
        let error: String
        var truncated = false
        var combined: String { [output, error].filter { !$0.isEmpty }.joined(separator: "\n") }
        var failureMessage: String {
            switch code {
            case 130: return "已取消；已经完成的操作不会自动回滚"
            case 124: return "执行超时；请查看记录确认已完成的步骤"
            default:
                guard let line = (error.isEmpty ? output : error).split(separator: "\n").last,
                      let detail = CommandRunner.progressLine(Data(line.suffix(240).utf8)), !detail.isEmpty else {
                    return "命令退出码 \(code)"
                }
                return "命令退出码 \(code)：\(detail)"
            }
        }
    }

    private final class Cancellation: @unchecked Sendable {
        private let lock = NSLock()
        private var cancelled = false
        func cancel() { lock.lock(); cancelled = true; lock.unlock() }
        var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    }

    // 持续排空管道，每个流最多保留 1 MiB，保留首尾以免丢失最终错误。
    struct OutputBuffer {
        static let limit = 1_048_576
        private var head = Data()
        private var tail = Data()
        private(set) var total = 0
        var truncated: Bool { total > Self.limit }
        var storedBytes: Int { head.count + tail.count }
        mutating func append(_ data: Data) {
            total += data.count
            let headLimit = Self.limit * 3 / 4
            let needed = min(data.count, headLimit - head.count)
            head.append(data.prefix(needed))
            tail.append(data.dropFirst(needed))
            let tailLimit = Self.limit - headLimit
            if tail.count > tailLimit { tail.removeFirst(tail.count - tailLimit) }
        }
        var text: String {
            let start = String(decoding: head, as: UTF8.self)
            let end = String(decoding: tail, as: UTF8.self)
            return truncated ? start + "\n…中间输出已截断…\n" + end : start + end
        }
    }

    static func run(_ launchPath: String, _ arguments: [String], timeout: TimeInterval,
                    environment: [String: String] = [:],
                    onProgress: (@Sendable (String) -> Void)? = nil) async -> Result {
        let cancellation = Cancellation()
        return await withTaskCancellationHandler {
            await Task.detached(priority: .utility) {
                runSync(launchPath, arguments, timeout: timeout, environment: environment,
                        isCancelled: { cancellation.isCancelled }, onProgress: onProgress)
            }.value
        } onCancel: { cancellation.cancel() }
    }

    @discardableResult
    static func runSync(_ launchPath: String, _ arguments: [String], timeout: TimeInterval = 30,
                        environment: [String: String] = [:], isCancelled: () -> Bool = { false },
                        onProgress: (@Sendable (String) -> Void)? = nil) -> Result {
        guard !isCancelled() else { return Result(code: 130, output: "", error: "已取消") }
        guard timeout.isFinite, timeout >= 0 else { return Result(code: -1, output: "", error: "无效超时时间") }
        guard !([launchPath] + arguments).contains(where: { $0.utf8.contains(0) }),
              !environment.contains(where: { $0.key.isEmpty || $0.key.contains("=") || $0.key.utf8.contains(0) || $0.value.utf8.contains(0) }) else {
            return Result(code: -1, output: "", error: "命令参数包含无效字符")
        }
        var outFD: [Int32] = [0, 0], errFD: [Int32] = [0, 0]
        guard pipe(&outFD) == 0 else { return systemError(errno) }
        defer { close(outFD[0]) }
        guard pipe(&errFD) == 0 else { let failure = errno; close(outFD[1]); return systemError(failure) }
        defer { close(errFD[0]) }
        var writeEndsOpen = true
        defer { if writeEndsOpen { close(outFD[1]); close(errFD[1]) } }
        for fd in outFD + errFD {
            guard fcntl(fd, F_SETFD, FD_CLOEXEC) != -1 else { return systemError(errno) }
        }
        guard fcntl(outFD[0], F_SETFL, O_NONBLOCK) != -1,
              fcntl(errFD[0], F_SETFL, O_NONBLOCK) != -1 else { return systemError(errno) }

        var actions: posix_spawn_file_actions_t?, attrs: posix_spawnattr_t?
        let actionSetup = posix_spawn_file_actions_init(&actions)
        guard actionSetup == 0 else { return systemError(actionSetup) }
        defer { posix_spawn_file_actions_destroy(&actions) }
        let attrSetup = posix_spawnattr_init(&attrs)
        guard attrSetup == 0 else { return systemError(attrSetup) }
        defer { posix_spawnattr_destroy(&attrs) }
        // 不把 App / Swift 工作线程忽略或屏蔽的信号传给命令。
        var defaults = sigset_t(), mask = sigset_t()
        sigfillset(&defaults)
        sigdelset(&defaults, SIGKILL)
        sigdelset(&defaults, SIGSTOP)
        sigemptyset(&mask)
        let setups = [
            posix_spawnattr_setflags(&attrs, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK)),
            posix_spawnattr_setpgroup(&attrs, 0),
            posix_spawnattr_setsigdefault(&attrs, &defaults),
            posix_spawnattr_setsigmask(&attrs, &mask),
            posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0),
            posix_spawn_file_actions_adddup2(&actions, outFD[1], STDOUT_FILENO),
            posix_spawn_file_actions_adddup2(&actions, errFD[1], STDERR_FILENO),
        ]
        if let failure = setups.first(where: { $0 != 0 }) { return systemError(failure) }
        var argv = ([launchPath] + arguments).map { strdup($0) } + [nil]
        let env = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        var envp = env.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { for pointer in argv + envp { free(pointer) } }
        var pid: pid_t = 0
        let spawned = posix_spawn(&pid, launchPath, &actions, &attrs, &argv, &envp)
        guard spawned == 0 else { return systemError(spawned) }
        close(outFD[1]); close(errFD[1]); writeEndsOpen = false
        return collect(pid: pid, outFD: outFD[0], errFD: errFD[0], timeout: timeout,
                       isCancelled: isCancelled, onProgress: onProgress)
    }

    // 独立进程组接收 TERM / KILL。双路读取，不落盘。
    private static func collect(pid: pid_t, outFD: Int32, errFD: Int32, timeout: TimeInterval,
                                isCancelled: () -> Bool, onProgress: (@Sendable (String) -> Void)?) -> Result {
        var out = OutputBuffer(), err = OutputBuffer()
        var outEOF = false, errEOF = false
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        var stopped: Int32?, stopTime: TimeInterval?, killed = false
        var status: Int32 = 0, exitedAt: TimeInterval?
        var lastProgress: TimeInterval = 0
        while true {
            let now = ProcessInfo.processInfo.systemUptime
            if stopped == nil && exitedAt == nil && (isCancelled() || now >= deadline) {
                stopped = isCancelled() ? 130 : 124
                stopTime = now
                kill(-pid, SIGTERM)
            }
            // 即使组长先退出，也清理同组中忽略 TERM 的子进程。
            if let stopTime, now >= stopTime + 0.25, !killed { kill(-pid, SIGKILL); killed = true }
            if exitedAt == nil {
                let waited = waitpid(pid, &status, WNOHANG)
                if waited == pid || (waited == -1 && errno == ECHILD) { exitedAt = now }
            }
            let progressOut = drain(outFD, into: &out, eof: &outEOF, progress: onProgress != nil)
            let progressErr = drain(errFD, into: &err, eof: &errEOF, progress: onProgress != nil)
            if now - lastProgress >= 0.2, let line = progressErr ?? progressOut {
                onProgress?(line); lastProgress = now
            }
            if let exitedAt, (stopped == nil || killed),
               (outEOF && errEOF || now >= exitedAt + 0.3) { break }
            var polls = [pollfd(fd: outEOF ? -1 : outFD, events: Int16(POLLIN), revents: 0),
                         pollfd(fd: errEOF ? -1 : errFD, events: Int16(POLLIN), revents: 0)]
            _ = poll(&polls, 2, 20)
            if outEOF && errEOF { Thread.sleep(forTimeInterval: 0.01) }
        }
        let code = stopped ?? ((status & 0x7f) == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f))
        var error = err.text
        if code == 130 { error += "\n已取消" }
        if code == 124 { error += "\n超时(\(Int(timeout))s)" }
        return Result(code: code, output: out.text, error: error, truncated: out.truncated || err.truncated)
    }

    private static func drain(_ fd: Int32, into output: inout OutputBuffer, eof: inout Bool, progress: Bool) -> String? {
        guard !eof else { return nil }
        var bytes = [UInt8](repeating: 0, count: 16_384)
        var lastLine: String?
        // 限制每轮读取量，连续输出也不会阻止超时 / 取消检查。
        for _ in 0..<8 {
            let count = read(fd, &bytes, bytes.count)
            if count > 0 {
                let data = Data(bytes.prefix(count))
                output.append(data)
                if progress { lastLine = progressLine(data) }
            } else if count == 0 { eof = true; break }
            else if errno == EINTR { continue }
            else { break }
        }
        return lastLine
    }

    static func progressLine(_ data: Data) -> String? {
        let clean = String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "\u{001b}\\[[0-?]*[ -/]*[@-~]", with: "", options: .regularExpression)
        return clean.split(whereSeparator: { $0.isNewline }).last.map { line in
            String(line.filter { !$0.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) }.prefix(240))
        }
    }

    private static func systemError(_ code: Int32) -> Result {
        Result(code: -1, output: "", error: String(cString: strerror(code)))
    }
}

import Foundation

// ============================================================
// 优化任务:真实执行,全部可解释;只做安全、界内、可恢复的操作
// ============================================================

struct OptimizeTaskState: Identifiable {
    enum Status {
        case idle, running, done, skipped, failed
    }

    let id: String
    let title: String
    let note: String
    let requiresAuth: Bool
    let readOnly: Bool
    var status: Status = .idle
    var result: String?
}

@MainActor
final class OptimizeStore: ObservableObject {
    @Published private(set) var states: [OptimizeTaskState] = OptimizeStore.defaultTasks()
    @Published private(set) var running = false

    static func defaultTasks() -> [OptimizeTaskState] {
        [
            OptimizeTaskState(
                id: "quicklook", title: "Quick Look 缩略图", note: "重建缩略图缓存,预览下次自动生成",
                requiresAuth: false, readOnly: false
            ),
            OptimizeTaskState(
                id: "dns", title: "DNS 缓存刷新", note: "刷新解析记录(会弹出系统授权)",
                requiresAuth: true, readOnly: false
            ),
            OptimizeTaskState(
                id: "spotlight", title: "Spotlight 索引检查", note: "只读检查索引状态,不做重建",
                requiresAuth: false, readOnly: true
            ),
            OptimizeTaskState(
                id: "disk", title: "磁盘校验", note: "只读校验宗卷(可能耗时一两分钟)",
                requiresAuth: false, readOnly: true
            ),
        ]
    }

    func reset() {
        states = Self.defaultTasks()
    }

    func runAll() async {
        guard !running else { return }
        running = true
        reset()
        for index in states.indices {
            states[index].status = .running
            let outcome = await Self.execute(states[index])
            states[index].status = outcome.status
            states[index].result = outcome.message
        }
        running = false
    }

    // ---------------------------------------------------------- 执行

    private static func execute(_ task: OptimizeTaskState) async -> (status: OptimizeTaskState.Status, message: String) {
        switch task.id {
        case "quicklook":
            let result = await run("/usr/bin/qlmanage", ["-r", "cache"], timeout: 60)
            if result.code == 0 {
                return (.done, "缩略图缓存已重建")
            }
            return (.skipped, "qlmanage 返回 \(result.code),已跳过")
        case "dns":
            let script = "do shell script \"/usr/bin/dscacheutil -flushcache; /usr/bin/killall -HUP mDNSResponder\" with administrator privileges"
            let result = await run("/usr/bin/osascript", ["-e", script], timeout: 180)
            if result.code == 0 {
                return (.done, "DNS 缓存已刷新")
            }
            if result.error.contains("User canceled") || result.error.contains("-128") {
                return (.skipped, "已取消授权,未做任何改动")
            }
            return (.failed, "未能刷新:\(firstLine(result.error))")
        case "spotlight":
            let result = await run("/usr/bin/mdutil", ["-s", "/"], timeout: 30)
            let output = result.output.lowercased()
            if output.contains("indexing enabled") {
                return (.done, "索引正常启用,无需处理")
            }
            if output.contains("indexing disabled") {
                return (.done, "索引当前处于关闭状态")
            }
            return (.skipped, "状态未知:\(firstLine(result.output + result.error))")
        case "disk":
            let result = await run("/usr/sbin/diskutil", ["verifyVolume", "/"], timeout: 300)
            if result.code == 0 {
                return (.done, "宗卷校验通过")
            }
            return (.failed, "校验未通过,建议在「磁盘工具」中查看")
        default:
            return (.skipped, "未实现")
        }
    }

    private static func firstLine(_ text: String) -> String {
        text.split(separator: "\n").first.map(String.init) ?? text
    }

    // ---------------------------------------------------------- 进程执行(带超时)

    struct RunResult {
        let code: Int32
        let output: String
        let error: String
    }

    private static func run(_ launchPath: String, _ arguments: [String], timeout: TimeInterval) async -> RunResult {
        await Task.detached(priority: .userInitiated) {
            guard FileManager.default.isExecutableFile(atPath: launchPath) else {
                return RunResult(code: -1, output: "", error: "找不到 \(launchPath)")
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
                return RunResult(code: -1, output: "", error: error.localizedDescription)
            }

            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning && Date() < deadline {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            if process.isRunning {
                process.terminate()
                return RunResult(code: 124, output: "", error: "超时(\(Int(timeout))s)")
            }
            let output = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let error = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return RunResult(code: process.terminationStatus, output: output, error: error)
        }.value
    }
}

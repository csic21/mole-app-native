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
    var output: String?
    var duration: TimeInterval?
}

@MainActor
final class OptimizeStore: ObservableObject {
    @Published private(set) var states: [OptimizeTaskState] = OptimizeStore.defaultTasks()
    @Published private(set) var running = false
    @Published var selected: Set<String> = ["spotlight"]
    @Published private(set) var stopRequested = false

    /// DEBUG snapshots preserve fixed results without launching maintenance commands.
    private(set) var allowsLiveOperations = true
    private var runID = UUID()

    init() {}

#if DEBUG
    struct Snapshot {
        var states: [OptimizeTaskState] = []
        var running = false
        var selected: Set<String> = []
        var stopRequested = false
    }

    convenience init(snapshot: Snapshot) {
        self.init()
        allowsLiveOperations = false
        states = snapshot.states
        running = snapshot.running
        selected = snapshot.selected
        stopRequested = snapshot.stopRequested
    }
#endif

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

    func requestStop() {
        guard allowsLiveOperations else { return }
        stopRequested = true
    }

    func runSelected(_ ids: Set<String>? = nil) async {
        guard allowsLiveOperations else { return }
        let requested = ids ?? selected
        guard !running, !requested.isEmpty else { return }
        running = true
        let run = UUID()
        runID = run
        stopRequested = false
        for index in states.indices where requested.contains(states[index].id) {
            states[index].status = .idle
            states[index].result = nil
            states[index].output = nil
            states[index].duration = nil
        }
        for index in states.indices where requested.contains(states[index].id) {
            if stopRequested || Task.isCancelled {
                states[index].status = .skipped
                states[index].result = "已停止,未运行"
                continue
            }
            states[index].status = .running
            let start = ProcessInfo.processInfo.systemUptime
            let outcome = await Self.execute(states[index]) { [weak self] line in
                // 只有仍在运行的本轮任务可以显示实时输出行。
                Task { @MainActor in
                    guard let self, self.running, self.runID == run, self.states[index].status == .running else { return }
                    self.states[index].result = line
                }
            }
            states[index].duration = ProcessInfo.processInfo.systemUptime - start
            states[index].status = outcome.status
            states[index].result = outcome.message
            states[index].output = outcome.output
        }
        running = false
    }

    // ---------------------------------------------------------- 执行

    private static func execute(
        _ task: OptimizeTaskState,
        progress: @escaping @Sendable (String) -> Void
    ) async -> (status: OptimizeTaskState.Status, message: String, output: String) {
        let result: CommandRunner.Result
        switch task.id {
        case "quicklook":
            result = await CommandRunner.run("/usr/bin/qlmanage", ["-r", "cache"], timeout: 60, onProgress: progress)
        case "dns":
            let script = "do shell script \"/usr/bin/dscacheutil -flushcache && /usr/bin/killall -HUP mDNSResponder\" with administrator privileges"
            result = await CommandRunner.run("/usr/bin/osascript", ["-e", script], timeout: 180, onProgress: progress)
        case "spotlight":
            result = await CommandRunner.run("/usr/bin/mdutil", ["-s", "/"], timeout: 30, onProgress: progress)
        case "disk":
            result = await CommandRunner.run("/usr/sbin/diskutil", ["verifyVolume", "/"], timeout: 300, onProgress: progress)
        default:
            return (.skipped, "未实现", "")
        }
        return interpret(result, taskID: task.id)
    }

    /// 退出码优先于输出文本:超时不代表磁盘损坏,部分 stdout 也不能覆盖失败退出码。
    nonisolated static func interpret(
        _ result: CommandRunner.Result, taskID: String
    ) -> (status: OptimizeTaskState.Status, message: String, output: String) {
        if taskID == "dns", result.code != 0, result.error.contains("(-128)") {
            return (.skipped, "已取消授权,未做任何改动", result.combined)
        }
        guard result.code == 0 else {
            return (result.code == 130 ? .skipped : .failed, result.failureMessage, result.combined)
        }
        switch taskID {
        case "quicklook":
            return (.done, "缩略图缓存已重建", result.combined)
        case "dns":
            return (.done, "DNS 缓存已刷新", result.combined)
        case "disk":
            return (.done, "宗卷校验通过", result.combined)
        case "spotlight":
            let text = result.output.lowercased()
            if text.contains("indexing enabled") { return (.done, "索引正常启用,无需处理", result.combined) }
            if text.contains("indexing disabled") { return (.done, "索引当前处于关闭状态", result.combined) }
            return (.skipped, "命令已完成,但未识别索引状态,请查看执行记录", result.combined)
        default:
            return (.skipped, "未实现", result.combined)
        }
    }
}

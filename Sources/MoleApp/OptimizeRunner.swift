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
                states[index].result = "已停止，未运行"
                continue
            }
            states[index].status = .running
            let start = ProcessInfo.processInfo.systemUptime
            let outcome = await Self.execute(states[index])
            states[index].duration = ProcessInfo.processInfo.systemUptime - start
            states[index].status = outcome.status
            states[index].result = outcome.message
            states[index].output = outcome.output
        }
        running = false
    }

    // ---------------------------------------------------------- 执行

    private static func execute(_ task: OptimizeTaskState) async -> (status: OptimizeTaskState.Status, message: String, output: String) {
        switch task.id {
        case "quicklook":
            let result = await CommandRunner.run("/usr/bin/qlmanage", ["-r", "cache"], timeout: 60)
            if result.code == 0 {
                return (.done, "缩略图缓存已重建", result.combined)
            }
            return (.skipped, "qlmanage 返回 \(result.code),已跳过", result.combined)
        case "dns":
            let script = "do shell script \"/usr/bin/dscacheutil -flushcache && /usr/bin/killall -HUP mDNSResponder\" with administrator privileges"
            let result = await CommandRunner.run("/usr/bin/osascript", ["-e", script], timeout: 180)
            if result.code == 0 {
                return (.done, "DNS 缓存已刷新", result.combined)
            }
            if result.error.contains("User canceled") || result.error.contains("-128") {
                return (.skipped, "已取消授权,未做任何改动", result.combined)
            }
            return (.failed, "未能刷新:\(firstLine(result.error))", result.combined)
        case "spotlight":
            let result = await CommandRunner.run("/usr/bin/mdutil", ["-s", "/"], timeout: 30)
            let output = result.output.lowercased()
            if output.contains("indexing enabled") {
                return (.done, "索引正常启用,无需处理", result.combined)
            }
            if output.contains("indexing disabled") {
                return (.done, "索引当前处于关闭状态", result.combined)
            }
            return (.skipped, "状态未知:\(firstLine(result.output + result.error))", result.combined)
        case "disk":
            let result = await CommandRunner.run("/usr/sbin/diskutil", ["verifyVolume", "/"], timeout: 300)
            if result.code == 0 {
                return (.done, "宗卷校验通过", result.combined)
            }
            return (.failed, "校验未通过,建议在「磁盘工具」中查看", result.combined)
        default:
            return (.skipped, "未实现", "")
        }
    }

    private static func firstLine(_ text: String) -> String {
        text.split(separator: "\n").first.map(String.init) ?? text
    }
}

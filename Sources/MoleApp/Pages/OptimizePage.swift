import SwiftUI

struct OptimizePage: View {
    @ObservedObject var store: OptimizeStore
    private var doneCount: Int { store.states.filter { $0.status == .done }.count }
    private var failedCount: Int { store.states.filter { $0.status == .failed }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 18) {
                Image(systemName: "wrench.and.screwdriver").font(.system(size: 30)).foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 7) {
                    Text(store.running ? "正在执行维护任务" : "按需维护").font(.system(size: 20, weight: .semibold))
                    Text("默认只选索引检查；缓存刷新与磁盘校验按需运行。")
                        .font(.system(size: 12.5)).foregroundStyle(Theme.dim2)
                }
                Spacer()
                if store.running {
                    ProgressView().controlSize(.small)
                    Button(store.stopRequested ? "将在本项结束后停止" : "停止后续任务") { store.requestStop() }
                        .disabled(store.stopRequested).buttonStyle(.plain).foregroundStyle(Theme.accent)
                } else {
                    PillButton(title: "运行已选 \(store.selected.count) 项", disabled: store.selected.isEmpty) {
                        Task { await store.runSelected() }
                    }
                }
            }.padding(22).background(Theme.surface, in: RoundedRectangle(cornerRadius: 12)).padding(.bottom, 14)
            ForEach(store.states) { task in
                RowBox {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            CheckView(on: store.selected.contains(task.id), label: "选择\(task.title)") {
                                if !store.selected.insert(task.id).inserted { store.selected.remove(task.id) }
                            }.disabled(store.running)
                            Text(task.title).font(.system(size: 13.5, weight: .medium))
                            if task.readOnly { Chip(text: "只读") }
                            if task.requiresAuth { Chip(text: "需系统授权", tone: .skip) }
                            Spacer()
                            chip(task)
                            Button("单独运行") { Task { await store.runSelected([task.id]) } }
                                .buttonStyle(.plain).foregroundStyle(Theme.accent).disabled(store.running)
                        }
                        Text(task.note).font(.system(size: 12.5)).foregroundStyle(Theme.dim2)
                            .padding(.leading, 28)
                        if let result = task.result {
                            Text(result).font(.system(size: 12)).foregroundStyle(task.status == .failed ? Theme.warm : Theme.dim2)
                                .padding(.leading, 28).textSelection(.enabled)
                        }
                        if let output = task.output, !output.isEmpty {
                            DisclosureGroup("查看执行记录" + (task.duration.map { String(format: " · %.1f 秒", $0) } ?? "")) {
                                Text(output).font(Theme.monoSmall).foregroundStyle(Theme.dim2)
                                    .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled).padding(.top, 8)
                            }.font(.system(size: 12)).padding(.leading, 28)
                        }
                    }
                }
            }
            Text("\(doneCount) 项完成 · \(failedCount) 项失败 · 停止后续任务会等待当前任务结束")
                .font(.system(size: 12)).foregroundStyle(Theme.dim3).padding(.top, 14)
        }
    }

    private func chip(_ task: OptimizeTaskState) -> Chip {
        switch task.status {
        case .idle: Chip(text: "待命")
        case .running: Chip(text: "执行中…", tone: .running)
        case .done: Chip(text: "完成", tone: .done)
        case .skipped: Chip(text: "跳过", tone: .skip)
        case .failed: Chip(text: "失败", tone: .failed)
        }
    }
}

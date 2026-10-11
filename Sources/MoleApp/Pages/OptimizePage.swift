import SwiftUI

struct OptimizePage: View {
    @ObservedObject var store: OptimizeStore

    private var doneCount: Int { store.states.filter { $0.status == .done }.count }
    private var skippedCount: Int { store.states.filter { $0.status == .skipped }.count }
    private var failedCount: Int { store.states.filter { $0.status == .failed }.count }
    private var idleCount: Int { store.states.filter { $0.status == .idle }.count }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 20) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 64, height: 64)
                    .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(store.states.count) 项维护任务").font(.system(size: 19, weight: .semibold))
                    Text("查看任务说明后运行。需要权限时，系统会向你确认。")
                        .font(.system(size: 12.5)).foregroundStyle(Theme.dim2)
                }
                Spacer()
                PillButton(title: store.running ? "正在维护…" : "运行维护任务", disabled: store.running) {
                    Task { await store.runAll() }
                }
            }
            .padding(22)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
            .padding(.bottom, 24)

            ForEach(store.states) { task in
                RowBox {
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Text(task.title).font(.system(size: 13.5))
                            if task.readOnly {
                                Text("只读")
                                    .font(.system(size: 10.5))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.08), in: Capsule())
                                    .foregroundStyle(Theme.dim3)
                            }
                            if task.requiresAuth {
                                Text("需授权")
                                    .font(.system(size: 10.5))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Theme.accent.opacity(0.16), in: Capsule())
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .frame(width: 200, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.note)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Theme.dim2)
                                .lineLimit(1)
                            if let result = task.result, task.status != .running {
                                Text(result)
                                    .font(.system(size: 12))
                                    .foregroundStyle(
                                        task.status == .failed ? Color(hex: 0xF09090) : Theme.dim3
                                    )
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        chip(for: task)
                    }
                }
            }

            FootBar(note: "\(doneCount) 项完成 · \(skippedCount) 项跳过 · \(failedCount) 项失败 · \(idleCount) 项待命") {
                PillButton(title: "再次运行", disabled: store.running) {
                    Task { await store.runAll() }
                }
            }
        }
    }

    private func chip(for task: OptimizeTaskState) -> Chip {
        switch task.status {
        case .idle: Chip(text: "待命")
        case .running: Chip(text: "执行中…", tone: .running)
        case .done: Chip(text: "完成", tone: .done)
        case .skipped: Chip(text: "跳过", tone: .skip)
        case .failed: Chip(text: "失败", tone: .failed)
        }
    }
}

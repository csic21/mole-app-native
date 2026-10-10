import SwiftUI

struct OptimizePage: View {
    @StateObject private var store = OptimizeStore()

    private var doneCount: Int { store.states.filter { $0.status == .done }.count }
    private var skippedCount: Int { store.states.filter { $0.status == .skipped }.count }
    private var failedCount: Int { store.states.filter { $0.status == .failed }.count }
    private var idleCount: Int { store.states.filter { $0.status == .idle }.count }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                Text("优化")
                    .font(.system(size: 12.5))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 5)
                    .background(Color(hex: 0xEFE8D8, opacity: 0.12), in: Capsule())
                Spacer()
                Text("全部在本机执行 · 遇授权会先弹系统窗口 · 失败会说明原因")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.dim3)
            }
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                MoonView()
                Text("循理而行,分毫不乱")
                    .font(Theme.display)
                    .tracking(6)
                    .foregroundStyle(Theme.star.opacity(0.8))
                    .padding(.top, 30)
                    .padding(.bottom, 20)
                PillButton(title: store.running ? "优化中…" : "优化 Mac", disabled: store.running) {
                    Task { await store.runAll() }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 18)

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
                                    .background(Color(hex: 0x8B7CF0, opacity: 0.16), in: Capsule())
                                    .foregroundStyle(Color(hex: 0xB3A8F5))
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

struct MoonView: View {
    var size: CGFloat = 150

    var body: some View {
        ZStack {
            Circle().fill(
                RadialGradient(
                    colors: [Color(hex: 0xAAA496), Color(hex: 0x8D887C), Color(hex: 0x6E6A60)],
                    center: UnitPoint(x: 0.3, y: 0.28),
                    startRadius: 4,
                    endRadius: size * 0.8
                )
            )
            Circle().fill(Color(hex: 0x6F6A60)).frame(width: size * 0.16).offset(x: size * 0.18, y: -size * 0.16).blur(radius: 2)
            Circle().fill(Color(hex: 0x736E63)).frame(width: size * 0.22).offset(x: -size * 0.14, y: size * 0.22).blur(radius: 3)
            Circle().fill(Color(hex: 0x615C52)).frame(width: size * 0.12).offset(x: size * 0.1, y: size * 0.3).blur(radius: 2)
            Circle().fill(
                RadialGradient(
                    colors: [.white.opacity(0.3), .clear],
                    center: UnitPoint(x: 0.32, y: 0.28),
                    startRadius: 2,
                    endRadius: size * 0.6
                )
            )
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.55), radius: 24, y: 20)
    }
}

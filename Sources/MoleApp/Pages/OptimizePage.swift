import SwiftUI

struct OptimizePage: View {
    @State private var tasks = MockData.tasks
    @State private var running = false

    private var finished: Int { tasks.filter { $0.status == .done }.count }
    private var skipped: Int { tasks.filter { $0.status == .skip }.count }
    private var idle: Int { tasks.filter { $0.status == .idle }.count }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                Text("优化")
                    .font(.system(size: 12.5))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 5)
                    .background(Color(hex: 0xEFE8D8, opacity: 0.12), in: Capsule())
                Spacer()
                Text("有风险的任务自动跳过并说明")
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
                PillButton(title: running ? "优化中…" : "优化 Mac", disabled: running) { run() }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 18)

            ForEach(tasks) { task in
                RowBox {
                    HStack(spacing: 12) {
                        Text(task.name)
                            .font(.system(size: 13.5))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(task.note)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.dim2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        chip(for: task)
                    }
                }
            }

            FootBar(note: "\(finished) 项完成 · \(skipped) 项跳过 · \(idle) 项待命") {
                PillButton(title: "再次运行", disabled: running) { run() }
            }
        }
        .task(id: running) {
            guard running else { return }
            while true {
                try? await Task.sleep(nanoseconds: 620_000_000)
                if Task.isCancelled { return }
                let advanced = advance()
                if !advanced { break }
            }
            try? await Task.sleep(nanoseconds: 350_000_000)
            running = false
        }
    }

    private func run() {
        guard !running else { return }
        tasks = MockData.tasks
        running = true
    }

    private func advance() -> Bool {
        if let index = tasks.firstIndex(where: { $0.status == .running }) {
            tasks[index].status = tasks[index].skipNote == nil ? .done : .skip
            return true
        }
        if let index = tasks.firstIndex(where: { $0.status == .idle }) {
            tasks[index].status = .running
            return true
        }
        return false
    }

    private func chip(for task: MockData.Task) -> Chip {
        switch task.status {
        case .done: Chip(text: "完成", tone: .done)
        case .skip: Chip(text: task.skipNote ?? "跳过", tone: .skip)
        case .running: Chip(text: "执行中…", tone: .running)
        case .idle: Chip(text: "待命")
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

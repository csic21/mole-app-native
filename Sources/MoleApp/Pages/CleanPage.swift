import SwiftUI

struct CleanPage: View {
    private enum Phase { case scanning, result, list, cleaned }

    @State private var phase: Phase = .result
    @State private var progress: Double = 0
    @State private var selected: Set<String> = ["system", "xcode", "browser"]
    @State private var openSystem = true

    private var selectedMB: Double {
        MockData.cleanGroups.filter { selected.contains($0.id) }.reduce(0) { $0 + $1.sizeMB }
    }

    var body: some View {
        Group {
            switch phase {
            case .scanning: scanningView
            case .result: resultView
            case .list: listView
            case .cleaned: cleanedView
            }
        }
        .task(id: phase) {
            guard phase == .scanning else { return }
            progress = 0
            while progress < 100 {
                try? await Task.sleep(nanoseconds: 55_000_000)
                progress = min(100, progress + 3)
            }
            try? await Task.sleep(nanoseconds: 320_000_000)
            phase = .result
        }
    }

    private var scanningView: some View {
        VStack(spacing: 16) {
            Text("正在扫描…").font(.system(size: 18))
            BarView(value: progress).frame(width: 340)
            Text("\(Int(progress))% · 已发现 9 类可清理项")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.dim3)
        }
        .frame(maxWidth: .infinity, minHeight: 520)
    }

    private var resultView: some View {
        VStack(spacing: 0) {
            EarthView()
            Text("共 154.19 GB").font(.system(size: 27)).padding(.top, 46)
            HStack(spacing: 4) {
                Text("136 项 9 类 ·").foregroundStyle(Theme.dim3)
                Button("重新扫描") { phase = .scanning }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.dim2)
                    .underline()
            }
            .font(.system(size: 12.5))
            .padding(.top, 6)
            .padding(.bottom, 22)
            PillButton(title: "查看结果") { phase = .list }
        }
        .frame(maxWidth: .infinity, minHeight: 520)
    }

    private var cleanedView: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(
                    RadialGradient(
                        colors: [Color(hex: 0x3F7D43), Color(hex: 0x2C5C33)],
                        center: UnitPoint(x: 0.34, y: 0.3),
                        startRadius: 4,
                        endRadius: 110
                    )
                )
                Image(systemName: "checkmark")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .frame(width: 150, height: 150)
            Text("已释放 \(MockData.formatSize(selectedMB))").font(.system(size: 27)).padding(.top, 46)
            Text("\(selected.count) 类 · 清理完成")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.dim3)
                .padding(.top, 6)
                .padding(.bottom, 22)
            PillButton(title: "重新扫描") { phase = .scanning }
        }
        .frame(maxWidth: .infinity, minHeight: 520)
    }

    private var listView: some View {
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                Text("清理")
                    .font(.system(size: 12.5))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 5)
                    .background(Color(hex: 0xEFE8D8, opacity: 0.12), in: Capsule())
                Spacer()
                Text("已扫描 · 1 分钟前").font(.system(size: 12)).foregroundStyle(Theme.dim3)
            }
            .padding(.bottom, 10)

            ForEach(MockData.cleanGroups) { group in
                RowBox(selected: selected.contains(group.id)) {
                    HStack(spacing: 12) {
                        CheckView(on: selected.contains(group.id)) {
                            toggle(group.id)
                        }
                        HStack(spacing: 8) {
                            Text(group.name).font(.system(size: 13.5))
                            Text(group.sizeText).font(Theme.mono).foregroundStyle(Theme.dim2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(group.note)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.dim2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if group.children.isEmpty {
                            Text(group.sizeText)
                                .font(Theme.mono)
                                .foregroundStyle(Theme.dim2)
                        } else {
                            Button(openSystem ? "收起 △" : "展开 ▽") { openSystem.toggle() }
                                .buttonStyle(.plain)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Theme.dim2)
                        }
                    }
                }
                if openSystem {
                    ForEach(group.children, id: \.name) { child in
                        RowBox {
                            HStack(spacing: 12) {
                                CheckView(on: selected.contains(group.id)) { toggle(group.id) }
                                Text(child.name)
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(Theme.star.opacity(0.72))
                                    .frame(width: 100, alignment: .leading)
                                Text(child.note)
                                    .font(Theme.monoSmall)
                                    .foregroundStyle(Theme.dim3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(child.sizeText).font(Theme.mono).foregroundStyle(Theme.dim2)
                            }
                            .padding(.leading, 14)
                        }
                    }
                }
            }

            FootBar(note: "已选 \(selected.count) 类 · 预计释放 \(MockData.formatSize(selectedMB)) · 先看后删") {
                PillButton(title: "立即清理", disabled: selected.isEmpty) { phase = .cleaned }
            }
        }
    }

    private func toggle(_ id: String) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }
}

struct EarthView: View {
    var body: some View {
        ZStack {
            Circle().fill(
                RadialGradient(
                    colors: [Color(hex: 0x4A7CAE), Color(hex: 0x2F5C86), Color(hex: 0x234566)],
                    center: UnitPoint(x: 0.3, y: 0.28),
                    startRadius: 6,
                    endRadius: 150
                )
            )
            Circle().fill(Color(hex: 0x3F7D43)).frame(width: 74).offset(x: 30, y: -20).blur(radius: 3)
            Circle().fill(Color(hex: 0x4D8F52)).frame(width: 54).offset(x: -24, y: 36).blur(radius: 3)
            Circle().fill(Color(hex: 0x4A8A52)).frame(width: 60).offset(x: -32, y: -30).blur(radius: 3)
            Circle().fill(
                RadialGradient(
                    colors: [.white.opacity(0.26), .clear],
                    center: UnitPoint(x: 0.28, y: 0.26),
                    startRadius: 2,
                    endRadius: 90
                )
            )
        }
        .frame(width: 190, height: 190)
        .clipShape(Circle())
        .overlay(
            Circle().strokeBorder(
                LinearGradient(colors: [.clear, .black.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 16
            )
            .blur(radius: 8)
        )
        .shadow(color: .black.opacity(0.5), radius: 26, y: 22)
        .padding(.top, 40)
    }
}

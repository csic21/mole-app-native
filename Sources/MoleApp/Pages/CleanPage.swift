import SwiftUI

struct CleanPage: View {
    private enum Phase { case scanning, result, list, trashing, done }

    @ObservedObject var store: CleanStore
    @State private var phase: Phase = .scanning
    @State private var selected: Set<String> = []
    @State private var expanded: Set<String> = []
    @State private var confirmVisible = false
    @State private var result: TrashResult?

    private var totalBytes: Int64 { store.categories.reduce(0) { $0 + $1.sizeBytes } }
    private var totalItems: Int { store.categories.reduce(0) { $0 + $1.children.count } }
    private var selectedBytes: Int64 {
        store.categories.filter { selected.contains($0.id) }.reduce(0) { $0 + $1.sizeBytes }
    }
    private var selectedItemCount: Int {
        store.categories.filter { selected.contains($0.id) }.reduce(0) { $0 + $1.children.count }
    }

    var body: some View {
        Group {
            switch phase {
            case .scanning: scanningView
            case .result: resultView
            case .list: listView
            case .trashing: trashingView
            case .done: doneView
            }
        }
        .task {
            if store.categories.isEmpty {
                store.scan()
            }
        }
        .onChange(of: store.scanning) { _, scanning in
            if !scanning && phase == .scanning {
                phase = .result
            }
        }
        .alert("移到废纸篓", isPresented: $confirmVisible) {
            Button("取消", role: .cancel) {}
            Button("移到废纸篓", role: .destructive) {
                runTrash()
            }
        } message: {
            Text("将把 \(selectedItemCount) 个目录(\(AppsStore.formatBytes(selectedBytes)))移到废纸篓,可随时恢复。")
        }
    }

    // ---------------------------------------------------------- 各阶段

    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.small)
            Text("正在扫描可清理项…").font(.system(size: 16))
            Text("已测量 \(store.measuredCount)/\(store.categories.count) 类")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.dim3)
        }
        .frame(maxWidth: .infinity, minHeight: 520)
    }

    private var resultView: some View {
        VStack(spacing: 0) {
            EarthView()
            Text("共 \(AppsStore.formatBytes(totalBytes))").font(.system(size: 27)).padding(.top, 46)
            HStack(spacing: 4) {
                Text("\(totalItems) 项 \(store.categories.count) 类 ·").foregroundStyle(Theme.dim3)
                Button("重新扫描") { rescan() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.dim2)
                    .underline()
            }
            .font(.system(size: 12.5))
            .padding(.top, 6)
            .padding(.bottom, 22)
            PillButton(title: "查看结果", disabled: totalBytes == 0) { phase = .list }
            if totalBytes == 0 {
                Text("没有找到可清理项,这台机器很干净")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.dim3)
                    .padding(.top, 12)
            }
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
                Text("真实路径 · 只会移到废纸篓")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.dim3)
            }
            .padding(.bottom, 10)

            ForEach(store.categories) { category in
                RowBox(selected: selected.contains(category.id)) {
                    HStack(spacing: 12) {
                        CheckView(on: selected.contains(category.id)) { toggle(category.id) }
                        HStack(spacing: 8) {
                            Text(category.title).font(.system(size: 13.5))
                            Text(AppsStore.formatBytes(category.sizeBytes))
                                .font(Theme.mono)
                                .foregroundStyle(Theme.dim2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(category.note)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.dim2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if category.children.count > 1 {
                            Button(expanded.contains(category.id) ? "收起 △" : "\(category.children.count) 项 ▽") {
                                if expanded.contains(category.id) {
                                    expanded.remove(category.id)
                                } else {
                                    expanded.insert(category.id)
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.dim2)
                        } else {
                            Text("1 项").font(.system(size: 12.5)).foregroundStyle(Theme.dim3)
                        }
                    }
                }
                if expanded.contains(category.id) {
                    ForEach(category.children.prefix(30)) { child in
                        RowBox {
                            HStack(spacing: 12) {
                                CheckView(on: selected.contains(category.id)) { toggle(category.id) }
                                Text(child.name)
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(Theme.star.opacity(0.72))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(AppsStore.formatBytes(child.sizeBytes))
                                    .font(Theme.mono)
                                    .foregroundStyle(Theme.dim2)
                            }
                            .padding(.leading, 14)
                        }
                    }
                    if category.children.count > 30 {
                        Text("仅显示前 30 项,清理时会处理全部 \(category.children.count) 项")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.dim3)
                            .padding(.leading, 34)
                            .padding(.vertical, 4)
                    }
                }
            }

            FootBar(note: "已选 \(selected.count) 类 · 预计释放 \(AppsStore.formatBytes(selectedBytes)) · 全部移到废纸篓") {
                PillButton(title: "移到废纸篓", disabled: selected.isEmpty) {
                    confirmVisible = true
                }
            }
        }
    }

    private var trashingView: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.small)
            Text("正在移到废纸篓…").font(.system(size: 16))
        }
        .frame(maxWidth: .infinity, minHeight: 520)
    }

    private var doneView: some View {
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
            Text("已释放 \(AppsStore.formatBytes(result?.freedBytes ?? 0))")
                .font(.system(size: 27))
                .padding(.top, 46)
            Text("\(result?.moved ?? 0) 项已移入废纸篓 · 可随时恢复")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.dim3)
                .padding(.top, 6)
            if let failed = result?.failed, failed > 0 {
                Text("\(failed) 项未能移动")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.dim2)
                    .padding(.top, 4)
            }
            PillButton(title: "重新扫描") { rescan() }
                .padding(.top, 22)
        }
        .frame(maxWidth: .infinity, minHeight: 520)
    }

    // ---------------------------------------------------------- 动作

    private func toggle(_ id: String) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }

    private func rescan() {
        selected = []
        expanded = []
        store.scan()
        phase = .scanning
    }

    private func runTrash() {
        let ids = selected
        phase = .trashing
        Task {
            let outcome = await store.trash(selected: ids)
            result = outcome
            // 已清理的类别从列表里移除,其余重新扫描一次拿到新体积
            store.scan()
            phase = .done
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

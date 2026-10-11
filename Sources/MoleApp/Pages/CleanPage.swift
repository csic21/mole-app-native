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
            } else if !store.scanning && phase == .scanning {
                phase = .result
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
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("可以整理的空间").font(.system(size: 13)).foregroundStyle(Theme.dim2)
                    Text(AppsStore.formatBytes(totalBytes))
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                    Text("\(totalItems) 个目录，分布在 \(store.categories.count) 个分类")
                        .font(.system(size: 13)).foregroundStyle(Theme.dim2)
                }
                Spacer()
                Image(systemName: "tray.2.fill")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 92, height: 92)
                    .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
            }
            .padding(26)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))

            Text("空间分布").font(.system(size: 16, weight: .semibold))
            VStack(spacing: 8) {
                ForEach(store.categories) { category in
                    Button { phase = .list } label: {
                        HStack(spacing: 20) {
                            Image(systemName: "folder").foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(category.title).font(.system(size: 14, weight: .medium))
                                Text(category.note).font(.system(size: 12)).foregroundStyle(Theme.dim2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            BarView(value: totalBytes > 0 ? Double(category.sizeBytes) / Double(totalBytes) * 100 : 0)
                                .frame(width: 110)
                            Text(AppsStore.formatBytes(category.sizeBytes))
                                .font(Theme.mono).frame(width: 80, alignment: .trailing)
                            Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(Theme.dim3)
                        }
                        .padding(18)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            FootBar(note: totalBytes == 0 ? "没有找到可清理项。" : "查看明细后勾选；确认后移到废纸篓。") {
                HStack(spacing: 18) {
                    Button("重新扫描") { rescan() }.buttonStyle(.plain).foregroundStyle(Theme.dim2)
                    PillButton(title: "查看整理清单", disabled: totalBytes == 0) { phase = .list }
                }
            }
        }
    }

    private var listView: some View {
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                Text("清理")
                    .font(.system(size: 12.5))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 5)
                    .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                Spacer()
                Text("确认后移到废纸篓，可恢复")
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
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 54))
                .foregroundStyle(Theme.accent)
                .frame(width: 100, height: 100)
                .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
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

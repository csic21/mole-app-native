import AppKit
import SwiftUI

struct CleanPage: View {
    @ObservedObject var store: CleanStore
    private var totalBytes: Int64 { store.categories.reduce(0) { $0 + $1.sizeBytes } }
    private var totalItems: Int { store.categories.reduce(0) { $0 + $1.children.count } }

    var body: some View {
        Group {
            switch store.phase {
            case .scanning: scanningView
            case .result: resultView
            case .list: listView
            case .trashing: trashingView
            case .done: doneView
            }
        }
        .task {
            if !store.hasScanned { store.scan() }
        }
    }

    // ---------------------------------------------------------- 各阶段

    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.small)
            Text("正在扫描可清理项…").font(.system(size: 16))
            Text("\(store.currentCategory) · 已测量 \(store.measuredCount)/\(store.categories.count) 类 · 已发现 \(AppsStore.formatBytes(totalBytes))")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.dim3)
            Button("停止扫描，查看已完成结果") { store.stop() }
                .buttonStyle(.plain).foregroundStyle(Theme.accent)
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
                    Text("\(totalItems) 项，分布在 \(store.categories.count) 个分类")
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

            if store.stopped || store.categories.contains(where: { $0.partial }) {
                Label(store.stopped ? "扫描已停止，以下为已完成结果" : "部分路径无法访问，大小为已读取部分", systemImage: "info.circle")
                    .font(.system(size: 12)).foregroundStyle(Theme.warm)
            }
            Text("空间分布").font(.system(size: 16, weight: .semibold))
            VStack(spacing: 8) {
                ForEach(store.categories) { category in
                    Button { store.expanded = [category.id]; store.phase = .list } label: {
                        HStack(spacing: 20) {
                            Image(systemName: "folder").foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(category.title).font(.system(size: 14, weight: .medium))
                                Text(category.note).font(.system(size: 12)).foregroundStyle(Theme.dim2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            BarView(value: totalBytes > 0 ? Double(category.sizeBytes) / Double(totalBytes) * 100 : 0)
                                .frame(width: 110)
                            Text(category.measured ? (category.partial ? "≥ " : "") + AppsStore.formatBytes(category.sizeBytes) : "未测量")
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
            FootBar(note: store.stopped ? "可继续查看已读取的项目，或重新扫描。" : (totalItems == 0 ? "没有找到可整理项。" : "查看明细后勾选；确认后移到废纸篓。")) {
                HStack(spacing: 18) {
                    Button("重新扫描") { rescan() }.buttonStyle(.plain).foregroundStyle(Theme.dim2)
                    PillButton(title: "查看整理清单", disabled: totalItems == 0) { store.phase = .list }
                }
            }
        }
    }

    private var listView: some View {
        LazyVStack(spacing: 5) {
            HStack {
                Button("返回概览") { store.phase = .result }.buttonStyle(.plain).foregroundStyle(Theme.accent)
                Spacer()
                Button("全选") { store.selected = Set(store.categories.flatMap(\.children).map(\.id)) }
                    .buttonStyle(.plain).foregroundStyle(Theme.dim2)
                Button("取消选择") { store.selected = [] }.buttonStyle(.plain).foregroundStyle(Theme.dim2)
            }
            .font(.system(size: 12.5)).padding(.bottom, 12)
            ForEach(store.categories) { category in
                RowBox {
                    HStack(spacing: 12) {
                        CheckView(on: !category.children.isEmpty && category.children.allSatisfy { store.selected.contains($0.id) },
                                  mixed: category.children.contains { store.selected.contains($0.id) }
                                    && !category.children.allSatisfy { store.selected.contains($0.id) },
                                  label: "选择\(category.title)") { store.toggleCategory(category) }
                            .disabled(category.children.isEmpty)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.title).font(.system(size: 13.5, weight: .medium))
                            Text(category.note).font(.system(size: 12)).foregroundStyle(Theme.dim2)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Text(category.measured ? (category.partial ? "≥ " : "") + AppsStore.formatBytes(category.sizeBytes) : "未测量")
                            .font(Theme.mono).foregroundStyle(Theme.dim2)
                        Button {
                            if !store.expanded.insert(category.id).inserted { store.expanded.remove(category.id) }
                        } label: {
                            Label("\(category.children.count) 项", systemImage: store.expanded.contains(category.id) ? "chevron.up" : "chevron.down")
                        }
                        .buttonStyle(.plain).foregroundStyle(Theme.accent)
                        .accessibilityLabel("\(store.expanded.contains(category.id) ? "收起" : "展开")\(category.title)明细")
                    }
                }
                if store.expanded.contains(category.id) {
                    ForEach(category.children) { child in
                        RowBox(selected: store.selected.contains(child.id)) {
                            HStack(spacing: 12) {
                                CheckView(on: store.selected.contains(child.id), label: "选择\(child.name)") {
                                    store.toggleItem(child.id)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(child.name).font(.system(size: 12.5)).lineLimit(1)
                                    Text(AppsStore.tildePath(URL(fileURLWithPath: child.id)))
                                        .font(Theme.monoSmall).foregroundStyle(Theme.dim3).lineLimit(1).truncationMode(.middle)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                Text((child.partial ? "≥ " : "") + AppsStore.formatBytes(child.sizeBytes))
                                    .font(Theme.mono).foregroundStyle(Theme.dim2)
                                Button {
                                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: child.id)])
                                } label: { Image(systemName: "arrow.up.forward.square") }
                                    .buttonStyle(.plain).foregroundStyle(Theme.dim2)
                                    .help("在访达中显示\(child.name)")
                            }.padding(.leading, 16)
                        }
                    }
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
            Image(systemName: store.result?.moved == 0 ? "exclamationmark.circle" : "checkmark.seal.fill")
                .font(.system(size: 54))
                .foregroundStyle(Theme.accent)
                .frame(width: 100, height: 100)
                .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
            Text("已整理 \(AppsStore.formatBytes(store.result?.movedBytes ?? 0))")
                .font(.system(size: 27))
                .padding(.top, 46)
            Text("\(store.result?.moved ?? 0) 项已移入废纸篓 · 可随时恢复")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.dim3)
                .padding(.top, 6)
            if let failed = store.result?.failed, failed > 0 {
                Text("\(failed) 项未能移动")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.dim2)
                    .padding(.top, 4)
            }
            Text("移入废纸篓后仍占用磁盘空间；需要时可从废纸篓恢复。")
                .font(.system(size: 12)).foregroundStyle(Theme.dim3).padding(.top, 12)
            if let failures = store.result?.failures, !failures.isEmpty {
                DisclosureGroup("查看未能移动的项目") {
                    Text(failures.joined(separator: "\n")).font(Theme.monoSmall).textSelection(.enabled)
                }.padding(.top, 12)
            }
            PillButton(title: "重新扫描") { rescan() }
                .padding(.top, 22)
        }
        .frame(maxWidth: .infinity, minHeight: 520)
    }

    // ---------------------------------------------------------- 动作

    private func rescan() { store.scan() }
}

/// 放在滚动区外：明细再长，已选数量和最终操作也始终可见。
struct CleanSelectionBar: View {
    @ObservedObject var store: CleanStore
    @State private var confirmVisible = false
    private var bytes: Int64 { store.selectedItems.reduce(0) { $0 + $1.sizeBytes } }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("已选 \(store.selectedItems.count) 项 · \(AppsStore.formatBytes(bytes))").font(.system(size: 13, weight: .medium))
                Text("移到废纸篓后可恢复；清空前仍占用磁盘空间")
                    .font(.system(size: 11.5)).foregroundStyle(Theme.dim3)
            }
            Spacer()
            PillButton(title: "移到废纸篓", disabled: store.selected.isEmpty || store.scanning) { confirmVisible = true }
        }
        .padding(.horizontal, 26).padding(.vertical, 16).background(Theme.surface)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        .alert("移到废纸篓", isPresented: $confirmVisible) {
            Button("取消", role: .cancel) {}
            Button("移到废纸篓", role: .destructive) { Task { await store.trash() } }
        } message: {
            Text("仅移动勾选的 \(store.selectedItems.count) 项（\(AppsStore.formatBytes(bytes))），可从废纸篓恢复。正在运行的应用可能重新生成缓存。")
        }
    }
}

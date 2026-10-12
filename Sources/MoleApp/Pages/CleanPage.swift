import AppKit
import SwiftUI

/// Outcome wording is deliberately independent of colour and byte totals.
struct CleanOutcomePresentation {
    enum Kind { case completed, partial, failed, unchanged }
    let kind: Kind
    let mode: CleanupMode

    init(result: CleanupResult?) {
        let moved = result?.cleaned ?? 0
        let failed = result?.failed ?? 0
        if failed > 0 { kind = moved > 0 ? .partial : .failed }
        else { kind = moved > 0 ? .completed : .unchanged }
        mode = result?.mode ?? .trash
    }

    var title: String {
        switch (mode, kind) {
        case (.trash, .completed): "已移到废纸篓"
        case (.trash, .partial): "部分项目未能移动"
        case (.trash, .failed): "未能移动所选项目"
        case (.trash, .unchanged): "未移动任何项目"
        case (.delete, .completed): "已删除"
        case (.delete, .partial): "部分项目未能删除"
        case (.delete, .failed): "未能删除所选项目"
        case (.delete, .unchanged): "未删除任何项目"
        }
    }

    /// 汇总行与提示里的完成动词，随清理方式变化。
    var completionVerb: String { mode == .delete ? "删除" : "移动" }
    var symbol: String {
        switch kind {
        case .completed: "checkmark.circle"
        case .partial: "exclamationmark.circle"
        case .failed: "xmark.circle"
        case .unchanged: "info.circle"
        }
    }
    var tone: Color {
        switch kind {
        case .completed: Theme.accent
        case .partial: Theme.warm
        case .failed: Theme.danger
        case .unchanged: Theme.dim2
        }
    }
}

struct CleanPage: View {
    @ObservedObject var store: CleanStore
    private var totalBytes: Int64 { store.categories.reduce(0) { $0 + $1.sizeBytes } }
    private var totalItems: Int { store.categories.reduce(0) { $0 + $1.children.count } }
    private var incomplete: Bool { store.stopped || store.categories.contains { $0.partial || !$0.measured } }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            CleanSteps(phase: store.phase)
            switch store.phase {
            case .ready: readyView
            case .scanning: scanningView
            case .result: resultView
            case .list: listView
            case .trashing: trashingView
            case .done: doneView
            }
        }
    }

    private var readyView: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 22) {
                Image(systemName: "tray.2")
                    .font(.system(size: 28, weight: .light)).foregroundStyle(Theme.accent)
                    .frame(width: 60, height: 60)
                    .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 9) {
                    Text("先看清，再整理").font(.system(size: 25, weight: .semibold))
                    Text("扫描常见缓存与日志，查看每一项的路径和占用，再选择要移到废纸篓的内容。")
                        .font(.system(size: 14)).foregroundStyle(Theme.dim2)
                        .fixedSize(horizontal: false, vertical: true)
                    PillButton(title: "开始扫描") { store.scan() }.padding(.top, 10)
                }
                Spacer(minLength: 0)
            }
            .padding(26)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))

            sectionTitle("扫描范围", detail: "仅检查预设目录")
            VStack(spacing: 8) {
                scopeRow("用户缓存与日志", note: "应用缓存、运行日志；保留受保护的系统项目", symbol: "folder")
                scopeRow("Xcode 开发文件", note: "构建缓存与设备支持文件", symbol: "hammer")
                scopeRow("npm 缓存", note: "已下载的软件包缓存", symbol: "shippingbox")
            }
            Notice(text: "扫描只读取本机文件。不会默认勾选任何项目，也不会清空废纸篓。", symbol: "checkmark.shield")
        }
    }

    private func scopeRow(_ title: String, note: String, symbol: String) -> some View {
        RowBox {
            HStack(spacing: 14) {
                Image(systemName: symbol).frame(width: 24).foregroundStyle(Theme.dim2)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 14, weight: .medium))
                    Text(note).font(.system(size: 12)).foregroundStyle(Theme.dim2)
                }
                Spacer()
            }
        }
    }

    private var scanningView: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 16) {
                ProgressView().controlSize(.small).padding(10)
                VStack(alignment: .leading, spacing: 7) {
                    Text("正在测量文件占用").font(Theme.display)
                    Text(store.currentCategory.isEmpty ? "准备扫描…" : store.currentCategory)
                        .font(.system(size: 13)).foregroundStyle(Theme.dim2)
                }
                Spacer()
                Button("停止扫描") { store.stop() }
                    .buttonStyle(WorkspaceButtonStyle())
                    .help("停止后仍可查看已经读取的结果")
            }
            HStack(alignment: .firstTextBaseline) {
                Text(AppsStore.formatBytes(totalBytes)).font(.system(size: 32, weight: .semibold, design: .rounded)).monospacedDigit()
                Text("已发现 · 尚未完成测量").font(.system(size: 12)).foregroundStyle(Theme.dim2)
                Spacer()
                Text("\(store.measuredCount) / \(store.categories.count) 类已完成").font(Theme.monoSmall).foregroundStyle(Theme.dim2)
            }
            // This is category progress, never an invented time estimate.
            ProgressView(value: Double(store.measuredCount), total: Double(max(1, store.categories.count)))
                .tint(Theme.accent)
                .accessibilityLabel("分类测量进度")
            VStack(spacing: 8) {
                ForEach(store.categories) { category in
                    RowBox {
                        HStack(spacing: 14) {
                            Image(systemName: category.measured ? "checkmark.circle" : "folder")
                                .foregroundStyle(category.measured ? Theme.accent : Theme.dim3)
                                .frame(width: 24)
                            Text(category.title).font(.system(size: 14, weight: .medium))
                            Spacer()
                            if category.measured {
                                Text((category.partial ? "≥ " : "") + AppsStore.formatBytes(category.sizeBytes)).font(Theme.mono)
                            } else {
                                Text(category.title == store.currentCategory ? "测量中…" : "等待测量")
                                    .font(.system(size: 12)).foregroundStyle(Theme.dim3)
                            }
                        }
                    }
                }
            }
            Notice(text: "扫描期间不会移动文件。你可以停止扫描，再查看已读取的项目。")
        }
    }

    private var resultView: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(totalItems == 0 ? (incomplete ? "暂时无法确认可整理项目" : "未发现可整理项目") : "已找到的项目占用")
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.dim2)
                    Text((incomplete && totalBytes > 0 ? "≥ " : "") + AppsStore.formatBytes(totalBytes))
                        .font(.system(size: 38, weight: .semibold, design: .rounded)).monospacedDigit()
                    Text("\(totalItems) 项 · \(store.measuredCount) 个分类已测量")
                        .font(.system(size: 13)).foregroundStyle(Theme.dim2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    PillButton(title: "查看并选择项目", disabled: totalItems == 0) { store.phase = .list }
                    Button("重新扫描") { store.scan() }.buttonStyle(WorkspaceButtonStyle(kind: .quiet))
                }
            }
            .padding(24)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))

            if incomplete {
                Notice(text: store.stopped ? "扫描已停止。这些是已读取的结果，未测量的分类不计入总量。" : "部分路径无法完整读取。标有 ≥ 的大小只是已读取部分；未发现项目不代表这些目录为空。", symbol: "exclamationmark.circle", tone: Theme.warm)
            } else if totalItems == 0 {
                Notice(text: "本次扫描范围内没有找到项目。你也可以到「文件地图」查看其他文件夹的占用。", symbol: "folder")
            }
            sectionTitle("分类明细", detail: "先查看，后选择")
            VStack(spacing: 8) {
                ForEach(store.categories) { category in
                    Button {
                        store.expanded = [category.id]
                        store.phase = .list
                    } label: {
                        RowBox {
                            HStack(spacing: 16) {
                                Image(systemName: "folder").frame(width: 24).foregroundStyle(Theme.dim2)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(category.title).font(.system(size: 14, weight: .medium))
                                    Text("\(category.children.count) 项 · \(category.note)").font(.system(size: 12)).foregroundStyle(Theme.dim2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                BarView(value: totalBytes > 0 ? Double(category.sizeBytes) / Double(totalBytes) * 100 : 0)
                                    .frame(width: 84)
                                Text(sizeLabel(category)).font(Theme.mono).frame(width: 92, alignment: .trailing)
                                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.dim3)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(category.children.isEmpty)
                    .accessibilityLabel("\(category.title)，\(sizeLabel(category))，\(category.children.count) 项，查看明细")
                }
            }
            Notice(text: "这里显示文件的测量占用，并非可立即释放的空间。移到废纸篓后，文件仍占用磁盘。", symbol: "info.circle")
        }
    }

    private var listView: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button { store.phase = .result } label: { Label("扫描概览", systemImage: "chevron.left") }
                    .buttonStyle(WorkspaceButtonStyle(kind: .quiet))
                Spacer()
                Button("全选 \(totalItems) 项") { store.selected = Set(store.categories.flatMap(\.children).map(\.id)) }
                    .buttonStyle(WorkspaceButtonStyle(kind: .quiet))
                Button("取消选择") { store.selected = [] }
                    .buttonStyle(WorkspaceButtonStyle(kind: .quiet)).disabled(store.selected.isEmpty)
            }
            Notice(text: "只勾选你确认不再需要的内容。展开项目可查看完整路径；应用可能重新生成缓存。")
                .padding(.bottom, 8)
            ForEach(store.categories) { category in
                RowBox {
                    HStack(spacing: 10) {
                        CheckView(on: !category.children.isEmpty && category.children.allSatisfy { store.selected.contains($0.id) },
                                  mixed: category.children.contains { store.selected.contains($0.id) }
                                    && !category.children.allSatisfy { store.selected.contains($0.id) },
                                  label: "选择\(category.title)") { store.toggleCategory(category) }
                            .disabled(category.children.isEmpty)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.title).font(.system(size: 14, weight: .semibold))
                            Text(category.note).font(.system(size: 12)).foregroundStyle(Theme.dim2)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Text(sizeLabel(category)).font(Theme.mono).foregroundStyle(Theme.dim2)
                        Button {
                            if !store.expanded.insert(category.id).inserted { store.expanded.remove(category.id) }
                        } label: {
                            Label("\(category.children.count) 项", systemImage: store.expanded.contains(category.id) ? "chevron.up" : "chevron.down")
                        }
                        .buttonStyle(WorkspaceButtonStyle(kind: .quiet))
                        .accessibilityLabel("\(store.expanded.contains(category.id) ? "收起" : "展开")\(category.title)明细")
                        .disabled(category.children.isEmpty)
                    }
                }
                if store.expanded.contains(category.id) {
                    ForEach(category.children) { child in
                        CleanItemRow(item: child, selected: store.selected.contains(child.id), allowsLiveOperations: store.allowsLiveOperations) {
                            store.toggleItem(child.id)
                        }
                        .padding(.leading, 20)
                    }
                }
            }
        }
    }

    private var trashingView: some View {
        let progress = store.cleanupProgress
        let deleting = store.cleanupMode == .delete
        return VStack(spacing: 18) {
            ProgressView(value: Double(min(progress.completed, max(progress.total, 1))),
                         total: Double(max(progress.total, 1)))
                .frame(maxWidth: 280)
            Text(deleting ? "正在删除" : "正在移到废纸篓").font(Theme.display)
            Text(trashingDetail)
                .font(.system(size: 13)).foregroundStyle(Theme.dim2)
                .multilineTextAlignment(.center)
            Notice(text: deleting
                ? "直接删除无法从废纸篓恢复。缓存与构建目录通常会在再次使用时自动重建。"
                : "移入废纸篓后仍占用磁盘空间。需要时可从废纸篓恢复；栖理不会清空废纸篓。",
                   symbol: deleting ? "trash.slash" : "arrow.uturn.backward",
                   tone: deleting ? Theme.warm : Theme.dim2)
        }
        .frame(maxWidth: .infinity, minHeight: 340)
    }

    /// 只报已处理项数，不显示预估时间。
    private var trashingDetail: String {
        let progress = store.cleanupProgress
        guard progress.total > 0 else { return "正在读取所选项目…" }
        var detail = "已完成 \(progress.completed) / \(progress.total) 项"
        if !progress.currentName.isEmpty { detail += " · 正在处理 \(progress.currentName)" }
        return detail
    }

    private var doneView: some View {
        let presentation = CleanOutcomePresentation(result: store.result)
        return VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 18) {
                Image(systemName: presentation.symbol)
                    .font(.system(size: 34, weight: .light)).foregroundStyle(presentation.tone)
                    .frame(width: 62, height: 62)
                    .background(presentation.tone.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 10) {
                    Text(presentation.title).font(.system(size: 24, weight: .semibold))
                    HStack(spacing: 12) {
                        Chip(text: "\(store.result?.cleaned ?? 0) 项已\(presentation.completionVerb)", tone: (store.result?.cleaned ?? 0) > 0 ? .done : .plain)
                        if let failed = store.result?.failed, failed > 0 {
                            Chip(text: "\(failed) 项未能\(store.cleanupMode == .delete ? "删除" : "移动")", tone: .failed)
                        }
                    }
                    Text("已\(presentation.completionVerb)项目的测量大小：\(AppsStore.formatBytes(store.result?.cleanedBytes ?? 0))")
                        .font(.system(size: 13)).foregroundStyle(Theme.dim2)
                    Spacer()
                }
                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
            Notice(text: store.cleanupMode == .delete
                ? "已直接删除所选项目，无法从废纸篓恢复。缓存类目录通常会在应用或系统再次使用时自动重建。"
                : "移入废纸篓后仍占用磁盘空间。需要时可从废纸篓恢复；栖理不会清空废纸篓。",
                   symbol: store.cleanupMode == .delete ? "trash.slash" : "arrow.uturn.backward",
                   tone: store.cleanupMode == .delete ? Theme.warm : Theme.dim2)
            if let failures = store.result?.failures, !failures.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("未能\(store.cleanupMode == .delete ? "删除" : "移动")的项目", detail: "这些项目未被本次操作移走")
                    ForEach(Array(failures.enumerated()), id: \.offset) { _, failure in
                        Label(failure, systemImage: "exclamationmark.circle")
                            .font(.system(size: 13)).foregroundStyle(Theme.warm)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(18).background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
            }
            HStack {
                PillButton(title: "重新扫描") { store.scan() }
                Text("重新测量后再选择下一批项目").font(.system(size: 12)).foregroundStyle(Theme.dim3)
            }
        }
    }

    private func sizeLabel(_ category: CleanCategory) -> String {
        category.measured ? (category.partial ? "≥ " : "") + AppsStore.formatBytes(category.sizeBytes) : "未测量"
    }

    private func sectionTitle(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 14, weight: .semibold)).accessibilityAddTraits(.isHeader)
            Spacer()
            Text(detail).font(.system(size: 12)).foregroundStyle(Theme.dim3)
        }
    }
}

private struct CleanItemRow: View {
    let item: CleanItem
    let selected: Bool
    let allowsLiveOperations: Bool
    let toggle: () -> Void
    @State private var detailsVisible = false

    var body: some View {
        RowBox(selected: selected) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    CheckView(on: selected, label: "选择\(item.name)", action: toggle)
                    Button { detailsVisible.toggle() } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                                Text(AppsStore.tildePath(URL(fileURLWithPath: item.id)))
                                    .font(Theme.monoSmall).foregroundStyle(Theme.dim3).lineLimit(1).truncationMode(.middle)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Text((item.partial ? "≥ " : "") + AppsStore.formatBytes(item.sizeBytes)).font(Theme.mono)
                            Image(systemName: detailsVisible ? "chevron.up" : "info.circle")
                                .foregroundStyle(Theme.dim3).frame(width: 20, height: 28)
                        }.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(detailsVisible ? "收起" : "查看")\(item.name)的路径与说明")
                    .accessibilityValue("\(item.partial ? "测量不完整，至少 " : "")\(AppsStore.formatBytes(item.sizeBytes))，路径 \(item.id)")
                }
                if detailsVisible {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(item.id).font(Theme.monoSmall).foregroundStyle(Theme.dim2).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        if item.partial { Text("大小未完整读取，仅显示已测量部分。").font(.system(size: 12)).foregroundStyle(Theme.warm) }
                        Button {
                            guard allowsLiveOperations else { return }
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.id)])
                        } label: { Label("在访达中显示", systemImage: "arrow.up.forward.square") }
                            .buttonStyle(WorkspaceButtonStyle())
                    }
                    .padding(.leading, 38).padding(.top, 4)
                }
            }
        }
    }
}

private struct CleanSteps: View {
    let phase: CleanStore.Phase
    private var current: Int {
        switch phase {
        case .ready, .scanning: 0
        case .result, .list: 1
        case .trashing, .done: 2
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ForEach(Array(["扫描", "查看并选择", "移到废纸篓"].enumerated()), id: \.offset) { index, title in
                HStack(spacing: 7) {
                    Text("\(index + 1)").font(.system(size: 11, weight: .semibold)).frame(width: 20, height: 20)
                        .background(index == current ? Theme.accent.opacity(0.14) : Theme.card, in: Circle())
                    Text(title).font(.system(size: 12, weight: index == current ? .semibold : .regular))
                }
                .foregroundStyle(index == current ? Theme.accent : Theme.dim3)
                if index < 2 { Rectangle().fill(Theme.line).frame(width: 24, height: 1).accessibilityHidden(true) }
            }
            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("第 \(current + 1) 步，共 3 步：\(["扫描", "查看并选择", "移到废纸篓"][current])")
    }
}

/// Kept outside the scrolling review list; selected count and final action stay visible.
struct CleanSelectionBar: View {
    @ObservedObject var store: CleanStore
    @State private var confirmVisible = false
    @State private var deleteConfirmVisible = false
    @State private var deleteAcknowledged = false
    private var bytes: Int64 { store.selectedItems.reduce(0) { $0 + $1.sizeBytes } }

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("已选 \(store.selectedItems.count) 项 · \(AppsStore.formatBytes(bytes))").font(.system(size: 14, weight: .semibold)).monospacedDigit()
                Text("移到废纸篓可恢复；直接删除立即释放空间，但不可恢复")
                    .font(.system(size: 12)).foregroundStyle(Theme.dim2)
            }
            Spacer(minLength: 10)
            PillButton(title: "整理所选…", disabled: store.selected.isEmpty || store.scanning) { confirmVisible = true }
        }
        .padding(.horizontal, 26).padding(.vertical, 18).background(Theme.surface)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        .alert("如何清理所选项目？", isPresented: $confirmVisible) {
            Button("取消", role: .cancel) {}
            Button("移到废纸篓") { Task { await store.cleanup(mode: .trash) } }
            Button("直接删除…", role: .destructive) {
                deleteAcknowledged = false
                deleteConfirmVisible = true
            }
        } message: {
            Text("""
                勾选的 \(store.selectedItems.count) 项（\(AppsStore.formatBytes(bytes))）。
                移到废纸篓：可从访达恢复，清空前仍占用磁盘。
                直接删除：立即释放空间，无法从废纸篓恢复。
                """)
        }
        .alert("直接删除所选项目？", isPresented: $deleteConfirmVisible) {
            Toggle("我了解直接删除后无法从废纸篓恢复", isOn: $deleteAcknowledged)
            Button("取消", role: .cancel) { deleteAcknowledged = false }
            Button("直接删除", role: .destructive) {
                deleteAcknowledged = false
                Task { await store.cleanup(mode: .delete) }
            }
            .disabled(!deleteAcknowledged)
        } message: {
            Text("""
                将永久删除勾选的 \(store.selectedItems.count) 项（\(AppsStore.formatBytes(bytes))）。
                缓存与构建目录通常会在应用或系统再次使用时自动重建。
                """)
        }
        .onChange(of: deleteConfirmVisible) { _, visible in
            if !visible { deleteAcknowledged = false }
        }
    }
}

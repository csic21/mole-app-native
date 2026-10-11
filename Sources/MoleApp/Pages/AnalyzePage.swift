import AppKit
import SwiftUI

struct AnalyzePage: View {
    @ObservedObject var store: AnalyzeStore
    @State private var search = ""
    @State private var showHidden = true
    @State private var listMode = false
    @State private var disk: SystemMetrics.DiskInfo?
    private let columns = [GridItem(.adaptive(minimum: 190), spacing: 10)]
    private let palette: [Color] = [Color(hex: 0x3B605A), Color(hex: 0x3C5465), Color(hex: 0x595B49),
                                  Color(hex: 0x5B5148), Color(hex: 0x435A55), Color(hex: 0x4E5368)]
    private var visibleItems: [AnalyzeItem] {
        let filtered = store.items.filter { (showHidden || !$0.name.hasPrefix(".")) && (search.isEmpty || $0.name.localizedStandardContains(search)) }
        // 测量期间保持位置稳定，避免目标在点击前移动到另一行。
        if store.sizing { return filtered }
        return filtered.sorted {
                if $0.sizeBytes != $1.sizeBytes { return ($0.sizeBytes ?? -1) > ($1.sizeBytes ?? -1) }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "folder.fill").font(.system(size: 25)).foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 5) {
                    Text("当前文件夹 · 实际分配大小").font(.system(size: 12)).foregroundStyle(Theme.dim2)
                    Text("\(store.items.count) 项 · \(store.totalText)").font(.system(size: 23, weight: .semibold))
                    Text(progressText).font(.system(size: 12)).foregroundStyle(Theme.dim3)
                }
                Spacer()
                if store.sizing {
                    ProgressView().controlSize(.small)
                    Button("停止") { store.stop() }.buttonStyle(.plain).foregroundStyle(Theme.accent)
                } else {
                    Button("重新测量") { store.rescan() }.buttonStyle(.plain).foregroundStyle(Theme.accent)
                }
                Button("选择文件夹…") { chooseFolder() }.buttonStyle(.bordered)
            }.padding(20).background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
            HStack(spacing: 5) {
                Button { store.goUp() } label: { Image(systemName: "arrow.up") }
                    .disabled(store.path.count < 2).help("返回上一层").keyboardShortcut(.upArrow, modifiers: .command)
                ForEach(Array(store.path.enumerated()), id: \.offset) { index, url in
                    if index > 0 { Text("›").foregroundStyle(Theme.dim3) }
                    Button(url == store.home ? "~" : url.lastPathComponent) { store.jump(to: index) }
                        .buttonStyle(.plain).lineLimit(1).help(url.path)
                }
                Spacer()
                Button { NSWorkspace.shared.activateFileViewerSelecting([store.current]) } label: {
                    Label("访达", systemImage: "arrow.up.forward.square")
                }.buttonStyle(.plain)
            }.font(.system(size: 12.5)).foregroundStyle(Theme.dim2)
            if store.totalBytes > 0 { distribution }
            HStack(spacing: 14) {
                TextField("搜索当前文件夹", text: $search).textFieldStyle(.roundedBorder).frame(maxWidth: 300)
                Toggle("显示隐藏项", isOn: $showHidden).toggleStyle(.checkbox)
                Spacer()
                Picker("显示方式", selection: $listMode) {
                    Text("卡片").tag(false)
                    Text("列表").tag(true)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 130)
            }.font(.system(size: 12))
            if let error = store.error {
                ContentUnavailableView("无法读取文件夹", systemImage: "folder.badge.questionmark", description: Text(error))
            } else if visibleItems.isEmpty && !store.sizing {
                ContentUnavailableView(search.isEmpty ? "文件夹为空" : "没有匹配的项目", systemImage: "folder", description: Text("可以选择其他文件夹或调整筛选条件。"))
            } else if listMode {
                LazyVStack(spacing: 5) { ForEach(visibleItems) { item in fileRow(item) } }
            } else {
                LazyVGrid(columns: columns, spacing: 10) { ForEach(visibleItems) { item in tile(item) } }
            }
            if let disk {
                Text("本卷已用 \(AppsStore.formatBytes(Int64(disk.usedBytes))) / \(AppsStore.formatBytes(Int64(disk.totalBytes))) · 部分文件不可访问时标为 ≥")
                    .font(Theme.monoSmall).foregroundStyle(Theme.dim3)
            }
        }
        .task {
            disk = await Task.detached(priority: .utility) { SystemMetrics.diskInfo() }.value
            if !store.hasLoaded { store.rescan() }
        }
        .onChange(of: store.current) { _, _ in search = "" }
    }

    private var progressText: String {
        if store.sizing { return "已测 \(store.sizedCount)/\(store.items.count) 项 · 结果逐步显示" }
        if store.stopped { return "测量已停止，保留已完成结果" }
        if store.fromCache { return "使用两分钟内的测量结果 · 可重新测量" }
        return "点击文件夹继续查看；文件可在访达中定位"
    }

    private var distribution: some View {
        let largest = Array(store.items.filter { ($0.sizeBytes ?? 0) > 0 }.sorted { ($0.sizeBytes ?? 0) > ($1.sizeBytes ?? 0) }.prefix(6))
        let other = store.totalBytes - largest.compactMap(\.sizeBytes).reduce(0, +)
        return VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(Array(largest.enumerated()), id: \.element.id) { index, item in
                        Button { enterOrReveal(item) } label: { palette[index % palette.count] }
                            .buttonStyle(.plain)
                            .frame(width: geometry.size.width * Double(item.sizeBytes ?? 0) / Double(store.totalBytes))
                            .help("\(item.name) · \(AppsStore.formatBytes(item.sizeBytes))")
                            .disabled(store.sizing)
                    }
                    if other > 0 { Theme.dim3.opacity(0.3) }
                }.clipShape(RoundedRectangle(cornerRadius: 5))
            }.frame(height: 16)
            Text((store.sizing || store.stopped ? "已测项目的占比：" : "最大项：") + largest.prefix(3).map { "\($0.name) \(share($0))" }.joined(separator: " · "))
                .font(.system(size: 12)).foregroundStyle(Theme.dim2).lineLimit(2)
        }
    }

    private func tile(_ item: AnalyzeItem) -> some View {
        Button { enterOrReveal(item) } label: {
            VStack(alignment: .leading, spacing: 9) {
                Label(item.name, systemImage: item.isDirectory ? "folder" : "doc")
                    .font(.system(size: 13, weight: .medium)).lineLimit(1)
                HStack {
                    Text(sizeText(item)).font(Theme.mono)
                    Spacer()
                    Text(share(item)).font(Theme.monoSmall).foregroundStyle(Theme.dim2)
                }
                BarView(value: fraction(item))
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).help(item.url.path)
            .contextMenu { revealButton(item) }
    }

    private func fileRow(_ item: AnalyzeItem) -> some View {
        RowBox {
            Button { enterOrReveal(item) } label: {
                HStack(spacing: 14) {
                    Label(item.name, systemImage: item.isDirectory ? "folder" : "doc").lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    BarView(value: fraction(item)).frame(width: 110)
                    Text(share(item)).font(Theme.monoSmall).foregroundStyle(Theme.dim3).frame(width: 55, alignment: .trailing)
                    Text(sizeText(item)).font(Theme.mono).frame(width: 100, alignment: .trailing)
                    Image(systemName: item.isDirectory ? "chevron.right" : "arrow.up.forward.square").foregroundStyle(Theme.dim3)
                }.font(.system(size: 13)).contentShape(Rectangle())
            }.buttonStyle(.plain).contextMenu { revealButton(item) }
        }
    }

    private func revealButton(_ item: AnalyzeItem) -> some View {
        Button("在访达中显示") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
    }
    private func sizeText(_ item: AnalyzeItem) -> String {
        guard let size = item.sizeBytes else { return store.sizing ? "测量中…" : "未测量" }
        return (item.partial ? "≥ " : "") + AppsStore.formatBytes(size)
    }
    private func fraction(_ item: AnalyzeItem) -> Double {
        store.totalBytes > 0 ? Double(item.sizeBytes ?? 0) / Double(store.totalBytes) * 100 : 0
    }
    private func share(_ item: AnalyzeItem) -> String { item.sizeBytes == nil ? "—" : String(format: "%.1f%%", fraction(item)) }
    private func enterOrReveal(_ item: AnalyzeItem) {
        if item.isDirectory { store.enter(item) }
        else { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
    }
    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = store.current
        panel.prompt = "分析此文件夹"
        panel.begin { response in if response == .OK, let url = panel.url { store.open(url) } }
    }
}

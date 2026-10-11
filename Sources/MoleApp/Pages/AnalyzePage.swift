import AppKit
import SwiftUI

struct AnalyzePage: View {
    @ObservedObject var store: AnalyzeStore
    @State private var search = ""
    @AppStorage private var showHidden: Bool
    @AppStorage private var listMode: Bool

    init(store: AnalyzeStore) {
        self.store = store
        _showHidden = AppStorage(wrappedValue: true, "analyze.showHidden")
        _listMode = AppStorage(wrappedValue: true, "analyze.listMode")
    }

#if DEBUG
    @MainActor
    init(snapshotStore: AnalyzeStore, listMode: Bool = true, showHidden: Bool = true) {
        precondition(!snapshotStore.allowsLiveOperations, "Snapshots require an inert store")
        store = snapshotStore
        // Private volatile preferences prevent captures from reading or changing app preferences.
        let suite = "QiliPreview.AnalyzePage.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.setVolatileDomain(["analyze.listMode": listMode, "analyze.showHidden": showHidden], forName: suite)
        _showHidden = AppStorage(wrappedValue: showHidden, "analyze.showHidden", store: defaults)
        _listMode = AppStorage(wrappedValue: listMode, "analyze.listMode", store: defaults)
    }
#endif

    private var hiddenPreference: Binding<Bool> {
        Binding(get: { showHidden }, set: { if store.allowsLiveOperations { showHidden = $0 } })
    }
    private var listPreference: Binding<Bool> {
        Binding(get: { listMode }, set: { if store.allowsLiveOperations { listMode = $0 } })
    }
    private let columns = [GridItem(.adaptive(minimum: 190), spacing: 10)]
    private let legendColumns = [GridItem(.adaptive(minimum: 280), spacing: 20)]
    private let palette: [Color] = [Color(hex: 0x8DAE9D), Color(hex: 0x879BB4), Color(hex: 0xB4A47E),
                                  Color(hex: 0xB59083), Color(hex: 0x9C91AC), Color(hex: 0x82ABAE)]
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
            folderSummary
            HStack(spacing: 5) {
                Button { store.goUp() } label: { Image(systemName: "arrow.up") }
                    .disabled(store.path.count < 2).help("返回上一层").keyboardShortcut(.upArrow, modifiers: .command)
                    .accessibilityLabel("返回上一层")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(store.path.enumerated()), id: \.offset) { index, url in
                            if index > 0 { Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(Theme.dim3) }
                            Button(url == store.home ? "~" : folderName(url)) { store.jump(to: index) }
                                .buttonStyle(.plain).fixedSize().help(url.path)
                                .foregroundStyle(index == store.path.count - 1 ? Theme.star : Theme.dim2)
                                .accessibilityLabel(url.path)
                        }
                    }
                }
                Button { reveal(store.current) } label: {
                    Label("访达", systemImage: "arrow.up.forward.square")
                }.buttonStyle(.plain).fixedSize().help("在访达中显示当前文件夹")
            }.font(.system(size: 12.5)).foregroundStyle(Theme.dim2)
            if store.totalBytes > 0 { distribution }
            HStack(spacing: 14) {
                TextField("搜索当前文件夹", text: $search).textFieldStyle(.roundedBorder).frame(maxWidth: 300)
                Toggle("显示隐藏项", isOn: hiddenPreference).toggleStyle(.checkbox)
                Spacer()
                Picker("显示方式", selection: listPreference) {
                    Text("列表").tag(true)
                    Text("卡片").tag(false)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 130)
            }.font(.system(size: 12))
            HStack {
                Text("显示 \(visibleItems.count) / \(store.items.count) 项")
                Spacer()
                Text(store.sizing ? "测量中保持名称顺序" : "按分配大小排列")
            }.font(.system(size: 12)).foregroundStyle(Theme.dim2)
            if let error = store.error {
                ContentUnavailableView("无法读取文件夹", systemImage: "folder.badge.questionmark", description: Text(error))
            } else if store.stopped && store.items.isEmpty {
                ContentUnavailableView("测量已停止", systemImage: "pause.circle", description: Text("重新测量以读取当前文件夹。"))
            } else if visibleItems.isEmpty && !store.sizing {
                ContentUnavailableView(store.items.isEmpty ? "文件夹为空" : "没有匹配的项目", systemImage: "folder", description: Text("可以选择其他文件夹或调整筛选条件。"))
            } else if listMode {
                VStack(spacing: 6) {
                    listHeader
                    LazyVStack(spacing: 3) { ForEach(visibleItems) { item in fileRow(item) } }
                }
            } else {
                Text("卡片等宽排列，占比见数值与进度条。")
                    .font(.system(size: 12)).foregroundStyle(Theme.dim2)
                LazyVGrid(columns: columns, spacing: 10) { ForEach(visibleItems) { item in tile(item) } }
            }
            Text("大小按文件实际分配空间计算；≥ 表示结果不完整，不等同于可释放空间。此页仅查看与定位文件。")
                .font(.system(size: 12)).foregroundStyle(Theme.dim2)
        }
        .task {
            guard store.allowsLiveOperations else { return }
            if !store.hasLoaded { store.rescan() }
        }
        .onChange(of: store.current) { _, _ in search = "" }
    }

    private var folderSummary: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 28)).foregroundStyle(Theme.accent)
                    .padding(.top, 3).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(folderName(store.current)).font(.system(size: 20, weight: .semibold)).lineLimit(1)
                    Text(store.current.path).font(Theme.monoSmall).foregroundStyle(Theme.dim2)
                        .lineLimit(1).truncationMode(.middle).textSelection(.enabled).help(store.current.path)
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 6) {
                    Text(totalText).font(.system(size: 25, weight: .semibold)).monospacedDigit()
                    Text("\(store.items.count) 项 · 已测分配大小")
                        .font(.system(size: 12)).foregroundStyle(Theme.dim2)
                }.fixedSize(horizontal: true, vertical: false)
            }
            HStack(spacing: 12) {
                if store.sizing { ProgressView().controlSize(.small) }
                Text(progressText).font(.system(size: 12)).foregroundStyle(Theme.dim2)
                Spacer(minLength: 12)
                if store.sizing {
                    Button("停止") { store.stop() }.buttonStyle(.bordered)
                } else {
                    Button("重新测量") { store.rescan() }.buttonStyle(.bordered)
                }
                Button("选择文件夹…") { chooseFolder() }.buttonStyle(.bordered)
            }
        }
        .padding(20).background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line))
    }

    private var totalText: String {
        if store.error != nil || ((store.sizing || store.stopped) && store.items.isEmpty) { return "—" }
        let incomplete = store.items.contains { $0.sizeBytes == nil || $0.partial }
        return (incomplete ? "≥ " : "") + store.totalText
    }

    private func folderName(_ url: URL) -> String {
        url.lastPathComponent.isEmpty ? "/" : url.lastPathComponent
    }

    private var progressText: String {
        if store.sizing { return "已测 \(store.sizedCount)/\(store.items.count) 项 · 结果逐步显示" }
        if store.stopped { return "测量已停止，保留已完成结果" }
        if store.fromCache { return "使用两分钟内的测量结果 · 可重新测量" }
        return "点击文件夹继续查看；文件可在访达中定位"
    }

    private var distribution: some View {
        let largest = Array(visibleItems.filter { ($0.sizeBytes ?? 0) > 0 }.sorted {
            if $0.sizeBytes != $1.sizeBytes { return ($0.sizeBytes ?? 0) > ($1.sizeBytes ?? 0) }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }.prefix(6))
        let other = max(0, store.totalBytes - largest.compactMap(\.sizeBytes).reduce(0, +))
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("空间分布").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("以当前文件夹全部已测大小为基准")
                    .font(.system(size: 12)).foregroundStyle(Theme.dim2)
            }
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(Array(largest.enumerated()), id: \.element.id) { index, item in
                        Button { enterOrReveal(item) } label: { palette[index % palette.count] }
                            .buttonStyle(.plain)
                            .frame(width: geometry.size.width * Double(item.sizeBytes ?? 0) / Double(store.totalBytes))
                            .help("\(item.name) · \(sizeText(item)) · \(share(item))")
                            .accessibilityLabel("\(item.name)，\(sizeText(item))，占比 \(share(item))")
                            .disabled(store.sizing)
                    }
                    if other > 0 {
                        Theme.dim3.opacity(0.45)
                            .frame(width: geometry.size.width * Double(other) / Double(store.totalBytes))
                            .accessibilityLabel("其余项目，\(AppsStore.formatBytes(other))")
                    }
                }.clipShape(RoundedRectangle(cornerRadius: 5))
            }.frame(height: 18)
            LazyVGrid(columns: legendColumns, alignment: .leading, spacing: 9) {
                ForEach(Array(largest.enumerated()), id: \.element.id) { index, item in
                    distributionKey(name: item.name, size: sizeText(item), share: share(item), color: palette[index])
                        .help(item.url.path)
                }
                if other > 0 {
                    distributionKey(name: "其余项目", size: AppsStore.formatBytes(other),
                                    share: String(format: "%.1f%%", Double(other) / Double(store.totalBytes) * 100),
                                    color: Theme.dim3.opacity(0.45))
                }
            }
            if !showHidden || !search.isEmpty || store.sizing || store.stopped || store.items.contains(where: \.partial) {
                Text("筛选不改变占比基准；已筛除项目计入「其余项目」。未完成或受限的测量仅统计已读部分。")
                    .font(.system(size: 12)).foregroundStyle(Theme.dim2)
            }
        }
    }

    private func distributionKey(name: String, size: String, share: String, color: Color) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 9, height: 9).accessibilityHidden(true)
            Text(name).lineLimit(1).truncationMode(.middle).frame(maxWidth: .infinity, alignment: .leading)
            Text(size).font(Theme.monoSmall).foregroundStyle(Theme.dim2).fixedSize()
            Text(share).font(Theme.monoSmall).foregroundStyle(Theme.dim2).frame(width: 54, alignment: .trailing)
        }.font(.system(size: 12))
            .accessibilityElement(children: .combine)
    }

    private var listHeader: some View {
        HStack(spacing: 14) {
            Text("名称").frame(maxWidth: .infinity, alignment: .leading)
            Text("占文件夹已测大小").frame(width: 179, alignment: .trailing)
            Text("分配大小").frame(width: 100, alignment: .trailing)
            Color.clear.frame(width: 12, height: 1)
        }.font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.dim2)
            .padding(.horizontal, 14).padding(.bottom, 3)
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
                    Text(share(item)).font(Theme.monoSmall).foregroundStyle(Theme.dim2).frame(width: 55, alignment: .trailing)
                    Text(sizeText(item)).font(Theme.mono).frame(width: 100, alignment: .trailing)
                    Image(systemName: item.isDirectory ? "chevron.right" : "arrow.up.forward.square").foregroundStyle(Theme.dim3)
                        .frame(width: 12).accessibilityHidden(true)
                }.font(.system(size: 13)).contentShape(Rectangle())
            }.buttonStyle(.plain).help(item.url.path).contextMenu { revealButton(item) }
        }
    }

    private func revealButton(_ item: AnalyzeItem) -> some View {
        Button("在访达中显示") { reveal(item.url) }
    }
    private func reveal(_ url: URL) {
        guard store.allowsLiveOperations else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
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
        guard store.allowsLiveOperations else { return }
        if item.isDirectory { store.enter(item) }
        else { reveal(item.url) }
    }
    private func chooseFolder() {
        guard store.allowsLiveOperations else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = store.current
        panel.prompt = "分析此文件夹"
        panel.begin { response in if response == .OK, let url = panel.url { store.open(url) } }
    }
}

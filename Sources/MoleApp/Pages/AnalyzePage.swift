import AppKit
import SwiftUI

struct AnalyzePage: View {
    @ObservedObject var store: AnalyzeStore
    @State private var disk: SystemMetrics.DiskInfo?

    private let columns = [GridItem(.adaptive(minimum: 180), spacing: 10)]
    private let palette: [Color] = [
        Color(hex: 0x3B605A), Color(hex: 0x3C5465), Color(hex: 0x595B49),
        Color(hex: 0x5B5148), Color(hex: 0x435A55), Color(hex: 0x4E5368),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "folder.fill").font(.system(size: 25)).foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 5) {
                    Text("当前文件夹").font(.system(size: 12)).foregroundStyle(Theme.dim2)
                    Text("\(store.items.count) 项，占用 \(store.totalText)")
                        .font(.system(size: 19, weight: .semibold))
                }
                Spacer()
                Button("重新测量") { store.rescan() }
                    .buttonStyle(.plain).foregroundStyle(Theme.accent)
                    .disabled(store.sizing)
            }
            .padding(20)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
            mapHead
            tiles
            FootBar(note: "点文件夹继续查看；点文件在访达中显示。") {
                PillButton(title: "返回上一层", disabled: store.path.count <= 1) { store.goUp() }
            }
        }
        .task {
            disk = SystemMetrics.diskInfo()
            if store.items.isEmpty && !store.sizing { store.rescan() }
        }
    }

    private var mapHead: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                ForEach(Array(store.path.enumerated()), id: \.offset) { index, url in
                    if index > 0 { Text(" › ").foregroundStyle(Theme.dim3) }
                    Button(displayName(for: url, isHome: index == 0)) {
                        store.jump(to: index)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.dim2)
                }
            }
            .font(.system(size: 12.5))
            if let disk {
                Text("文件 \(store.totalText) · 已用 \(AppsStore.formatBytes(Int64(disk.usedBytes)))/\(AppsStore.formatBytes(Int64(disk.totalBytes)))")
                    .font(Theme.mono)
                    .foregroundStyle(Theme.dim2)
            }
        }
        .padding(.top, 2)
    }

    private var tiles: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                Button {
                    enterOrReveal(item)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(item.name, systemImage: item.isDirectory ? "folder" : "doc")
                            .font(.system(size: 12.5, weight: .semibold))
                            .lineLimit(1)
                        if let size = item.sizeBytes {
                            Text(AppsStore.formatBytes(size))
                                .font(Theme.monoSmall)
                                .foregroundStyle(.white.opacity(0.62))
                        } else {
                            Text("测量中…")
                                .font(Theme.monoSmall)
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .frame(height: 92)
                    .background(palette[index % palette.count], in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white.opacity(0.9))
                    .contentShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("在访达中显示") {
                        NSWorkspace.shared.activateFileViewerSelecting([item.url])
                    }
                }
            }
        }
    }

    private func enterOrReveal(_ item: AnalyzeItem) {
        if item.isDirectory {
            store.enter(item)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([item.url])
        }
    }

    private func displayName(for url: URL, isHome: Bool) -> String {
        if isHome { return "~" }
        return url.lastPathComponent
    }
}

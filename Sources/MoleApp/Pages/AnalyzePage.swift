import AppKit
import SwiftUI

struct AnalyzePage: View {
    @StateObject private var store = AnalyzeStore()
    @State private var disk: SystemMetrics.DiskInfo?

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
    ]

    private let palette: [Color] = [
        Color(hex: 0x5B4A42),
        Color(hex: 0x8A4A34),
        Color(hex: 0x6B5A68),
        Color(hex: 0x8A6A3C),
        Color(hex: 0x6E5433),
        Color(hex: 0x5A5566),
        Color(hex: 0x5A5348),
        Color(hex: 0x4F5F6E),
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            side
            VStack(alignment: .leading, spacing: 10) {
                mapHead
                tiles
                FootBar(note: "点方块进入下一层 · 右键可在访达中显示") {
                    PillButton(title: "返回上一层", disabled: store.path.count <= 1) {
                        store.goUp()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            disk = SystemMetrics.diskInfo()
            if store.items.isEmpty && !store.sizing {
                store.rescan()
            }
        }
    }

    private var side: some View {
        VStack(spacing: 6) {
            JupiterView()
                .padding(.top, 4)
                .padding(.bottom, 6)
            Text("\(store.items.count) 项 · \(store.totalText)")
                .font(.system(size: 13))
            Text("当前目录")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.dim3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            ForEach(store.items) { item in
                Button {
                    enterOrReveal(item)
                } label: {
                    HStack(spacing: 8) {
                        Text(item.name)
                            .font(.system(size: 13))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let size = item.sizeBytes {
                            Text(AppsStore.formatBytes(size)).font(Theme.mono).foregroundStyle(Theme.dim2)
                        } else {
                            ProgressView().controlSize(.mini)
                        }
                        Text(item.isDirectory ? "›" : "").foregroundStyle(Theme.dim3)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("在访达中显示") {
                        NSWorkspace.shared.activateFileViewerSelecting([item.url])
                    }
                }
            }
            Spacer(minLength: 12)
            Text("右键可打开或移到废纸篓")
                .font(.system(size: 11))
                .foregroundStyle(Theme.dim3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 248)
        .padding(.trailing, 12)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Theme.line).frame(width: 1)
        }
    }

    private var mapHead: some View {
        HStack {
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
            Spacer()
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
                        Text("▸ \(item.name)")
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

struct JupiterView: View {
    var size: CGFloat = 74

    var body: some View {
        ZStack {
            Circle().fill(
                LinearGradient(
                    colors: [Color(hex: 0xD9B184), Color(hex: 0xB98A5C), Color(hex: 0xE2C39A), Color(hex: 0xA97A4E)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
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
        .overlay(Circle().strokeBorder(.black.opacity(0.25), lineWidth: 6).blur(radius: 4))
    }
}

import AppKit
import SwiftUI

struct AppsPage: View {
    private enum Sub: String, CaseIterable { case uninstall = "卸载", update = "更新", login = "启动项" }

    @ObservedObject var store: AppsStore
    @ObservedObject var loginStore: LoginItemsStore
    @State private var sub: Sub = .uninstall
    @State private var selected: Set<String> = []
    @State private var expanded: String?
    @State private var leftoverCache: [String: [LeftoverItem]] = [:]
    @State private var updated: Set<String> = []
    @State private var pendingEntry: LoginEntry?
    @State private var showConfirm = false

    private var apps: [ScannedApp] { store.apps }

    private var selectedBytes: Int64 {
        apps.filter { selected.contains($0.id) }.compactMap(\.sizeBytes).reduce(0, +)
    }

    var body: some View {
        VStack(spacing: 2) {
            subnav

            switch sub {
            case .uninstall: uninstallList
            case .update: updateList
            case .login: loginList
            }
        }
        .task {
            if store.apps.isEmpty && !store.scanning {
                store.refresh()
            }
        }
    }

    private var subnav: some View {
        HStack(spacing: 4) {
            ForEach(Sub.allCases, id: \.self) { item in
                Button(item.rawValue) { sub = item }
                    .buttonStyle(.plain)
                    .font(.system(size: 12.5))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 5)
                    .background(
                        sub == item ? Color(hex: 0xEFE8D8, opacity: 0.12) : .clear,
                        in: Capsule()
                    )
                    .foregroundStyle(sub == item ? Theme.star : Theme.dim2)
            }
            Spacer()
            if store.scanning {
                Text("正在扫描 /Applications…")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.dim3)
            } else {
                Text("\(apps.count) 个应用 · 大小 \(store.sizedCount)/\(apps.count) 已测量")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.dim3)
            }
            Button("重新扫描") { store.refresh() }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(Theme.dim2)
                .underline()
        }
        .padding(.bottom, 10)
    }

    private var uninstallList: some View {
        LazyVStack(spacing: 2) {
            if store.scanning {
                scanningPlaceholder
            } else if apps.isEmpty {
                Text("没有在 /Applications 找到应用")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.dim2)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            } else {
                Text("已安装 App \(apps.count) 个 · 大小测量 \(store.sizedCount)/\(apps.count)")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.dim2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 10)
                    .padding(.bottom, 6)
            }

            // ForEach 直接挂在 LazyVStack 下:滚动时只渲染可见行。
            ForEach(store.scanning || apps.isEmpty ? [] : apps) { app in
                RowBox(selected: selected.contains(app.id)) {
                    HStack(spacing: 12) {
                        appIcon(app)
                        Text(app.name)
                            .font(.system(size: 13.5))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(app.version) · \(AppsStore.formatBytes(app.sizeBytes)) · \(app.modified)")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.dim2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(AppsStore.formatBytes(app.sizeBytes))
                            .font(Theme.mono)
                            .foregroundStyle(Theme.dim2)
                        CheckView(on: selected.contains(app.id)) { toggle(app.id) }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        expanded = expanded == app.id ? nil : app.id
                        loadLeftoversIfNeeded(app)
                    }
                }

                if expanded == app.id {
                    expandPanel(app)
                }
            }

            if !store.scanning && !apps.isEmpty {
                FootBar(note: footerNote) {
                    PillButton(title: "移除 \(selected.count) 项", disabled: selected.isEmpty) {
                        selected = []
                        expanded = nil
                    }
                }
            }
        }
    }

    private func appIcon(_ app: ScannedApp) -> some View {
        Group {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 28, height: 28)
            }
        }
    }

    private var scanningPlaceholder: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text("正在读取 /Applications 与 ~/Applications …")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.dim2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 70)
    }

    private var footerNote: String {
        let sizeText = selectedBytes > 0 ? AppsStore.formatBytes(selectedBytes) : "大小测量中"
        return "\(selected.count) 个 App · \(sizeText) — 真实删除将在下一步接入"
    }

    private func expandPanel(_ app: ScannedApp) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("清除")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.dim2)
                Spacer()
                Button("在访达中显示") {
                    NSWorkspace.shared.activateFileViewerSelecting([app.url])
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(Theme.dim2)
                .underline()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            if let items = leftoverCache[app.id] {
                if items.isEmpty {
                    Text("没有找到关联残留文件")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.dim3)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                } else {
                    ForEach(items) { item in
                        RowBox {
                            HStack(spacing: 12) {
                                CheckView(on: true)
                                Text(item.kind)
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(Theme.star.opacity(0.72))
                                    .frame(width: 90, alignment: .leading)
                                Text(item.path)
                                    .font(Theme.monoSmall)
                                    .foregroundStyle(Theme.dim3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(AppsStore.formatBytes(item.sizeBytes))
                                    .font(Theme.mono)
                                    .foregroundStyle(Theme.dim2)
                            }
                        }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("正在检查关联文件…")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.dim3)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .padding(6)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line))
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
    }

    private func loadLeftoversIfNeeded(_ app: ScannedApp) {
        guard leftoverCache[app.id] == nil else { return }
        Task.detached(priority: .userInitiated) {
            let items = AppsStore.leftovers(for: app)
            await MainActor.run {
                leftoverCache[app.id] = items
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

    // ---------------------------------------------------------- 更新 / 启动项(示意,下一步接真实来源)

    private var updateList: some View {
        Group {
            Text("更新检查将在接入 Sparkle / App Store 后展示真实结果")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.dim2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 10)
                .padding(.bottom, 6)
            ForEach(MockData.updates) { row in
                RowBox {
                    HStack(spacing: 12) {
                        AppIconView(mark: row.mark, tone: row.tone)
                        Text(row.name)
                            .font(.system(size: 13.5))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(row.from) → \(row.to)")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.dim2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            updated.insert(row.id)
                        } label: {
                            Text(updated.contains(row.id) ? "已是最新" : "更新")
                                .font(.system(size: 12))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(
                                    updated.contains(row.id) ? Color.white.opacity(0.08) : Color(hex: 0xEFE8D8, opacity: 0.9),
                                    in: Capsule()
                                )
                                .foregroundStyle(updated.contains(row.id) ? Theme.dim2 : Color(hex: 0x17181B))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            FootBar(note: "更新来源:Sparkle · App Store · Homebrew") {
                PillButton(title: "全部更新", disabled: updated.count == MockData.updates.count) {
                    for row in MockData.updates { updated.insert(row.id) }
                }
            }
        }
    }

    private var loginList: some View {
        LazyVStack(spacing: 2) {
            Text("来自 ~/Library 与 /Library 的 LaunchAgents;macOS 设置的登录项(BTM)暂不读取")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.dim2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 10)
                .padding(.bottom, 6)

            if loginStore.scanning && loginStore.entries.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("正在读取登录项…")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.dim2)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            }

            ForEach(loginStore.scanning && loginStore.entries.isEmpty ? [] : loginStore.entries) { entry in
                RowBox {
                    HStack(spacing: 12) {
                        CheckView(on: !entry.disabled) {
                            guard entry.scope == .user else { return }
                            pendingEntry = entry
                            showConfirm = true
                        }
                        .opacity(entry.scope == .user ? 1 : 0.4)

                        HStack(spacing: 6) {
                            Text(entry.label)
                                .font(.system(size: 13))
                                .lineLimit(1)
                            Text(entry.scope == .user ? "用户" : "系统")
                                .font(.system(size: 10.5))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.08), in: Capsule())
                                .foregroundStyle(Theme.dim3)
                        }
                        .frame(width: 330, alignment: .leading)

                        Text(entry.program.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "—")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.dim2)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let error = loginStore.errors[entry.id] {
                            Text(error)
                                .font(.system(size: 11.5))
                                .foregroundStyle(Color(hex: 0xF09090))
                                .lineLimit(1)
                                .frame(width: 200, alignment: .trailing)
                        }

                        Text(stateText(for: entry))
                            .font(Theme.monoSmall)
                            .foregroundStyle(Theme.dim2)
                            .frame(width: 110, alignment: .trailing)
                    }
                }
            }

            FootBar(note: "用户级 \(loginStore.entries.filter { $0.scope == .user && !$0.disabled }.count) 项启用 · 启停跨重启生效") {
                PillButton(title: "重新扫描") { loginStore.scan() }
            }
        }
        .task {
            if loginStore.entries.isEmpty && !loginStore.scanning {
                loginStore.scan()
            }
        }
        .alert("登录项", isPresented: $showConfirm) {
            Button("取消", role: .cancel) { pendingEntry = nil }
            if let entry = pendingEntry {
                Button(entry.disabled ? "启用" : "停用", role: entry.disabled ? nil : .destructive) {
                    Task {
                        await loginStore.setEnabled(entry, enabled: entry.disabled)
                        pendingEntry = nil
                    }
                }
            }
        } message: {
            if let entry = pendingEntry {
                Text(entry.disabled
                    ? "启用 \(entry.label) 会立即加载,并在之后每次登录自动运行。"
                    : "停用 \(entry.label) 会立即停止它,之后每次登录也不再运行;随时可以再启用。")
            }
        }
    }

    private func stateText(for entry: LoginEntry) -> String {
        if entry.scope == .system { return "只读" }
        if entry.disabled { return "已停用" }
        return entry.loaded ? "已启用 · 运行中" : "已启用"
    }
}

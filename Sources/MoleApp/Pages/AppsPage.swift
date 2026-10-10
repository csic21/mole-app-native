import AppKit
import SwiftUI

struct AppsPage: View {
    private enum Sub: String, CaseIterable { case uninstall = "卸载", update = "更新", login = "启动项" }

    @StateObject private var store = AppsStore()
    @State private var sub: Sub = .uninstall
    @State private var selected: Set<String> = []
    @State private var expanded: String?
    @State private var leftoverCache: [String: [LeftoverItem]] = [:]
    @State private var updated: Set<String> = []
    @State private var loginItems = MockData.loginItems

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
        Group {
            if store.scanning {
                scanningPlaceholder
            } else if apps.isEmpty {
                Text("没有在 /Applications 找到应用")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.dim2)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            } else {
                ForEach(apps) { app in
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
        Group {
            Text("登录项读取将在下一步接入(ServiceManagement)")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.dim2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 10)
                .padding(.bottom, 6)
            ForEach($loginItems) { $item in
                RowBox {
                    HStack(spacing: 12) {
                        CheckView(on: item.on) { item.on.toggle() }
                        Text(item.name)
                            .font(.system(size: 13.5))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(item.note)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.dim2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(item.on ? "已启用" : "已停用")
                            .font(Theme.mono)
                            .foregroundStyle(Theme.dim2)
                    }
                }
            }
            FootBar(note: "\(loginItems.filter { !$0.on }.count) 项已停用") {
                PillButton(title: "恢复默认") { loginItems = MockData.loginItems }
            }
        }
    }
}

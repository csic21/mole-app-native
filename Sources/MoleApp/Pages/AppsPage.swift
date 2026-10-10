import SwiftUI

struct AppsPage: View {
    private enum Sub: String, CaseIterable { case uninstall = "卸载", update = "更新", login = "启动项" }

    @State private var sub: Sub = .uninstall
    @State private var selected: Set<String> = ["vscode"]
    @State private var expanded: String? = "vscode"
    @State private var removed: Set<String> = []
    @State private var updated: Set<String> = []
    @State private var loginItems = MockData.loginItems

    private var apps: [MockData.InstalledApp] {
        MockData.installedApps.filter { !removed.contains($0.id) }
    }

    private var selectedMB: Double {
        apps.filter { selected.contains($0.id) }.reduce(0) { $0 + $1.sizeMB }
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
            Text("名称 · App 大小 · 最近使用 · 安装日期 ↓")
                .font(.system(size: 12))
                .foregroundStyle(Theme.dim3)
        }
        .padding(.bottom, 10)
    }

    private var uninstallList: some View {
        Group {
            Text("已安装 App \(apps.count + 28) 个 · 18.31GB")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.dim2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 10)
                .padding(.bottom, 6)

            ForEach(apps) { app in
                RowBox(selected: selected.contains(app.id)) {
                    HStack(spacing: 12) {
                        AppIconView(mark: app.mark, tone: app.tone)
                        Text(app.name)
                            .font(.system(size: 13.5))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(app.meta)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.dim2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("移除 \(MockData.formatSize(app.sizeMB))")
                            .font(Theme.mono)
                            .foregroundStyle(Theme.dim2)
                        CheckView(on: selected.contains(app.id)) { toggle(app.id) }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { expanded = expanded == app.id ? nil : app.id }
                }

                if expanded == app.id {
                    expandPanel
                }
            }

            FootBar(note: "\(selected.count) 个 App · \(MockData.formatSize(selectedMB)) — 一并移除数据 · 取消选择") {
                PillButton(title: "移除 \(selected.count) 项", disabled: selected.isEmpty) {
                    removed.formUnion(selected)
                    selected = []
                    expanded = nil
                }
            }
        }
    }

    private var expandPanel: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("清除")
                .font(.system(size: 12))
                .foregroundStyle(Theme.dim2)
                .padding(.leading, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)
            ForEach(MockData.vscodeLeftovers, id: \.path) { item in
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
                        Text(item.size).font(Theme.mono).foregroundStyle(Theme.dim2)
                    }
                }
            }
        }
        .padding(6)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line))
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
    }

    private var updateList: some View {
        Group {
            Text("\(MockData.updates.count) 个应用有新版本")
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
            Text("登录项与后台项,所有改动即时生效")
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

    private func toggle(_ id: String) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }
}

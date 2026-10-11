import AppKit
import SwiftUI

enum WorkspaceTab: String, CaseIterable, Identifiable {
    case clean, apps, optimize, analyze, status
    var id: String { rawValue }

    var label: String {
        switch self {
        case .clean: "空间整理"
        case .apps: "应用管理"
        case .optimize: "系统维护"
        case .analyze: "文件地图"
        case .status: "运行状态"
        }
    }

    var symbol: String {
        switch self {
        case .clean: "tray.2"
        case .apps: "square.stack.3d.up"
        case .optimize: "slider.horizontal.3"
        case .analyze: "folder.badge.gearshape"
        case .status: "waveform.path.ecg"
        }
    }

    var detail: String {
        switch self {
        case .clean: "看清占用，再决定哪些可以离开。"
        case .apps: "应用、更新与启动项，集中打理。"
        case .optimize: "按需运行维护任务，每一步都有记录。"
        case .analyze: "沿着文件夹找出空间去了哪里。"
        case .status: "观察此刻的负载，让数字说明状态。"
        }
    }
}

struct ContentView: View {
    @State private var tab: WorkspaceTab = .clean
    @StateObject private var cleanStore = CleanStore()
    @StateObject private var appsStore = AppsStore()
    @StateObject private var loginStore = LoginItemsStore()
    @StateObject private var updateStore = UpdateStore()
    @StateObject private var optimizeStore = OptimizeStore()
    @StateObject private var analyzeStore = AnalyzeStore()
    @StateObject private var statusStore = StatusStore()
    @StateObject private var selfUpdate = SelfUpdateStore()

    var body: some View {
        WorkspaceShell(tab: $tab,
                       updateTitle: selfUpdate.updateAvailable ? selfUpdate.latestTag : nil,
                       updateAction: { if let url = selfUpdate.releaseURL { NSWorkspace.shared.open(url) } },
                       scrollKey: pageIdentity) {
            page
        } footer: {
            if tab == .clean && cleanStore.phase == .list {
                CleanSelectionBar(store: cleanStore)
            }
        }
        .background(WindowConfigurator().frame(width: 0, height: 0))
        .task { selfUpdate.checkOnce() }
    }

    private var pageIdentity: String {
        switch tab {
        case .clean: tab.rawValue + "|" + String(describing: cleanStore.phase)
        case .analyze: tab.rawValue + "|" + analyzeStore.current.path
        default: tab.rawValue
        }
    }

    @ViewBuilder
    private var page: some View {
        switch tab {
        case .clean: CleanPage(store: cleanStore)
        case .apps: AppsPage(store: appsStore, loginStore: loginStore, updateStore: updateStore)
        case .optimize: OptimizePage(store: optimizeStore)
        case .analyze: AnalyzePage(store: analyzeStore)
        case .status: StatusPage(store: statusStore)
        }
    }
}

/// Presentation-only shell. Previews and snapshot tests never create live stores.
struct WorkspaceShell<Content: View, Footer: View>: View {
    @Binding var tab: WorkspaceTab
    let updateTitle: String?
    let updateAction: () -> Void
    let scrollKey: String
    let content: Content
    let footer: Footer

    init(tab: Binding<WorkspaceTab>, updateTitle: String? = nil, updateAction: @escaping () -> Void = {},
         scrollKey: String = "", @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {
        self._tab = tab
        self.updateTitle = updateTitle
        self.updateAction = updateAction
        self.scrollKey = scrollKey
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(tab: $tab, updateTitle: updateTitle, updateAction: updateAction)
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tab.label).font(.system(size: 24, weight: .semibold))
                            .accessibilityAddTraits(.isHeader)
                        Text(tab.detail).font(.system(size: 13)).foregroundStyle(Theme.dim2)
                    }
                    Spacer(minLength: 0)
                    Label("本机工作台", systemImage: "desktopcomputer")
                        .font(.system(size: 12)).foregroundStyle(Theme.dim3)
                }
                .padding(.horizontal, 28)
                .padding(.top, 34)
                .padding(.bottom, 22)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            Color.clear.frame(height: 0).id("workspace-top")
                            content
                                .padding(26)
                                .frame(maxWidth: 1080)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    // Reset scroll position, not the identity of the page's controls.
                    .onChange(of: scrollKey) { _, _ in proxy.scrollTo("workspace-top", anchor: .top) }
                }
                footer
            }
            .background(Theme.canvas)
        }
        .foregroundStyle(Theme.star)
        .tint(Theme.accent)
    }
}

private struct Sidebar: View {
    @Binding var tab: WorkspaceTab
    let updateTitle: String?
    let updateAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                LogoView(size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text("栖理").font(.system(size: 20, weight: .semibold))
                    Text("Qili").font(.system(size: 12)).foregroundStyle(Theme.dim2)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 30)

            Text("我的 Mac")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.dim3)
                .padding(.leading, 12).padding(.bottom, 10)

            ForEach(Array(WorkspaceTab.allCases.enumerated()), id: \.element.id) { index, item in
                SidebarItem(item: item, selected: tab == item) { tab = item }
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                    .help("\(item.label) · ⌘\(index + 1)")
                    .padding(.bottom, 4)
            }
            Spacer(minLength: 24)
            Divider().overlay(Theme.line).padding(.bottom, 16)
            if let updateTitle {
                Button(action: updateAction) {
                    Label("下载更新 \(updateTitle)", systemImage: "arrow.down.circle")
                }
                .buttonStyle(WorkspaceButtonStyle(kind: .quiet))
                .padding(.bottom, 8)
            }
            Text("栖理 v\(AppVersion.current)").font(.system(size: 12)).foregroundStyle(Theme.dim2)
            Text("给文件留位置，给工作留余地。")
                .font(.system(size: 11)).foregroundStyle(Theme.dim3).padding(.top, 6)
        }
        .padding(.horizontal, 14)
        .padding(.top, 52)
        .padding(.bottom, 24)
        .frame(width: 204)
        .background(Theme.sidebar)
        .overlay(alignment: .trailing) { Rectangle().fill(Theme.line).frame(width: 1) }
    }
}

private struct SidebarItem: View {
    let item: WorkspaceTab
    let selected: Bool
    let action: () -> Void
    @State private var hover = false
    @FocusState private var focused: Bool

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: item.symbol).font(.system(size: 16)).frame(width: 20)
                    .foregroundStyle(selected ? Theme.accent : Theme.dim2)
                Text(item.label).font(.system(size: 13, weight: selected ? .semibold : .regular))
                Spacer(minLength: 0)
                if selected { Circle().fill(Theme.accent).frame(width: 5, height: 5) }
            }
            .padding(.horizontal, 12).frame(height: 42)
            .foregroundStyle(selected ? Theme.star : Theme.dim2)
            .background(selected ? Theme.selection : (hover ? Theme.cardHover : .clear), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .focused($focused)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(focused ? Theme.accent : .clear, lineWidth: 2))
        .onHover { hover = $0 }
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

struct LogoView: View {
    var size: CGFloat = 28
    var body: some View {
        Image(nsImage: BrandAssets.logo)
            .resizable().interpolation(.high).scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("栖理")
    }
}

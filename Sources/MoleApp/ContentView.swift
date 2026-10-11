import AppKit
import SwiftUI

enum Tab: String, CaseIterable, Identifiable {
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
    @State private var tab: Tab = .clean
    @StateObject private var cleanStore = CleanStore()
    @StateObject private var appsStore = AppsStore()
    @StateObject private var loginStore = LoginItemsStore()
    @StateObject private var updateStore = UpdateStore()
    @StateObject private var optimizeStore = OptimizeStore()
    @StateObject private var analyzeStore = AnalyzeStore()
    @StateObject private var statusStore = StatusStore()
    @StateObject private var selfUpdate = SelfUpdateStore()

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(tab: $tab, selfUpdate: selfUpdate)
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(tab.label).font(.system(size: 25, weight: .semibold))
                        Text(tab.detail).font(.system(size: 13)).foregroundStyle(Theme.dim2)
                    }
                    Spacer()
                    Label("本机工作台", systemImage: "desktopcomputer")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.dim2)
                }
                .padding(.horizontal, 30)
                .padding(.top, 34)
                .padding(.bottom, 24)
                .background(Theme.surface)

                ScrollView {
                    page
                        .padding(26)
                        .frame(maxWidth: 1080)
                        .frame(maxWidth: .infinity)
                }
                .id(pageIdentity)
                if tab == .clean && cleanStore.phase == .list {
                    CleanSelectionBar(store: cleanStore)
                }
            }
            .background(Theme.canvas)
        }
        .foregroundStyle(Theme.star)
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

private struct Sidebar: View {
    @Binding var tab: Tab
    @ObservedObject var selfUpdate: SelfUpdateStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                LogoView(size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text("栖理").font(.system(size: 21, weight: .semibold))
                    Text("Qili").font(.system(size: 12)).foregroundStyle(Theme.dim2)
                }
            }
            .padding(.bottom, 38)

            Text("我的 Mac")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.dim3)
                .padding(.leading, 12)
                .padding(.bottom, 12)

            ForEach(Tab.allCases) { item in
                Button { tab = item } label: {
                    HStack(spacing: 12) {
                        Image(systemName: item.symbol).frame(width: 20)
                        Text(item.label).font(.system(size: 13, weight: tab == item ? .semibold : .regular))
                        Spacer(minLength: 0)
                        if tab == item {
                            RoundedRectangle(cornerRadius: 2).fill(Theme.accent).frame(width: 3, height: 16)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 13)
                    .foregroundStyle(tab == item ? Theme.star : Theme.dim2)
                    .background(tab == item ? Theme.accent.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 8))
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(KeyEquivalent(Character(String((Tab.allCases.firstIndex(of: item) ?? 0) + 1))), modifiers: .command)
                .accessibilityAddTraits(tab == item ? [.isSelected] : [])
                .padding(.bottom, 5)
            }
            Spacer(minLength: 24)
            Divider().overlay(Theme.line).padding(.bottom, 18)
            if selfUpdate.updateAvailable, let tag = selfUpdate.latestTag {
                Button {
                    if let url = selfUpdate.releaseURL { NSWorkspace.shared.open(url) }
                } label: {
                    Label("下载更新 \(tag)", systemImage: "arrow.down.circle")
                        .font(.system(size: 12)).foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 10)
            }
            Text("栖理 v\(AppVersion.current)").font(.system(size: 11.5)).foregroundStyle(Theme.dim2)
            Text("给文件留位置，给工作留余地。")
                .font(.system(size: 10.5)).foregroundStyle(Theme.dim3).padding(.top, 6)
        }
        .padding(.horizontal, 16)
        .padding(.top, 52)
        .padding(.bottom, 24)
        .frame(width: 200)
        .background(Theme.sidebar)
        .overlay(alignment: .trailing) { Rectangle().fill(Theme.line).frame(width: 1) }
    }
}

struct LogoView: View {
    var size: CGFloat = 28
    var body: some View {
        Image(nsImage: BrandAssets.logo)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("栖理")
    }
}

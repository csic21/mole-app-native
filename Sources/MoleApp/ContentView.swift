import AppKit
import SwiftUI

enum Tab: String, CaseIterable, Identifiable {
    case clean, apps, optimize, analyze, status

    var id: String { rawValue }

    var label: String {
        switch self {
        case .clean: "清理"
        case .apps: "软件"
        case .optimize: "优化"
        case .analyze: "分析"
        case .status: "状态"
        }
    }

    var background: Color {
        switch self {
        case .clean: Theme.windowClean
        case .apps: Theme.windowApps
        case .optimize: Theme.windowOptimize
        case .analyze: Theme.windowAnalyze
        case .status: Theme.windowStatus
        }
    }
}

struct ContentView: View {
    @State private var tab: Tab = .clean
    // store 只在 ContentView 建一次:切回任意标签都直接渲染缓存,不会再触发重扫。
    @StateObject private var cleanStore = CleanStore()
    @StateObject private var appsStore = AppsStore()
    @StateObject private var loginStore = LoginItemsStore()
    @StateObject private var updateStore = UpdateStore()
    @StateObject private var optimizeStore = OptimizeStore()
    @StateObject private var analyzeStore = AnalyzeStore()
    @StateObject private var statusStore = StatusStore()
    @StateObject private var selfUpdate = SelfUpdateStore()

    var body: some View {
        VStack(spacing: 0) {
            TopBar(tab: $tab, selfUpdate: selfUpdate)
            ScrollView {
                page
                    .padding(.horizontal, 30)
                    .padding(.top, 6)
                    .padding(.bottom, 36)
                    .frame(maxWidth: 980)
                    .frame(maxWidth: .infinity)
                    .id(tab)
            }
        }
        .background(tab.background.animation(.easeInOut(duration: 0.22), value: tab))
        .background(WindowConfigurator().frame(width: 0, height: 0))
        .task {
            selfUpdate.checkOnce()
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

struct TopBar: View {
    @Binding var tab: Tab
    @ObservedObject var selfUpdate: SelfUpdateStore

    var body: some View {
        ZStack {
            HStack(spacing: 4) {
                LogoView()
                ForEach(Tab.allCases) { item in
                    Button {
                        tab = item
                    } label: {
                        Text(item.label)
                            .font(.system(size: 13))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(
                                item == tab ? Color(hex: 0xEEE9DE, opacity: 0.94) : .clear,
                                in: Capsule()
                            )
                            .foregroundStyle(item == tab ? Color(hex: 0x17181B) : Theme.dim2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color.white.opacity(0.06), in: Capsule())

            HStack {
                Spacer()
                if selfUpdate.updateAvailable, let tag = selfUpdate.latestTag {
                    Button {
                        if let url = selfUpdate.releaseURL {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Text("↑ 新版本 \(tag)")
                            .font(.system(size: 11.5, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(hex: 0x68C46B, opacity: 0.18), in: Capsule())
                            .foregroundStyle(Color(hex: 0x8FD693))
                    }
                    .buttonStyle(.plain)
                    .help("打开 GitHub Releases 下载新版本")
                } else {
                    Text("v\(AppVersion.current) · 研究版")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.dim3)
                }
            }
        }
        .padding(.leading, 84)
        .padding(.trailing, 18)
        .frame(height: 54)
        .frame(maxWidth: .infinity)
    }
}

struct LogoView: View {
    var size: CGFloat = 22

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color(hex: 0xF2C078), Color(hex: 0xB65C3E), Color(hex: 0x5E4030)],
                    center: UnitPoint(x: 0.32, y: 0.3),
                    startRadius: 1,
                    endRadius: size * 0.72
                )
            )
            .frame(width: size, height: size)
            .padding(.horizontal, 8)
    }
}

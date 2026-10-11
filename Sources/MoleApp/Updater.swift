import Foundation
import Sparkle

/// 基于 Sparkle 的应用内自动更新:后台检查新版本、应用内下载并安装、自动重启。
/// 更新源(appcast)与 EdDSA 公钥由打包脚本写入 Info.plist。
final class AppUpdater: ObservableObject {
    static let shared = AppUpdater()

    /// 已发现的新版本(侧栏提示用);nil 表示当前没有可用更新。
    @Published private(set) var availableVersion: String?

    private var controller: SPUStandardUpdaterController?
    private let delegateProxy = DelegateProxy()

    private init() {
        delegateProxy.owner = self
        // 只有正式打包的 .app(Info.plist 含 SUFeedURL)才启动 Sparkle;
        // swift run / 测试环境没有更新源,保持安静。
        guard Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") is String else { return }
        controller = SPUStandardUpdaterController(startingUpdater: true,
                                                  updaterDelegate: delegateProxy,
                                                  userDriverDelegate: nil)
        // 自动化验证入口:设置 QILI_AUTO_CHECK_UPDATES=1 时启动即触发一次检查。
        if ProcessInfo.processInfo.environment["QILI_AUTO_CHECK_UPDATES"] == "1" {
            DispatchQueue.main.async { [weak self] in self?.checkForUpdates() }
        }
    }

    /// 立即检查更新并展示 Sparkle 的标准界面(下载、安装、重启都在其中完成)。
    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }

    /// Sparkle 弱引用 delegate,这里用代理对象持有回调并转交给 AppUpdater。
    final class DelegateProxy: NSObject, SPUUpdaterDelegate {
        weak var owner: AppUpdater?

        func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
            owner?.availableVersion = item.displayVersionString
        }

        func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
            owner?.availableVersion = nil
        }
    }
}

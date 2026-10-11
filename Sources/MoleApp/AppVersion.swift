import Foundation

/// 当前应用版本:打包后的 .app 读 Info.plist;开发运行(swift run)回落到常量。
/// 发版时同时更新这里与 git tag(vX.Y.Z),两者保持一致。
enum AppVersion {
    static let development = "0.4.2"

    static var current: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? development
    }
}

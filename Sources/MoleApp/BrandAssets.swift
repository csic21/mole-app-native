import AppKit

enum BrandAssets {
    static let logo = image(named: "QiliLogo", extension: "png")
    static let appIcon = image(named: "AppIcon", extension: "icns")

    /// SwiftPM 生成的 `Bundle.module` 在 .app 里只会查「.app 根目录 + 编译时写死的
    /// 构建路径」,而打包脚本把资源放在 Contents/Resources,在别人机器上两个位置
    /// 都不存在,启动加载 Logo 时就会 fatalError 闪退。这里按真实打包布局自行解析。
    private static let resourceBundle: Bundle = {
        let bundleName = "MoleApp_MoleApp.bundle"
        let candidates = [
            Bundle.main.resourceURL, // 打包后:.app/Contents/Resources
            Bundle.main.bundleURL, // 开发时:swift run/测试与可执行文件同级
        ]
        for candidate in candidates {
            if let url = candidate?.appendingPathComponent(bundleName),
               let bundle = Bundle(url: url) {
                return bundle
            }
        }
        // 仅在开发环境布局异常时才会走到这里的 SwiftPM 兜底访问器。
        return Bundle.module
    }()

    private static func image(named name: String, extension fileExtension: String) -> NSImage {
        guard let url = resourceBundle.url(forResource: name, withExtension: fileExtension),
              let image = NSImage(contentsOf: url) else {
            preconditionFailure("Missing brand asset: \(name).\(fileExtension)")
        }
        return image
    }
}

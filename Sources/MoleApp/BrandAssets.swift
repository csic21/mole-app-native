import AppKit

enum BrandAssets {
    static let logo = image(named: "QiliLogo", extension: "png")
    static let appIcon = image(named: "AppIcon", extension: "icns")

    private static func image(named name: String, extension fileExtension: String) -> NSImage {
        guard let url = Bundle.module.url(forResource: name, withExtension: fileExtension),
              let image = NSImage(contentsOf: url) else {
            preconditionFailure("Missing brand asset: \(name).\(fileExtension)")
        }
        return image
    }
}

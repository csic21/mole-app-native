import Foundation

struct AppcastItem {
    var build: String?
    var displayVersion: String?
    var minimumOS: String?
    var maximumOS: String?
    var channel: String?
    var hardware: String?

    func comparisonVersion(buildAvailable: Bool) -> String {
        buildAvailable ? (build ?? displayVersion ?? "") : (displayVersion ?? "")
    }

    func isNewer(thanBuild installedBuild: String?, displayVersion installedDisplay: String) -> Bool {
        if let installedBuild, !installedBuild.isEmpty, let build {
            return build.compare(installedBuild, options: .numeric) == .orderedDescending
        }
        // 缺少本机构建号时只比较显示版本，绝不拿构建号与显示版本交叉比较。
        guard let displayVersion else { return false }
        return displayVersion.compare(installedDisplay, options: .numeric) == .orderedDescending
    }

    func isCompatible(with os: String) -> Bool {
        guard channel == nil || channel == "" else { return false }
        if let minimumOS, minimumOS.compare(os, options: .numeric) == .orderedDescending { return false }
        if let maximumOS, maximumOS.compare(os, options: .numeric) == .orderedAscending { return false }
        if let hardware, !hardware.isEmpty {
            #if arch(arm64)
            if hardware != "arm64" { return false }
            #else
            if hardware != "x86_64" { return false }
            #endif
        }
        return true
    }
}

/// 按 item 保留构建号、显示版本及兼容条件；只接受 Sparkle 命名空间的版本字段。
final class AppcastParser: NSObject, XMLParserDelegate {
    private var items: [AppcastItem] = []
    private var current: AppcastItem?
    private var capture: String?
    private var buffer = ""
    private var depth = 0
    private var itemDepth = 0
    private var rss = false
    private var channel = false
    private var mappings: [String: [String]] = [:]
    private var topLevelFields: Set<String> = []
    private static let namespace = "http://www.andymatuschak.org/xml-namespaces/sparkle"

    static func items(in data: Data) throws -> [AppcastItem] {
        guard data.count <= 2_097_152 else { throw CheckError("更新源数据过大") }
        let delegate = AppcastParser()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldReportNamespacePrefixes = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse(), delegate.rss, delegate.channel else {
            throw CheckError("更新源不是有效的 appcast")
        }
        return delegate.items
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes: [String: String]) {
        depth += 1
        if name == "rss", depth == 1 { rss = true }
        if name == "channel", depth == 2, rss { channel = true }
        if name == "item", depth == 3, channel {
            current = AppcastItem(); itemDepth = depth; topLevelFields = []
        }
        guard current != nil, depth == itemDepth + 1 else { return }
        if name == "enclosure" {
            // 标准旧版 appcast 的 enclosure 属性。
            for (key, value) in attributes {
                let parts = key.split(separator: ":", maxSplits: 1)
                if parts.count == 2, mappings[String(parts[0])]?.last == Self.namespace {
                    let field = String(parts[1])
                    if ["version", "shortVersionString"].contains(field), !topLevelFields.contains(field) {
                        set(field, value)
                    }
                }
            }
        }
        if namespaceURI == Self.namespace,
           ["version", "shortVersionString", "minimumSystemVersion", "maximumSystemVersion", "channel", "hardwareRequirements"].contains(name) {
            capture = name; buffer = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capture != nil { buffer += string }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName qName: String?) {
        if let capture, depth == itemDepth + 1, name == capture {
            set(capture, buffer); topLevelFields.insert(capture); self.capture = nil
        }
        if name == "item", depth == itemDepth, let current {
            if current.build != nil || current.displayVersion != nil { items.append(current) }
            self.current = nil
        }
        depth -= 1
    }

    func parser(_ parser: XMLParser, didStartMappingPrefix prefix: String, toURI uri: String) {
        mappings[prefix, default: []].append(uri)
    }

    func parser(_ parser: XMLParser, didEndMappingPrefix prefix: String) {
        _ = mappings[prefix]?.popLast()
    }

    private func set(_ key: String, _ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if ["version", "shortVersionString", "minimumSystemVersion", "maximumSystemVersion"].contains(key),
           text.first?.isNumber != true { return }
        switch key {
        case "version": current?.build = text
        case "shortVersionString": current?.displayVersion = text
        case "minimumSystemVersion": current?.minimumOS = text
        case "maximumSystemVersion": current?.maximumOS = text
        case "channel": current?.channel = text
        case "hardwareRequirements": current?.hardware = text
        default: break
        }
    }
}

import Foundation
import SwiftUI

/// 基于 GitHub Releases 的自我更新检查(只提示,不自动下载)。
@MainActor
final class SelfUpdateStore: ObservableObject {
    @Published private(set) var latestTag: String?
    @Published private(set) var releaseURL: URL?

    private static let endpoint = "https://api.github.com/repos/csic21/mole-app-native/releases/latest"
    private var checked = false

    var updateAvailable: Bool {
        guard let latestTag else { return false }
        return Self.isNewer(latestTag, than: AppVersion.current)
    }

    func checkOnce() {
        guard !checked else { return }
        checked = true
        Task { [weak self] in
            await self?.performCheck()
        }
    }

    private func performCheck() async {
        guard let url = URL(string: Self.endpoint) else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String else {
            return // 没有发布 / 网络失败:保持安静
        }
        latestTag = tag
        releaseURL = (json["html_url"] as? String).flatMap(URL.init(string:))
    }

    nonisolated static func isNewer(_ tag: String, than current: String) -> Bool {
        let normalized = tag.hasPrefix("v") || tag.hasPrefix("V") ? String(tag.dropFirst()) : tag
        return normalized.compare(current, options: .numeric) == .orderedDescending
    }
}

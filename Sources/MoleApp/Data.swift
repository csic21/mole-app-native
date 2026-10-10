// 示意数据:只保留尚未接入真实来源的模块(更新 / 启动项 / 优化任务 / 分析树)。
// 清理、软件、状态三个页已经使用真实数据,对应 mock 已移除。

import SwiftUI

enum MockData {
    struct UpdateRow: Identifiable {
        let id: String
        let mark: String
        let tone: Color
        let name: String
        let from: String
        let to: String
    }

    static let updates: [UpdateRow] = [
        .init(id: "u1", mark: "S", tone: Color(hex: 0x5B7BB3), name: "Slack", from: "4.42.0", to: "4.43.2"),
        .init(id: "u2", mark: "C", tone: Color(hex: 0x2F79C9), name: "Cursor", from: "1.7.52", to: "1.8.1"),
        .init(id: "u3", mark: "R", tone: Color(hex: 0xB34A5E), name: "Raycast", from: "1.98.0", to: "1.99.1"),
    ]

    struct LoginItem: Identifiable {
        let id: String
        let name: String
        let note: String
        var on: Bool
    }

    static let loginItems: [LoginItem] = [
        .init(id: "g1", name: "Dropbox", note: "登录时打开", on: true),
        .init(id: "g2", name: "Unsplash Wallpapers", note: "后台运行", on: true),
        .init(id: "g3", name: "Legacy Helper", note: "所属应用已卸载", on: false),
    ]
}

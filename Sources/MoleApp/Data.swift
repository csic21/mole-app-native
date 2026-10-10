import SwiftUI

struct CleanGroup: Identifiable {
    let id: String
    let name: String
    let note: String
    let sizeText: String
    let sizeMB: Double
    var children: [(name: String, note: String, sizeText: String)] = []
}

enum MockData {
    static let cleanGroups: [CleanGroup] = [
        CleanGroup(
            id: "system", name: "系统数据", note: "快照、缓存与日志单独成组",
            sizeText: "128.4 GB", sizeMB: 131481,
            children: [
                (name: "快照", note: "本地 APFS 快照", sizeText: "12.6 GB"),
                (name: "系统缓存", note: "可重建", sizeText: "86.2 GB"),
                (name: "日志与诊断", note: "30 天前", sizeText: "29.6 GB"),
            ]
        ),
        CleanGroup(id: "xcode", name: "Xcode 缓存", note: "DerivedData 与设备支持", sizeText: "36.2 GB", sizeMB: 37068),
        CleanGroup(id: "ai", name: "AI 工具旧会话", note: "Codex 与 Claude Code", sizeText: "8.7 GB", sizeMB: 8909),
        CleanGroup(id: "browser", name: "浏览器缓存", note: "Chrome 与 Safari", sizeText: "2.3 GB", sizeMB: 2355),
        CleanGroup(id: "trash", name: "废纸篓", note: "31 项", sizeText: "1.4 GB", sizeMB: 1434),
    ]

    struct InstalledApp: Identifiable {
        let id: String
        let mark: String
        let tone: Color
        let name: String
        let meta: String
        let sizeMB: Double
    }

    static let installedApps: [InstalledApp] = [
        .init(id: "slack", mark: "S", tone: Color(hex: 0x5B7BB3), name: "Slack", meta: "4.42.0 · 421.8MB · 8 小时前 活跃", sizeMB: 422),
        .init(id: "figma", mark: "F", tone: Color(hex: 0x8A5BC0), name: "Figma", meta: "124.6 · 336.2MB · 昨天 活跃", sizeMB: 336),
        .init(id: "vscode", mark: "V", tone: Color(hex: 0x2F79C9), name: "Visual Studio Code", meta: "1.139.1 · 913.4MB · 2 天前 活跃", sizeMB: 913),
        .init(id: "warp", mark: "W", tone: Color(hex: 0xC9762F), name: "Warp", meta: "0.2026.1 · 288.4MB · 3 天前 活跃", sizeMB: 288),
        .init(id: "raycast", mark: "R", tone: Color(hex: 0xB34A5E), name: "Raycast", meta: "1.98.0 · 164.2MB · 5 天前 活跃", sizeMB: 164),
    ]

    static let vscodeLeftovers: [(kind: String, path: String, size: String)] = [
        ("App", "/Applications/Visual Studio Code.app", "913.4MB"),
        ("临时缓存", "~/Library/Application Support/Code", "3.1MB"),
        ("HTTP 存储", "~/Library/HTTPStorages/com.microsoft.VSCode", "696KB"),
        ("最近使用记录", "~/Library/Application Support/.../com.microsoft.vscode.sfl4", "9KB"),
        ("Electron 缓存", "~/Library/Application Support/Code/Cache", "0KB"),
    ]

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

    struct Task: Identifiable {
        let id: String
        let name: String
        let note: String
        var status: Status = .idle
        var skipNote: String?

        enum Status { case idle, running, done, skip }
    }

    static let tasks: [Task] = [
        .init(id: "t1", name: "Quick Look 缩略图", note: "重建索引"),
        .init(id: "t2", name: "DNS 缓存", note: "刷新解析记录"),
        .init(id: "t3", name: "Spotlight 索引", note: "Safari 正在使用", skipNote: "跳过 · 稍后再试"),
        .init(id: "t4", name: "内存异常报告", note: "清理旧诊断"),
        .init(id: "t5", name: "磁盘校验", note: "仅在需要时运行", skipNote: "待命 · 需要时手动"),
    ]

    struct TreeNode: Identifiable {
        let id: String
        let name: String
        let sizeText: String
        let sizeMB: Double
        let tone: Color
        var children: [TreeNode] = []
    }

    static let root = TreeNode(
        id: "root", name: "整个硬盘", sizeText: "438.45 GB", sizeMB: 448973, tone: Color(hex: 0x5A5348),
        children: [
            TreeNode(
                id: "library", name: "Library", sizeText: "130.9 GB", sizeMB: 134042, tone: Color(hex: 0x5B4A42),
                children: [
                    TreeNode(id: "caches", name: "Caches", sizeText: "86.2 GB", sizeMB: 88269, tone: Color(hex: 0x5B4A42)),
                    TreeNode(id: "containers", name: "Containers", sizeText: "22.4 GB", sizeMB: 22938, tone: Color(hex: 0x6B5A68)),
                    TreeNode(id: "developer", name: "Developer", sizeText: "14.1 GB", sizeMB: 14438, tone: Color(hex: 0x6E5433)),
                    TreeNode(id: "lib-other", name: "其他", sizeText: "8.2 GB", sizeMB: 8397, tone: Color(hex: 0x5A5566)),
                ]
            ),
            TreeNode(id: "parallels", name: "Parallels", sizeText: "68.66 GB", sizeMB: 70308, tone: Color(hex: 0x8A6A3C)),
            TreeNode(id: "www", name: "www", sizeText: "57.5 GB", sizeMB: 58880, tone: Color(hex: 0x8A4A34)),
            TreeNode(id: "tart", name: ".tart", sizeText: "54.74 GB", sizeMB: 56054, tone: Color(hex: 0x6B5A68)),
            TreeNode(id: "downloads", name: "Downloads", sizeText: "39.2 GB", sizeMB: 40141, tone: Color(hex: 0x6E5433)),
            TreeNode(id: "codex", name: ".codex", sizeText: "26.32 GB", sizeMB: 26952, tone: Color(hex: 0x5A5566)),
            TreeNode(id: "config", name: ".config", sizeText: "23.11 GB", sizeMB: 23665, tone: Color(hex: 0x6B5A68)),
            TreeNode(id: "documents", name: "Documents", sizeText: "10.39 GB", sizeMB: 10639, tone: Color(hex: 0x5A5348)),
        ]
    )

    struct ProcessRow: Identifiable {
        let id: String
        let name: String
        let mem: String
        let memPct: Double
        let cpu: Double
        let pid: Int
    }

    static let processes: [ProcessRow] = [
        .init(id: "p1", name: "Parallels Desktop", mem: "14.3 GB", memPct: 88, cpu: 32.0, pid: 15980),
        .init(id: "p2", name: "Claude", mem: "4.2 GB", memPct: 32, cpu: 55.0, pid: 22350),
        .init(id: "p3", name: "ChatGPT", mem: "2.1 GB", memPct: 16, cpu: 7.7, pid: 74821),
        .init(id: "p4", name: "Cursor", mem: "2.0 GB", memPct: 15, cpu: 44.7, pid: 74509),
        .init(id: "p5", name: "微信", mem: "1.2 GB", memPct: 9, cpu: 1.8, pid: 49392),
    ]

    static func formatSize(_ sizeMB: Double) -> String {
        if sizeMB >= 1024 * 1024 { return String(format: "%.2f TB", sizeMB / 1024 / 1024) }
        if sizeMB >= 1024 { return String(format: "%.2f GB", sizeMB / 1024) }
        return "\(Int(sizeMB.rounded())) MB"
    }
}

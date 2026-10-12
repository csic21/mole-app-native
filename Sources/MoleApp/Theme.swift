import AppKit
import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Quiet neutral surfaces. Green is reserved for action, selection and progress.
/// Every appearance keeps metadata at least 4.5:1 contrast on opaque row states;
/// both palettes are checked by scripts/check_design_contrast.py.
enum Theme {
    static let star = adaptive(light: 0x263C44, dark: 0xF1F3F2)
    static let dim2 = adaptive(light: 0x4F6260, dark: 0xC1C8C5)
    static let dim3 = adaptive(light: 0x546866, dark: 0xAAB5AF)
    static let line = adaptive(light: 0xD8E1DD, dark: 0x324440)
    static let accent = adaptive(light: 0x376874, dark: 0x9BCBB5)
    static let warm = adaptive(light: 0x7C5522, dark: 0xEBC08F)
    static let danger = adaptive(light: 0x9E322A, dark: 0xF0A3A3)
    static let canvas = adaptive(light: 0xF3F5F4, dark: 0x1D2024)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x24282D)
    static let sidebar = adaptive(light: 0xE7ECEA, dark: 0x191C20)
    static let card = adaptive(light: 0xFFFFFF, dark: 0x292E33)
    static let cardHover = adaptive(light: 0xEDF2EF, dark: 0x343B41)
    static let selection = adaptive(light: 0xDCE8E2, dark: 0x2D4038)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: Double((value >> 16) & 0xFF) / 255,
                           green: Double((value >> 8) & 0xFF) / 255,
                           blue: Double(value & 0xFF) / 255, alpha: 1)
        })
    }

    static let mono = Font.system(size: 12, design: .monospaced)
    static let monoSmall = Font.system(size: 11.5, design: .monospaced)
    static let display = Font.system(size: 20, weight: .semibold)
    static let radius: CGFloat = 10
}

/// 显示外观:浅色、深色或跟随系统。默认保持深色,截图与视觉检查以此为准。
enum AppAppearance: String, CaseIterable {
    case dark, light, system

    var label: String {
        switch self {
        case .dark: "深色"
        case .light: "浅色"
        case .system: "跟随系统"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
}

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
/// Metadata maintains at least 4.5:1 contrast on every opaque row state.
enum Theme {
    static let star = Color(hex: 0xF1F3F2)
    static let dim2 = Color(hex: 0xC1C8C5)
    static let dim3 = Color(hex: 0xAAB5AF)
    static let line = Color(hex: 0xC4D5CE, opacity: 0.16)
    static let accent = Color(hex: 0x9BCBB5)
    static let warm = Color(hex: 0xEBC08F)
    static let danger = Color(hex: 0xF0A3A3)
    static let canvas = Color(hex: 0x1D2024)
    static let surface = Color(hex: 0x24282D)
    static let sidebar = Color(hex: 0x191C20)
    static let card = Color(hex: 0x292E33)
    static let cardHover = Color(hex: 0x343B41)
    static let selection = Color(hex: 0x2D4038)

    static let mono = Font.system(size: 12, design: .monospaced)
    static let monoSmall = Font.system(size: 12, design: .monospaced)
    static let display = Font.system(size: 20, weight: .semibold)
    static let radius: CGFloat = 10
}

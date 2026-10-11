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

enum Theme {
    static let star = Color(hex: 0xE9EFEC)
    static let dim2 = Color(hex: 0xB2C1BB)
    static let dim3 = Color(hex: 0x899F96)
    static let line = Color(hex: 0xC4D5CE, opacity: 0.12)
    static let accent = Color(hex: 0x8BC4AF)
    static let warm = Color(hex: 0xE9B782)
    static let canvas = Color(hex: 0x202A2D)
    static let surface = Color(hex: 0x263235)
    static let sidebar = Color(hex: 0x172225)
    static let card = Color(hex: 0x2C393C)
    static let cardHover = Color(hex: 0x36494A)

    static let mono = Font.system(size: 12, design: .monospaced)
    static let monoSmall = Font.system(size: 11.5, design: .monospaced)
    static let display = Font.system(size: 18, weight: .semibold)
}

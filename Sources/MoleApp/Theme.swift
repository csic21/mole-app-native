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
    static let star = Color(hex: 0xEFE8D8)
    static let dim2 = Color(hex: 0xEFE8D8, opacity: 0.55)
    static let dim3 = Color(hex: 0xEFE8D8, opacity: 0.38)
    static let line = Color(hex: 0xEFE8D8, opacity: 0.09)
    static let accent = Color(hex: 0x8B7CF0)
    static let card = Color.white.opacity(0.035)
    static let cardHover = Color.white.opacity(0.05)

    static let windowClean = Color(hex: 0x1E2337)
    static let windowApps = Color(hex: 0x1E1918)
    static let windowOptimize = Color(hex: 0x1B1A17)
    static let windowAnalyze = Color(hex: 0x241D15)
    static let windowStatus = Color(hex: 0x23231A)

    static let mono = Font.system(size: 12, design: .monospaced)
    static let monoSmall = Font.system(size: 11.5, design: .monospaced)
    static let display = Font.custom("Songti SC", size: 15)
}

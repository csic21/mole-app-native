import SwiftUI

struct CheckView: View {
    var on: Bool
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Color(hex: 0xEFE8D8, opacity: 0.35), lineWidth: 1.5)
                if on {
                    RoundedRectangle(cornerRadius: 5).fill(Theme.accent)
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

struct AppIconView: View {
    let mark: String
    let tone: Color

    var body: some View {
        Text(mark)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(tone, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct BarView: View {
    var value: Double
    var warm = false
    var mini = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.09))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: warm ? [Color(hex: 0xC89A6B), Color(hex: 0xB65C3E)] : [Color(hex: 0x8B7CF0), Color(hex: 0x4F7FA8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * value / 100))
            }
        }
        .frame(height: mini ? 6 : 8)
    }
}

struct SparkView: View {
    var tone: Color = Color(hex: 0x8FD693)
    private let heights: [Double] = (0..<42).map { 20 + Double(($0 * 37) % 60) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(heights.enumerated()), id: \.offset) { _, height in
                RoundedRectangle(cornerRadius: 2)
                    .fill(tone.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .frame(height: height * 0.26 + 2)
            }
        }
        .frame(height: 26)
    }
}

struct PillButton: View {
    let title: String
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13.5, weight: .medium))
                .padding(.vertical, 9)
                .padding(.horizontal, 26)
        }
        .buttonStyle(.plain)
        .background(Color(hex: 0xF2EEE3), in: Capsule())
        .foregroundStyle(Color(hex: 0x17181B))
        .opacity(disabled ? 0.45 : 1)
        .disabled(disabled)
    }
}

struct RowBox<Content: View>: View {
    var selected = false
    @ViewBuilder var content: Content
    @State private var hover = false

    var body: some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                selected ? Theme.cardHover : (hover ? Theme.card : Color.clear),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .onHover { hover = $0 }
    }
}

struct FootBar<Trailing: View>: View {
    let note: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Text(note)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.dim2)
            Spacer()
            trailing
        }
        .padding(.top, 14)
        .padding(.bottom, 2)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.line).frame(height: 1)
        }
        .padding(.top, 14)
    }
}

struct Chip: View {
    enum Tone { case plain, done, skip, running }
    let text: String
    var tone: Tone = .plain

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(background, in: Capsule())
            .foregroundStyle(foreground)
    }

    private var background: Color {
        switch tone {
        case .plain: Color.white.opacity(0.08)
        case .done: Color(hex: 0x68C46B, opacity: 0.16)
        case .skip: Color(hex: 0xE28E60, opacity: 0.16)
        case .running: Color(hex: 0x8B7CF0, opacity: 0.18)
        }
    }

    private var foreground: Color {
        switch tone {
        case .plain: Theme.dim2
        case .done: Color(hex: 0x8FD693)
        case .skip: Color(hex: 0xE8A97F)
        case .running: Color(hex: 0xB3A8F5)
        }
    }
}

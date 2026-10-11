import SwiftUI

struct CheckView: View {
    var on: Bool
    var mixed = false
    var label = "选择"
    var action: (() -> Void)?
    @FocusState private var focused: Bool
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        Button { action?() } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(on || mixed ? Theme.accent : Theme.canvas)
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(on || mixed ? Theme.accent : Theme.dim3, lineWidth: 1)
                if on || mixed {
                    Image(systemName: mixed ? "minus" : "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.sidebar)
                }
            }
            .frame(width: 16, height: 16)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($focused)
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(focused ? Theme.accent : .clear, lineWidth: 2))
        .disabled(action == nil)
        .opacity(enabled && action != nil ? 1 : 0.45)
        .accessibilityLabel(label)
        .accessibilityValue(mixed ? "部分选择" : (on ? "已选择" : "未选择"))
        .accessibilityHint("按空格切换选择")
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
                    .fill(warm ? Theme.warm : Theme.accent)
                    .frame(width: max(0, geo.size.width * min(100, max(0, value.isFinite ? value : 0)) / 100))
            }
        }
        .frame(height: mini ? 5 : 7)
        .accessibilityHidden(true)
    }
}

struct SparkView: View {
    var values: [Double]
    var tone: Color = Theme.accent
    /// Utilization uses 0...100; rates can opt into local auto-scaling.
    var domain: ClosedRange<Double>? = nil

    var body: some View {
        let finite = values.map { $0.isFinite ? max(0, $0) : 0 }
        let lower = domain?.lowerBound ?? 0
        let upper = domain?.upperBound ?? max(finite.max() ?? 1, 0.0001)
        let span = max(upper - lower, 0.0001)
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(finite.enumerated()), id: \.offset) { _, value in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(tone.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .frame(height: max(1, min(1, max(0, (value - lower) / span)) * 26))
            }
        }
        .frame(height: 26)
        .accessibilityElement(children: .ignore)
    }
}

struct WorkspaceButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, quiet }
    var kind: Kind = .secondary
    @Environment(\.isEnabled) private var enabled
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, kind == .quiet ? 10 : 16)
            .frame(minHeight: 34)
            .foregroundStyle(kind == .primary ? Theme.sidebar : Theme.star)
            .background(background(pressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(kind == .secondary ? Theme.line : .clear))
            .contentShape(RoundedRectangle(cornerRadius: 7))
            .opacity(enabled ? 1 : 0.45)
            .onHover { hovering = $0 }
    }

    private func background(pressed: Bool) -> Color {
        if kind == .primary { return Theme.accent.opacity(pressed ? 0.75 : (hovering ? 0.9 : 1)) }
        if pressed { return Theme.selection }
        if hovering { return Theme.cardHover }
        return kind == .quiet ? .clear : Theme.card
    }
}

struct PillButton: View {
    let title: String
    var disabled = false
    let action: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        Button(title, action: action)
            .buttonStyle(WorkspaceButtonStyle(kind: .primary))
            .focused($focused)
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(focused ? Theme.star : .clear, lineWidth: 2).padding(-3))
            .disabled(disabled)
    }
}

struct RowBox<Content: View>: View {
    var selected = false
    @ViewBuilder var content: Content
    @State private var hover = false
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(selected ? Theme.selection : (hover ? Theme.cardHover : Theme.card), in: RoundedRectangle(cornerRadius: Theme.radius))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radius)
                    .strokeBorder(selected ? Theme.accent.opacity(0.75) : (contrast == .increased ? Theme.dim3 : Theme.line), lineWidth: selected ? 1.5 : 1)
                    .allowsHitTesting(false)
            }
            .contentShape(RoundedRectangle(cornerRadius: Theme.radius))
            .onHover { hover = $0 }
    }
}

struct FootBar<Trailing: View>: View {
    let note: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 16) {
            Text(note)
                .font(.system(size: 12))
                .foregroundStyle(Theme.dim2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.top, 16)
        .padding(.bottom, 2)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        .padding(.top, 12)
    }
}

struct Chip: View {
    enum Tone { case plain, done, skip, running, failed }
    let text: String
    var tone: Tone = .plain

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(foreground.opacity(0.1), in: Capsule())
            .foregroundStyle(foreground)
    }

    private var foreground: Color {
        switch tone {
        case .plain: Theme.dim2
        case .done, .running: Theme.accent
        case .skip: Theme.warm
        case .failed: Theme.danger
        }
    }
}

struct Notice: View {
    let text: String
    var symbol = "info.circle"
    var tone: Color = Theme.dim2

    var body: some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol)
        }
        .font(.system(size: 12))
        .foregroundStyle(tone)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}

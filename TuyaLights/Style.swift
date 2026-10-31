import SwiftUI

extension Color {
    /// T3 accent, only for selection and the active state.
    static let accent = Color(red: 0x34 / 255, green: 0x6b / 255, blue: 0xf1 / 255)
}

extension View {
    /// T3 black behind a screen. Forms also hide their own grey background.
    func screenBackground() -> some View {
        scrollContentBackground(.hidden).background(Color.black.ignoresSafeArea())
    }

    /// Neutral card: white 4%, or 8% when selected or active. Radius 12, no border.
    func card(selected: Bool = false) -> some View {
        background(.white.opacity(selected ? 0.08 : 0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    /// Liquid Glass button on iOS 26+, bordered style before that.
    @ViewBuilder
    func glassButton(prominent: Bool = false, tint: Color? = nil) -> some View {
        if #available(iOS 26, *) {
            if prominent { buttonStyle(.glassProminent).tint(tint) } else { buttonStyle(.glass).tint(tint) }
        } else {
            if prominent { buttonStyle(.borderedProminent).tint(tint) } else { buttonStyle(.bordered).tint(tint) }
        }
    }

    /// Liquid Glass surface on iOS 26+, thin material before that. Only for round power buttons.
    @ViewBuilder
    func glassBackground<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
        }
    }
}

extension AnyTransition {
    /// Screen and mode changes: fade with a 4 pt rise.
    static let rise = AnyTransition.opacity.combined(with: .offset(y: 4))
}

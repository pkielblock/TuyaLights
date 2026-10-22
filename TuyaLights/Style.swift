import SwiftUI

/// Soft gradient so the glass has something to refract.
struct LightsBackground: View {
    @Environment(\.colorScheme) private var scheme
    var glow: Color? = nil

    var body: some View {
        ZStack {
            LinearGradient(
                colors: scheme == .dark
                    ? [Color(red: 0.06, green: 0.06, blue: 0.12), Color(red: 0.13, green: 0.07, blue: 0.16)]
                    : [Color(red: 0.93, green: 0.93, blue: 0.98), Color(red: 0.98, green: 0.92, blue: 0.90)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            if let glow {
                RadialGradient(colors: [glow.opacity(0.55), .clear], center: .top, startRadius: 0, endRadius: 520)
                    .animation(.easeInOut(duration: 0.4), value: glow)
            }
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Liquid Glass button on iOS 26+, bordered style before that.
    @ViewBuilder
    func glassButton(prominent: Bool = false, tint: Color? = nil) -> some View {
        if #available(iOS 26, *) {
            if prominent { buttonStyle(.glassProminent).tint(tint) } else { buttonStyle(.glass).tint(tint) }
        } else {
            if prominent { buttonStyle(.borderedProminent).tint(tint) } else { buttonStyle(.bordered).tint(tint) }
        }
    }

    /// Liquid Glass surface on iOS 26+, thin material (acrylic) before that.
    @ViewBuilder
    func glassBackground<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
        }
    }
}

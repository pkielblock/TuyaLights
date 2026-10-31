import SwiftUI

/// Full controls for a lamp or a group: power, white tones and colours.
struct LampView: View {
    @AppStorage(AppLanguage.storageKey) private var lang = AppLanguage.english.rawValue
    @EnvironmentObject private var remote: BeaconRemote
    var title: String
    var lamps: [BeaconLamp]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        let on = remote.isOn(lamps)
        let look = remote.look(of: lamps)
        ScrollView {
            VStack(spacing: 20) {
                powerButton(on: on, look: look)
                Text(on ? look.label : BeaconCommand.off.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)

                section(L("White", "Branco"), icon: "thermometer.medium") {
                    LazyVGrid(columns: Array(columns.prefix(3)), spacing: 12) {
                        ForEach(BeaconCommand.whites, id: \.self) { swatch($0, selected: on && look == $0) }
                    }
                }
                section(L("Colour", "Cor"), icon: "paintpalette") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(BeaconCommand.colours, id: \.self) { swatch($0, selected: on && look == $0) }
                    }
                }
            }
            .padding(16)
            .animation(.easeOut(duration: 0.2), value: on)
            .animation(.easeOut(duration: 0.2), value: look)
        }
        .screenBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func powerButton(on: Bool, look: BeaconCommand) -> some View {
        Button { remote.setPower(!on, for: lamps) } label: {
            Image(systemName: "power")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(on ? .white : .primary)
                .frame(width: 120, height: 120)
                .background(on ? Color.accent : .clear, in: Circle())
        }
        .buttonStyle(.plain)
        .glassBackground(in: Circle())
        .accessibilityLabel(on ? L("Turn off", "Desligar") : L("Turn on", "Ligar"))
        .padding(.top, 20)
    }

    private func swatch(_ command: BeaconCommand, selected: Bool) -> some View {
        Button { remote.setLook(command, for: lamps) } label: {
            VStack(spacing: 8) {
                Circle()
                    .fill(command.colour)
                    .frame(width: 52, height: 52)
                    .padding(4)
                    .overlay(Circle().strokeBorder(Color.accent, lineWidth: selected ? 2 : 0))
                Text(command.label).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func section<Content: View>(_ title: String, icon: String,
                                         @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            content()
        }
        .padding(12)
        .card()
    }
}

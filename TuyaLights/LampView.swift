import SwiftUI

/// Full controls for a lamp or a group: power, white tones and colours.
struct LampView: View {
    @AppStorage(AppLanguage.storageKey) private var lang = AppLanguage.english.rawValue
    @EnvironmentObject private var remote: BeaconRemote
    var title: String
    var lamps: [BeaconLamp]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 4)

    var body: some View {
        let on = remote.isOn(lamps)
        let look = remote.look(of: lamps)
        ScrollView {
            VStack(spacing: 20) {
                powerButton(on: on, look: look)
                Text(on ? look.label : BeaconCommand.off.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                section(L("White", "Branco"), icon: "thermometer.medium") {
                    LazyVGrid(columns: Array(columns.prefix(3)), spacing: 14) {
                        ForEach(BeaconCommand.whites, id: \.self) { swatch($0, selected: on && look == $0) }
                    }
                }
                section(L("Colour", "Cor"), icon: "paintpalette") {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(BeaconCommand.colours, id: \.self) { swatch($0, selected: on && look == $0) }
                    }
                }
            }
            .padding()
        }
        .background(LightsBackground(glow: on ? look.colour : nil))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func powerButton(on: Bool, look: BeaconCommand) -> some View {
        Button { remote.setPower(!on, for: lamps) } label: {
            Image(systemName: "power")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(on ? .white : .primary)
                .frame(width: 120, height: 120)
                .background(on ? look.colour.opacity(0.9) : .clear, in: Circle())
        }
        .buttonStyle(.plain)
        .glassBackground(in: Circle())
        .shadow(color: on ? look.colour.opacity(0.6) : .clear, radius: 24)
        .padding(.top, 20)
    }

    private func swatch(_ command: BeaconCommand, selected: Bool) -> some View {
        Button { remote.setLook(command, for: lamps) } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(command.colour)
                    .frame(width: 52, height: 52)
                    .overlay(Circle().stroke(.white, lineWidth: selected ? 3 : 0))
                    .shadow(color: command.colour.opacity(selected ? 0.8 : 0), radius: 10)
                Text(command.label).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private func section<Content: View>(_ title: String, icon: String,
                                         @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            content()
        }
        .padding(16)
        .glassBackground(in: RoundedRectangle(cornerRadius: 24))
    }
}

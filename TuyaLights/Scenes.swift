import SwiftUI

/// A named setting per lamp, applied in one tap. Lamps left out are not touched.
/// `.off` turns a lamp off, `.on` turns it on as it was, any other command sets that look.
struct LampScene: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var settings: [String: BeaconCommand] = [:]   // lamp node → command
}

extension BeaconCommand: Codable {}

final class SceneStore: ObservableObject {
    private static let key = "scenes"

    @Published private(set) var scenes: [LampScene]

    init() {
        scenes = UserDefaults.standard.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode([LampScene].self, from: $0) } ?? []
    }

    func save(_ scene: LampScene) {
        if let i = scenes.firstIndex(where: { $0.id == scene.id }) {
            scenes[i] = scene
        } else {
            scenes.append(scene)
        }
        persist()
    }

    func move(_ id: UUID, before target: UUID) {
        guard let from = scenes.firstIndex(where: { $0.id == id }),
              let to = scenes.firstIndex(where: { $0.id == target }), from != to else { return }
        scenes.move(fromOffsets: [from], toOffset: to > from ? to + 1 : to)
        persist()
    }

    func remove(_ scene: LampScene) {
        scenes.removeAll { $0.id == scene.id }
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(try? JSONEncoder().encode(scenes), forKey: Self.key)
    }
}

extension BeaconRemote {
    func apply(_ scene: LampScene) {
        for lamp in BeaconLamp.all {
            switch scene.settings[lamp.node] {
            case nil: break
            case .off: setPower(false, for: [lamp])
            case .on: setPower(true, for: [lamp])
            case let command?: setLook(command, for: [lamp])
            }
        }
    }
}

/// Sheet to create or edit a scene. Each lamp gets a card with skip/off/on and the
/// actual colours, so the scene reads the way it will look.
struct SceneEditor: View {
    @AppStorage(AppLanguage.storageKey) private var lang = AppLanguage.english.rawValue
    @EnvironmentObject private var scenes: SceneStore
    @EnvironmentObject private var lampList: LampList
    @Environment(\.dismiss) private var dismiss
    @State var scene: LampScene

    private let dots = [GridItem(.adaptive(minimum: 34), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    TextField(L("Scene name", "Nome da cena"), text: $scene.name)
                        .font(.title3.weight(.semibold))
                        .padding(16)
                        .glassBackground(in: RoundedRectangle(cornerRadius: 20))
                    ForEach(lampList.lamps) { lamp in lampCard(lamp) }
                }
                .padding()
            }
            .background(LightsBackground())
            .navigationTitle(L("Scene", "Cena"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Cancel", "Cancelar")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Save", "Salvar")) {
                        scenes.save(scene)
                        dismiss()
                    }
                    .disabled(scene.name.trimmingCharacters(in: .whitespaces).isEmpty || scene.settings.isEmpty)
                }
            }
        }
    }

    private func lampCard(_ lamp: BeaconLamp) -> some View {
        let setting = scene.settings[lamp.node]
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: setting == nil || setting == .off ? "lightbulb" : "lightbulb.fill")
                    .foregroundStyle(setting.map { $0 == .off || $0 == .on ? Color.secondary : $0.colour } ?? .secondary)
                Text(lamp.name).font(.headline)
            }
            HStack(spacing: 8) {
                choice(L("Skip", "Ignorar"), selected: setting == nil) { scene.settings[lamp.node] = nil }
                choice(L("Off", "Desligar"), selected: setting == .off) { scene.settings[lamp.node] = .off }
                choice(L("On", "Ligar"), selected: setting == .on) { scene.settings[lamp.node] = .on }
            }
            LazyVGrid(columns: dots, spacing: 10) {
                ForEach(BeaconCommand.whites + BeaconCommand.colours, id: \.self) { command in
                    Button { scene.settings[lamp.node] = command } label: {
                        Circle()
                            .fill(command.colour)
                            .frame(width: 34, height: 34)
                            .overlay(Circle().stroke(.white, lineWidth: setting == command ? 3 : 0))
                            .shadow(color: command.colour.opacity(setting == command ? 0.8 : 0), radius: 8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(command.label)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassBackground(in: RoundedRectangle(cornerRadius: 24))
        .opacity(setting == nil ? 0.75 : 1)
    }

    private func choice(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? .white : .primary)
                .background(selected ? Color.orange : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .glassBackground(in: Capsule())
    }
}

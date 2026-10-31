import SwiftUI

/// A named set of lamps controlled together. Members are stored by lamp node.
struct LampGroup: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var nodes: [String]

    var lamps: [BeaconLamp] { BeaconLamp.all.filter { nodes.contains($0.node) } }
}

final class GroupStore: ObservableObject {
    private static let key = "groups"

    @Published private(set) var groups: [LampGroup]

    init() {
        groups = UserDefaults.standard.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode([LampGroup].self, from: $0) } ?? []
    }

    func save(_ group: LampGroup) {
        if let i = groups.firstIndex(where: { $0.id == group.id }) {
            groups[i] = group
        } else {
            groups.append(group)
        }
        persist()
    }

    func move(_ id: UUID, before target: UUID) {
        guard let from = groups.firstIndex(where: { $0.id == id }),
              let to = groups.firstIndex(where: { $0.id == target }), from != to else { return }
        groups.move(fromOffsets: [from], toOffset: to > from ? to + 1 : to)
        persist()
    }

    func remove(_ group: LampGroup) {
        groups.removeAll { $0.id == group.id }
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(try? JSONEncoder().encode(groups), forKey: Self.key)
    }
}

/// Sheet to create or edit a group: a name and the lamps in it.
struct GroupEditor: View {
    @AppStorage(AppLanguage.storageKey) private var lang = AppLanguage.english.rawValue
    @EnvironmentObject private var groups: GroupStore
    @EnvironmentObject private var lampList: LampList
    @Environment(\.dismiss) private var dismiss
    @State var group: LampGroup

    var body: some View {
        NavigationStack {
            Form {
                TextField(L("Name", "Nome"), text: $group.name)
                Section(L("Lamps", "Lâmpadas")) {
                    ForEach(lampList.lamps) { lamp in
                        Button {
                            if let i = group.nodes.firstIndex(of: lamp.node) {
                                group.nodes.remove(at: i)
                            } else {
                                group.nodes.append(lamp.node)
                            }
                        } label: {
                            HStack {
                                Text(lamp.name).foregroundStyle(.primary)
                                Spacer()
                                if group.nodes.contains(lamp.node) {
                                    Image(systemName: "checkmark").foregroundStyle(Color.accent)
                                }
                            }
                        }
                    }
                }
            }
            .screenBackground()
            .navigationTitle(L("Group", "Grupo"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Cancel", "Cancelar")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Save", "Salvar")) {
                        groups.save(group)
                        dismiss()
                    }
                    .disabled(group.name.trimmingCharacters(in: .whitespaces).isEmpty || group.nodes.isEmpty)
                }
            }
        }
    }
}

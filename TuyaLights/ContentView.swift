import CoreBluetooth
import SwiftUI

struct ContentView: View {
    @AppStorage(AppLanguage.storageKey) private var lang = AppLanguage.english.rawValue
    @EnvironmentObject private var remote: BeaconRemote
    @EnvironmentObject private var groups: GroupStore
    @EnvironmentObject private var scenes: SceneStore
    @EnvironmentObject private var lampList: LampList
    @State private var showSettings = false
    @State private var editing: LampGroup?
    @State private var editingScene: LampScene?
    @State private var renaming: BeaconLamp?
    @State private var newName = ""
    /// Arrange mode, like a dashboard's edit mode: drag tiles to reorder, tap to rename or edit.
    @State private var arranging = false

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if remote.bluetoothState == .poweredOff || remote.bluetoothState == .unauthorized {
                        bluetoothNotice
                    }
                    if arranging {
                        Text(L("Drag tiles to reorder. Tap a lamp to rename it, or a scene or group to edit it.",
                               "Arraste os blocos para reordenar. Toque numa lâmpada para renomear, ou numa cena ou grupo para editar."))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        allButtons
                    }
                    if !scenes.scenes.isEmpty {
                        heading(L("Scenes", "Cenas"))
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(scenes.scenes) { scene in
                                tile("scene", scene.id.uuidString,
                                     onDrop: { scenes.move(UUID(uuidString: $0)!, before: scene.id) },
                                     onTap: { editingScene = scene },
                                     onDelete: { scenes.remove(scene) }) {
                                    Button { remote.apply(scene) } label: {
                                        Label(scene.name, systemImage: "sparkles").lineLimit(1).frame(maxWidth: .infinity)
                                    }
                                    .glassButton()
                                    .controlSize(.large)
                                }
                            }
                        }
                    }
                    if !groups.groups.isEmpty {
                        heading(L("Groups", "Grupos"))
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(groups.groups) { group in
                                tile("group", group.id.uuidString,
                                     onDrop: { groups.move(UUID(uuidString: $0)!, before: group.id) },
                                     onTap: { editing = group },
                                     onDelete: { groups.remove(group) }) {
                                    NavigationLink(value: group) { LampCard(title: group.name, lamps: group.lamps) }
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    if !scenes.scenes.isEmpty || !groups.groups.isEmpty {
                        heading(L("Lamps", "Lâmpadas"))
                    }
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(lampList.lamps) { lamp in
                            tile("lamp", lamp.node,
                                 onDrop: { lampList.move($0, before: lamp.node) },
                                 onTap: { newName = lamp.name; renaming = lamp },
                                 onDelete: nil) {
                                NavigationLink(value: lamp) { LampCard(title: lamp.name, lamps: [lamp]) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
                .animation(.snappy, value: lampList.lamps.map(\.node))
                .animation(.snappy, value: scenes.scenes)
                .animation(.snappy, value: groups.groups)
            }
            .background(LightsBackground())
            .navigationTitle(L("Lights", "Luzes"))
            .navigationDestination(for: BeaconLamp.self) { LampView(title: $0.name, lamps: [$0]) }
            .navigationDestination(for: LampGroup.self) { group in
                // Read back from the store so edits show while the group is open.
                let current = groups.groups.first { $0.id == group.id } ?? group
                LampView(title: current.name, lamps: current.lamps)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(arranging ? L("Done", "OK") : L("Edit", "Editar")) {
                        withAnimation { arranging.toggle() }
                    }
                }
                if !arranging {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(L("New scene", "Nova cena"), systemImage: "sparkles") {
                                editingScene = LampScene(name: "")
                            }
                            Button(L("New group", "Novo grupo"), systemImage: "square.grid.2x2") {
                                editing = LampGroup(name: "", nodes: [])
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showSettings = true } label: { Image(systemName: "gearshape") }
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(item: $editing) { GroupEditor(group: $0).environmentObject(groups).environmentObject(lampList) }
            .sheet(item: $editingScene) { SceneEditor(scene: $0).environmentObject(scenes).environmentObject(lampList) }
            .alert(L("Rename lamp", "Renomear lâmpada"), isPresented: Binding(
                get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField(L("Name", "Nome"), text: $newName)
                Button(L("Save", "Salvar")) {
                    if let renaming { lampList.rename(renaming, to: newName) }
                }
                Button(L("Cancel", "Cancelar"), role: .cancel) {}
            }
        }
    }

    /// A home tile. Normally it's just `content`; while arranging it can be dragged onto another
    /// tile of the same kind, a tap edits it, and a badge deletes it.
    @ViewBuilder
    private func tile<Content: View>(_ kind: String, _ id: String,
                                     onDrop: @escaping (String) -> Void,
                                     onTap: @escaping () -> Void,
                                     onDelete: (() -> Void)?,
                                     @ViewBuilder content: () -> Content) -> some View {
        if arranging {
            content()
                .allowsHitTesting(false)
                .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6])))
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
                .overlay(alignment: .topLeading) {
                    if let onDelete {
                        Button(action: onDelete) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .red)
                        }
                        .offset(x: -8, y: -8)
                    }
                }
                .draggable("\(kind):\(id)")
                .dropDestination(for: String.self) { items, _ in
                    guard let item = items.first, item.hasPrefix(kind + ":") else { return false }
                    onDrop(String(item.dropFirst(kind.count + 1)))
                    return true
                }
        } else {
            content()
        }
    }

    private var allButtons: some View {
        HStack(spacing: 12) {
            Button { remote.setAll(true) } label: {
                Label(L("All on", "Ligar todas"), systemImage: "lightbulb.fill").frame(maxWidth: .infinity)
            }
            .glassButton(prominent: true, tint: .orange)
            Button { remote.setAll(false) } label: {
                Label(L("All off", "Desligar todas"), systemImage: "lightbulb.slash").frame(maxWidth: .infinity)
            }
            .glassButton()
        }
        .controlSize(.large)
    }

    private func heading(_ text: String) -> some View {
        Text(text).font(.title3.bold()).frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bluetoothNotice: some View {
        Label(remote.bluetoothState == .unauthorized
              ? L("Allow Bluetooth for Lights in Settings.", "Permita Bluetooth para Luzes em Ajustes.")
              : L("Bluetooth is off.", "Bluetooth está desligado."),
              systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .glassBackground(in: RoundedRectangle(cornerRadius: 18))
    }
}

/// Tile with the last colour, name and a power button for a lamp or a group.
struct LampCard: View {
    @AppStorage(AppLanguage.storageKey) private var lang = AppLanguage.english.rawValue
    @EnvironmentObject private var remote: BeaconRemote
    var title: String
    var lamps: [BeaconLamp]

    var body: some View {
        let on = remote.isOn(lamps)
        let look = remote.look(of: lamps)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: on ? "lightbulb.fill" : "lightbulb")
                    .font(.title)
                    .foregroundStyle(on ? look.colour : .secondary)
                    .shadow(color: on ? look.colour.opacity(0.8) : .clear, radius: 10)
                Spacer()
                Button { remote.setPower(!on, for: lamps) } label: {
                    Image(systemName: "power")
                        .font(.headline)
                        .frame(width: 40, height: 40)
                        .foregroundStyle(on ? .white : .primary)
                        .background(on ? Color.orange : Color.clear, in: Circle())
                }
                .buttonStyle(.plain)
                .glassBackground(in: Circle())
            }
            Text(title).font(.headline).lineLimit(1)
            Text(on ? look.label : BeaconCommand.off.label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassBackground(in: RoundedRectangle(cornerRadius: 24))
    }
}

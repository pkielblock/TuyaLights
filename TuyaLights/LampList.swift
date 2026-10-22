import SwiftUI

/// The user's names and order for the recorded lamps.
final class LampList: ObservableObject {
    @Published private var names: [String: String]
    @Published private var order: [String]

    init() {
        names = UserDefaults.standard.dictionary(forKey: "lamps.names") as? [String: String] ?? [:]
        order = UserDefaults.standard.stringArray(forKey: "lamps.order") ?? []
    }

    /// Lamps in the user's order with their names; lamps not yet ordered go last.
    var lamps: [BeaconLamp] {
        BeaconLamp.all
            .sorted { (order.firstIndex(of: $0.node) ?? .max) < (order.firstIndex(of: $1.node) ?? .max) }
            .map { lamp in
                var lamp = lamp
                lamp.name = names[lamp.node] ?? lamp.name
                return lamp
            }
    }

    func rename(_ lamp: BeaconLamp, to name: String) {
        let name = name.trimmingCharacters(in: .whitespaces)
        names[lamp.node] = name.isEmpty ? nil : name
        UserDefaults.standard.set(names, forKey: "lamps.names")
    }

    func move(_ node: String, before target: String) {
        var nodes = lamps.map(\.node)
        guard let from = nodes.firstIndex(of: node), let to = nodes.firstIndex(of: target), from != to else { return }
        nodes.move(fromOffsets: [from], toOffset: to > from ? to + 1 : to)
        order = nodes
        UserDefaults.standard.set(order, forKey: "lamps.order")
    }
}

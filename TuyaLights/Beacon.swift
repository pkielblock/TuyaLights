import CoreBluetooth
import SwiftUI

/// Commands recorded from Smart Life. Every lamp has its own encrypted payload for each.
enum BeaconCommand: String, CaseIterable {
    case on, off, white, warm, neutral, cool, red, orange, yellow, green, cyan, blue, purple, pink

    static let whites: [BeaconCommand] = [.warm, .neutral, .cool]
    static let colours: [BeaconCommand] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink]

    var colour: Color {
        switch self {
        case .warm: Color(red: 1, green: 0.78, blue: 0.5)
        case .neutral, .white, .on, .off: Color(red: 1, green: 0.96, blue: 0.9)
        case .cool: Color(red: 0.82, green: 0.9, blue: 1)
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .cyan: .cyan
        case .blue: .blue
        case .purple: .purple
        case .pink: .pink
        }
    }

    var label: String {
        switch self {
        case .on: L("On", "Ligada")
        case .off: L("Off", "Desligada")
        case .white, .neutral: L("White", "Branca")
        case .warm: L("Warm", "Quente")
        case .cool: L("Cold", "Fria")
        case .red: L("Red", "Vermelho")
        case .orange: L("Orange", "Laranja")
        case .yellow: L("Yellow", "Amarelo")
        case .green: L("Green", "Verde")
        case .cyan: L("Cyan", "Ciano")
        case .blue: L("Blue", "Azul")
        case .purple: L("Purple", "Roxo")
        case .pink: L("Pink", "Rosa")
        }
    }
}

/// A lamp driven by Tuya Beacon broadcasts. Nothing connects: the node in each frame
/// addresses the lamp, and the lamp never answers.
/// Frame: 0b, node (4), counter (2, big-endian), 05, payload (17), CRC-8.
struct BeaconLamp: Identifiable, Hashable {
    var name: String
    var node: String        // 4-byte address, hex
    var seed: UInt8         // CRC seed; it also tells the lamp's Smart Life group apart
    var firstCounter: Int   // first frame counter to use for the group, above anything the lamps have heard
    var commands: [BeaconCommand: String]

    var id: String { node }

    /// Loaded from `Lamps.json` in the app bundle. That file holds recorded commands for
    /// real lamps, so it's kept out of git; see `Lamps.example.json`.
    static let all: [BeaconLamp] = {
        guard let url = Bundle.main.url(forResource: "Lamps", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(LampFile.self, from: data)
        else { return [] }
        return file.lamps.map { lamp in
            BeaconLamp(name: lamp.name, node: lamp.node, seed: UInt8(lamp.seed, radix: 16) ?? 0,
                       firstCounter: Int(lamp.counter, radix: 16) ?? 0x1000,
                       commands: Dictionary(uniqueKeysWithValues: lamp.commands.compactMap { key, value in
                           BeaconCommand(rawValue: key).map { ($0, value) }
                       }))
        }
    }()

    private struct LampFile: Decodable {
        struct Entry: Decodable {
            var name: String
            var node: String
            var seed: String
            var counter: String
            var commands: [String: String]
        }
        var lamps: [Entry]
    }
}

/// Broadcasts commands as 13 16-bit service UUIDs, the way Smart Life does. iOS keeps one
/// advertisement at a time, so frames queue and each goes out for `airtime`.
@MainActor
final class BeaconRemote: NSObject, ObservableObject, CBPeripheralManagerDelegate {
    @Published private(set) var bluetoothState: CBManagerState = .unknown
    /// Last command sent per lamp, since lamps don't report their state.
    @Published private(set) var power: [String: Bool]
    @Published private(set) var look: [String: BeaconCommand]

    private static let airtime = 0.6

    private var manager: CBPeripheralManager!
    private var queue: [Data] = []
    private var sending = false

    /// Lamps drop frames whose counter isn't above the last one heard in their group, from
    /// any lamp of that group.

    private func nextCounter(for lamp: BeaconLamp) -> UInt16 {
        let key = String(format: "beacon.counter.%02x", lamp.seed)
        let next = (UserDefaults.standard.object(forKey: key) as? Int ?? lamp.firstCounter) + 1
        UserDefaults.standard.set(next, forKey: key)
        return UInt16(truncatingIfNeeded: next)
    }

    override init() {
        let defaults = UserDefaults.standard
        power = defaults.dictionary(forKey: "beacon.power") as? [String: Bool] ?? [:]
        look = (defaults.dictionary(forKey: "beacon.look") as? [String: String] ?? [:])
            .compactMapValues(BeaconCommand.init(rawValue:))
        super.init()
        manager = CBPeripheralManager(delegate: self, queue: nil)
    }

    func isOn(_ lamp: BeaconLamp) -> Bool { power[lamp.id] ?? false }
    func look(of lamp: BeaconLamp) -> BeaconCommand { look[lamp.id] ?? .neutral }
    /// A set of lamps counts as on when any of them is; it shows the first lit lamp's look.
    func isOn(_ lamps: [BeaconLamp]) -> Bool { lamps.contains(where: isOn) }
    func look(of lamps: [BeaconLamp]) -> BeaconCommand { lamps.first(where: isOn).map(look(of:)) ?? .neutral }

    func setPower(_ on: Bool, for lamps: [BeaconLamp]) {
        for lamp in lamps {
            send([on ? .on : .off], to: lamp)
            power[lamp.id] = on
        }
        save()
    }

    func setAll(_ on: Bool) { setPower(on, for: BeaconLamp.all) }

    /// Whites need the white mode switch first, which is what Smart Life sends too.
    /// It's skipped when the lamp is already showing a white.
    func setLook(_ command: BeaconCommand, for lamps: [BeaconLamp]) {
        for lamp in lamps {
            var commands: [BeaconCommand] = isOn(lamp) ? [] : [.on]
            if BeaconCommand.whites.contains(command),
               !(isOn(lamp) && BeaconCommand.whites.contains(look(of: lamp))) {
                commands.append(.white)
            }
            send(commands + [command], to: lamp)
            power[lamp.id] = true
            look[lamp.id] = command
        }
        save()
    }

    private func save() {
        UserDefaults.standard.set(power, forKey: "beacon.power")
        UserDefaults.standard.set(look.mapValues(\.rawValue), forKey: "beacon.look")
    }

    private func send(_ commands: [BeaconCommand], to lamp: BeaconLamp) {
        for command in commands {
            guard let payload = lamp.commands[command] else { continue }
            let counter = nextCounter(for: lamp)
            var frame = Data([0x0b]) + Data(hexString: lamp.node) + Data([UInt8(counter >> 8), UInt8(counter & 0xff), 0x05])
                + Data(hexString: payload)
            frame.append(Self.crc8(frame[1..<25], seed: lamp.seed))
            queue.append(frame)
        }
        pump()
    }

    private func pump() {
        guard !sending, bluetoothState == .poweredOn, let frame = queue.first else { return }
        sending = true
        let uuids = stride(from: 0, to: 26, by: 2).map {
            CBUUID(string: String(format: "%02X%02X", frame[$0 + 1], frame[$0]))
        }
        manager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: uuids])
        Task {
            try? await Task.sleep(for: .seconds(Self.airtime))
            manager.stopAdvertising()
            queue.removeFirst()
            sending = false
            pump()
        }
    }

    static func crc8(_ data: Data, seed: UInt8) -> UInt8 {
        var c = seed
        for x in data {
            c ^= x
            for _ in 0..<8 { c = c & 0x80 != 0 ? (c << 1) ^ 0x07 : c << 1 }
        }
        return c
    }

    nonisolated func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        MainActor.assumeIsolated {
            bluetoothState = peripheral.state
            pump()
        }
    }
}

extension Data {
    init(hexString: String) {
        var d = Data()
        var i = hexString.startIndex
        while i < hexString.endIndex {
            let j = hexString.index(i, offsetBy: 2)
            d.append(UInt8(hexString[i..<j], radix: 16)!)
            i = j
        }
        self = d
    }
}

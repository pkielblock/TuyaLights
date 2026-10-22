// Prints the Tuya Beacon frames that a phone broadcasts while you use Smart Life,
// so you can copy each lamp's command payloads into Lamps.json.
//
//   swift tools/record.swift [seconds]
//
// macOS asks for Bluetooth permission for your terminal the first time.
import CoreBluetooth
import Foundation

setvbuf(stdout, nil, _IOLBF, 0)
let seconds = Double(CommandLine.arguments.dropFirst().first ?? "300") ?? 300

final class Recorder: NSObject, CBCentralManagerDelegate {
    var central: CBCentralManager!
    var seen = Set<Data>()

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else { return print("Bluetooth state \(central.state.rawValue)") }
        print("Listening. Use Smart Life now; one line per new frame.")
        print("node      counter type payload                            crc")
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi: NSNumber) {
        // A frame is 26 bytes sent as 13 16-bit service UUIDs, each little-endian.
        guard let uuids = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID],
              uuids.count == 13, uuids.allSatisfy({ $0.data.count == 2 }) else { return }
        let frame = uuids.reduce(into: Data()) { $0.append(contentsOf: $1.data.reversed()) }
        guard frame[0] == 0x0b, seen.insert(frame).inserted else { return }
        let hex = { (range: Range<Int>) in frame[range].map { String(format: "%02x", $0) }.joined() }
        print(hex(1..<5), "  ", hex(5..<7), "  ", hex(7..<8), "  ", hex(8..<25), hex(25..<26))
    }
}

let recorder = Recorder()
RunLoop.main.run(until: Date().addingTimeInterval(seconds))

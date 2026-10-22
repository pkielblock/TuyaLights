import SwiftUI

@main
struct TuyaLightsApp: App {
    @StateObject private var remote = BeaconRemote()
    @StateObject private var groups = GroupStore()
    @StateObject private var scenes = SceneStore()
    @StateObject private var lampList = LampList()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(remote)
                .environmentObject(groups)
                .environmentObject(scenes)
                .environmentObject(lampList)
        }
    }
}

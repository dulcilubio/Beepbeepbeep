import SwiftUI

@main
struct startclockApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var gnss = GNSSTimeManager()
    @StateObject private var liveresultat = LiveResultatManager()
    @StateObject private var eventor = EventorManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(gnss)
                .environmentObject(liveresultat)
                .environmentObject(eventor)
        }
    }
}

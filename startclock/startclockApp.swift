import SwiftUI

@main
struct startclockApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var gnss = GNSSTimeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(gnss)
        }
    }
}

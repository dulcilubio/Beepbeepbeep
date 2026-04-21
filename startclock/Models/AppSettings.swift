import SwiftUI

class AppSettings: ObservableObject {

    init() {
        // "system" (SF Mono) was removed — migrate any saved value to "sfpro"
        if UserDefaults.standard.string(forKey: "clockFont") == "system" {
            UserDefaults.standard.set("sfpro", forKey: "clockFont")
        }
    }
    // Start interval — kept for clock highlighting logic; not exposed in Settings UI
    @AppStorage("startInterval")             var startInterval: Int     = 60

    // Pitch steps:    440  660  880  1100  1320  1760  2200 Hz  (indices 0–6)
    // Duration steps:  50  100  200   500  1000 ms              (indices 0–4)
    static let pitchSteps:    [Double] = [440, 660, 880, 1100, 1320, 1760, 2200]
    static let durationSteps: [Int]    = [50, 100, 200, 500, 1000]

    // Audio
    @AppStorage("beepEnabled")               var beepEnabled: Bool = true
    @AppStorage("countdownPitchStep")        var countdownPitchStep: Int    = 3  // 1100 Hz
    @AppStorage("countdownDurationStep")     var countdownDurationStep: Int = 1  // 100 ms
    @AppStorage("goBeepPitchStep")           var goBeepPitchStep: Int       = 4  // 1320 Hz
    @AppStorage("goBeepDurationStep")        var goBeepDurationStep: Int    = 3  // 500 ms

    // Gå-fram-tid
    @AppStorage("gaFramTidEnabled")          var gaFramTidEnabled: Bool   = false
    @AppStorage("gaFramTidOffsetMin")        var gaFramTidOffsetMin: Int  = 3

    // Display
    @AppStorage("invertedMode")              var invertedMode: Bool       = false
    // "sfpro" | "sfCondensed" | "sfCompressed" | "newYork" | "courierNew" | "digital" | "flapBoard"
    @AppStorage("clockFont")                 var clockFont: String        = "sfpro"
    @AppStorage("clockBold")                 var clockBold: Bool          = true
}

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

    // Testing / fake time
    @AppStorage("fakeTimeEnabled")           var fakeTimeEnabled: Bool    = false
    @AppStorage("fakeTimeHour")              var fakeTimeHour: Int        = 10
    @AppStorage("fakeTimeMinute")            var fakeTimeMinute: Int      = 0

    // Display
    @AppStorage("invertedMode")              var invertedMode: Bool       = false
    // Stored as the raw value of ClockStyle — see clockStyle below.
    @AppStorage("clockFont")                 var clockFont: String        = "sfpro"
    @AppStorage("clockBold")                 var clockBold: Bool          = true

    // Start list text size, 1.0 = the original 15 pt rows.
    @AppStorage("bannerTextScale")           var bannerTextScale: Double  = 1.0
    static let bannerScaleRange: ClosedRange<Double> = 0.8...3.0

    // MARK: - Palette
    //
    // Picked per mode rather than dimmed with opacity. The yellow that carries
    // on black is unreadable on white, and a faded tint of it is worse — this
    // screen is read from several metres away, outdoors, in daylight.

    /// Start times and the lead-time label.
    var highlightColor: Color {
        invertedMode
            ? Color(red: 0.58, green: 0.32, blue: 0.00)   // dark amber on white
            : Color(red: 1.00, green: 0.85, blue: 0.10)   // bright yellow on black
    }

    var primaryTextColor: Color { invertedMode ? .black : .white }

    /// Classes and other supporting text — still has to be legible, so it is a
    /// defined grey rather than SwiftUI's .secondary.
    var secondaryTextColor: Color {
        invertedMode ? Color(white: 0.26) : Color(white: 0.84)
    }

    var warningColor: Color {
        invertedMode ? Color(red: 0.72, green: 0.33, blue: 0.00) : .orange
    }

    var alertColor: Color {
        invertedMode ? Color(red: 0.74, green: 0.00, blue: 0.00) : .red
    }

    var panelBackground: Color { invertedMode ? .white : Color(white: 0.08) }
    var panelBorder: Color     { highlightColor.opacity(invertedMode ? 0.85 : 0.7) }
    var separatorColor: Color  { primaryTextColor.opacity(0.25) }

    var clockStyle: ClockStyle {
        get { ClockStyle(rawValue: clockFont) ?? .sfpro }
        set { clockFont = newValue.rawValue }
    }
}

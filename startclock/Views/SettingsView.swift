import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var gnss: GNSSTimeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // TIME SOURCE
                Section("GPS Sync") {
                    LabeledContent("Status", value: activeSourceLabel)
                        .foregroundStyle(.secondary)
                }

                // GÅ-FRAM-TID
                Section("Gå-fram-tid") {
                    Toggle("Enable offset", isOn: $settings.gaFramTidEnabled)
                    if settings.gaFramTidEnabled {
                        Stepper(
                            "Offset: \(settings.gaFramTidOffsetMin) min",
                            value: $settings.gaFramTidOffsetMin,
                            in: 0...5
                        )
                    }

                    Picker("Start interval", selection: $settings.startInterval) {
                        ForEach([10, 20, 30, 45, 60, 90, 120], id: \.self) { sec in
                            Text("\(sec) s").tag(sec)
                        }
                    }
                }

                // AUDIO
                Section("Audio") {
                    Toggle("Beeps", isOn: $settings.beepEnabled)

                    if settings.beepEnabled {
                        stepPicker(
                            label: "Countdown pitch",
                            value: "\(Int(AppSettings.pitchSteps[settings.countdownPitchStep])) Hz",
                            count: AppSettings.pitchSteps.count,
                            selection: $settings.countdownPitchStep
                        )
                        stepPicker(
                            label: "Countdown length",
                            value: "\(AppSettings.durationSteps[settings.countdownDurationStep]) ms",
                            count: AppSettings.durationSteps.count,
                            selection: $settings.countdownDurationStep
                        )
                        stepPicker(
                            label: "Go-beep pitch",
                            value: "\(Int(AppSettings.pitchSteps[settings.goBeepPitchStep])) Hz",
                            count: AppSettings.pitchSteps.count,
                            selection: $settings.goBeepPitchStep
                        )
                        stepPicker(
                            label: "Go-beep length",
                            value: "\(AppSettings.durationSteps[settings.goBeepDurationStep]) ms",
                            count: AppSettings.durationSteps.count,
                            selection: $settings.goBeepDurationStep
                        )
                    }
                }

                // DISPLAY
                Section("Display") {
                    Toggle("Inverted (outdoor)", isOn: $settings.invertedMode)

                    Picker("Font", selection: $settings.clockFont) {
                        Text("SF Pro").tag("sfpro")
                        Text("SF Condensed").tag("sfCondensed")
                        Text("SF Compressed").tag("sfCompressed")
                        Text("New York").tag("newYork")
                        Text("Courier New").tag("courierNew")
                        Text("Digital").tag("digital")
                        Text("Flap Board").tag("flapBoard")
                    }

                    Toggle("Bold", isOn: $settings.clockBold)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func stepPicker(label: String, value: String, count: Int, selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text(value).font(.subheadline).foregroundStyle(.secondary)
            }
            Picker(label, selection: selection) {
                ForEach(0..<count, id: \.self) { i in
                    Text("\(i + 1)").tag(i)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 2)
    }

    private var activeSourceLabel: String {
        switch gnss.syncStatus {
        case .acquiring:    return "Acquiring…"
        case .synced:
            switch gnss.timeSource {
            case .gnss:   return "GNSS · Synced"
            case .ntp:    return "NTP · Synced"
            case .device: return "Device · Synced"
            }
        case .driftWarning: return "Drift Warning"
        case .unavailable:  return "Unavailable"
        }
    }
}

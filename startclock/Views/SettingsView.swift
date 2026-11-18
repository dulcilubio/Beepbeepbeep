import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var gnss: GNSSTimeManager
    @EnvironmentObject var liveresultat: LiveResultatManager
    @EnvironmentObject var eventor: EventorManager
    @Environment(\.dismiss) private var dismiss
    @State private var showSelectCompetition = false
    @State private var showCompetitionPicker = false
    @State private var showEventorImport = false

    var body: some View {
        NavigationStack {
            Form {
                startListSection
                timingSection
                audioSection
                clockSection
                timeSourceSection
                testingSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showSelectCompetition) { SelectCompetitionView() }
            .sheet(isPresented: $showCompetitionPicker) { CompetitionPickerView() }
            .sheet(isPresented: $showEventorImport) { EventorImportView() }
        }
        // Always show settings in dark mode — invertedMode forces light on the clock
        // but settings should remain readable regardless.
        .preferredColorScheme(.dark)
    }

    // MARK: - Start list

    @ViewBuilder
    private var startListSection: some View {
        Section {
            if liveresultat.hasActiveCompetition {
                LabeledContent("Competition", value: liveresultat.savedCompName)
                LabeledContent("Class", value: liveresultat.classFilterLabel)
                if liveresultat.isLoadingStartList {
                    LabeledContent("Status", value: "Updating…")
                } else {
                    LabeledContent("Runners", value: "\(liveresultat.startEntries.count)")
                    if let t = liveresultat.lastUpdated {
                        LabeledContent("Updated", value: t, format: .dateTime.hour().minute())
                    }
                }
                Button("Change…") { showCompetitionPicker = true }
                Button("Refresh") { liveresultat.refreshNow() }
                Button("Remove", role: .destructive) { liveresultat.clearSelection() }

            } else if let list = eventor.importedList {
                LabeledContent("Competition", value: list.name)
                if eventor.availableClasses.isEmpty {
                    LabeledContent("Class", value: "All classes")
                } else {
                    NavigationLink {
                        ClassSelectionList(
                            classes: eventor.availableClasses,
                            selection: $eventor.classFilters
                        )
                        .navigationTitle("Classes")
                        .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        LabeledContent("Class", value: eventor.classFilterLabel)
                    }
                }
                if eventor.isLoading {
                    LabeledContent("Status", value: "Updating…")
                } else {
                    LabeledContent(
                        "Entries",
                        value: eventor.classFilters.isEmpty
                            ? "\(list.entries.count)"
                            : "\(eventor.filteredEntries.count) of \(list.entries.count)"
                    )
                    LabeledContent("Updated", value: list.importedAt, format: .dateTime.hour().minute())
                    if eventor.lastRefreshFailed {
                        Text("Auto-update failed — this list may be out of date. Re-import it from Eventor to be sure.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                Button("Change…") { showEventorImport = true }
                Button("Refresh") { eventor.refreshNow() }
                Button("Remove", role: .destructive) { eventor.clearList() }

            } else {
                Button("Select competition…") { showSelectCompetition = true }
                Text("Liveresultat or Eventor start list")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            Text("Start list")
        } footer: {
            // GPS status lives here instead of its own section
            HStack(spacing: 5) {
                Circle().fill(gpsStatusColor).frame(width: 7, height: 7)
                Text(gpsStatusLabel).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Timing

    @ViewBuilder
    private var timingSection: some View {
        Section("Timing") {
            Picker("Start interval", selection: $settings.startInterval) {
                Text("Auto").tag(0)
                ForEach([10, 15, 20, 30, 45, 60, 90, 120], id: \.self) { s in
                    Text("\(s) s").tag(s)
                }
            }
            if let detected = activeDetectedInterval,
               settings.startInterval != 0,
               settings.startInterval != detected {
                Text("Start list uses \(detected) s intervals — interval mismatch.")
                    .font(.caption).foregroundStyle(.orange)
            }

            Toggle("Gå-fram-tid", isOn: $settings.gaFramTidEnabled)
            if settings.gaFramTidEnabled {
                Stepper(
                    "Offset: \(settings.gaFramTidOffsetMin) min",
                    value: $settings.gaFramTidOffsetMin,
                    in: 0...5
                )
            }
        }
    }

    // MARK: - Time source

    @ViewBuilder
    private var timeSourceSection: some View {
        Section {
            LabeledContent("Source", value: gpsStatusLabel)
            LabeledContent("Correction", value: String(format: "%+.3f s", gnss.appliedOffset))
            if let synced = gnss.lastSyncAt {
                LabeledContent("Last sync", value: synced,
                               format: .dateTime.hour().minute().second())
            }
            if let accuracy = gnss.lastAccuracy {
                LabeledContent("Fix accuracy", value: String(format: "%.0f m", accuracy))
            }
            if gnss.hasLargeCorrection {
                Text("The clock has been moved more than a second from device time. Check it against another synced clock before the first start.")
                    .font(.caption).foregroundStyle(.orange)
            }
        } header: {
            Text("Time")
        } footer: {
            Text("Correction is how far the shown time sits from this device's own clock.")
        }
    }

    // MARK: - Audio

    @ViewBuilder
    private var audioSection: some View {
        Section {
            Toggle("Beeps", isOn: $settings.beepEnabled)
            if settings.beepEnabled {
                beepControls(
                    label: "Countdown (last 5 s)",
                    pitchStep: $settings.countdownPitchStep,
                    durationStep: $settings.countdownDurationStep
                )
                beepControls(
                    label: "Go",
                    pitchStep: $settings.goBeepPitchStep,
                    durationStep: $settings.goBeepDurationStep
                )
            }
        } header: {
            Text("Audio")
        } footer: {
            Text("An incoming call always interrupts the beeps — iOS lets no app override that. The beeps resume by themselves afterwards. To avoid it entirely, turn on Do Not Disturb, or Airplane Mode, where GPS time sync keeps working.")
        }
    }

    // MARK: - Clock

    @ViewBuilder
    private var clockSection: some View {
        Section("Clock") {
            Picker("Style", selection: $settings.clockFont) {
                Text("SF Pro").tag("sfpro")
                Text("Condensed").tag("sfCondensed")
                Text("Compressed").tag("sfCompressed")
                Text("New York").tag("newYork")
                Text("Courier New").tag("courierNew")
                Text("Digital").tag("digital")
                Text("Flap Board").tag("flapBoard")
                Text("Analog").tag("analog")
                Text("Analog (seconds)").tag("analogSeconds")
                Text("Hour only").tag("hourOnly")
                Text("Minute only").tag("minuteOnly")
                Text("Second only").tag("secondOnly")
            }
            // Bold has no effect on non-text styles
            if styleUsesBold {
                Toggle("Bold", isOn: $settings.clockBold)
            }
            Toggle("Inverted (outdoor)", isOn: $settings.invertedMode)
        }
    }

    // MARK: - Testing

    @ViewBuilder
    private var testingSection: some View {
        Section("Testing") {
            Toggle("Override time", isOn: $settings.fakeTimeEnabled)
            if settings.fakeTimeEnabled {
                DatePicker("Fake time", selection: fakeTimeBinding,
                           displayedComponents: .hourAndMinute)
                Text("Disable before competition — seconds still tick from the real clock.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - About

    @ViewBuilder
    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: Bundle.main.versionString)
        }
    }

    // MARK: - Beep row helper

    @ViewBuilder
    private func beepControls(label: String, pitchStep: Binding<Int>, durationStep: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline)

            // Pitch
            HStack {
                Text("Pitch").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(AppSettings.pitchSteps[pitchStep.wrappedValue])) Hz")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Picker("Pitch", selection: pitchStep) {
                ForEach(Array(AppSettings.pitchSteps.enumerated()), id: \.offset) { i, hz in
                    Text(pitchLabel(hz)).tag(i)
                }
            }
            .pickerStyle(.segmented)

            // Duration
            HStack {
                Text("Length").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(AppSettings.durationSteps[durationStep.wrappedValue]) ms")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Picker("Length", selection: durationStep) {
                ForEach(Array(AppSettings.durationSteps.enumerated()), id: \.offset) { i, ms in
                    Text(durationLabel(ms)).tag(i)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func pitchLabel(_ hz: Double) -> String {
        hz >= 1000
            ? String(format: "%.1fk", hz / 1000).replacingOccurrences(of: ".0k", with: "k")
            : "\(Int(hz))"
    }

    private func durationLabel(_ ms: Int) -> String {
        ms >= 1000 ? "\(ms / 1000)s" : "\(ms)"
    }

    private var styleUsesBold: Bool {
        switch settings.clockFont {
        case "analog", "analogSeconds", "digital", "flapBoard":
            return false
        default:
            // text-based styles (sfpro, sfCondensed, sfCompressed, newYork, courierNew,
            // hourOnly, minuteOnly, secondOnly) all support bold
            return true
        }
    }

    private var fakeTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: settings.fakeTimeHour,
                    minute: settings.fakeTimeMinute,
                    second: 0, of: Date()
                ) ?? Date()
            },
            set: { d in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: d)
                settings.fakeTimeHour = comps.hour ?? 0
                settings.fakeTimeMinute = comps.minute ?? 0
            }
        )
    }

    private var activeDetectedInterval: Int? {
        if liveresultat.hasActiveCompetition { return liveresultat.detectedInterval }
        if eventor.hasActiveList { return eventor.detectedInterval }
        return nil
    }

    private var gpsStatusLabel: String {
        switch gnss.syncStatus {
        case .acquiring:    return "GPS acquiring…"
        case .synced:
            switch gnss.timeSource {
            case .gnss:   return "GPS synced"
            case .ntp:    return "NTP synced"
            case .device: return "Device clock (no GPS)"
            }
        case .driftWarning: return "GPS drift warning"
        case .unavailable:  return "GPS unavailable"
        }
    }

    private var gpsStatusColor: Color {
        switch gnss.syncStatus {
        case .acquiring:    return .yellow
        case .synced:       return .green
        case .driftWarning: return .orange
        case .unavailable:  return .red
        }
    }
}

extension Bundle {
    /// "1.1 (2)" — marketing version with the build number in parentheses.
    var versionString: String {
        let short = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var gnss: GNSSTimeManager
    @EnvironmentObject var liveresultat: LiveResultatManager
    @EnvironmentObject var eventor: EventorManager

    @State private var now: Date = Date()
    @State private var prevStarters: [StartEntry]    = []
    @State private var currentStarters: [StartEntry] = []
    @State private var nextStarters: [StartEntry]    = []
    @State private var highlight: ClockHighlight     = .none
    @State private var showSettings = false
    @State private var lastBeepSecond: Int = -1
    @State private var showDeniedAlert = false
    @State private var chromaVisible = true
    @State private var hideWorkItem: DispatchWorkItem?

    @StateObject private var audio = AudioManager()
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            (settings.invertedMode ? Color.white : Color.black)
                .ignoresSafeArea()

            // Outer VStack reserves space for status bar (top) and controls (bottom).
            // Placing the banner here — not as an overlay — lets the clock shrink to
            // make room, preventing occlusion in both portrait and landscape.
            VStack(spacing: 0) {
                Color.clear.frame(height: 40)   // clear status bar overlay

                VStack(spacing: 8) {
                    if settings.gaFramTidEnabled {
                        VStack(spacing: 2) {
                            Text("GÅ-FRAM-TID")
                                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.yellow)
                                .tracking(2)
                            if settings.gaFramTidOffsetMin > 0 {
                                Text("+\(settings.gaFramTidOffsetMin) min")
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.yellow.opacity(0.75))
                            }
                        }
                    }
                    ClockView(date: now, highlight: highlight)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if !prevStarters.isEmpty || !currentStarters.isEmpty || !nextStarters.isEmpty {
                    ParticipantBannerView(
                        previous: prevStarters,
                        current:  currentStarters,
                        next:     nextStarters,
                        showSeconds: showsSeconds
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.opacity)
                }
                // No bottom reservation — controls overlay floats on top of the banner.
            }
        }
        // Chrome floats on top without affecting clock layout.
        .overlay(alignment: .top) {
            StatusBarView(audioAlert: settings.beepEnabled && !audio.isReady)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                // An alert nobody can see is useless, so the status bar stops
                // auto-hiding while the beeps are dead or the clock was moved.
                .opacity(chromaVisible || hasAlert ? 1 : 0)
        }
        .overlay(alignment: .bottom) {
            ControlsView(showSettings: $showSettings)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .opacity(chromaVisible ? 1 : 0)
                .allowsHitTesting(chromaVisible)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in wakeChroma() }
                .onEnded   { _ in wakeChroma() }
        )
        .preferredColorScheme(settings.invertedMode ? .light : .dark)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .alert("Location Access Denied", isPresented: $showDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Continue", role: .cancel) { }
        } message: {
            Text("startclock uses GPS to synchronise time. No location data is stored or transmitted.\n\nFalling back to NTP or device clock — accuracy may be reduced.")
        }
        .onReceive(timer) { _ in
            let gftSecs = settings.gaFramTidEnabled ? settings.gaFramTidOffsetMin * 60 : 0
            let real = gnss.syncedNow(gaFramTidSecs: gftSecs)
            if settings.fakeTimeEnabled {
                let cal = Calendar.current
                var comps = cal.dateComponents([.year, .month, .day, .second, .nanosecond], from: real)
                comps.hour = settings.fakeTimeHour
                comps.minute = settings.fakeTimeMinute
                now = cal.date(from: comps) ?? real
            } else {
                now = real
            }
            (prevStarters, currentStarters, nextStarters) = computeWindowedStarters(for: now)
            highlight = computeHighlight(for: now)
            scheduleBeepsIfNeeded(for: now, highlight: highlight)
        }
        .onAppear {
            gnss.start()
            scheduleHide()
        }
        .onDisappear {
            gnss.stop()
            hideWorkItem?.cancel()
        }
        .onChange(of: gnss.locationPermissionDenied) { denied in
            if denied { showDeniedAlert = true }
        }
    }

    /// Conditions the start crew must not miss.
    private var hasAlert: Bool {
        (settings.beepEnabled && !audio.isReady) || gnss.hasLargeCorrection
    }

    // MARK: - Chroma auto-hide

    private func wakeChroma() {
        if !chromaVisible {
            withAnimation(.easeIn(duration: 0.2)) { chromaVisible = true }
        }
        scheduleHide()
    }

    private func scheduleHide() {
        hideWorkItem?.cancel()
        let item = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.6)) { chromaVisible = false }
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: item)
    }

    // MARK: - Starters

    private func computeWindowedStarters(for date: Date)
        -> (prev: [StartEntry], curr: [StartEntry], next: [StartEntry])
    {
        let entries = activeEntries
        guard !entries.isEmpty else { return ([], [], []) }

        let cal      = Calendar.current
        let secs     = Int(date.timeIntervalSince(cal.startOfDay(for: date)))
        // Use 60 s as the window size in auto mode (align to whole minutes)
        let interval = settings.startInterval > 0 ? settings.startInterval : 60
        let winStart = (secs / interval) * interval

        func window(_ lo: Int, _ hi: Int) -> [StartEntry] {
            entries.filter { ($0.startSeconds ?? -1) >= lo && ($0.startSeconds ?? -1) < hi }
        }

        return (
            prev: window(winStart - interval, winStart),
            curr: window(winStart,            winStart + interval),
            next: window(winStart + interval,  winStart + 2 * interval)
        )
    }

    private var activeEntries: [StartEntry] {
        if liveresultat.hasActiveCompetition { return liveresultat.startEntries }
        if eventor.hasActiveList { return eventor.filteredEntries }
        return []
    }

    /// Whole-minute starts are the norm, so seconds are only shown when the
    /// loaded start list actually uses them.
    private var showsSeconds: Bool {
        if liveresultat.hasActiveCompetition { return liveresultat.usesSecondStarts }
        if eventor.hasActiveList { return eventor.usesSecondStarts }
        return false
    }

    // MARK: - Highlight

    /// Single source of truth for the clock colour and the beeps.
    /// Fixed interval: derived from epoch seconds. Auto (0): derived from the
    /// actual start times in the loaded list.
    private func computeHighlight(for date: Date) -> ClockHighlight {
        let interval = settings.startInterval

        if interval > 0 {
            let pos = Int(date.timeIntervalSince1970) % interval
            if pos == 0 { return .go }
            return interval - pos <= 5 ? .warning : .none
        }

        let entries = activeEntries
        guard !entries.isEmpty else { return .none }
        let cal  = Calendar.current
        let secs = Int(date.timeIntervalSince(cal.startOfDay(for: date)))
        var warning = false
        for entry in entries {
            guard let s = entry.startSeconds else { continue }
            let diff = s - secs
            // A start at this exact second wins over a countdown for a later one,
            // so keep scanning instead of returning on the first match.
            if diff == 0 { return .go }
            if diff > 0, diff <= 5 { warning = true }
        }
        return warning ? .warning : .none
    }

    // MARK: - Beep scheduling

    private func scheduleBeepsIfNeeded(for date: Date, highlight: ClockHighlight) {
        guard settings.beepEnabled, highlight != .none else { return }
        let totalSecs = Int(date.timeIntervalSince1970)
        guard totalSecs != lastBeepSecond else { return }
        lastBeepSecond = totalSecs

        let pitchStep    = highlight == .go ? settings.goBeepPitchStep    : settings.countdownPitchStep
        let durationStep = highlight == .go ? settings.goBeepDurationStep : settings.countdownDurationStep
        audio.beep(
            frequency: AppSettings.pitchSteps[pitchStep],
            durationSecs: Double(AppSettings.durationSteps[durationStep]) / 1000.0
        )
    }
}

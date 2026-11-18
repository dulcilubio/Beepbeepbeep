import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var gnss: GNSSTimeManager
    @EnvironmentObject var liveresultat: LiveResultatManager
    @EnvironmentObject var eventor: EventorManager
    @EnvironmentObject var nowPlaying: NowPlayingManager

    @State private var now: Date = Date()
    @State private var banner = StartSchedule.BannerContent()
    @State private var highlight: ClockHighlight     = .none
    @State private var showSettings = false
    @State private var lastBeepSecond: Int = -1
    @State private var showDeniedAlert = false
    @State private var chromaVisible = true
    @State private var hideWorkItem: DispatchWorkItem?
    @State private var pinchBaseScale: Double?

    /// The share of the screen the clock keeps whatever the names are doing.
    private static let clockMinHeightFraction: CGFloat = 0.45

    @StateObject private var audio = AudioManager()
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            (settings.invertedMode ? Color.white : Color.black)
                .ignoresSafeArea()

            // Outer VStack reserves space for status bar (top) and controls (bottom).
            // Placing the banner here — not as an overlay — lets the clock shrink to
            // make room, preventing occlusion in both portrait and landscape.
            GeometryReader { geo in
              VStack(spacing: 0) {
                Color.clear.frame(height: 40)   // clear status bar overlay

                VStack(spacing: 8) {
                    if settings.gaFramTidEnabled {
                        VStack(spacing: 2) {
                            Text("GÅ-FRAM-TID")
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundStyle(settings.highlightColor)
                                .tracking(2)
                            if settings.gaFramTidOffsetMin > 0 {
                                Text("+\(settings.gaFramTidOffsetMin) min")
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(settings.highlightColor)
                            }
                        }
                    }
                    ClockView(
                        date: now,
                        highlight: highlight,
                        style: settings.clockStyle,
                        bold: settings.clockBold
                    )
                }
                .frame(maxWidth: .infinity,
                       minHeight: geo.size.height * Self.clockMinHeightFraction,
                       maxHeight: .infinity)

                if !banner.isEmpty {
                    ParticipantBannerView(
                        departed: banner.departed,
                        departedOpacity: banner.departedOpacity,
                        current:  banner.current,
                        next:     banner.next,
                        showSeconds: showsSeconds,
                        scale: settings.bannerTextScale,
                        // Scaling the names up must never squeeze the clock —
                        // rows drop out instead. The 40 pt is the status strip.
                        maxHeight: max(0, geo.size.height
                                          * (1 - Self.clockMinHeightFraction) - 92),
                        availableWidth: geo.size.width - 60
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.opacity)
                    // Pinch the names to resize them on the spot — the clock
                    // gives up the height, so this sizes both at once.
                    .gesture(
                        MagnificationGesture()
                            .onChanged { magnification in
                                let base = pinchBaseScale ?? settings.bannerTextScale
                                if pinchBaseScale == nil { pinchBaseScale = base }
                                settings.bannerTextScale = clampedScale(base * magnification)
                            }
                            .onEnded { _ in
                                // Snap to the same steps the slider uses.
                                settings.bannerTextScale =
                                    clampedScale((settings.bannerTextScale * 10).rounded() / 10)
                                pinchBaseScale = nil
                            }
                    )
                }
                // Reserve the control strip so the floating controls never land on a
                // banner row.
                Color.clear.frame(height: 52)
              }
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
            banner = StartSchedule.banner(
                entries: activeEntries,
                secondsFromMidnight: Self.secondsFromMidnight(now),
                interval: settings.startInterval,
                leadTimeEnabled: settings.gaFramTidEnabled
            )
            highlight = computeHighlight(for: now)
            scheduleBeepsIfNeeded(for: now, highlight: highlight)
        }
        .onAppear {
            gnss.start()
            scheduleHide()
            nowPlaying.start { settings.beepEnabled = $0 }
            refreshNowPlaying()
        }
        .onChange(of: nowPlayingSubtitle) { _ in refreshNowPlaying() }
        .onChange(of: settings.beepEnabled) { _ in refreshNowPlaying() }
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

    private func clampedScale(_ value: Double) -> Double {
        min(max(value, AppSettings.bannerScaleRange.lowerBound),
            AppSettings.bannerScaleRange.upperBound)
    }

    // MARK: - Lock Screen

    /// The competition if one is loaded, so the entry says which clock this is
    /// when several devices are running at the same event.
    private var nowPlayingTitle: String {
        if liveresultat.hasActiveCompetition, !liveresultat.savedCompName.isEmpty {
            return liveresultat.savedCompName
        }
        if let name = eventor.importedList?.name, !name.isEmpty { return name }
        return "Start clock"
    }

    private var nowPlayingSubtitle: String {
        guard let next = banner.current.first,
              let seconds = next.startSeconds
        else { return "Running" }
        return String(format: "Next start %02d:%02d:%02d",
                      seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }

    private func refreshNowPlaying() {
        nowPlaying.update(
            title: nowPlayingTitle,
            subtitle: nowPlayingSubtitle,
            beepsOn: settings.beepEnabled
        )
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

    private static func secondsFromMidnight(_ date: Date) -> Int {
        let cal = Calendar.current
        return Int(date.timeIntervalSince(cal.startOfDay(for: date)))
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

    private func computeHighlight(for date: Date) -> ClockHighlight {
        StartSchedule.highlight(
            entries: activeEntries,
            secondsFromMidnight: Self.secondsFromMidnight(date),
            epochSeconds: Int(date.timeIntervalSince1970),
            interval: settings.startInterval
        )
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

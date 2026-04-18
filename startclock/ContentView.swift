import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var gnss: GNSSTimeManager

    @State private var now: Date = Date()
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

            // Clock is laid out independently — always truly centered.
            VStack(spacing: 10) {
                if settings.gaFramTidEnabled {
                    Text("GÅ-FRAM-TID")
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.yellow)
                        .tracking(2)
                }
                ClockView(date: now)
            }
        }
        // Chrome floats on top without affecting clock layout.
        .overlay(alignment: .top) {
            StatusBarView()
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .opacity(chromaVisible ? 1 : 0)
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
            now = gnss.syncedNow(gaFramTidSecs: gftSecs)
            scheduleBeepsIfNeeded(for: now)
        }
        .onAppear {
            gnss.start()
            scheduleHide()
        }
        .onDisappear {
            gnss.stop()
            hideWorkItem?.cancel()
        }
        .onChange(of: gnss.locationPermissionDenied) { _, denied in
            if denied { showDeniedAlert = true }
        }
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

    // MARK: - Beep scheduling

    private func scheduleBeepsIfNeeded(for date: Date) {
        guard settings.beepEnabled else { return }
        let cal = Calendar.current
        let s   = cal.component(.second, from: date)
        guard s != lastBeepSecond else { return }
        lastBeepSecond = s

        let interval      = settings.startInterval
        let posInInterval = s % interval

        if posInInterval == 0 {
            audio.beep(
                frequency: AppSettings.pitchSteps[settings.goBeepPitchStep],
                durationSecs: Double(AppSettings.durationSteps[settings.goBeepDurationStep]) / 1000.0
            )
        } else if interval - posInInterval <= 5 {
            audio.beep(
                frequency: AppSettings.pitchSteps[settings.countdownPitchStep],
                durationSecs: Double(AppSettings.durationSteps[settings.countdownDurationStep]) / 1000.0
            )
        }
    }
}

import AVFoundation
import UIKit

/// Owns the audio session and plays the countdown / go beeps.
///
/// iOS gives an app no way to block an incoming phone call — a call always
/// interrupts the audio session, and no entitlement or category changes that.
/// What the app can do, and now does:
///   • tell the system not to interrupt for *system alerts* (notification
///     sounds, alarms-adjacent chimes), which covers most interruptions,
///   • come back by itself the instant an interruption ends,
///   • rebuild the engine if media services die,
///   • report its state so the clock can warn that the beeps are silent.
class AudioManager: ObservableObject {
    /// False whenever a beep would not be heard — read by the status bar.
    @Published private(set) var isReady = false
    /// True while a call or another app holds the session.
    @Published private(set) var isInterrupted = false

    private var engine     = AVAudioEngine()
    private var beepPlayer = AVAudioPlayerNode()
    private var keepAlive  = AVAudioPlayerNode()

    /// All engine and session work happens here, so the nodes are never touched
    /// from two threads at once. Heavy session work blocks for 200–500 ms.
    private let queue = DispatchQueue(label: "se.erikfrick.startclock.audio", qos: .userInitiated)
    private var ready = false          // queue-confined mirror of isReady
    private var retryScheduled = false
    private var observers: [NSObjectProtocol] = []

    init() {
        observeSystemEvents()
        configure(rebuildEngine: false)
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    // MARK: - Session / engine

    private func configure(rebuildEngine: Bool) {
        queue.async { [weak self] in
            guard let self else { return }

            if rebuildEngine {
                // After a media services reset every node is invalid.
                self.engine.stop()
                self.engine     = AVAudioEngine()
                self.beepPlayer = AVAudioPlayerNode()
                self.keepAlive  = AVAudioPlayerNode()
            }

            if self.beepPlayer.engine == nil {
                self.engine.attach(self.beepPlayer)
                self.engine.attach(self.keepAlive)
                self.engine.connect(self.beepPlayer, to: self.engine.mainMixerNode, format: nil)
                self.engine.connect(self.keepAlive,  to: self.engine.mainMixerNode, format: nil)
            }

            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playback, options: .duckOthers)
                // Keeps notification sounds and other system alerts from taking
                // the session. A phone call still interrupts — nothing prevents that.
                try session.setPrefersNoInterruptionsFromSystemAlerts(true)
                try session.setActive(true)
                if !self.engine.isRunning { try self.engine.start() }
                self.startKeepAlive()
                self.beepPlayer.play()
                self.setReady(true)
            } catch {
                // Typically "session in use" during a call — keep trying so the
                // beeps return on their own once the call ends.
                self.setReady(false)
                self.scheduleRetry()
            }
        }
    }

    /// Silent looping buffer — keeps the AVAudioSession alive when the screen is
    /// off or the app is backgrounded.
    private func startKeepAlive() {
        let fmt        = keepAlive.outputFormat(forBus: 0)
        let frameCount = AVAudioFrameCount(fmt.sampleRate) // 1 s of silence
        guard frameCount > 0,
              let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frameCount)
        else { return }
        buf.frameLength = frameCount
        keepAlive.scheduleBuffer(buf, at: nil, options: .loops)
        keepAlive.play()
    }

    private func scheduleRetry() {
        guard !retryScheduled else { return }
        retryScheduled = true
        queue.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self else { return }
            self.retryScheduled = false
            guard !self.ready else { return }
            self.configure(rebuildEngine: false)
        }
    }

    private func setReady(_ value: Bool) {
        ready = value
        DispatchQueue.main.async { self.isReady = value }
    }

    // MARK: - Interruptions

    private func observeSystemEvents() {
        let center = NotificationCenter.default

        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw)
            else { return }

            switch type {
            case .began:
                self.isInterrupted = true
                self.setReadyFromMain(false)
            case .ended:
                self.isInterrupted = false
                // Resume regardless of .shouldResume: beeping on time is the
                // whole point of the app, it is not background music.
                self.configure(rebuildEngine: false)
            @unknown default:
                self.configure(rebuildEngine: false)
            }
        })

        // Media services died — everything must be built again.
        observers.append(center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.configure(rebuildEngine: true)
        })

        // Route change (headphones, Bluetooth, CarPlay) can stop the engine.
        observers.append(center.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.configure(rebuildEngine: false)
        })

        // Backstop: whatever happened while we were away, check on return.
        observers.append(center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, !self.isReady else { return }
            self.configure(rebuildEngine: false)
        })
    }

    private func setReadyFromMain(_ value: Bool) {
        isReady = value
        queue.async { self.ready = value }
    }

    // MARK: - Beep

    func beep(frequency: Double, durationSecs: Double) {
        queue.async { [weak self] in
            guard let self, self.ready else { return }

            let fmt        = self.beepPlayer.outputFormat(forBus: 0)
            let sampleRate = fmt.sampleRate
            let channels   = Int(fmt.channelCount)
            let frameCount = AVAudioFrameCount(sampleRate * durationSecs)
            guard sampleRate > 0, channels > 0, frameCount > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frameCount)
            else { return }
            buffer.frameLength = frameCount

            let fadeFrames = max(1, min(Int(sampleRate * 0.005), Int(frameCount) / 4))
            for ch in 0..<channels {
                guard let data = buffer.floatChannelData?[ch] else { continue }
                for i in 0..<Int(frameCount) {
                    let t       = Double(i) / sampleRate
                    let sine    = Float(sin(2 * .pi * frequency * t))
                    let fadeIn  = i < fadeFrames ? Float(i) / Float(fadeFrames) : 1.0
                    let fadeOut = i > Int(frameCount) - fadeFrames
                                    ? Float(Int(frameCount) - i) / Float(fadeFrames) : 1.0
                    data[i]     = sine * fadeIn * fadeOut * 0.6
                }
            }

            guard self.engine.isRunning else {
                // Engine died without an interruption notice — rebuild for next time.
                self.setReady(false)
                self.configure(rebuildEngine: false)
                return
            }
            self.beepPlayer.scheduleBuffer(buffer)
            if !self.beepPlayer.isPlaying { self.beepPlayer.play() }
        }
    }
}

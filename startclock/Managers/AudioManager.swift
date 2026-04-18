import AVFoundation

class AudioManager: ObservableObject {
    private let engine     = AVAudioEngine()
    private let beepPlayer = AVAudioPlayerNode()
    private let keepAlive  = AVAudioPlayerNode()
    private var isReady    = false

    init() {
        // Heavy audio-session work (setActive, engine.start) blocks for 200–500 ms.
        // Run it on a background thread so the UI appears instantly.
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            setup()
        }
    }

    private func setup() {
        engine.attach(beepPlayer)
        engine.attach(keepAlive)
        engine.connect(beepPlayer, to: engine.mainMixerNode, format: nil)
        engine.connect(keepAlive,  to: engine.mainMixerNode, format: nil)

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            startKeepAlive()
            beepPlayer.play()
            isReady = true
        } catch {
            isReady = false
        }
    }

    /// Silent looping buffer — keeps the AVAudioSession alive when screen is off / app backgrounded.
    private func startKeepAlive() {
        let fmt        = keepAlive.outputFormat(forBus: 0)
        let frameCount = AVAudioFrameCount(fmt.sampleRate) // 1 s of silence
        guard let buf  = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frameCount) else { return }
        buf.frameLength = frameCount
        keepAlive.scheduleBuffer(buf, at: nil, options: .loops)
        keepAlive.play()
    }

    func beep(frequency: Double, durationSecs: Double) {
        guard isReady else { return }

        let fmt        = beepPlayer.outputFormat(forBus: 0)
        let sampleRate = fmt.sampleRate
        let channels   = Int(fmt.channelCount)
        let frameCount = AVAudioFrameCount(sampleRate * durationSecs)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        let fadeFrames = max(1, min(Int(sampleRate * 0.005), Int(frameCount) / 4))
        for ch in 0..<channels {
            let data = buffer.floatChannelData![ch]
            for i in 0..<Int(frameCount) {
                let t       = Double(i) / sampleRate
                let sine    = Float(sin(2 * .pi * frequency * t))
                let fadeIn  = i < fadeFrames ? Float(i) / Float(fadeFrames) : 1.0
                let fadeOut = i > Int(frameCount) - fadeFrames
                                ? Float(Int(frameCount) - i) / Float(fadeFrames) : 1.0
                data[i]     = sine * fadeIn * fadeOut * 0.6
            }
        }

        beepPlayer.scheduleBuffer(buffer)
        if !beepPlayer.isPlaying { beepPlayer.play() }
    }
}

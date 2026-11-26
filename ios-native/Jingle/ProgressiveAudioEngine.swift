import AVFoundation
import Foundation
import JingleCore

/// Progressive wake playback. The session uses `.playback` and `.mixWithOthers`
/// so a Clock alarm at the same minute can sound at the same time.
final class ProgressiveAudioEngine {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var graphReady = false
    private var playback = AlarmPlaybackState.idle
    private var rampSeconds: TimeInterval = 60
    private var elapsedBeforePause: TimeInterval = 0
    private var segmentStarted: Date?
    private var volumeTimer: Timer?
    private var stopTimer: Timer?
    private var previewing = false

    /// Interruptions update playback state and leave the Live Activity alone.
    var onInterruption: ((PlaybackInterrupt) -> Void)?

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    func playAlarm(tone: WakeTone, rampSeconds: Int, alarmID: String) {
        previewing = false
        stopTimer?.invalidate()
        playback = .ringing(alarmID: alarmID)
        start(tone: tone, rampSeconds: TimeInterval(rampSeconds))
    }

    func playPreview(tone: WakeTone, rampSeconds: Int) {
        previewing = true
        playback = .idle
        let shortened = min(TimeInterval(max(rampSeconds, 1)), 8)
        start(tone: tone, rampSeconds: shortened)
        stopTimer?.invalidate()
        stopTimer = Timer.scheduledTimer(withTimeInterval: shortened + 4, repeats: false) { [weak self] _ in
            self?.stopPreview()
        }
    }

    func stopPreview() {
        guard previewing else { return }
        previewing = false
        tearDownPlayback()
    }

    func dismiss() {
        previewing = false
        playback = AlarmPlaybackReducer.reduce(playback, .dismissed)
        tearDownPlayback()
    }

    private func start(tone: WakeTone, rampSeconds: TimeInterval) {
        self.rampSeconds = rampSeconds
        elapsedBeforePause = 0
        segmentStarted = Date()
        let rate = 22_050.0
        let source = ToneSampleSource(tone: tone, sampleRate: rate, rampSeconds: 0)
        let frames = max(1, Int(source.phraseSeconds * rate))
        let samples = source.render(frames: frames)
        do {
            try configureSession()
            try install(samples: samples, sampleRate: rate)
            applyGain()
            volumeTimer?.invalidate()
            volumeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.applyGain()
            }
        } catch {
            tearDownPlayback()
        }
    }

    private func configureSession() throws {
        let configuration = AudioSessionConfiguration.alarmPlayback
        let session = AVAudioSession.sharedInstance()
        var options: AVAudioSession.CategoryOptions = []
        if configuration.mixWithOthers {
            options.insert(.mixWithOthers)
        }
        switch configuration.category {
        case .playback:
            try session.setCategory(.playback, mode: .default, options: options)
        }
        try session.setActive(true)
    }

    private func install(samples: [Float], sampleRate: Double) throws {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData else {
            return
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        for index in samples.indices {
            channel[0][index] = samples[index]
        }
        if !graphReady {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            graphReady = true
        }
        if !engine.isRunning {
            try engine.start()
        }
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .loops)
        player.play()
    }

    private func applyGain() {
        let running = segmentStarted.map { Date().timeIntervalSince($0) } ?? 0
        let elapsed = elapsedBeforePause + running
        player.volume = Float(ProgressiveRamp.gain(elapsed: elapsed, duration: rampSeconds))
    }

    private func freezeElapsed() {
        if let segmentStarted {
            elapsedBeforePause += Date().timeIntervalSince(segmentStarted)
        }
        segmentStarted = nil
    }

    private func tearDownPlayback() {
        volumeTimer?.invalidate()
        volumeTimer = nil
        stopTimer?.invalidate()
        stopTimer = nil
        segmentStarted = nil
        elapsedBeforePause = 0
        player.stop()
        engine.pause()
    }

    @objc private func handleInterruption(_ note: Notification) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.handleInterruption(note)
            }
            return
        }
        guard let info = note.userInfo,
              let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
            return
        }
        switch type {
        case .began:
            let event = PlaybackInterrupt.began
            playback = AlarmPlaybackReducer.reduce(playback, event)
            freezeElapsed()
            player.pause()
            noteInterruption(event)
        case .ended:
            let optionsRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: optionsRaw).contains(.shouldResume)
            let event = PlaybackInterrupt.ended(shouldResume: shouldResume)
            playback = AlarmPlaybackReducer.reduce(playback, event)
            noteInterruption(event)
            guard playback.audioRunning, !playback.dismissed else { return }
            try? AVAudioSession.sharedInstance().setActive(true)
            if !engine.isRunning {
                try? engine.start()
            }
            segmentStarted = Date()
            player.play()
        default:
            break
        }
    }

    /// Clock can interrupt the audio session. That must not end the Live Activity.
    private func noteInterruption(_ event: PlaybackInterrupt) {
        if LiveActivityPolicy.shouldEnd(after: event) {
            return
        }
        onInterruption?(event)
    }
}

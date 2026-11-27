import AVFoundation
import Darwin
import Foundation
import JingleCore

/// Plays a bundled wake CAF. The first pass uses the whole file. Later passes loop the
/// arrived section so the quiet opening does not return. The session mixes with Clock.
final class ProgressiveAudioEngine {
    private var players: [AVAudioPlayer] = []
    private var activeIndex = 0
    private var outgoing: AVAudioPlayer?
    private var incoming: AVAudioPlayer?
    private var crossfading = false
    private var crossfadeStarted: Date?
    private var loopStart: TimeInterval = 14
    private let crossfadeDuration: TimeInterval = 0.04

    private var playback = AlarmPlaybackState.idle
    private var rampSeconds: TimeInterval = 60
    private var elapsedBeforePause: TimeInterval = 0
    private var segmentStarted: Date?
    private var volumeTimer: Timer?
    private var stopTimer: Timer?
    private var previewing = false
    private var bedsidePlayer: AVAudioPlayer?

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
        stopBedsidePlayer()
        playback = .ringing(alarmID: alarmID)
        start(tone: tone, rampSeconds: TimeInterval(rampSeconds))
    }

    /// Holds `.playback` while Jingle is backgrounded or the phone is locked and AlarmKit
    /// is not armed. The file is inaudible. The session ignores the Ring/Silent switch,
    /// and the clock timer can then start the real tone without waiting for a tap.
    func startBedside() {
        if bedsidePlayer?.isPlaying == true { return }
        guard let url = Self.bedsideFileURL() else { return }
        do {
            try configureSession()
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 1
            player.prepareToPlay()
            player.play()
            bedsidePlayer = player
        } catch {
            bedsidePlayer = nil
        }
    }

    func stopBedside() {
        stopBedsidePlayer()
        if players.isEmpty, !previewing {
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        }
    }

    func playPreview(tone: WakeTone, rampSeconds: Int) {
        previewing = true
        playback = .idle
        let shortened = min(TimeInterval(max(rampSeconds, 1)), 8)
        start(tone: tone, rampSeconds: shortened)
        stopTimer?.invalidate()
        stopTimer = Timer.scheduledTimer(withTimeInterval: 16, repeats: false) { [weak self] _ in
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
        tearDownPlayers()
        self.rampSeconds = rampSeconds
        elapsedBeforePause = 0
        segmentStarted = Date()
        loopStart = tone.loopStart
        crossfading = false
        activeIndex = 0
        guard let url = Self.bundleURL(for: tone) else { return }
        do {
            try configureSession()
            let first = try AVAudioPlayer(contentsOf: url)
            let second = try AVAudioPlayer(contentsOf: url)
            first.prepareToPlay()
            second.prepareToPlay()
            first.numberOfLoops = 0
            second.numberOfLoops = 0
            first.currentTime = 0
            players = [first, second]
            first.volume = Float(masterGain())
            first.play()
            volumeTimer?.invalidate()
            volumeTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
                self?.tick()
            }
        } catch {
            tearDownPlayback()
        }
    }

    static func bundleURL(for tone: WakeTone) -> URL? {
        let name = tone.notificationSoundName as NSString
        return Bundle.main.url(forResource: name.deletingPathExtension, withExtension: name.pathExtension)
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

    private func tick() {
        let master = Float(masterGain())
        guard players.indices.contains(activeIndex) else { return }
        let lead = players[activeIndex]
        if !crossfading {
            lead.volume = master
            let end = lead.duration
            if end > 1, lead.isPlaying, lead.currentTime >= end - crossfadeDuration {
                beginBodyLoop(from: lead, master: master)
            }
        } else if let outgoing, let incoming {
            let elapsed = Date().timeIntervalSince(crossfadeStarted ?? Date())
            let t = min(1, elapsed / crossfadeDuration)
            outgoing.volume = Float(cos(t * .pi / 2)) * master
            incoming.volume = Float(sin(t * .pi / 2)) * master
            if t >= 1 {
                outgoing.stop()
                incoming.volume = master
                if let index = players.firstIndex(where: { $0 === incoming }) {
                    activeIndex = index
                }
                self.outgoing = nil
                self.incoming = nil
                crossfading = false
            }
        }
    }

    /// After the opening rise, keep the arrived body going instead of returning to the start.
    private func beginBodyLoop(from lead: AVAudioPlayer, master: Float) {
        let next = activeIndex == 0 ? 1 : 0
        guard players.indices.contains(next) else { return }
        let follow = players[next]
        let start = min(loopStart, max(0, follow.duration - 1))
        follow.currentTime = start
        follow.volume = 0
        follow.play()
        outgoing = lead
        incoming = follow
        crossfading = true
        crossfadeStarted = Date()
    }

    private func masterGain() -> Double {
        let running = segmentStarted.map { Date().timeIntervalSince($0) } ?? 0
        return WakePlaybackGain.level(elapsed: elapsedBeforePause + running, rampSeconds: rampSeconds)
    }

    private func freezeElapsed() {
        if let segmentStarted {
            elapsedBeforePause += Date().timeIntervalSince(segmentStarted)
        }
        segmentStarted = nil
    }

    private func stopBedsidePlayer() {
        bedsidePlayer?.stop()
        bedsidePlayer = nil
    }

    /// One second of mono little-endian PCM at amplitude 1. It keeps the playback
    /// session alive and stays below what a person can hear.
    private static func bedsideFileURL() -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("jingle-bedside.caf")
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        let frames = 8_000
        var pcm = Data(capacity: frames * 2)
        for index in 0..<frames {
            let sample: Int16 = (index % 40 < 20) ? 1 : -1
            let bits = UInt16(bitPattern: sample)
            pcm.append(UInt8(bits & 0xFF))
            pcm.append(UInt8(bits >> 8))
        }
        var file = Data()
        func append(_ bytes: [UInt8]) { file.append(contentsOf: bytes) }
        func appendUInt32(_ value: UInt32) {
            append([
                UInt8((value >> 24) & 0xFF),
                UInt8((value >> 16) & 0xFF),
                UInt8((value >> 8) & 0xFF),
                UInt8(value & 0xFF),
            ])
        }
        func appendUInt64(_ value: UInt64) {
            append([
                UInt8((value >> 56) & 0xFF),
                UInt8((value >> 48) & 0xFF),
                UInt8((value >> 40) & 0xFF),
                UInt8((value >> 32) & 0xFF),
                UInt8((value >> 24) & 0xFF),
                UInt8((value >> 16) & 0xFF),
                UInt8((value >> 8) & 0xFF),
                UInt8(value & 0xFF),
            ])
        }
        append([0x63, 0x61, 0x66, 0x66])
        append([0x00, 0x01, 0x00, 0x00])
        append([0x64, 0x65, 0x73, 0x63])
        appendUInt64(32)
        var rate = 8_000.0
        append(withUnsafeBytes(of: &rate) { Array($0.reversed()) })
        appendUInt32(0x6C70_636D)
        appendUInt32(0x2)
        appendUInt32(2)
        appendUInt32(1)
        appendUInt32(1)
        appendUInt32(16)
        append([0x64, 0x61, 0x74, 0x61])
        appendUInt64(UInt64(4 + pcm.count))
        appendUInt32(0)
        file.append(pcm)
        do {
            try file.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private func tearDownPlayers() {
        volumeTimer?.invalidate()
        volumeTimer = nil
        players.forEach { $0.stop() }
        players = []
        outgoing = nil
        incoming = nil
        crossfading = false
    }

    private func tearDownPlayback() {
        stopTimer?.invalidate()
        stopTimer = nil
        segmentStarted = nil
        elapsedBeforePause = 0
        stopBedsidePlayer()
        tearDownPlayers()
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
            players.forEach { $0.pause() }
            bedsidePlayer?.pause()
            noteInterruption(event)
        case .ended:
            let optionsRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: optionsRaw).contains(.shouldResume)
            let event = PlaybackInterrupt.ended(shouldResume: shouldResume)
            playback = AlarmPlaybackReducer.reduce(playback, event)
            noteInterruption(event)
            if bedsidePlayer != nil {
                try? AVAudioSession.sharedInstance().setActive(true)
                bedsidePlayer?.play()
            }
            guard playback.audioRunning, !playback.dismissed else { return }
            try? AVAudioSession.sharedInstance().setActive(true)
            segmentStarted = Date()
            if let incoming, crossfading {
                incoming.play()
            }
            if let outgoing, crossfading {
                outgoing.play()
            } else if players.indices.contains(activeIndex) {
                players[activeIndex].play()
            }
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

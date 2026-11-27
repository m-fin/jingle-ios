import Foundation

/// Playback session that can pause for another app (such as Clock) without dropping the wake.
public struct AlarmPlaybackState: Equatable, Sendable {
    public var alarmID: String?
    public var dismissed: Bool
    public var audioRunning: Bool
    public var interrupted: Bool
    public var liveActivityActive: Bool

    public init(
        alarmID: String?,
        dismissed: Bool,
        audioRunning: Bool,
        interrupted: Bool,
        liveActivityActive: Bool
    ) {
        self.alarmID = alarmID
        self.dismissed = dismissed
        self.audioRunning = audioRunning
        self.interrupted = interrupted
        self.liveActivityActive = liveActivityActive
    }

    public static func ringing(alarmID: String) -> AlarmPlaybackState {
        AlarmPlaybackState(
            alarmID: alarmID,
            dismissed: false,
            audioRunning: true,
            interrupted: false,
            liveActivityActive: true
        )
    }

    public static let idle = AlarmPlaybackState(
        alarmID: nil,
        dismissed: false,
        audioRunning: false,
        interrupted: false,
        liveActivityActive: false
    )
}

public enum PlaybackInterrupt: Equatable, Sendable {
    case began
    case ended(shouldResume: Bool)
    case dismissed
}

public enum AlarmPlaybackReducer {
    public static func reduce(_ state: AlarmPlaybackState, _ event: PlaybackInterrupt) -> AlarmPlaybackState {
        var state = state
        switch event {
        case .began:
            guard state.alarmID != nil, !state.dismissed else { return state }
            state.audioRunning = false
            state.interrupted = true
        case .ended:
            guard state.alarmID != nil, !state.dismissed else { return state }
            state.audioRunning = true
            state.interrupted = false
        case .dismissed:
            state.dismissed = true
            state.audioRunning = false
            state.interrupted = false
            state.liveActivityActive = false
        }
        return state
    }
}

public enum LiveActivityPolicy {
    /// An audio interruption never ends the Live Activity. Dismissal does.
    public static func shouldEnd(after event: PlaybackInterrupt) -> Bool {
        if case .dismissed = event { return true }
        return false
    }
}

public enum AudioSessionCategory: String, Equatable, Sendable {
    case playback
}

public struct AudioSessionConfiguration: Equatable, Sendable {
    public var category: AudioSessionCategory
    public var mixWithOthers: Bool

    public init(category: AudioSessionCategory, mixWithOthers: Bool) {
        self.category = category
        self.mixWithOthers = mixWithOthers
    }

    /// Playback continues under the Ring/Silent switch once the session is active,
    /// and mixes so a Clock alarm at the same minute can play too.
    public static let alarmPlayback = AudioSessionConfiguration(category: .playback, mixWithOthers: true)
}

public enum BackgroundAudioMode {
    public static let mode = "audio"
}

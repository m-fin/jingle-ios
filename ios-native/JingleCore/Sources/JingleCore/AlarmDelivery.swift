import Foundation

public enum NotificationAuthorizationOption: String, Equatable, CaseIterable, Sendable {
    case alert
    case sound
    case badge
    case timeSensitive
}

/// Options passed to `UNUserNotificationCenter.requestAuthorization`.
/// Sound is required for the alert tone. Time Sensitive is required for the
/// interruption level already set on every alarm notification.
public enum NotificationAuthorizationRequest {
    public static let options: [NotificationAuthorizationOption] = [.alert, .sound, .badge, .timeSensitive]
}

extension ForegroundPresentation {
    /// Names match `UNNotificationPresentationOptions` for an alarm delivered while Jingle is open.
    public var optionNames: [String] {
        var names: [String] = []
        if showsBanner { names.append("banner") }
        if showsList { names.append("list") }
        if playsSound { names.append("sound") }
        return names
    }
}

/// Where the phone is when the alarm instant arrives.
public enum PhoneAlarmSurface: String, Equatable, Sendable {
    /// Jingle is the frontmost app.
    case foreground
    /// Jingle is still executing, but another app or the Home Screen is in front.
    case background
    /// The display is locked. Jingle may still be executing a bedside session.
    case locked
    /// The phone is unlocked and Jingle is not the frontmost app.
    case unlocked
}

/// What Jingle does at the alarm instant when its process can run.
public struct AlarmFireAction: Equatable, Sendable {
    public var startPlayback: Bool
    public var session: AudioSessionConfiguration
    public var ignoresHardwareSilentSwitch: Bool
    public var showRingingScreen: Bool
    public var presentationOptionNames: [String]

    public init(
        startPlayback: Bool,
        session: AudioSessionConfiguration,
        ignoresHardwareSilentSwitch: Bool,
        showRingingScreen: Bool,
        presentationOptionNames: [String]
    ) {
        self.startPlayback = startPlayback
        self.session = session
        self.ignoresHardwareSilentSwitch = ignoresHardwareSilentSwitch
        self.showRingingScreen = showRingingScreen
        self.presentationOptionNames = presentationOptionNames
    }
}

public enum AlarmFireTrigger {
    /// In-app playback uses `.playback`, which ignores the Ring/Silent switch.
    /// A suspended process cannot start that session; the armed route (AlarmKit or
    /// the notification tone) has to carry the sound instead.
    public static func action(on surface: PhoneAlarmSurface, processIsRunning: Bool) -> AlarmFireAction {
        let playback = AudioSessionConfiguration.alarmPlayback
        let start = processIsRunning
        return AlarmFireAction(
            startPlayback: start,
            session: playback,
            ignoresHardwareSilentSwitch: start && playback.category == .playback,
            showRingingScreen: start && surface != .locked,
            presentationOptionNames: ForegroundPresentation.alarm.optionNames
        )
    }
}

public enum AlarmSoundRoute: Equatable, Sendable {
    /// AlarmKit plays the tone and breaks through silent mode, Focus, and the lock screen.
    case systemAlarm
    /// A local notification carries the tone. The Ring/Silent switch can mute that tone.
    case localNotification
}

public struct AlarmArmingPlan: Equatable, Sendable {
    public var route: AlarmSoundRoute
    /// `nil` means "do not schedule a local notification". A silent notification with no
    /// system alarm is the failure we are fixing, so this is never a sounding-off banner
    /// standing in for the alarm.
    public var notificationSound: NotificationSoundChoice?
    /// Keep an inaudible `.playback` session so a locked or backgrounded phone can still
    /// start the wake tone when AlarmKit is not available.
    public var holdBedsidePlayback: Bool
    public var breaksThroughSilentSwitchWhenSuspended: Bool

    public init(
        route: AlarmSoundRoute,
        notificationSound: NotificationSoundChoice?,
        holdBedsidePlayback: Bool,
        breaksThroughSilentSwitchWhenSuspended: Bool
    ) {
        self.route = route
        self.notificationSound = notificationSound
        self.holdBedsidePlayback = holdBedsidePlayback
        self.breaksThroughSilentSwitchWhenSuspended = breaksThroughSilentSwitchWhenSuspended
    }
}

public enum AlarmArmingPolicy {
    public static func plan(
        alarmKitAuthorized: Bool,
        resolvedSound: NotificationSoundChoice
    ) -> AlarmArmingPlan {
        if alarmKitAuthorized {
            return AlarmArmingPlan(
                route: .systemAlarm,
                notificationSound: nil,
                holdBedsidePlayback: false,
                breaksThroughSilentSwitchWhenSuspended: true
            )
        }
        return AlarmArmingPlan(
            route: .localNotification,
            notificationSound: resolvedSound,
            holdBedsidePlayback: true,
            breaksThroughSilentSwitchWhenSuspended: false
        )
    }
}

public enum BedsideSessionPolicy {
    /// Hold the playback session only while an alarm is armed, Jingle is not already
    /// ringing, AlarmKit is not covering the silent switch, and the scene is not active.
    /// An active scene already runs the one-second clock.
    public static func shouldHold(
        alarmKitAuthorized: Bool,
        hasEnabledAlarm: Bool,
        isRinging: Bool,
        sceneIsActive: Bool
    ) -> Bool {
        hasEnabledAlarm && !isRinging && !alarmKitAuthorized && !sceneIsActive
    }
}

public enum SilentSwitchGuidance {
    public static func footnote(alarmKit: AlarmKitAuthorization) -> String {
        switch alarmKit {
        case .authorized:
            return "Alarms ring with the phone locked, with Jingle in the background, and with the Ring/Silent switch on silent."
        case .unavailable, .notDetermined, .denied:
            return "With the Ring/Silent switch on silent, leave Jingle open so bedside playback can ring. Set the switch to Ring if you lock the phone after force-quitting Jingle."
        }
    }
}

public struct SystemAlarmDraft: Equatable, Sendable {
    public var alarmID: String
    public var systemID: UUID
    public var title: String
    public var hour: Int
    public var minute: Int
    /// Empty means the next occurrence once. Otherwise a weekly AlarmKit schedule.
    public var weekdays: [Weekday]
    public var soundFileName: String

    public init(
        alarmID: String,
        systemID: UUID,
        title: String,
        hour: Int,
        minute: Int,
        weekdays: [Weekday],
        soundFileName: String
    ) {
        self.alarmID = alarmID
        self.systemID = systemID
        self.title = title
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
        self.soundFileName = soundFileName
    }
}

public enum AlarmSystemIdentifier {
    /// Stable across launches so a reschedule cancels the same AlarmKit alarm.
    public static func uuid(for alarmID: String) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        var state: UInt32 = 2_166_136_261
        for (index, byte) in alarmID.utf8.enumerated() {
            state ^= UInt32(byte)
            state &*= 16_777_619
            bytes[index % 16] ^= byte
            bytes[(index * 3) % 16] ^= UInt8(truncatingIfNeeded: state >> UInt32((index % 4) * 8))
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        let formatted = "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20))"
        return UUID(uuidString: formatted) ?? UUID()
    }
}

public enum SystemAlarmPlanner {
    /// One AlarmKit alarm per enabled Jingle alarm. One-shots use the resolved clock
    /// time, including the hour a daylight-saving gap moves.
    public static func drafts(
        for alarms: [Alarm],
        now: Date,
        calendar: Calendar = .current
    ) -> [SystemAlarmDraft] {
        alarms.compactMap { draft(for: $0, now: now, calendar: calendar) }
    }

    private static func draft(
        for alarm: Alarm,
        now: Date,
        calendar: Calendar
    ) -> SystemAlarmDraft? {
        let alarm = alarm.normalized()
        guard alarm.enabled else { return nil }
        let hour: Int
        let minute: Int
        let days: [Weekday]
        if alarm.repeatWeekdays.isEmpty {
            guard let fire = AlarmScheduleCalculator.nextFireDate(for: alarm, now: now, calendar: calendar) else {
                return nil
            }
            let parts = calendar.dateComponents([.hour, .minute], from: fire)
            hour = parts.hour ?? alarm.hour
            minute = parts.minute ?? alarm.minute
            days = []
        } else {
            hour = alarm.hour
            minute = alarm.minute
            days = alarm.repeatWeekdays.sorted { $0.rawValue < $1.rawValue }
        }
        return SystemAlarmDraft(
            alarmID: alarm.id,
            systemID: AlarmSystemIdentifier.uuid(for: alarm.id),
            title: alarm.label,
            hour: hour,
            minute: minute,
            weekdays: days,
            soundFileName: alarm.tone.notificationSoundName
        )
    }
}

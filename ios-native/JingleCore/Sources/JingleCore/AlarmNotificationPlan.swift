import Foundation

public enum NotificationInterruptionLevel: String, Equatable, Sendable {
    case timeSensitive
}

public struct PlannedNotificationAction: Equatable, Sendable {
    public var identifier: String
    public var title: String

    public init(identifier: String, title: String) {
        self.identifier = identifier
        self.title = title
    }
}

public struct ForegroundPresentation: Equatable, Sendable {
    public var showsBanner: Bool
    public var showsList: Bool
    public var playsSound: Bool

    /// Banner and list together are the replacement for the deprecated `.alert` option.
    public var includesAlert: Bool { showsBanner || showsList }
    public var includesSound: Bool { playsSound }

    public init(showsBanner: Bool, showsList: Bool, playsSound: Bool) {
        self.showsBanner = showsBanner
        self.showsList = showsList
        self.playsSound = playsSound
    }

    public static let alarm = ForegroundPresentation(showsBanner: true, showsList: true, playsSound: true)
}

public struct PlannedNotification: Equatable, Sendable {
    public var identifier: String
    public var alarmID: String
    public var title: String
    public var body: String
    public var soundName: String
    public var hour: Int
    public var minute: Int
    public var weekday: Weekday?
    public var fireDate: Date?
    public var repeats: Bool
    public var interruptionLevel: NotificationInterruptionLevel
    public var categoryIdentifier: String

    public init(
        identifier: String,
        alarmID: String,
        title: String,
        body: String,
        soundName: String,
        hour: Int,
        minute: Int,
        weekday: Weekday?,
        fireDate: Date?,
        repeats: Bool,
        interruptionLevel: NotificationInterruptionLevel,
        categoryIdentifier: String
    ) {
        self.identifier = identifier
        self.alarmID = alarmID
        self.title = title
        self.body = body
        self.soundName = soundName
        self.hour = hour
        self.minute = minute
        self.weekday = weekday
        self.fireDate = fireDate
        self.repeats = repeats
        self.interruptionLevel = interruptionLevel
        self.categoryIdentifier = categoryIdentifier
    }
}

public enum AlarmNotificationIdentity {
    public static let prefix = "jingle.alarm."
    public static let categoryIdentifier = "jingle.alarm"
    public static let dismissActionIdentifier = "jingle.dismiss"

    /// `jingle.alarm.<uuid>`, plus `.w<weekday>` when a repeating alarm needs one request per day.
    public static func make(alarmID: String, weekday: Weekday? = nil) -> String {
        if let weekday {
            return "\(prefix)\(alarmID).w\(weekday.rawValue)"
        }
        return "\(prefix)\(alarmID)"
    }

    public static func alarmID(from identifier: String) -> String? {
        guard identifier.hasPrefix(prefix) else { return nil }
        let rest = identifier.dropFirst(prefix.count)
        if rest.count >= 3 {
            let tail = rest.suffix(3)
            if tail.first == ".", tail.dropFirst().first == "w", let digit = tail.last, let value = Int(String(digit)), (1...7).contains(value) {
                let id = rest.dropLast(3)
                return id.isEmpty ? nil : String(id)
            }
        }
        return rest.isEmpty ? nil : String(rest)
    }
}

public enum AlarmNotificationPlanner {
    public static let dismissAction = PlannedNotificationAction(
        identifier: AlarmNotificationIdentity.dismissActionIdentifier,
        title: "Dismiss"
    )
    public static let actions: [PlannedNotificationAction] = [dismissAction]
    public static let foregroundPresentation = ForegroundPresentation.alarm

    public static func requests(
        for alarms: [Alarm],
        now: Date,
        calendar: Calendar = .current
    ) -> [PlannedNotification] {
        alarms.flatMap { requests(for: $0, now: now, calendar: calendar) }
    }

    public static func requests(
        for alarm: Alarm,
        now: Date,
        calendar: Calendar = .current
    ) -> [PlannedNotification] {
        let alarm = alarm.normalized()
        guard alarm.enabled else { return [] }
        if alarm.repeatWeekdays.isEmpty {
            guard let fire = AlarmScheduleCalculator.nextFireDate(for: alarm, now: now, calendar: calendar) else {
                return []
            }
            let parts = calendar.dateComponents([.hour, .minute], from: fire)
            return [make(
                alarm,
                hour: parts.hour ?? alarm.hour,
                minute: parts.minute ?? alarm.minute,
                weekday: nil,
                fireDate: fire,
                repeats: false
            )]
        }
        if alarm.repeatWeekdays.count == Weekday.allCases.count {
            return [make(alarm, hour: alarm.hour, minute: alarm.minute, weekday: nil, fireDate: nil, repeats: true)]
        }
        return alarm.repeatWeekdays.sorted { $0.rawValue < $1.rawValue }.map { weekday in
            make(alarm, hour: alarm.hour, minute: alarm.minute, weekday: weekday, fireDate: nil, repeats: true)
        }
    }

    private static func make(
        _ alarm: Alarm,
        hour: Int,
        minute: Int,
        weekday: Weekday?,
        fireDate: Date?,
        repeats: Bool
    ) -> PlannedNotification {
        PlannedNotification(
            identifier: AlarmNotificationIdentity.make(alarmID: alarm.id, weekday: weekday),
            alarmID: alarm.id,
            title: alarm.label,
            body: "Time to get up.",
            soundName: alarm.tone.notificationSoundName,
            hour: hour,
            minute: minute,
            weekday: weekday,
            fireDate: fireDate,
            repeats: repeats,
            interruptionLevel: .timeSensitive,
            categoryIdentifier: AlarmNotificationIdentity.categoryIdentifier
        )
    }
}

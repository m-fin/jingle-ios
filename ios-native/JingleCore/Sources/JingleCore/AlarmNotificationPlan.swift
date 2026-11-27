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
    public var includesAlert: Bool
    public var includesSound: Bool

    public static let alarm = ForegroundPresentation(includesAlert: true, includesSound: true)
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
    public var purpose: NotificationPurpose

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
        categoryIdentifier: String,
        purpose: NotificationPurpose = .alarm
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
        self.purpose = purpose
    }
}

public enum AlarmNotificationIdentity {
    public static let prefix = "jingle.alarm."
    public static let machinePrefix = "jingle.machine."
    public static let categoryIdentifier = "jingle.alarm"
    public static let dismissActionIdentifier = "jingle.dismiss"

    /// `jingle.alarm.<uuid>`, plus `.w<weekday>` when a repeating alarm needs one request per day.
    public static func make(alarmID: String, weekday: Weekday? = nil, purpose: NotificationPurpose = .alarm) -> String {
        let head = purpose == .machine ? machinePrefix : prefix
        if let weekday {
            return "\(head)\(alarmID).w\(weekday.rawValue)"
        }
        return "\(head)\(alarmID)"
    }

    public static func purpose(from identifier: String) -> NotificationPurpose? {
        if identifier.hasPrefix(machinePrefix) { return .machine }
        if identifier.hasPrefix(prefix) { return .alarm }
        return nil
    }

    public static func alarmID(from identifier: String) -> String? {
        let rest: Substring
        if identifier.hasPrefix(machinePrefix) {
            rest = identifier.dropFirst(machinePrefix.count)
        } else if identifier.hasPrefix(prefix) {
            rest = identifier.dropFirst(prefix.count)
        } else {
            return nil
        }
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
    public static let machineForegroundPresentation = ForegroundPresentation(includesAlert: true, includesSound: false)
    /// iOS keeps at most 64 pending local notifications. Prefer the wake over machine mode.
    public static let budget = 56

    public static func requests(
        for alarms: [Alarm],
        now: Date,
        calendar: Calendar = .current
    ) -> [PlannedNotification] {
        let planned = alarms.flatMap { requests(for: $0, now: now, calendar: calendar) }
        return fit(planned, to: budget)
    }

    public static func requests(
        for alarm: Alarm,
        now: Date,
        calendar: Calendar = .current
    ) -> [PlannedNotification] {
        alarmRequests(for: alarm, now: now, calendar: calendar)
            + machineRequests(for: alarm, now: now, calendar: calendar)
    }

    public static func fit(_ planned: [PlannedNotification], to budget: Int) -> [PlannedNotification] {
        let alarms = planned.filter { $0.purpose == .alarm }
        let machines = planned.filter { $0.purpose == .machine }
        if alarms.count >= budget { return Array(alarms.prefix(budget)) }
        return alarms + Array(machines.prefix(budget - alarms.count))
    }

    private static func alarmRequests(
        for alarm: Alarm,
        now: Date,
        calendar: Calendar
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
                purpose: .alarm,
                hour: parts.hour ?? alarm.hour,
                minute: parts.minute ?? alarm.minute,
                weekday: nil,
                fireDate: fire,
                repeats: false
            )]
        }
        if alarm.repeatWeekdays.count == Weekday.allCases.count {
            return [make(alarm, purpose: .alarm, hour: alarm.hour, minute: alarm.minute, weekday: nil, fireDate: nil, repeats: true)]
        }
        return alarm.repeatWeekdays.sorted { $0.rawValue < $1.rawValue }.map { weekday in
            make(alarm, purpose: .alarm, hour: alarm.hour, minute: alarm.minute, weekday: weekday, fireDate: nil, repeats: true)
        }
    }

    private static func machineRequests(
        for alarm: Alarm,
        now: Date,
        calendar: Calendar
    ) -> [PlannedNotification] {
        let alarm = alarm.normalized()
        guard alarm.enabled, alarm.machineLeadMinutes > 0 else { return [] }
        if alarm.repeatWeekdays.isEmpty {
            guard let fire = AlarmScheduleCalculator.nextFireDate(for: alarm, now: now, calendar: calendar),
                  let start = MachineMode.leadDate(fireDate: fire, leadMinutes: alarm.machineLeadMinutes),
                  start > now.addingTimeInterval(1) else {
                return []
            }
            let parts = calendar.dateComponents([.hour, .minute], from: start)
            return [make(
                alarm,
                purpose: .machine,
                hour: parts.hour ?? 0,
                minute: parts.minute ?? 0,
                weekday: nil,
                fireDate: start,
                repeats: false
            )]
        }
        guard let slot = MachineMode.weeklySlot(
            hour: alarm.hour,
            minute: alarm.minute,
            leadMinutes: alarm.machineLeadMinutes,
            days: alarm.repeatWeekdays
        ) else {
            return []
        }
        if slot.days.count == Weekday.allCases.count {
            return [make(alarm, purpose: .machine, hour: slot.hour, minute: slot.minute, weekday: nil, fireDate: nil, repeats: true)]
        }
        return slot.days.sorted { $0.rawValue < $1.rawValue }.map { weekday in
            make(alarm, purpose: .machine, hour: slot.hour, minute: slot.minute, weekday: weekday, fireDate: nil, repeats: true)
        }
    }

    private static func make(
        _ alarm: Alarm,
        purpose: NotificationPurpose,
        hour: Int,
        minute: Int,
        weekday: Weekday?,
        fireDate: Date?,
        repeats: Bool
    ) -> PlannedNotification {
        let isMachine = purpose == .machine
        return PlannedNotification(
            identifier: AlarmNotificationIdentity.make(alarmID: alarm.id, weekday: weekday, purpose: purpose),
            alarmID: alarm.id,
            title: alarm.label,
            body: isMachine ? "Soft start before \(alarm.label)." : "Time to get up.",
            soundName: isMachine ? MachineMode.soundFileName : alarm.tone.notificationSoundName,
            hour: hour,
            minute: minute,
            weekday: weekday,
            fireDate: fireDate,
            repeats: repeats,
            interruptionLevel: .timeSensitive,
            categoryIdentifier: AlarmNotificationIdentity.categoryIdentifier,
            purpose: purpose
        )
    }
}

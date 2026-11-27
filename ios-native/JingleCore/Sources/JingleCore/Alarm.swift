import Foundation

public struct Alarm: Codable, Equatable, Identifiable, Sendable, Hashable {
    public var id: String
    public var hour: Int
    public var minute: Int
    public var label: String
    public var enabled: Bool
    /// Empty means the alarm rings once, then turns off.
    public var repeatWeekdays: Set<Weekday>
    public var tone: WakeTone
    public var progressiveRampSeconds: Int

    public init(
        id: String,
        hour: Int,
        minute: Int,
        label: String,
        enabled: Bool,
        repeatWeekdays: Set<Weekday>,
        tone: WakeTone,
        progressiveRampSeconds: Int
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.label = label
        self.enabled = enabled
        self.repeatWeekdays = repeatWeekdays
        self.tone = tone
        self.progressiveRampSeconds = progressiveRampSeconds
    }

    public static func weekdayMorning() -> Alarm {
        Alarm(
            id: "weekday-morning",
            hour: 6,
            minute: 0,
            label: "Morning",
            enabled: true,
            repeatWeekdays: Weekday.weekdays,
            tone: .pocketOfBells,
            progressiveRampSeconds: 60
        )
    }

    public func normalized() -> Alarm {
        var copy = self
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.label = String((trimmed.isEmpty ? "Alarm" : trimmed).prefix(40))
        copy.hour = min(23, max(0, hour))
        copy.minute = min(59, max(0, minute))
        copy.progressiveRampSeconds = min(600, max(0, progressiveRampSeconds))
        copy.id = String(id.prefix(80))
        return copy
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let clean = normalized()
        try container.encode(clean.id, forKey: .id)
        try container.encode(clean.hour, forKey: .hour)
        try container.encode(clean.minute, forKey: .minute)
        try container.encode(clean.label, forKey: .label)
        try container.encode(clean.enabled, forKey: .enabled)
        try container.encode(clean.repeatWeekdays.map(\.rawValue).sorted(), forKey: .repeatWeekdays)
        try container.encode(clean.tone, forKey: .tone)
        try container.encode(clean.progressiveRampSeconds, forKey: .progressiveRampSeconds)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let hour = try container.decode(Int.self, forKey: .hour)
        let minute = try container.decode(Int.self, forKey: .minute)
        let label = try container.decodeIfPresent(String.self, forKey: .label) ?? "Alarm"
        let enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        let rawDays = try container.decodeIfPresent([Int].self, forKey: .repeatWeekdays) ?? []
        let days = Set(rawDays.compactMap(Weekday.init(rawValue:)))
        let tone = try container.decodeIfPresent(WakeTone.self, forKey: .tone) ?? .pocketOfBells
        let ramp = try container.decodeIfPresent(Int.self, forKey: .progressiveRampSeconds) ?? 60
        self.init(
            id: id,
            hour: hour,
            minute: minute,
            label: label,
            enabled: enabled,
            repeatWeekdays: days,
            tone: tone,
            progressiveRampSeconds: ramp
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id, hour, minute, label, enabled, repeatWeekdays, tone, progressiveRampSeconds
    }
}

public enum AlarmFiring {
    /// A one-shot alarm turns off after it is dismissed. A repeating alarm stays armed.
    public static func dismissed(_ alarm: Alarm) -> Alarm {
        guard alarm.repeatWeekdays.isEmpty else { return alarm }
        var copy = alarm
        copy.enabled = false
        return copy
    }
}

import Foundation

public struct AlarmDismissal: Codable, Equatable, Sendable {
    public var alarmID: String
    public var at: Date

    public init(alarmID: String, at: Date) {
        self.alarmID = alarmID
        self.at = at
    }
}

public struct AlarmLibrary: Codable, Equatable, Sendable {
    public static let maximumAlarms = 8
    public static let storageVersion = 1

    public var version: Int
    public var seeded: Bool
    public var alarms: [Alarm]
    public var dismissal: AlarmDismissal?

    public init(version: Int = AlarmLibrary.storageVersion, seeded: Bool, alarms: [Alarm], dismissal: AlarmDismissal? = nil) {
        self.version = version
        self.seeded = seeded
        self.alarms = alarms
        self.dismissal = dismissal
    }

    public static let empty = AlarmLibrary(seeded: false, alarms: [])

    public func sortedForDisplay() -> [Alarm] {
        alarms.sorted {
            ($0.hour * 60 + $0.minute, $0.label, $0.id) < ($1.hour * 60 + $1.minute, $1.label, $1.id)
        }
    }

    public mutating func upsert(_ alarm: Alarm) -> Bool {
        let clean = alarm.normalized()
        guard !clean.id.isEmpty else { return false }
        if let index = alarms.firstIndex(where: { $0.id == clean.id }) {
            alarms[index] = clean
            return true
        }
        guard alarms.count < Self.maximumAlarms else { return false }
        alarms.append(clean)
        return true
    }

    public mutating func recordDismissal(alarmID: String, at: Date) {
        if let index = alarms.firstIndex(where: { $0.id == alarmID }) {
            alarms[index] = AlarmFiring.dismissed(alarms[index])
        }
        dismissal = AlarmDismissal(alarmID: alarmID, at: at)
    }
}

public enum AlarmLibrarySeeder {
    public static func seedIfNeeded(_ library: AlarmLibrary) -> AlarmLibrary {
        guard !library.seeded, library.alarms.isEmpty else {
            var copy = library
            copy.seeded = true
            return copy
        }
        return AlarmLibrary(seeded: true, alarms: [Alarm.weekdayMorning()])
    }
}

public protocol KeyValueStoring: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ value: Any?, forKey defaultName: String)
}

extension UserDefaults: KeyValueStoring {}

public enum AlarmLibraryEvents {
    public static let changedNotification = "app.jingle.ios.library-changed"
}

/// App Group persistence shared by the app and the widget extension.
public final class AlarmStore {
    public static let appGroupIdentifier = "group.app.jingle.ios"
    public static let storageKey = "jingle.library.v1"

    private let store: KeyValueStoring
    private let key: String

    public init(store: KeyValueStoring, key: String = AlarmStore.storageKey) {
        self.store = store
        self.key = key
    }

    public static func appGroup() -> AlarmStore {
        let defaults = UserDefaults(suiteName: appGroupIdentifier) ?? .standard
        return AlarmStore(store: defaults)
    }

    public func load() -> AlarmLibrary {
        guard let data = store.data(forKey: key) else { return .empty }
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return .empty }
        guard (raw["version"] as? Int) == AlarmLibrary.storageVersion else { return .empty }
        let seeded = (raw["seeded"] as? Bool) == true
        let rows = raw["alarms"] as? [Any] ?? []
        var alarms: [Alarm] = []
        for row in rows {
            if let alarm = Self.alarm(from: row) {
                alarms.append(alarm)
            }
            if alarms.count == AlarmLibrary.maximumAlarms { break }
        }
        var dismissal: AlarmDismissal?
        if let payload = raw["dismissal"] as? [String: Any],
           let alarmID = payload["alarmID"] as? String,
           !alarmID.isEmpty {
            let at = Self.date(from: payload["at"])
            if let at {
                dismissal = AlarmDismissal(alarmID: alarmID, at: at)
            }
        }
        return AlarmLibrary(seeded: seeded, alarms: alarms, dismissal: dismissal)
    }

    public func save(_ library: AlarmLibrary) {
        let kept = Array(library.alarms.prefix(AlarmLibrary.maximumAlarms)).map { $0.normalized() }
        var raw: [String: Any] = [
            "version": AlarmLibrary.storageVersion,
            "seeded": library.seeded,
            "alarms": kept.map(Self.dictionary(from:)),
        ]
        if let dismissal = library.dismissal {
            raw["dismissal"] = [
                "alarmID": dismissal.alarmID,
                "at": dismissal.at.timeIntervalSince1970,
            ]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: raw, options: [.sortedKeys]) else { return }
        store.set(data, forKey: key)
    }

    private static func dictionary(from alarm: Alarm) -> [String: Any] {
        [
            "id": alarm.id,
            "hour": alarm.hour,
            "minute": alarm.minute,
            "label": alarm.label,
            "enabled": alarm.enabled,
            "repeatWeekdays": alarm.repeatWeekdays.map(\.rawValue).sorted(),
            "tone": alarm.tone.rawValue,
            "progressiveRampSeconds": alarm.progressiveRampSeconds,
        ]
    }

    private static func alarm(from value: Any) -> Alarm? {
        guard let row = value as? [String: Any] else { return nil }
        guard let id = row["id"] as? String, !id.isEmpty, id.count <= 80 else { return nil }
        guard let hour = row["hour"] as? Int, (0...23).contains(hour) else { return nil }
        guard let minute = row["minute"] as? Int, (0...59).contains(minute) else { return nil }
        let label = row["label"] as? String
        let enabled = row["enabled"] as? Bool ?? true
        let days = (row["repeatWeekdays"] as? [Int] ?? []).compactMap(Weekday.init(rawValue:))
        let tone = WakeTone(rawValue: (row["tone"] as? String) ?? "") ?? .jingleBells
        let ramp = row["progressiveRampSeconds"] as? Int ?? 60
        return Alarm(
            id: id,
            hour: hour,
            minute: minute,
            label: label ?? "Alarm",
            enabled: enabled,
            repeatWeekdays: Set(days),
            tone: tone,
            progressiveRampSeconds: ramp
        ).normalized()
    }

    private static func date(from value: Any?) -> Date? {
        if let seconds = value as? Double {
            return Date(timeIntervalSince1970: seconds)
        }
        if let seconds = value as? Int {
            return Date(timeIntervalSince1970: Double(seconds))
        }
        return nil
    }
}

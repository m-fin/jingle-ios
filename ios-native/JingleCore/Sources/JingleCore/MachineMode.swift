import Foundation

/// Gentle pre-wake drone, separate from the wake tone. Lead of 0 means off.
public enum MachineMode {
    public static let allowedLeadMinutes = [0, 10, 20]
    public static let soundFileName = "machine-mode.caf"
    public static let duration: TimeInterval = 16
    public static let loopStart: TimeInterval = 0
    public static let playbackVolume: Double = 0.45
    public static let fadeOutSeconds: TimeInterval = 4
    public static let displayName = "Machine"
    public static let detail = "Quiet drone before the alarm"

    public static func normalizedLead(_ value: Int) -> Int {
        allowedLeadMinutes.contains(value) ? value : 0
    }

    public static func leadDate(fireDate: Date, leadMinutes: Int) -> Date? {
        let lead = normalizedLead(leadMinutes)
        guard lead > 0 else { return nil }
        return fireDate.addingTimeInterval(-TimeInterval(lead * 60))
    }

    /// Clock time for a repeating machine-mode start, shifting weekdays if the lead crosses midnight.
    public static func weeklySlot(
        hour: Int,
        minute: Int,
        leadMinutes: Int,
        days: Set<Weekday>
    ) -> (hour: Int, minute: Int, days: Set<Weekday>)? {
        let lead = normalizedLead(leadMinutes)
        guard lead > 0, !days.isEmpty else { return nil }
        let total = hour * 60 + minute - lead
        let shift = total < 0 ? -1 : 0
        let minutes = ((total % (24 * 60)) + (24 * 60)) % (24 * 60)
        let shifted = Set(days.map { day -> Weekday in
            let raw = day.rawValue + shift
            let wrapped = ((raw - 1 + 7) % 7) + 1
            return Weekday(rawValue: wrapped) ?? day
        })
        return (minutes / 60, minutes % 60, shifted)
    }
}

public enum NotificationPurpose: String, Equatable, Sendable {
    case alarm
    case machine
}

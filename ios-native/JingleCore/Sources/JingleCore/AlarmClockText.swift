import Foundation

public enum AlarmClockText {
    public static func time(hour: Int, minute: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let hour12 = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d %@", hour12, minute, period)
    }

    public static func repeatSummary(_ days: Set<Weekday>) -> String {
        if days.isEmpty { return "Once" }
        if days.count == Weekday.allCases.count { return "Every day" }
        if days == Weekday.weekdays { return "Weekdays" }
        if days == Weekday.weekends { return "Weekends" }
        return days.sorted { $0.rawValue < $1.rawValue }.map(\.name).map { String($0.prefix(3)) }.joined(separator: " ")
    }

    public static func countdown(from now: Date, to fire: Date, calendar: Calendar = .current) -> String {
        let seconds = fire.timeIntervalSince(now)
        if seconds <= 0 { return "Rings now" }
        let minutes = Int(ceil(seconds / 60))
        if minutes <= 1 { return "Rings in less than a minute" }
        if minutes < 60 {
            return "Rings in \(minutes) minutes"
        }
        let hours = minutes / 60
        let rest = minutes % 60
        if hours < 18 {
            let hourLabel = hours == 1 ? "1 hour" : "\(hours) hours"
            if rest == 0 { return "Rings in \(hourLabel)" }
            return "Rings in \(hourLabel) \(rest) min"
        }
        let startNow = calendar.startOfDay(for: now)
        let startFire = calendar.startOfDay(for: fire)
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: startNow), startFire == tomorrow {
            return "Rings tomorrow"
        }
        let weekday = calendar.component(.weekday, from: fire)
        let name = Weekday(rawValue: weekday)?.name ?? "soon"
        return "Rings \(name)"
    }
}

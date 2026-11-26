import Foundation

public struct UpcomingAlarm: Equatable, Sendable {
    public var alarm: Alarm
    public var fireDate: Date

    public init(alarm: Alarm, fireDate: Date) {
        self.alarm = alarm
        self.fireDate = fireDate
    }
}

/// Next civil fire date for one-shot, daily, and weekday alarms.
/// Times that fall in a daylight-saving gap fire at the first valid instant after the gap.
/// Repeated clock times (the fall-back hour) use the earliest occurrence still strictly after `now`.
public enum AlarmScheduleCalculator {
    public static func nextFireDate(
        for alarm: Alarm,
        now: Date,
        calendar: Calendar = .current
    ) -> Date? {
        let alarm = alarm.normalized()
        guard alarm.enabled else { return nil }
        let oneShot = alarm.repeatWeekdays.isEmpty
        let horizon = oneShot ? 2 : 8
        let today = calendar.startOfDay(for: now)
        for offset in 0..<horizon {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            if !oneShot {
                let raw = calendar.component(.weekday, from: day)
                guard let weekday = Weekday(rawValue: raw), alarm.repeatWeekdays.contains(weekday) else {
                    continue
                }
            }
            for candidate in occurrences(on: day, hour: alarm.hour, minute: alarm.minute, calendar: calendar) {
                if candidate > now {
                    return candidate
                }
            }
        }
        return nil
    }

    public static func nextUpcoming(
        alarms: [Alarm],
        now: Date,
        calendar: Calendar = .current
    ) -> UpcomingAlarm? {
        var best: UpcomingAlarm?
        for alarm in alarms where alarm.enabled {
            guard let fire = nextFireDate(for: alarm, now: now, calendar: calendar) else { continue }
            if let current = best {
                if fire < current.fireDate || (fire == current.fireDate && alarm.label < current.alarm.label) {
                    best = UpcomingAlarm(alarm: alarm, fireDate: fire)
                }
            } else {
                best = UpcomingAlarm(alarm: alarm, fireDate: fire)
            }
        }
        return best
    }

    /// Every real instant on `day` whose local clock reads `hour:minute`.
    /// A missing civil time (spring forward) yields the first instant after the gap.
    public static func occurrences(
        on day: Date,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> [Date] {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return [] }
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        let requested = hour * 60 + minute
        var found: [Date] = []
        var cursor = start
        var previousMinutes = minutes(from: cursor, calendar: calendar)
        var guardrail = 0
        while cursor < end && guardrail < 2_000 {
            guardrail += 1
            let local = minutes(from: cursor, calendar: calendar)
            if local == requested {
                found.append(cursor)
            }
            let next = cursor.addingTimeInterval(60)
            if next <= cursor { break }
            if next < end {
                let nextMinutes = minutes(from: next, calendar: calendar)
                if nextMinutes > previousMinutes + 1,
                   requested > previousMinutes,
                   requested < nextMinutes,
                   found.isEmpty {
                    found.append(next)
                }
                previousMinutes = nextMinutes
            }
            cursor = next
        }
        return found
    }

    private static func minutes(from date: Date, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}

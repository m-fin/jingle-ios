import Foundation
import XCTest
@testable import JingleCore

final class ScheduleTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        self.calendar = calendar
    }

    func testOneShotLaterTodayAndTomorrow() {
        let alarm = make(hour: 18, minute: 30, days: [])
        let morning = utc("2026-11-14T13:00:00Z") // 8:00 AM EST
        let later = AlarmScheduleCalculator.nextFireDate(for: alarm, now: morning, calendar: calendar)
        XCTAssertEqual(later, utc("2026-11-14T23:30:00Z"))

        let evening = utc("2026-11-15T00:00:00Z") // 7:00 PM EST
        let tomorrow = AlarmScheduleCalculator.nextFireDate(for: alarm, now: evening, calendar: calendar)
        XCTAssertEqual(tomorrow, utc("2026-11-15T23:30:00Z"))
    }

    func testDisabledAlarmHasNoFireDate() {
        var alarm = make(hour: 6, minute: 0, days: Weekday.weekdays)
        alarm.enabled = false
        XCTAssertNil(AlarmScheduleCalculator.nextFireDate(for: alarm, now: utc("2026-11-14T15:00:00Z"), calendar: calendar))
    }

    func testWeekdayRecurrenceSkipsToMonday() {
        let alarm = make(hour: 6, minute: 0, days: Weekday.weekdays)
        let saturdayEvening = utc("2026-11-15T01:00:00Z") // Sat Nov 14, 8:00 PM EST
        let next = AlarmScheduleCalculator.nextFireDate(for: alarm, now: saturdayEvening, calendar: calendar)
        XCTAssertEqual(next, utc("2026-11-16T11:00:00Z")) // Mon 6:00 AM EST
        XCTAssertEqual(calendar.component(.weekday, from: next!), Weekday.monday.rawValue)
    }

    func testExactFireTimeMovesToTheFollowingDay() {
        let alarm = make(hour: 6, minute: 0, days: Weekday.weekdays)
        let exactly = utc("2026-11-16T11:00:00Z") // Mon 6:00 AM
        let next = AlarmScheduleCalculator.nextFireDate(for: alarm, now: exactly, calendar: calendar)
        XCTAssertEqual(next, utc("2026-11-17T11:00:00Z"))
    }

    func testDailyIncludesTodayWhenStillAhead() {
        let alarm = make(hour: 6, minute: 0, days: Set(Weekday.allCases))
        let before = utc("2026-11-16T10:00:00Z")
        XCTAssertEqual(
            AlarmScheduleCalculator.nextFireDate(for: alarm, now: before, calendar: calendar),
            utc("2026-11-16T11:00:00Z")
        )
    }

    func testMidnightBoundary() {
        let alarm = make(hour: 0, minute: 0, days: Set(Weekday.allCases))
        let before = utc("2026-11-16T04:30:00Z") // 11:30 PM EST Nov 15
        XCTAssertEqual(
            AlarmScheduleCalculator.nextFireDate(for: alarm, now: before, calendar: calendar),
            utc("2026-11-16T05:00:00Z")
        )
        let exactly = utc("2026-11-16T05:00:00Z")
        XCTAssertEqual(
            AlarmScheduleCalculator.nextFireDate(for: alarm, now: exactly, calendar: calendar),
            utc("2026-11-17T05:00:00Z")
        )
    }

    func testSpringForwardGapUsesTheFirstValidInstant() {
        let alarm = make(hour: 2, minute: 30, days: Set(Weekday.allCases))
        let beforeGap = utc("2026-03-08T06:00:00Z") // 1:00 AM EST
        let fire = AlarmScheduleCalculator.nextFireDate(for: alarm, now: beforeGap, calendar: calendar)
        XCTAssertEqual(fire, utc("2026-03-08T07:00:00Z")) // 3:00 AM EDT
        let parts = calendar.dateComponents([.hour, .minute], from: fire!)
        XCTAssertEqual(parts.hour, 3)
        XCTAssertEqual(parts.minute, 0)
    }

    func testFallBackUsesTheEarliestRemainingOccurrence() {
        let alarm = make(hour: 1, minute: 30, days: Set(Weekday.allCases))
        let firstHour = utc("2026-11-01T05:00:00Z") // 1:00 AM EDT
        XCTAssertEqual(
            AlarmScheduleCalculator.nextFireDate(for: alarm, now: firstHour, calendar: calendar),
            utc("2026-11-01T05:30:00Z")
        )
        let afterFirst = utc("2026-11-01T05:40:00Z") // 1:40 AM EDT
        XCTAssertEqual(
            AlarmScheduleCalculator.nextFireDate(for: alarm, now: afterFirst, calendar: calendar),
            utc("2026-11-01T06:30:00Z") // 1:30 AM EST
        )
    }

    func testDailyAcrossTheTwentyFiveHourFallbackDayKeepsCivilTime() {
        let alarm = make(hour: 0, minute: 30, days: Set(Weekday.allCases))
        let now = utc("2026-11-01T04:45:00Z") // 12:45 AM EDT
        let fire = AlarmScheduleCalculator.nextFireDate(for: alarm, now: now, calendar: calendar)
        XCTAssertEqual(fire, utc("2026-11-02T05:30:00Z"))
        XCTAssertEqual(fire!.timeIntervalSince(now), 24 * 3600 + 45 * 60, accuracy: 1)
    }

    func testSpecificWednesday() {
        let alarm = make(hour: 7, minute: 15, days: [.wednesday])
        let monday = utc("2026-11-16T15:00:00Z")
        let fire = AlarmScheduleCalculator.nextFireDate(for: alarm, now: monday, calendar: calendar)
        XCTAssertEqual(fire, utc("2026-11-18T12:15:00Z"))
        XCTAssertEqual(calendar.component(.weekday, from: fire!), Weekday.wednesday.rawValue)
    }

    func testNextUpcomingPicksTheSoonerAlarm() {
        let early = make(id: "a", hour: 7, minute: 0, days: Set(Weekday.allCases))
        let late = make(id: "b", hour: 8, minute: 0, days: Set(Weekday.allCases))
        let now = utc("2026-11-16T10:30:00Z")
        let upcoming = AlarmScheduleCalculator.nextUpcoming(alarms: [late, early], now: now, calendar: calendar)
        XCTAssertEqual(upcoming?.alarm.id, "a")
    }

    func testDismissTurnsOffOneShotAndKeepsRepeating() {
        let once = make(hour: 6, minute: 0, days: [])
        XCTAssertFalse(AlarmFiring.dismissed(once).enabled)
        let daily = make(hour: 6, minute: 0, days: Set(Weekday.allCases))
        XCTAssertTrue(AlarmFiring.dismissed(daily).enabled)
    }

    func testCountdownAndRepeatLabels() {
        XCTAssertEqual(AlarmClockText.time(hour: 0, minute: 0), "12:00 AM")
        XCTAssertEqual(AlarmClockText.time(hour: 6, minute: 5), "6:05 AM")
        XCTAssertEqual(AlarmClockText.time(hour: 18, minute: 0), "6:00 PM")
        XCTAssertEqual(AlarmClockText.repeatSummary([]), "Once")
        XCTAssertEqual(AlarmClockText.repeatSummary(Weekday.weekdays), "Weekdays")
        XCTAssertEqual(AlarmClockText.repeatSummary(Weekday.weekends), "Weekends")
        XCTAssertEqual(AlarmClockText.repeatSummary(Set(Weekday.allCases)), "Every day")
        XCTAssertEqual(AlarmClockText.repeatSummary([.monday, .wednesday]), "Mon Wed")
        let now = utc("2026-11-16T10:00:00Z")
        let soon = utc("2026-11-16T10:20:00Z")
        XCTAssertEqual(AlarmClockText.countdown(from: now, to: soon, calendar: calendar), "Rings in 20 minutes")
    }

    private func make(id: String = "alarm-1", hour: Int, minute: Int, days: Set<Weekday>) -> Alarm {
        Alarm(
            id: id,
            hour: hour,
            minute: minute,
            label: "Morning",
            enabled: true,
            repeatWeekdays: days,
            tone: .jingleBells,
            progressiveRampSeconds: 60
        )
    }

    private func utc(_ string: String) -> Date {
        ISO8601DateFormatter().date(from: string)!
    }
}

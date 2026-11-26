import Foundation
import XCTest
@testable import JingleCore

final class NotificationTests: XCTestCase {
    func testIdentifiersAreAppScopedAndTimeSensitive() {
        let calendar = newYork()
        let now = ISO8601DateFormatter().date(from: "2026-11-14T15:00:00Z")!
        let once = alarm(id: "11111111-1111-1111-1111-111111111111", hour: 18, minute: 0, days: [])
        let daily = alarm(id: "22222222-2222-2222-2222-222222222222", hour: 6, minute: 30, days: Set(Weekday.allCases))
        let weekdays = alarm(id: "33333333-3333-3333-3333-333333333333", hour: 6, minute: 0, days: Weekday.weekdays)
        let planned = AlarmNotificationPlanner.requests(for: [once, daily, weekdays], now: now, calendar: calendar)

        XCTAssertEqual(planned.count, 1 + 1 + 5)
        XCTAssertEqual(Set(planned.map(\.identifier)).count, planned.count)
        for request in planned {
            XCTAssertTrue(request.identifier.hasPrefix("jingle.alarm.\(request.alarmID)"))
            XCTAssertEqual(AlarmNotificationIdentity.alarmID(from: request.identifier), request.alarmID)
            XCTAssertEqual(request.interruptionLevel, .timeSensitive)
            XCTAssertEqual(request.categoryIdentifier, "jingle.alarm")
            XCTAssertEqual(request.body, "Time to get up.")
        }

        let onceID = planned.first { $0.alarmID == once.id }!
        XCTAssertEqual(onceID.identifier, "jingle.alarm.\(once.id)")
        XCTAssertFalse(onceID.repeats)
        XCTAssertNotNil(onceID.fireDate)
        XCTAssertEqual(onceID.soundName, "jingleBells.wav")

        let dailyID = planned.first { $0.alarmID == daily.id }!
        XCTAssertEqual(dailyID.identifier, "jingle.alarm.\(daily.id)")
        XCTAssertTrue(dailyID.repeats)
        XCTAssertNil(dailyID.weekday)

        let days = planned.filter { $0.alarmID == weekdays.id }
        XCTAssertEqual(days.map(\.weekday), [.monday, .tuesday, .wednesday, .thursday, .friday])
        XCTAssertTrue(days.allSatisfy { $0.repeats && $0.identifier.contains(".w") })
    }

    func testOneShotInTheSpringGapUsesTheResolvedClockTime() {
        let calendar = newYork()
        let now = ISO8601DateFormatter().date(from: "2026-03-08T06:00:00Z")!
        let gap = alarm(id: "gap", hour: 2, minute: 30, days: [])
        let planned = AlarmNotificationPlanner.requests(for: gap, now: now, calendar: calendar)
        XCTAssertEqual(planned.count, 1)
        XCTAssertEqual(planned[0].hour, 3)
        XCTAssertEqual(planned[0].minute, 0)
        XCTAssertEqual(planned[0].identifier, "jingle.alarm.gap")
        XCTAssertFalse(planned[0].repeats)
    }

    func testDisabledAlarmIsNotScheduled() {
        var alarm = alarm(id: "off", hour: 6, minute: 0, days: Set(Weekday.allCases))
        alarm.enabled = false
        XCTAssertTrue(AlarmNotificationPlanner.requests(for: alarm, now: Date(), calendar: newYork()).isEmpty)
    }

    func testForegroundPresentationAndDismissAction() {
        XCTAssertTrue(AlarmNotificationPlanner.foregroundPresentation.includesAlert)
        XCTAssertTrue(AlarmNotificationPlanner.foregroundPresentation.includesSound)
        XCTAssertEqual(AlarmNotificationPlanner.actions.map(\.title), ["Dismiss"])
        XCTAssertEqual(AlarmNotificationPlanner.actions.map(\.identifier), ["jingle.dismiss"])
    }

    func testTwoAlarmsNeverShareAnIdentifier() {
        let calendar = newYork()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let first = alarm(id: "alpha", hour: 7, minute: 0, days: [.monday])
        let second = alarm(id: "beta", hour: 7, minute: 0, days: [.monday])
        let planned = AlarmNotificationPlanner.requests(for: [first, second], now: now, calendar: calendar)
        XCTAssertEqual(planned.count, 2)
        XCTAssertNotEqual(planned[0].identifier, planned[1].identifier)
        XCTAssertTrue(planned[0].identifier.hasPrefix("jingle.alarm.alpha"))
        XCTAssertTrue(planned[1].identifier.hasPrefix("jingle.alarm.beta"))
    }

    private func alarm(id: String, hour: Int, minute: Int, days: Set<Weekday>) -> Alarm {
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

    private func newYork() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }
}

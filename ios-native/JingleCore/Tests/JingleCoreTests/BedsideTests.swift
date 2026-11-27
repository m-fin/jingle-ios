import Foundation
import XCTest
@testable import JingleCore

final class BedsideSettingsTests: XCTestCase {
    func testDefaultIsMatteBlackWithBlankAndDimOn() {
        let settings = BedsideSettings.default
        XCTAssertEqual(settings.theme, .matteBlack)
        XCTAssertTrue(settings.autoBlank)
        XCTAssertTrue(settings.bedsideDim)
        XCTAssertEqual(BedsideSettings.blankAfter, 45)
        XCTAssertEqual(AppearanceTheme.allCases.map(\.displayName), ["Matte Black", "Stone", "Bitcoin Orange"])
        XCTAssertTrue(AppearanceTheme.matteBlack.prefersDarkInterface)
        XCTAssertFalse(AppearanceTheme.stone.prefersDarkInterface)
        XCTAssertTrue(AppearanceTheme.bitcoinOrange.prefersDarkInterface)
    }

    func testRoundTripAndUnknownThemeFallsBack() {
        let memory = MemoryDefaults()
        let store = BedsideSettingsStore(store: memory)
        store.save(BedsideSettings(theme: .stone, autoBlank: false, bedsideDim: true))
        let loaded = store.load()
        XCTAssertEqual(loaded.theme, .stone)
        XCTAssertFalse(loaded.autoBlank)
        XCTAssertTrue(loaded.bedsideDim)

        memory.set(Data("[]".utf8), forKey: BedsideSettingsStore.storageKey)
        XCTAssertEqual(store.load(), .default)

        let raw: [String: Any] = [
            "version": 1,
            "theme": "not-a-theme",
            "autoBlank": false,
            "bedsideDim": false,
        ]
        memory.set(try! JSONSerialization.data(withJSONObject: raw), forKey: BedsideSettingsStore.storageKey)
        let fallback = store.load()
        XCTAssertEqual(fallback.theme, .matteBlack)
        XCTAssertFalse(fallback.autoBlank)
        XCTAssertFalse(fallback.bedsideDim)
    }
}

final class MachineModeTests: XCTestCase {
    func testLeadNormalizationAndDate() {
        XCTAssertEqual(MachineMode.normalizedLead(10), 10)
        XCTAssertEqual(MachineMode.normalizedLead(20), 20)
        XCTAssertEqual(MachineMode.normalizedLead(15), 0)
        XCTAssertEqual(MachineMode.soundFileName, "machine-mode.caf")
        let fire = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertNil(MachineMode.leadDate(fireDate: fire, leadMinutes: 0))
        XCTAssertEqual(MachineMode.leadDate(fireDate: fire, leadMinutes: 20)?.timeIntervalSince1970, 1_800_000_000 - 20 * 60)
    }

    func testWeeklySlotCrossesMidnightAndKeepsSameMorning() {
        let crossed = MachineMode.weeklySlot(
            hour: 0,
            minute: 10,
            leadMinutes: 20,
            days: Weekday.weekdays
        )
        XCTAssertEqual(crossed?.hour, 23)
        XCTAssertEqual(crossed?.minute, 50)
        XCTAssertEqual(crossed?.days, [.sunday, .monday, .tuesday, .wednesday, .thursday])

        let sameMorning = MachineMode.weeklySlot(
            hour: 6,
            minute: 0,
            leadMinutes: 20,
            days: Weekday.weekdays
        )
        XCTAssertEqual(sameMorning?.hour, 5)
        XCTAssertEqual(sameMorning?.minute, 40)
        XCTAssertEqual(sameMorning?.days, Weekday.weekdays)
        XCTAssertNil(MachineMode.weeklySlot(hour: 6, minute: 0, leadMinutes: 0, days: Weekday.weekdays))
    }

    func testStoreKeepsMachineLeadAndDropsInvalidValues() {
        let memory = MemoryDefaults()
        let store = AlarmStore(store: memory)
        var alarm = Alarm.weekdayMorning()
        alarm.machineLeadMinutes = 20
        store.save(AlarmLibrary(seeded: true, alarms: [alarm]))
        XCTAssertEqual(store.load().alarms.first?.machineLeadMinutes, 20)

        alarm.machineLeadMinutes = 7
        XCTAssertEqual(alarm.normalized().machineLeadMinutes, 0)
    }

    func testPlannerSchedulesMachineAndPrefersAlarmsWhenOverBudget() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        var weekdays = Alarm.weekdayMorning()
        weekdays.machineLeadMinutes = 20
        let planned = AlarmNotificationPlanner.requests(for: weekdays, now: now, calendar: calendar)
        let alarms = planned.filter { $0.purpose == .alarm }
        let machines = planned.filter { $0.purpose == .machine }
        XCTAssertEqual(alarms.count, 5)
        XCTAssertEqual(machines.count, 5)
        XCTAssertTrue(machines.allSatisfy { $0.hour == 5 && $0.minute == 40 })
        XCTAssertTrue(machines.allSatisfy { $0.soundName == "machine-mode.caf" })
        XCTAssertTrue(machines.allSatisfy { $0.identifier.hasPrefix("jingle.machine.") })
        XCTAssertEqual(AlarmNotificationIdentity.purpose(from: machines[0].identifier), .machine)
        XCTAssertEqual(AlarmNotificationIdentity.alarmID(from: machines[0].identifier), weekdays.id)

        let once = Alarm(
            id: "once",
            hour: 6,
            minute: 0,
            label: "Once",
            enabled: true,
            repeatWeekdays: [],
            tone: .pocketOfBells,
            progressiveRampSeconds: 60,
            machineLeadMinutes: 10
        )
        let later = calendar.date(byAdding: .day, value: 1, to: now)!
        // Build a fire definitely in the future by using calculator.
        let oncePlans = AlarmNotificationPlanner.requests(for: once, now: now, calendar: calendar)
        if let fire = AlarmScheduleCalculator.nextFireDate(for: once, now: now, calendar: calendar) {
            let machine = oncePlans.first { $0.purpose == .machine }
            XCTAssertNotNil(machine)
            XCTAssertEqual(machine?.fireDate, fire.addingTimeInterval(-10 * 60))
        } else {
            XCTFail("expected a one-shot fire date")
        }
        XCTAssertEqual(later.timeIntervalSince1970 > now.timeIntervalSince1970, true)

        let many = (0..<8).map { index in
            Alarm(
                id: "a\(index)",
                hour: 6,
                minute: index,
                label: "A",
                enabled: true,
                repeatWeekdays: Weekday.weekdays,
                tone: .pocketOfBells,
                progressiveRampSeconds: 60,
                machineLeadMinutes: 10
            )
        }
        let packed = AlarmNotificationPlanner.requests(for: many, now: now, calendar: calendar)
        XCTAssertEqual(packed.count, AlarmNotificationPlanner.budget)
        XCTAssertEqual(packed.filter { $0.purpose == .alarm }.count, 40)
        XCTAssertEqual(packed.filter { $0.purpose == .machine }.count, 16)
    }

    func testZeroLeadDoesNotScheduleMachine() {
        let planned = AlarmNotificationPlanner.requests(for: Alarm.weekdayMorning(), now: Date())
        XCTAssertTrue(planned.allSatisfy { $0.purpose == .alarm })
    }
}

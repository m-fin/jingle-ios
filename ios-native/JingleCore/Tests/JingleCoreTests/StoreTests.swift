import Foundation
import XCTest
@testable import JingleCore

final class StoreTests: XCTestCase {
    func testRoundTripKeepsAlarmsAndDismissal() {
        let store = AlarmStore(store: MemoryDefaults())
        var library = AlarmLibrary(seeded: true, alarms: [
            Alarm.weekdayMorning(),
            Alarm(
                id: "once",
                hour: 21,
                minute: 5,
                label: "  Read  ",
                enabled: true,
                repeatWeekdays: [],
                tone: .hearth,
                progressiveRampSeconds: 120
            ),
        ])
        library.recordDismissal(alarmID: "once", at: Date(timeIntervalSince1970: 1_700_000_000))
        store.save(library)
        let loaded = store.load()
        XCTAssertTrue(loaded.seeded)
        XCTAssertEqual(loaded.alarms.count, 2)
        let morning = loaded.alarms.first { $0.id == "weekday-morning" }
        XCTAssertEqual(morning?.tone, .jingleBells)
        XCTAssertEqual(morning?.repeatWeekdays, Weekday.weekdays)
        XCTAssertEqual(morning?.progressiveRampSeconds, 60)
        let once = loaded.alarms.first { $0.id == "once" }
        XCTAssertEqual(once?.label, "Read")
        XCTAssertEqual(once?.hour, 21)
        XCTAssertFalse(once?.enabled ?? true)
        XCTAssertEqual(loaded.dismissal?.alarmID, "once")
        XCTAssertEqual(loaded.dismissal?.at.timeIntervalSince1970 ?? 0, 1_700_000_000, accuracy: 0.5)
    }

    func testUnknownToneBecomesJingleBellsAndInvalidHourIsDropped() {
        let payload: [String: Any] = [
            "version": 1,
            "seeded": true,
            "alarms": [
                [
                    "id": "good",
                    "hour": 7,
                    "minute": 30,
                    "label": "Good",
                    "enabled": true,
                    "repeatWeekdays": [2, 2, 4],
                    "tone": "not-a-tone",
                    "progressiveRampSeconds": 30,
                ],
                [
                    "id": "bad",
                    "hour": 99,
                    "minute": 0,
                    "label": "Bad",
                    "enabled": true,
                    "repeatWeekdays": [],
                    "tone": "jingleBells",
                    "progressiveRampSeconds": 60,
                ],
            ],
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        let memory = MemoryDefaults()
        memory.set(data, forKey: AlarmStore.storageKey)
        let loaded = AlarmStore(store: memory).load()
        XCTAssertEqual(loaded.alarms.map(\.id), ["good"])
        XCTAssertEqual(loaded.alarms.first?.tone, .jingleBells)
        XCTAssertEqual(loaded.alarms.first?.repeatWeekdays, [.monday, .wednesday])
    }

    func testCorruptPayloadDoesNotCrash() {
        let memory = MemoryDefaults()
        memory.set(Data("[]".utf8), forKey: AlarmStore.storageKey)
        XCTAssertEqual(AlarmStore(store: memory).load(), .empty)
    }

    func testSeedAddsWeekdayMorningOnce() {
        let seeded = AlarmLibrarySeeder.seedIfNeeded(.empty)
        XCTAssertEqual(seeded.alarms, [Alarm.weekdayMorning()])
        XCTAssertTrue(seeded.seeded)
        let again = AlarmLibrarySeeder.seedIfNeeded(AlarmLibrary(seeded: true, alarms: []))
        XCTAssertTrue(again.alarms.isEmpty)
    }

    func testUpsertStopsAtEight() {
        var library = AlarmLibrary(seeded: true, alarms: [])
        for index in 0..<8 {
            XCTAssertTrue(library.upsert(Alarm(
                id: "id-\(index)",
                hour: index,
                minute: 0,
                label: "A",
                enabled: true,
                repeatWeekdays: [],
                tone: .jingleBells,
                progressiveRampSeconds: 60
            )))
        }
        XCTAssertFalse(library.upsert(Alarm(
            id: "extra",
            hour: 9,
            minute: 0,
            label: "Extra",
            enabled: true,
            repeatWeekdays: [],
            tone: .amber,
            progressiveRampSeconds: 60
        )))
        XCTAssertEqual(library.alarms.count, 8)
    }

    func testAppGroupIdentifier() {
        XCTAssertEqual(AlarmStore.appGroupIdentifier, "group.app.jingle.ios")
        XCTAssertEqual(AlarmLibraryEvents.changedNotification, "app.jingle.ios.library-changed")
    }
}

final class MemoryDefaults: KeyValueStoring {
    var values: [String: Any] = [:]
    func data(forKey key: String) -> Data? { values[key] as? Data }
    func set(_ value: Any?, forKey defaultName: String) { values[defaultName] = value }
}

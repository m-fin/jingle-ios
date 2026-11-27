import Foundation
import XCTest
@testable import JingleCore

final class AlarmSoundTests: XCTestCase {
    func testDelegatePresentsBannerListAndSound() {
        let presentation = AlarmNotificationPlanner.foregroundPresentation
        XCTAssertEqual(presentation.optionNames, ["banner", "list", "sound"])
        XCTAssertTrue(presentation.showsBanner)
        XCTAssertTrue(presentation.showsList)
        XCTAssertTrue(presentation.playsSound)
        XCTAssertTrue(presentation.includesAlert)
        XCTAssertTrue(presentation.includesSound)
    }

    func testAuthorizationAsksForSoundAndTimeSensitive() {
        XCTAssertTrue(NotificationAuthorizationRequest.options.contains(.sound))
        XCTAssertTrue(NotificationAuthorizationRequest.options.contains(.timeSensitive))
        XCTAssertTrue(NotificationAuthorizationRequest.options.contains(.alert))
    }

    func testWakeFilesResolveToBundleRootCustomSounds() throws {
        for tone in WakeTone.allCases {
            let name = tone.notificationSoundName
            let url = soundURL(name)
            let data = try Data(contentsOf: url)
            let header = try XCTUnwrap(CAFNotificationSound.header(of: data), name)
            XCTAssertTrue(NotificationSoundLookup.isBundleRootFileName(name), name)
            XCTAssertFalse(name.contains("/"))
            XCTAssertEqual(header.channels, 1, name)
            XCTAssertLessThanOrEqual(header.duration, NotificationSoundLookup.maximumDuration, name)
            XCTAssertEqual(header.duration, 28, accuracy: 0.05, name)
            guard case .linearPCM(let littleEndian, let bits, let floating) = header.encoding else {
                XCTFail("\(name) is not linear PCM")
                continue
            }
            XCTAssertTrue(littleEndian, name)
            XCTAssertEqual(bits, 16, name)
            XCTAssertFalse(floating, name)
            XCTAssertGreaterThanOrEqual(header.openingPeak, NotificationSoundLookup.minimumOpeningPeak, name)

            let bundled = [BundledSoundFile(fileName: name, subdirectory: nil)]
            XCTAssertEqual(
                NotificationSoundLookup.resolve(requestedFileName: name, bundled: bundled, header: header),
                .custom(name),
                name
            )
        }
    }

    func testLookupRejectsSubfolderCaseMismatchAndSilentEndian() throws {
        let name = WakeTone.pocketOfBells.notificationSoundName
        let data = try Data(contentsOf: soundURL(name))
        let header = try XCTUnwrap(CAFNotificationSound.header(of: data))

        XCTAssertEqual(
            NotificationSoundLookup.resolve(
                requestedFileName: name,
                bundled: [BundledSoundFile(fileName: name, subdirectory: "Sounds")],
                header: header
            ),
            .systemDefault
        )
        XCTAssertEqual(
            NotificationSoundLookup.resolve(
                requestedFileName: "01-A-Pocket-of-Bells.caf",
                bundled: [BundledSoundFile(fileName: name)],
                header: header
            ),
            .systemDefault
        )
        XCTAssertEqual(
            NotificationSoundLookup.resolve(
                requestedFileName: "Sounds/\(name)",
                bundled: [BundledSoundFile(fileName: "Sounds/\(name)")],
                header: header
            ),
            .systemDefault
        )

        let silent = NotificationSoundHeader(
            duration: 28,
            sampleRate: 44_100,
            channels: 1,
            encoding: .linearPCM(littleEndian: false, bitsPerChannel: 16, floatingPoint: false),
            openingPeak: 32_000
        )
        XCTAssertEqual(
            NotificationSoundLookup.resolve(
                requestedFileName: name,
                bundled: [BundledSoundFile(fileName: name)],
                header: silent
            ),
            .systemDefault
        )

        let swapped = NotificationSoundHeader(
            duration: 28,
            sampleRate: 44_100,
            channels: 1,
            encoding: .linearPCM(littleEndian: true, bitsPerChannel: 16, floatingPoint: false),
            openingPeak: 8
        )
        XCTAssertFalse(swapped.playsAsNotificationSound)
        XCTAssertEqual(
            NotificationSoundLookup.resolve(
                requestedFileName: name,
                bundled: [BundledSoundFile(fileName: name)],
                header: swapped
            ),
            .systemDefault
        )
    }

    func testFireTriggerStartsPlaybackOnEverySurfaceWhileTheProcessRuns() {
        let surfaces: [PhoneAlarmSurface] = [.foreground, .background, .locked, .unlocked]
        for surface in surfaces {
            let running = AlarmFireTrigger.action(on: surface, processIsRunning: true)
            XCTAssertTrue(running.startPlayback, surface.rawValue)
            XCTAssertEqual(running.session, .alarmPlayback)
            XCTAssertEqual(running.session.category, .playback)
            XCTAssertTrue(running.ignoresHardwareSilentSwitch, surface.rawValue)
            XCTAssertEqual(running.presentationOptionNames, ["banner", "list", "sound"])
            XCTAssertEqual(running.showRingingScreen, surface != .locked, surface.rawValue)

            let suspended = AlarmFireTrigger.action(on: surface, processIsRunning: false)
            XCTAssertFalse(suspended.startPlayback, surface.rawValue)
            XCTAssertFalse(suspended.ignoresHardwareSilentSwitch, surface.rawValue)
            XCTAssertFalse(suspended.showRingingScreen, surface.rawValue)
        }
    }

    func testArmingUsesAlarmKitWhenAuthorizedAndBedsideOtherwise() {
        let sound = NotificationSoundChoice.custom("01-a-pocket-of-bells.caf")
        let system = AlarmArmingPolicy.plan(alarmKitAuthorized: true, resolvedSound: sound)
        XCTAssertEqual(system.route, .systemAlarm)
        XCTAssertNil(system.notificationSound)
        XCTAssertFalse(system.holdBedsidePlayback)
        XCTAssertTrue(system.breaksThroughSilentSwitchWhenSuspended)

        let notification = AlarmArmingPolicy.plan(alarmKitAuthorized: false, resolvedSound: sound)
        XCTAssertEqual(notification.route, .localNotification)
        XCTAssertEqual(notification.notificationSound, sound)
        XCTAssertTrue(notification.holdBedsidePlayback)
        XCTAssertFalse(notification.breaksThroughSilentSwitchWhenSuspended)

        XCTAssertTrue(BedsideSessionPolicy.shouldHold(
            alarmKitAuthorized: false,
            hasEnabledAlarm: true,
            isRinging: false,
            sceneIsActive: false
        ))
        XCTAssertFalse(BedsideSessionPolicy.shouldHold(
            alarmKitAuthorized: true,
            hasEnabledAlarm: true,
            isRinging: false,
            sceneIsActive: false
        ))
        XCTAssertFalse(BedsideSessionPolicy.shouldHold(
            alarmKitAuthorized: false,
            hasEnabledAlarm: true,
            isRinging: false,
            sceneIsActive: true
        ))
        XCTAssertFalse(BedsideSessionPolicy.shouldHold(
            alarmKitAuthorized: false,
            hasEnabledAlarm: true,
            isRinging: true,
            sceneIsActive: false
        ))
    }

    func testSystemAlarmDraftKeepsSevenAmAndTheExactSoundName() {
        let calendar = newYork()
        let now = ISO8601DateFormatter().date(from: "2026-11-14T15:00:00Z")!
        let alarm = Alarm(
            id: "weekday-morning",
            hour: 7,
            minute: 0,
            label: "Morning",
            enabled: true,
            repeatWeekdays: Weekday.weekdays,
            tone: .pocketOfBells,
            progressiveRampSeconds: 60
        )
        let drafts = SystemAlarmPlanner.drafts(for: [alarm], now: now, calendar: calendar)
        XCTAssertEqual(drafts.count, 1)
        XCTAssertEqual(drafts[0].hour, 7)
        XCTAssertEqual(drafts[0].minute, 0)
        XCTAssertEqual(drafts[0].weekdays, [.monday, .tuesday, .wednesday, .thursday, .friday])
        XCTAssertEqual(drafts[0].soundFileName, "01-a-pocket-of-bells.caf")
        XCTAssertEqual(drafts[0].systemID, AlarmSystemIdentifier.uuid(for: alarm.id))
        XCTAssertEqual(AlarmSystemIdentifier.uuid(for: alarm.id), AlarmSystemIdentifier.uuid(for: "weekday-morning"))
        XCTAssertNotEqual(AlarmSystemIdentifier.uuid(for: alarm.id), AlarmSystemIdentifier.uuid(for: "other"))

        var disabled = alarm
        disabled.enabled = false
        XCTAssertTrue(SystemAlarmPlanner.drafts(for: [disabled], now: now, calendar: calendar).isEmpty)
    }

    func testGuidanceMentionsSilentSwitchForBothAlarmKitStates() {
        XCTAssertTrue(SilentSwitchGuidance.footnote(alarmKit: .authorized).contains("Ring/Silent"))
        XCTAssertTrue(SilentSwitchGuidance.footnote(alarmKit: .denied).contains("Ring/Silent"))
        XCTAssertTrue(SilentSwitchGuidance.footnote(alarmKit: .unavailable).contains("bedside"))
    }

    private func soundURL(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Jingle/Sounds/\(name)")
    }

    private func newYork() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }
}

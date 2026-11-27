import Foundation
import XCTest
@testable import JingleCore

final class PermissionTests: XCTestCase {
    func testAllGoodHasNoBanner() {
        let readiness = PermissionReadinessEvaluator.evaluate(PermissionSignals(
            authorization: .authorized,
            soundOn: true,
            timeSensitiveOn: true,
            liveActivitiesOn: true
        ))
        XCTAssertTrue(readiness.gaps.isEmpty)
        XCTAssertFalse(readiness.showsSettingsBanner)
        XCTAssertEqual(readiness.bannerMessage, "")
        XCTAssertNil(readiness.liveActivityNote)
        XCTAssertEqual(readiness.settingsButtonTitle, "Open Settings")
        XCTAssertFalse(readiness.requestsPromptInsteadOfSettings)
    }

    func testMissingNotifications() {
        let denied = PermissionReadinessEvaluator.evaluate(PermissionSignals(
            authorization: .denied,
            soundOn: true,
            timeSensitiveOn: true,
            liveActivitiesOn: true
        ))
        XCTAssertEqual(denied.gaps, [.notifications])
        XCTAssertTrue(denied.showsSettingsBanner)
        XCTAssertEqual(denied.bannerMessage, "Notifications are off.")
        XCTAssertEqual(denied.ringSwitchNote, PermissionReadiness.ringSwitchNote)
        XCTAssertEqual(denied.settingsButtonTitle, "Open Settings")

        let undecided = PermissionReadinessEvaluator.evaluate(PermissionSignals(
            authorization: .notDetermined,
            soundOn: false,
            timeSensitiveOn: false,
            liveActivitiesOn: true
        ))
        XCTAssertTrue(undecided.requestsPromptInsteadOfSettings)
        XCTAssertEqual(undecided.settingsButtonTitle, "Allow Notifications")
        XCTAssertTrue(undecided.gaps.contains(.notifications))
        XCTAssertTrue(undecided.gaps.contains(.sound))
        XCTAssertTrue(undecided.gaps.contains(.timeSensitive))
    }

    func testMissingSound() {
        let readiness = PermissionReadinessEvaluator.evaluate(PermissionSignals(
            authorization: .authorized,
            soundOn: false,
            timeSensitiveOn: true,
            liveActivitiesOn: true
        ))
        XCTAssertEqual(readiness.gaps, [.sound])
        XCTAssertTrue(readiness.showsSettingsBanner)
        XCTAssertEqual(readiness.bannerMessage, "Notification sound is off.")
        XCTAssertEqual(readiness.settingsButtonTitle, "Open Settings")
    }

    func testMissingTimeSensitive() {
        let readiness = PermissionReadinessEvaluator.evaluate(PermissionSignals(
            authorization: .authorized,
            soundOn: true,
            timeSensitiveOn: false,
            liveActivitiesOn: true
        ))
        XCTAssertEqual(readiness.gaps, [.timeSensitive])
        XCTAssertTrue(readiness.showsSettingsBanner)
        XCTAssertEqual(readiness.bannerMessage, "Time Sensitive alerts are off.")
    }

    func testProvisionalIsNotEnoughForAnAlarm() {
        let readiness = PermissionReadinessEvaluator.evaluate(PermissionSignals(
            authorization: .provisional,
            soundOn: true,
            timeSensitiveOn: true,
            liveActivitiesOn: true
        ))
        XCTAssertEqual(readiness.gaps, [.notifications])
        XCTAssertTrue(readiness.showsSettingsBanner)
    }

    func testLiveActivitiesAloneDoNotRaiseTheSettingsBanner() {
        let readiness = PermissionReadinessEvaluator.evaluate(PermissionSignals(
            authorization: .authorized,
            soundOn: true,
            timeSensitiveOn: true,
            liveActivitiesOn: false
        ))
        XCTAssertEqual(readiness.gaps, [.liveActivities])
        XCTAssertFalse(readiness.showsSettingsBanner)
        XCTAssertNotNil(readiness.liveActivityNote)
    }
}

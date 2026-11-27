import Foundation
import XCTest
@testable import JingleCore

final class CoexistenceTests: XCTestCase {
    func testInterruptionPausesWithoutDroppingTheAlarmOrLiveActivity() {
        let ringing = AlarmPlaybackState.ringing(alarmID: "morning")
        let paused = AlarmPlaybackReducer.reduce(ringing, .began)
        XCTAssertEqual(paused.alarmID, "morning")
        XCTAssertFalse(paused.dismissed)
        XCTAssertFalse(paused.audioRunning)
        XCTAssertTrue(paused.interrupted)
        XCTAssertTrue(paused.liveActivityActive)
        XCTAssertFalse(LiveActivityPolicy.shouldEnd(after: .began))
    }

    func testEndedResumesWhenTheAlarmIsStillActive() {
        let paused = AlarmPlaybackReducer.reduce(AlarmPlaybackState.ringing(alarmID: "morning"), .began)
        for shouldResume in [true, false] {
            let resumed = AlarmPlaybackReducer.reduce(paused, .ended(shouldResume: shouldResume))
            XCTAssertTrue(resumed.audioRunning)
            XCTAssertFalse(resumed.interrupted)
            XCTAssertEqual(resumed.alarmID, "morning")
            XCTAssertFalse(resumed.dismissed)
            XCTAssertTrue(resumed.liveActivityActive)
            XCTAssertFalse(LiveActivityPolicy.shouldEnd(after: .ended(shouldResume: shouldResume)))
        }
    }

    func testEndedDoesNotResumeAfterDismiss() {
        let dismissed = AlarmPlaybackReducer.reduce(AlarmPlaybackState.ringing(alarmID: "morning"), .dismissed)
        XCTAssertTrue(dismissed.dismissed)
        XCTAssertFalse(dismissed.audioRunning)
        XCTAssertFalse(dismissed.liveActivityActive)
        XCTAssertTrue(LiveActivityPolicy.shouldEnd(after: .dismissed))
        let after = AlarmPlaybackReducer.reduce(dismissed, .ended(shouldResume: true))
        XCTAssertFalse(after.audioRunning)
        XCTAssertTrue(after.dismissed)
        XCTAssertFalse(after.liveActivityActive)
    }

    func testBeganOnAnIdleSessionIsIgnored() {
        let idle = AlarmPlaybackReducer.reduce(.idle, .began)
        XCTAssertEqual(idle, .idle)
    }

    func testSessionMixesWithTheClockAppAndUsesBackgroundAudio() {
        XCTAssertEqual(AudioSessionConfiguration.alarmPlayback.category, .playback)
        XCTAssertTrue(AudioSessionConfiguration.alarmPlayback.mixWithOthers)
        XCTAssertEqual(BackgroundAudioMode.mode, "audio")
    }
}

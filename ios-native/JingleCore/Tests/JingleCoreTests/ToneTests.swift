import Foundation
import XCTest
@testable import JingleCore

final class ToneTests: XCTestCase {
    func testRampIsSilentAtTheStartAndFullAtTheEnd() {
        XCTAssertEqual(ProgressiveRamp.gain(elapsed: 0, duration: 60), 0, accuracy: 0.0001)
        XCTAssertEqual(ProgressiveRamp.gain(elapsed: -2, duration: 60), 0, accuracy: 0.0001)
        XCTAssertEqual(ProgressiveRamp.gain(elapsed: 60, duration: 60), 1, accuracy: 0.0001)
        XCTAssertEqual(ProgressiveRamp.gain(elapsed: 90, duration: 60), 1, accuracy: 0.0001)
        XCTAssertEqual(ProgressiveRamp.gain(elapsed: 0, duration: 0), 1, accuracy: 0.0001)
    }

    func testRampStartsQuieterThanAStraightLineAndIsMonotonic() {
        let early = ProgressiveRamp.gain(elapsed: 0.25, duration: 1)
        XCTAssertEqual(early, 0.15625, accuracy: 0.0001)
        XCTAssertLessThan(early, 0.25)
        let late = ProgressiveRamp.gain(elapsed: 0.75, duration: 1)
        XCTAssertGreaterThan(late, 0.75)
        var previous = -1.0
        for step in 0...20 {
            let gain = ProgressiveRamp.gain(elapsed: Double(step) / 20, duration: 1)
            XCTAssertGreaterThanOrEqual(gain, previous)
            previous = gain
        }
    }

    func testPlaybackGainStartsAtMinusTwelveDecibelsAndHoldsFull() {
        XCTAssertEqual(WakePlaybackGain.level(elapsed: 0, rampSeconds: 60), WakePlaybackGain.floorLinear, accuracy: 0.0001)
        XCTAssertEqual(WakePlaybackGain.floorDecibels, -12, accuracy: 0.001)
        XCTAssertEqual(WakePlaybackGain.level(elapsed: 90, rampSeconds: 60), 1, accuracy: 0.0001)
        XCTAssertLessThan(WakePlaybackGain.level(elapsed: 10, rampSeconds: 60), WakePlaybackGain.level(elapsed: 40, rampSeconds: 60))
    }

    func testCatalogMapsAllEightWakeFiles() {
        let expected = [
            "01-a-pocket-of-bells.caf",
            "02-keys-in-the-amber.caf",
            "03-brass-under-linen.caf",
            "04-brush-against-the-block.caf",
            "05-fifth-along-the-floor.caf",
            "06-harmonics-on-the-sill.caf",
            "07-loose-bells-slow-cadence.caf",
            "08-the-low-bloom.caf",
        ]
        let files = WakeTone.allCases.map(\.notificationSoundName)
        XCTAssertEqual(files, expected)
        XCTAssertEqual(Set(files).count, 8)
        XCTAssertEqual(WakeTone.catalog.map(\.filename), expected)
        for tone in WakeTone.allCases {
            XCTAssertTrue(tone.notificationSoundName.hasSuffix(".caf"))
            XCTAssertEqual(tone.duration, 28, accuracy: 0.001)
            XCTAssertGreaterThan(tone.loopStart, 0)
            XCTAssertLessThan(tone.loopStart, tone.duration)
            XCTAssertFalse(tone.displayName.isEmpty)
            XCTAssertFalse(tone.detail.isEmpty)
        }
    }

    func testPocketOfBellsIsTheFeaturedDefault() {
        XCTAssertEqual(WakeTone.featured, .pocketOfBells)
        XCTAssertEqual(WakeTone.allCases.first, .pocketOfBells)
        XCTAssertEqual(WakeTone.pocketOfBells.displayName, "A Pocket of Bells")
        XCTAssertEqual(WakeTone.pocketOfBells.notificationSoundName, "01-a-pocket-of-bells.caf")
        XCTAssertEqual(WakeTone.pocketOfBells.loopStart, 14, accuracy: 0.001)
        XCTAssertEqual(Alarm.weekdayMorning().tone, .pocketOfBells)
        XCTAssertEqual(WakeTone.looseBells.displayName, "Loose Bells, Slow Cadence")
        XCTAssertEqual(WakeTone.looseBells.notificationSoundName, "07-loose-bells-slow-cadence.caf")
    }

    func testLoopRegionsMatchTheWakeFiles() {
        let regions: [WakeTone: Double] = [
            .pocketOfBells: 14,
            .keysInTheAmber: 14,
            .brassUnderLinen: 12,
            .brushAgainstTheBlock: 14,
            .fifthAlongTheFloor: 14,
            .harmonicsOnTheSill: 13,
            .looseBells: 14,
            .lowBloom: 14,
        ]
        XCTAssertEqual(Set(regions.keys), Set(WakeTone.allCases))
        for (tone, start) in regions {
            XCTAssertEqual(tone.loopStart, start, accuracy: 0.001, tone.notificationSoundName)
        }
    }
}

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

    func testJingleBellsIsTheFeaturedDefault() {
        XCTAssertEqual(WakeTone.featured, .jingleBells)
        XCTAssertEqual(WakeTone.allCases.first, .jingleBells)
        XCTAssertEqual(Alarm.weekdayMorning().tone, .jingleBells)
        XCTAssertEqual(WakeTone.jingleBells.notificationSoundName, "jingleBells.wav")
    }

    func testChorusOpensWithThePublicDomainMelody() {
        let notes = JingleBellVoice.chorus.prefix(11).map(\.note)
        XCTAssertEqual(notes, [.e, .e, .e, .e, .e, .e, .e, .g, .c, .d, .e])
        XCTAssertEqual(JingleBellVoice.chorus.last?.note, .c)
        let e4 = MelodyEvent(note: .e, octave: 4, beats: 1).frequencyHz
        XCTAssertEqual(e4, 329.627, accuracy: 0.05)
    }

    func testBellVoiceIsAnInharmonicClusterWithAWarmBody() {
        let partials = JingleBellVoice.partials
        XCTAssertGreaterThanOrEqual(partials.count, 5)
        let inharmonic = partials.filter { partial in
            let nearest = round(partial.ratio)
            return abs(partial.ratio - nearest) > 0.03
        }
        XCTAssertGreaterThanOrEqual(inharmonic.count, 3)
        let highest = partials.max { $0.ratio < $1.ratio }!
        XCTAssertGreaterThan(highest.decay, JingleBellVoice.bodyDecay)
        XCTAssertEqual(JingleBellVoice.bodyRatio, 0.5)
        XCTAssertGreaterThan(JingleBellVoice.bodyAmplitude, highest.amplitude)
        XCTAssertEqual(JingleBellVoice.clusterDetune.count, 3)
        for detune in JingleBellVoice.clusterDetune {
            XCTAssertEqual(detune, 1, accuracy: 0.03)
        }
        let offsets = JingleBellVoice.shakeOffsets(duration: 0.5)
        XCTAssertGreaterThanOrEqual(offsets.count, 3)
        XCTAssertEqual(offsets.first, 0)
    }

    func testOtherTonesStayWarmAndQuietInTheOvertone() {
        for tone in WakeTone.allCases where tone != .jingleBells {
            let recipe = ToneLibrary.additive(for: tone)
            XCTAssertNotNil(recipe, tone.rawValue)
            XCTAssertGreaterThanOrEqual(recipe!.fundamentalHz, 80)
            XCTAssertLessThanOrEqual(recipe!.fundamentalHz, 180)
            XCTAssertLessThanOrEqual(recipe!.secondaryHz, 220)
            if !recipe!.alternates {
                XCTAssertLessThanOrEqual(recipe!.secondaryGain, 0.35)
            }
        }
        XCTAssertNil(ToneLibrary.additive(for: .jingleBells))
    }

    func testJingleBellsRendersRhythmicBurstsThatFollowTheRamp() {
        let full = ToneSampleSource(tone: .jingleBells, sampleRate: 8_000, rampSeconds: 0)
        let samples = full.render(frames: 16_000)
        let peaks = peakCount(samples, window: 320)
        XCTAssertGreaterThanOrEqual(peaks, 5)
        let peak = samples.map { abs($0) }.max() ?? 0
        XCTAssertGreaterThan(peak, 0.05)
        XCTAssertLessThanOrEqual(peak, 1)
        XCTAssertGreaterThan(windowEnergy(samples, start: 0, length: 1_200), 0.0001)

        let ramped = ToneSampleSource(tone: .jingleBells, sampleRate: 8_000, rampSeconds: 4)
        XCTAssertEqual(ramped.sample(at: 0), 0, accuracy: 0.0001)
        let early = windowEnergy(ramped.render(frames: 8_000), start: 0, length: 800)
        let later = windowEnergy(ramped.render(frames: 32_000), start: 24_000, length: 800)
        XCTAssertLessThan(early, later)
    }

    private func windowEnergy(_ samples: [Float], start: Int, length: Int) -> Float {
        let slice = samples[start..<min(samples.count, start + length)]
        let energy = slice.reduce(Float(0)) { $0 + $1 * $1 }
        return energy / Float(slice.count)
    }

    private func peakCount(_ samples: [Float], window: Int) -> Int {
        var rms: [Float] = []
        var index = 0
        while index + window <= samples.count {
            var energy: Float = 0
            for sample in samples[index..<(index + window)] {
                energy += sample * sample
            }
            rms.append(sqrt(energy / Float(window)))
            index += window
        }
        let maxRMS = rms.max() ?? 0
        guard maxRMS > 0 else { return 0 }
        let threshold = maxRMS * 0.35
        var peaks = 0
        for cursor in 1..<(rms.count - 1) where rms[cursor] >= threshold && rms[cursor] >= rms[cursor - 1] && rms[cursor] > rms[cursor + 1] {
            peaks += 1
        }
        return peaks
    }
}

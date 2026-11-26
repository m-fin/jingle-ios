import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Deterministic wake synthesizer shared by tests, the notification files, and the iOS engine.
public final class ToneSampleSource: @unchecked Sendable {
    public let tone: WakeTone
    public let sampleRate: Double
    public let rampSeconds: Double
    public let phraseSeconds: Double

    private struct Strike {
        var time: Double
        var frequency: Double
    }

    private let strikes: [Strike]

    public init(tone: WakeTone, sampleRate: Double = 44_100, rampSeconds: Double = 60) {
        self.tone = tone
        self.sampleRate = sampleRate
        self.rampSeconds = rampSeconds
        if tone == .jingleBells {
            phraseSeconds = JingleBellVoice.phraseSeconds
            strikes = ToneSampleSource.makeStrikes()
        } else {
            phraseSeconds = 8
            strikes = []
        }
    }

    public func sample(at frame: Int) -> Float {
        guard frame >= 0 else { return 0 }
        let time = Double(frame) / sampleRate
        let gain = ProgressiveRamp.gain(elapsed: time, duration: rampSeconds)
        let raw: Float
        if tone == .jingleBells {
            let local = phraseSeconds > 0 ? time.truncatingRemainder(dividingBy: phraseSeconds) : time
            raw = bell(at: local)
        } else {
            raw = drone(at: time)
        }
        return raw * Float(gain)
    }

    public func render(frames: Int) -> [Float] {
        guard frames > 0 else { return [] }
        if tone == .jingleBells {
            return renderBells(frames: frames)
        }
        var output = [Float]()
        output.reserveCapacity(frames)
        for frame in 0..<frames {
            output.append(sample(at: frame))
        }
        return output
    }

    private func renderBells(frames: Int) -> [Float] {
        var output = [Float](repeating: 0, count: frames)
        let kernelFrames = max(1, Int(1.35 * sampleRate))
        var kernels: [Int: [Float]] = [:]
        let phraseFrames = max(1, Int((phraseSeconds * sampleRate).rounded()))
        let wrap = frames == phraseFrames
        for strike in strikes {
            let key = Int((strike.frequency * 10).rounded())
            if kernels[key] == nil {
                kernels[key] = makeKernel(frequency: strike.frequency, frames: kernelFrames)
            }
            guard let kernel = kernels[key] else { continue }
            let start = Int((strike.time * sampleRate).rounded())
            if start >= frames { continue }
            for index in kernel.indices {
                let dest = start + index
                if dest < frames {
                    output[dest] += kernel[index]
                } else if wrap {
                    output[dest % frames] += kernel[index]
                } else {
                    break
                }
            }
        }
        for frame in 0..<frames {
            let time = Double(frame) / sampleRate
            let gain = Float(ProgressiveRamp.gain(elapsed: time, duration: rampSeconds))
            output[frame] = max(-1, min(1, output[frame] * 0.16 * gain))
        }
        return output
    }

    private func makeKernel(frequency: Double, frames: Int) -> [Float] {
        var kernel = [Float](repeating: 0, count: frames)
        for index in 0..<frames {
            let dt = Double(index) / sampleRate
            kernel[index] = Float(contribution(frequency: frequency, dt: dt))
        }
        return kernel
    }

    private func bell(at local: Double) -> Float {
        let window = 1.35
        let start = lowerBound(local - window)
        var sum = 0.0
        var index = start
        while index < strikes.count {
            let strike = strikes[index]
            if strike.time > local { break }
            let dt = local - strike.time
            if dt >= 0, dt <= window {
                sum += contribution(frequency: strike.frequency, dt: dt)
            }
            index += 1
        }
        return Float(max(-1, min(1, sum * 0.16)))
    }

    private func contribution(frequency: Double, dt: Double) -> Double {
        var sum = 0.0
        for partial in JingleBellVoice.partials {
            let amp = partial.amplitude * exp(-partial.decay * dt)
            sum += amp * sin(2 * Double.pi * frequency * partial.ratio * dt)
        }
        let body = JingleBellVoice.bodyAmplitude * exp(-JingleBellVoice.bodyDecay * dt)
        sum += body * sin(2 * Double.pi * frequency * JingleBellVoice.bodyRatio * dt)
        return sum
    }

    private func drone(at time: Double) -> Float {
        guard let recipe = ToneLibrary.additive(for: tone) else { return 0 }
        if recipe.alternates {
            let mix = 0.5 + 0.5 * sin(2 * Double.pi * (1.0 / 6.0) * time)
            let low = sin(2 * Double.pi * recipe.fundamentalHz * time)
            let high = sin(2 * Double.pi * recipe.secondaryHz * time)
            return Float((mix * low + (1 - mix) * high) * 0.42)
        }
        let tremolo = 0.78 + 0.22 * sin(2 * Double.pi * 0.12 * time)
        let fundamental = sin(2 * Double.pi * recipe.fundamentalHz * time)
        let overtone = recipe.secondaryGain * sin(2 * Double.pi * recipe.secondaryHz * time)
        let air = 0.05 * sin(2 * Double.pi * recipe.fundamentalHz * 2 * time)
        return Float((fundamental + overtone + air) * tremolo * 0.34)
    }

    private func lowerBound(_ time: Double) -> Int {
        var low = 0
        var high = strikes.count
        while low < high {
            let mid = (low + high) / 2
            if strikes[mid].time < time {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }

    private static func makeStrikes() -> [Strike] {
        var strikes: [Strike] = []
        var noteStart = 0.0
        for event in JingleBellVoice.chorus {
            let duration = event.beats * JingleBellVoice.quarterNoteSeconds
            let frequency = event.frequencyHz
            for offset in JingleBellVoice.shakeOffsets(duration: duration) {
                for index in JingleBellVoice.clusterDetune.indices {
                    let detune = JingleBellVoice.clusterDetune[index]
                    let delay = JingleBellVoice.clusterDelay[index]
                    let time = noteStart + offset + delay
                    if time < noteStart + duration + 0.02 {
                        strikes.append(Strike(time: time, frequency: frequency * detune))
                    }
                }
            }
            noteStart += duration
        }
        return strikes.sorted { $0.time < $1.time }
    }
}

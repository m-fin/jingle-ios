import Foundation

public enum ScaleNote: String, Equatable, Sendable, CaseIterable {
    case c, d, e, f, g, a, b

    public var semitone: Int {
        switch self {
        case .c: return 0
        case .d: return 2
        case .e: return 4
        case .f: return 5
        case .g: return 7
        case .a: return 9
        case .b: return 11
        }
    }
}

public struct MelodyEvent: Equatable, Sendable {
    public var note: ScaleNote
    public var octave: Int
    public var beats: Double

    public init(note: ScaleNote, octave: Int, beats: Double) {
        self.note = note
        self.octave = octave
        self.beats = beats
    }

    public var frequencyHz: Double {
        let midi = (octave + 1) * 12 + note.semitone
        return 440.0 * pow(2.0, Double(midi - 69) / 12.0)
    }
}

public struct BellPartial: Equatable, Sendable {
    public var ratio: Double
    public var amplitude: Double
    public var decay: Double

    public init(ratio: Double, amplitude: Double, decay: Double) {
        self.ratio = ratio
        self.amplitude = amplitude
        self.decay = decay
    }
}

/// Original sleigh-bell voice for the public-domain Jingle Bells melody (Pierpont, 1857).
/// Partials are an inharmonic metallic cluster. A slower body partial supplies warm resonance.
public enum JingleBellVoice {
    public static let quarterNoteSeconds: Double = 0.52

    public static let partials: [BellPartial] = [
        BellPartial(ratio: 1.00, amplitude: 0.48, decay: 3.4),
        BellPartial(ratio: 1.42, amplitude: 0.30, decay: 5.1),
        BellPartial(ratio: 2.03, amplitude: 0.22, decay: 6.8),
        BellPartial(ratio: 2.76, amplitude: 0.15, decay: 9.0),
        BellPartial(ratio: 3.58, amplitude: 0.09, decay: 12.0),
        BellPartial(ratio: 4.91, amplitude: 0.05, decay: 15.5),
    ]

    /// Wood and brass body under the metal, an octave below the strike, decaying slowly.
    public static let bodyRatio: Double = 0.5
    public static let bodyAmplitude: Double = 0.46
    public static let bodyDecay: Double = 1.15

    /// Three bells in one cluster, slightly detuned, shaken a few milliseconds apart.
    public static let clusterDetune: [Double] = [1.0, 1.018, 0.984]
    public static let clusterDelay: [Double] = [0.0, 0.009, 0.017]

    public static func shakeOffsets(duration: Double) -> [Double] {
        var times = [0.0, 0.055, 0.11]
        if duration > 0.85 {
            var cursor = 0.42
            while cursor < duration - 0.08 {
                times.append(cursor)
                times.append(cursor + 0.055)
                cursor += 0.42
            }
        }
        return times.filter { $0 < duration }
    }

    /// Chorus of Jingle Bells in C, held in a bedside register (C4–G4).
    public static let chorus: [MelodyEvent] = [
        MelodyEvent(note: .e, octave: 4, beats: 1),
        MelodyEvent(note: .e, octave: 4, beats: 1),
        MelodyEvent(note: .e, octave: 4, beats: 2),
        MelodyEvent(note: .e, octave: 4, beats: 1),
        MelodyEvent(note: .e, octave: 4, beats: 1),
        MelodyEvent(note: .e, octave: 4, beats: 2),
        MelodyEvent(note: .e, octave: 4, beats: 1),
        MelodyEvent(note: .g, octave: 4, beats: 1),
        MelodyEvent(note: .c, octave: 4, beats: 1),
        MelodyEvent(note: .d, octave: 4, beats: 1),
        MelodyEvent(note: .e, octave: 4, beats: 4),
        MelodyEvent(note: .f, octave: 4, beats: 1),
        MelodyEvent(note: .f, octave: 4, beats: 1),
        MelodyEvent(note: .f, octave: 4, beats: 1),
        MelodyEvent(note: .f, octave: 4, beats: 1),
        MelodyEvent(note: .f, octave: 4, beats: 1),
        MelodyEvent(note: .e, octave: 4, beats: 1),
        MelodyEvent(note: .e, octave: 4, beats: 1),
        MelodyEvent(note: .e, octave: 4, beats: 0.5),
        MelodyEvent(note: .e, octave: 4, beats: 0.5),
        MelodyEvent(note: .e, octave: 4, beats: 1),
        MelodyEvent(note: .d, octave: 4, beats: 1),
        MelodyEvent(note: .d, octave: 4, beats: 1),
        MelodyEvent(note: .e, octave: 4, beats: 1),
        MelodyEvent(note: .d, octave: 4, beats: 2),
        MelodyEvent(note: .g, octave: 4, beats: 2),
        MelodyEvent(note: .e, octave: 4, beats: 1),
        MelodyEvent(note: .e, octave: 4, beats: 1),
        MelodyEvent(note: .e, octave: 4, beats: 2),
        MelodyEvent(note: .e, octave: 4, beats: 1),
        MelodyEvent(note: .e, octave: 4, beats: 1),
        MelodyEvent(note: .e, octave: 4, beats: 2),
        MelodyEvent(note: .e, octave: 4, beats: 1),
        MelodyEvent(note: .g, octave: 4, beats: 1),
        MelodyEvent(note: .c, octave: 4, beats: 1),
        MelodyEvent(note: .d, octave: 4, beats: 1),
        MelodyEvent(note: .e, octave: 4, beats: 4),
        MelodyEvent(note: .f, octave: 4, beats: 1),
        MelodyEvent(note: .f, octave: 4, beats: 1),
        MelodyEvent(note: .f, octave: 4, beats: 1),
        MelodyEvent(note: .f, octave: 4, beats: 1),
        MelodyEvent(note: .f, octave: 4, beats: 1),
        MelodyEvent(note: .e, octave: 4, beats: 1),
        MelodyEvent(note: .e, octave: 4, beats: 1),
        MelodyEvent(note: .e, octave: 4, beats: 0.5),
        MelodyEvent(note: .e, octave: 4, beats: 0.5),
        MelodyEvent(note: .g, octave: 4, beats: 1),
        MelodyEvent(note: .g, octave: 4, beats: 1),
        MelodyEvent(note: .f, octave: 4, beats: 1),
        MelodyEvent(note: .d, octave: 4, beats: 1),
        MelodyEvent(note: .c, octave: 4, beats: 4),
    ]

    public static var phraseSeconds: Double {
        chorus.reduce(0) { $0 + $1.beats * quarterNoteSeconds }
    }
}

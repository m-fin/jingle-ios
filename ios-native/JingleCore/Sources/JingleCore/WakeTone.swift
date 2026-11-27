import Foundation

/// Wake tones from *The Unstartled Morning* by Matthew Finley.
/// Each file is a 28-second linear PCM CAF that iOS can play as a notification sound.
public struct WakeToneFile: Equatable, Sendable {
    public var tone: WakeTone
    public var title: String
    public var detail: String
    public var filename: String
    /// Seconds into the file where the stable body begins. Loops start here, not at the quiet opening.
    public var loopStart: Double
    public var duration: Double

    public init(tone: WakeTone, title: String, detail: String, filename: String, loopStart: Double, duration: Double) {
        self.tone = tone
        self.title = title
        self.detail = detail
        self.filename = filename
        self.loopStart = loopStart
        self.duration = duration
    }
}

public enum WakeTone: String, Codable, CaseIterable, Sendable, Hashable {
    case pocketOfBells
    case keysInTheAmber
    case brassUnderLinen
    case brushAgainstTheBlock
    case fifthAlongTheFloor
    case harmonicsOnTheSill
    case looseBells
    case lowBloom

    public static let featured: WakeTone = .pocketOfBells

    public var displayName: String { file.title }
    public var detail: String { file.detail }
    public var notificationSoundName: String { file.filename }
    public var loopStart: Double { file.loopStart }
    public var duration: Double { file.duration }

    public var file: WakeToneFile {
        switch self {
        case .pocketOfBells:
            return WakeToneFile(
                tone: self,
                title: "A Pocket of Bells",
                detail: "Jingle bells in a soft pouch",
                filename: "01-a-pocket-of-bells.caf",
                loopStart: 14,
                duration: 28
            )
        case .keysInTheAmber:
            return WakeToneFile(
                tone: self,
                title: "Keys in the Amber",
                detail: "Warm electric piano",
                filename: "02-keys-in-the-amber.caf",
                loopStart: 14,
                duration: 28
            )
        case .brassUnderLinen:
            return WakeToneFile(
                tone: self,
                title: "Brass Under Linen",
                detail: "Low brass and strings",
                filename: "03-brass-under-linen.caf",
                loopStart: 12,
                duration: 28
            )
        case .brushAgainstTheBlock:
            return WakeToneFile(
                tone: self,
                title: "Brush Against the Block",
                detail: "Soft woodblock pulse",
                filename: "04-brush-against-the-block.caf",
                loopStart: 14,
                duration: 28
            )
        case .fifthAlongTheFloor:
            return WakeToneFile(
                tone: self,
                title: "Fifth Along the Floor",
                detail: "Cello and marimba",
                filename: "05-fifth-along-the-floor.caf",
                loopStart: 14,
                duration: 28
            )
        case .harmonicsOnTheSill:
            return WakeToneFile(
                tone: self,
                title: "Harmonics on the Sill",
                detail: "Quiet harp harmonics",
                filename: "06-harmonics-on-the-sill.caf",
                loopStart: 13,
                duration: 28
            )
        case .looseBells:
            return WakeToneFile(
                tone: self,
                title: "Loose Bells, Slow Cadence",
                detail: "Slower jingle bells",
                filename: "07-loose-bells-slow-cadence.caf",
                loopStart: 14,
                duration: 28
            )
        case .lowBloom:
            return WakeToneFile(
                tone: self,
                title: "The Low Bloom",
                detail: "A low sunrise chord",
                filename: "08-the-low-bloom.caf",
                loopStart: 14,
                duration: 28
            )
        }
    }

    public static var catalog: [WakeToneFile] {
        allCases.map(\.file)
    }
}

/// Extra level on top of a tone file. The file already rises; this moves from −12 dB to full, then holds.
public enum WakePlaybackGain {
    public static let floorDecibels = -12.0
    public static var floorLinear: Double { pow(10, floorDecibels / 20) }

    public static func level(elapsed: TimeInterval, rampSeconds: TimeInterval) -> Double {
        let curve = ProgressiveRamp.gain(elapsed: elapsed, duration: rampSeconds)
        return floorLinear + (1 - floorLinear) * curve
    }
}

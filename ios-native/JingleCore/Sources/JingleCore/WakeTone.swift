import Foundation

/// Original wake voices. Jingle Bells is the featured default.
public enum WakeTone: String, Codable, CaseIterable, Sendable, Hashable {
    case jingleBells
    case hearth
    case amber
    case linen
    case tide

    public static let featured: WakeTone = .jingleBells

    public var displayName: String {
        switch self {
        case .jingleBells: return "Jingle Bells"
        case .hearth: return "Hearth"
        case .amber: return "Amber"
        case .linen: return "Linen"
        case .tide: return "Tide"
        }
    }

    public var detail: String {
        switch self {
        case .jingleBells: return "Sleigh bells with a gentle rise"
        case .hearth: return "Warm low drone"
        case .amber: return "Soft golden hum"
        case .linen: return "Quiet bedside tone"
        case .tide: return "Slow two-note swell"
        }
    }

    /// Bundle resource used when iOS plays the locked-phone alert.
    public var notificationSoundName: String {
        rawValue + ".wav"
    }
}

/// Steady additive voices. Jingle Bells uses `JingleBellVoice` instead.
public struct AdditiveTone: Equatable, Sendable {
    public var fundamentalHz: Double
    public var secondaryHz: Double
    public var secondaryGain: Double
    /// When true, the two pitches trade places instead of stacking.
    public var alternates: Bool

    public init(fundamentalHz: Double, secondaryHz: Double, secondaryGain: Double, alternates: Bool) {
        self.fundamentalHz = fundamentalHz
        self.secondaryHz = secondaryHz
        self.secondaryGain = secondaryGain
        self.alternates = alternates
    }
}

public enum ToneLibrary {
    public static func additive(for tone: WakeTone) -> AdditiveTone? {
        switch tone {
        case .jingleBells:
            return nil
        case .hearth:
            return AdditiveTone(fundamentalHz: 110, secondaryHz: 164.81, secondaryGain: 0.20, alternates: false)
        case .amber:
            return AdditiveTone(fundamentalHz: 98, secondaryHz: 146.83, secondaryGain: 0.16, alternates: false)
        case .linen:
            return AdditiveTone(fundamentalHz: 130.81, secondaryHz: 196, secondaryGain: 0.12, alternates: false)
        case .tide:
            return AdditiveTone(fundamentalHz: 82.41, secondaryHz: 123.47, secondaryGain: 1, alternates: true)
        }
    }
}

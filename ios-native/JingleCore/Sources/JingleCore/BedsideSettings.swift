import Foundation

/// Visual skins for the native bedside clock. Matte Black and Bitcoin Orange are the
/// launch colorways from the product brief. Stone is the moodboard putty / mist colorway.
public enum AppearanceTheme: String, Codable, CaseIterable, Sendable, Hashable {
    case matteBlack
    case stone
    case bitcoinOrange

    public var displayName: String {
        switch self {
        case .matteBlack: return "Matte Black"
        case .stone: return "Stone"
        case .bitcoinOrange: return "Bitcoin Orange"
        }
    }

    public var detail: String {
        switch self {
        case .matteBlack: return "Blends into night"
        case .stone: return "Moodboard putty and mist"
        case .bitcoinOrange: return "Wake and stack sats"
        }
    }

    public var prefersDarkInterface: Bool {
        self != .stone
    }
}

public struct BedsideSettings: Codable, Equatable, Sendable {
    public static let storageVersion = 1
    public static let blankAfter: TimeInterval = 45
    public static let dimLevel: Double = 0.34
    public static let blankDimLevel: Double = 0.02

    public var theme: AppearanceTheme
    public var autoBlank: Bool
    public var bedsideDim: Bool

    public init(theme: AppearanceTheme = .matteBlack, autoBlank: Bool = true, bedsideDim: Bool = true) {
        self.theme = theme
        self.autoBlank = autoBlank
        self.bedsideDim = bedsideDim
    }

    public static let `default` = BedsideSettings()

    public func normalized() -> BedsideSettings {
        self
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        theme = (try container.decodeIfPresent(AppearanceTheme.self, forKey: .theme)) ?? .matteBlack
        autoBlank = try container.decodeIfPresent(Bool.self, forKey: .autoBlank) ?? true
        bedsideDim = try container.decodeIfPresent(Bool.self, forKey: .bedsideDim) ?? true
    }
}

public final class BedsideSettingsStore {
    public static let storageKey = "jingle.settings.v1"

    private let store: KeyValueStoring
    private let key: String

    public init(store: KeyValueStoring, key: String = BedsideSettingsStore.storageKey) {
        self.store = store
        self.key = key
    }

    public static func appGroup() -> BedsideSettingsStore {
        let defaults = UserDefaults(suiteName: AlarmStore.appGroupIdentifier) ?? .standard
        return BedsideSettingsStore(store: defaults)
    }

    public func load() -> BedsideSettings {
        guard let data = store.data(forKey: key) else { return .default }
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return .default }
        guard (raw["version"] as? Int) == BedsideSettings.storageVersion else { return .default }
        let theme = AppearanceTheme(rawValue: (raw["theme"] as? String) ?? "") ?? .matteBlack
        let autoBlank = raw["autoBlank"] as? Bool ?? true
        let bedsideDim = raw["bedsideDim"] as? Bool ?? true
        return BedsideSettings(theme: theme, autoBlank: autoBlank, bedsideDim: bedsideDim)
    }

    public func save(_ settings: BedsideSettings) {
        let raw: [String: Any] = [
            "version": BedsideSettings.storageVersion,
            "theme": settings.theme.rawValue,
            "autoBlank": settings.autoBlank,
            "bedsideDim": settings.bedsideDim,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: raw, options: [.sortedKeys]) else { return }
        store.set(data, forKey: key)
    }
}

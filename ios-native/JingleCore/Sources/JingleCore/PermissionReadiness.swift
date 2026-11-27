import Foundation

public enum NotificationAuthorization: String, Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
}

public struct PermissionSignals: Equatable, Sendable {
    public var authorization: NotificationAuthorization
    public var soundOn: Bool
    public var timeSensitiveOn: Bool
    public var liveActivitiesOn: Bool

    public init(
        authorization: NotificationAuthorization,
        soundOn: Bool,
        timeSensitiveOn: Bool,
        liveActivitiesOn: Bool
    ) {
        self.authorization = authorization
        self.soundOn = soundOn
        self.timeSensitiveOn = timeSensitiveOn
        self.liveActivitiesOn = liveActivitiesOn
    }
}

public enum PermissionGap: String, Equatable, Sendable, CaseIterable {
    case notifications
    case sound
    case timeSensitive
    case liveActivities

    public var sentence: String {
        switch self {
        case .notifications: return "Notifications are off."
        case .sound: return "Notification sound is off."
        case .timeSensitive: return "Time Sensitive alerts are off."
        case .liveActivities: return "Live Activities are off."
        }
    }
}

public struct PermissionReadiness: Equatable, Sendable {
    public static let ringSwitchNote = "Set the Ring/Silent switch to Ring so a locked iPhone can start the alert."

    public var authorization: NotificationAuthorization
    public var gaps: [PermissionGap]
    public var showsSettingsBanner: Bool
    public var bannerMessage: String
    public var ringSwitchNote: String
    public var liveActivityNote: String?
    public var settingsButtonTitle: String
    public var requestsPromptInsteadOfSettings: Bool

    public init(
        authorization: NotificationAuthorization,
        gaps: [PermissionGap],
        showsSettingsBanner: Bool,
        bannerMessage: String,
        ringSwitchNote: String,
        liveActivityNote: String?,
        settingsButtonTitle: String,
        requestsPromptInsteadOfSettings: Bool
    ) {
        self.authorization = authorization
        self.gaps = gaps
        self.showsSettingsBanner = showsSettingsBanner
        self.bannerMessage = bannerMessage
        self.ringSwitchNote = ringSwitchNote
        self.liveActivityNote = liveActivityNote
        self.settingsButtonTitle = settingsButtonTitle
        self.requestsPromptInsteadOfSettings = requestsPromptInsteadOfSettings
    }
}

public enum PermissionReadinessEvaluator {
    public static func evaluate(_ signals: PermissionSignals) -> PermissionReadiness {
        var gaps: [PermissionGap] = []
        if signals.authorization != .authorized {
            gaps.append(.notifications)
        }
        if !signals.soundOn {
            gaps.append(.sound)
        }
        if !signals.timeSensitiveOn {
            gaps.append(.timeSensitive)
        }
        if !signals.liveActivitiesOn {
            gaps.append(.liveActivities)
        }
        let bannerGaps = gaps.filter { $0 != .liveActivities }
        let banner = bannerGaps.map(\.sentence).joined(separator: " ")
        let prompt = signals.authorization == .notDetermined
        return PermissionReadiness(
            authorization: signals.authorization,
            gaps: gaps,
            showsSettingsBanner: !bannerGaps.isEmpty,
            bannerMessage: banner,
            ringSwitchNote: bannerGaps.isEmpty ? "" : PermissionReadiness.ringSwitchNote,
            liveActivityNote: gaps.contains(.liveActivities)
                ? "Live Activities are off, so the Lock Screen and Dynamic Island will not show the countdown."
                : nil,
            settingsButtonTitle: prompt ? "Allow Notifications" : "Open Settings",
            requestsPromptInsteadOfSettings: prompt
        )
    }
}

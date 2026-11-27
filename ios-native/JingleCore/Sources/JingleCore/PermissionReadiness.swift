import Foundation

public enum NotificationAuthorization: String, Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
}

/// AlarmKit authorization. `.unavailable` means this OS has no AlarmKit.
public enum AlarmKitAuthorization: String, Equatable, Sendable {
    case unavailable
    case notDetermined
    case authorized
    case denied
}

public struct PermissionSignals: Equatable, Sendable {
    public var authorization: NotificationAuthorization
    public var soundOn: Bool
    public var timeSensitiveOn: Bool
    public var liveActivitiesOn: Bool
    public var alarmKit: AlarmKitAuthorization

    public init(
        authorization: NotificationAuthorization,
        soundOn: Bool,
        timeSensitiveOn: Bool,
        liveActivitiesOn: Bool,
        alarmKit: AlarmKitAuthorization = .unavailable
    ) {
        self.authorization = authorization
        self.soundOn = soundOn
        self.timeSensitiveOn = timeSensitiveOn
        self.liveActivitiesOn = liveActivitiesOn
        self.alarmKit = alarmKit
    }
}

public enum PermissionGap: String, Equatable, Sendable, CaseIterable {
    case notifications
    case sound
    case timeSensitive
    case liveActivities
    case alarmKit

    public var sentence: String {
        switch self {
        case .notifications: return "Notifications are off."
        case .sound: return "Notification sound is off."
        case .timeSensitive: return "Time Sensitive alerts are off."
        case .liveActivities: return "Live Activities are off."
        case .alarmKit: return "Alarm access is off."
        }
    }
}

public struct PermissionReadiness: Equatable, Sendable {
    public static let ringSwitchNote = "A locked notification follows the Ring/Silent switch. Allow Alarms, or leave Jingle open, to ring on silent too."

    public var authorization: NotificationAuthorization
    public var alarmKit: AlarmKitAuthorization
    public var gaps: [PermissionGap]
    public var showsSettingsBanner: Bool
    public var bannerMessage: String
    public var ringSwitchNote: String
    public var liveActivityNote: String?
    public var settingsButtonTitle: String
    public var requestsPromptInsteadOfSettings: Bool

    public init(
        authorization: NotificationAuthorization,
        alarmKit: AlarmKitAuthorization,
        gaps: [PermissionGap],
        showsSettingsBanner: Bool,
        bannerMessage: String,
        ringSwitchNote: String,
        liveActivityNote: String?,
        settingsButtonTitle: String,
        requestsPromptInsteadOfSettings: Bool
    ) {
        self.authorization = authorization
        self.alarmKit = alarmKit
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
        if signals.alarmKit == .denied || signals.alarmKit == .notDetermined {
            gaps.append(.alarmKit)
        }
        let bannerGaps = gaps.filter { $0 != .liveActivities }
        let banner = bannerGaps.map(\.sentence).joined(separator: " ")
        let needsNotificationPrompt = signals.authorization == .notDetermined
        let needsAlarmPrompt = signals.alarmKit == .notDetermined
        let prompt = needsNotificationPrompt || needsAlarmPrompt
        let button: String
        if needsNotificationPrompt {
            button = "Allow Notifications"
        } else if needsAlarmPrompt {
            button = "Allow Alarms"
        } else {
            button = "Open Settings"
        }
        let mentionSwitch = !bannerGaps.isEmpty && signals.alarmKit != .authorized
        return PermissionReadiness(
            authorization: signals.authorization,
            alarmKit: signals.alarmKit,
            gaps: gaps,
            showsSettingsBanner: !bannerGaps.isEmpty,
            bannerMessage: banner,
            ringSwitchNote: mentionSwitch ? PermissionReadiness.ringSwitchNote : "",
            liveActivityNote: gaps.contains(.liveActivities)
                ? "Live Activities are off, so the Lock Screen and Dynamic Island will not show the countdown."
                : nil,
            settingsButtonTitle: button,
            requestsPromptInsteadOfSettings: prompt
        )
    }
}

import ActivityKit
import JingleCore
import UIKit
import UserNotifications
#if canImport(AlarmKit)
import AlarmKit
#endif

@MainActor
final class AlarmPermissionsManager: ObservableObject {
    func signals() async -> PermissionSignals {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return PermissionSignals(
            authorization: Self.authorization(settings.authorizationStatus),
            soundOn: settings.soundSetting == .enabled,
            timeSensitiveOn: settings.timeSensitiveSetting == .enabled,
            liveActivitiesOn: ActivityAuthorizationInfo().areActivitiesEnabled,
            alarmKit: alarmKitAuthorization()
        )
    }

    func requestAuthorization() async -> PermissionSignals {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: Self.authorizationOptions())
        await requestAlarmKitIfNeeded()
        return await signals()
    }

    private static func authorizationOptions() -> UNAuthorizationOptions {
        var options: UNAuthorizationOptions = []
        for option in NotificationAuthorizationRequest.options {
            switch option {
            case .alert: options.insert(.alert)
            case .sound: options.insert(.sound)
            case .badge: options.insert(.badge)
            case .timeSensitive: options.insert(.timeSensitive)
            }
        }
        return options
    }

    private func requestAlarmKitIfNeeded() async {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            guard AlarmManager.shared.authorizationState == .notDetermined else { return }
            _ = try? await AlarmManager.shared.requestAuthorization()
        }
        #endif
    }

    private func alarmKitAuthorization() -> AlarmKitAuthorization {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            switch AlarmManager.shared.authorizationState {
            case .notDetermined: return .notDetermined
            case .authorized: return .authorized
            case .denied: return .denied
            @unknown default: return .denied
            }
        }
        #endif
        return .unavailable
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private static func authorization(_ status: UNAuthorizationStatus) -> NotificationAuthorization {
        switch status {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized: return .authorized
        case .provisional: return .provisional
        case .ephemeral: return .ephemeral
        @unknown default: return .denied
        }
    }
}

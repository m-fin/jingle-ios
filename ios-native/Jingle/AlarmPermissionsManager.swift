import ActivityKit
import JingleCore
import UIKit
import UserNotifications

@MainActor
final class AlarmPermissionsManager: ObservableObject {
    func signals() async -> PermissionSignals {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return PermissionSignals(
            authorization: Self.authorization(settings.authorizationStatus),
            soundOn: settings.soundSetting == .enabled,
            timeSensitiveOn: settings.timeSensitiveSetting == .enabled,
            liveActivitiesOn: ActivityAuthorizationInfo().areActivitiesEnabled
        )
    }

    func requestAuthorization() async -> PermissionSignals {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        return await signals()
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

import Foundation
import JingleCore
import UserNotifications

/// Installed at launch so a foreground alarm is not dropped before SwiftUI builds the scene.
/// `willPresent` asks for a banner, the notification list, and sound, and starts playback.
final class JingleNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = JingleNotificationDelegate()

    weak var controller: AlarmController?

    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    static var presentationOptions: UNNotificationPresentationOptions {
        let presentation = AlarmNotificationPlanner.foregroundPresentation
        var options: UNNotificationPresentationOptions = []
        if presentation.showsBanner { options.insert(.banner) }
        if presentation.showsList { options.insert(.list) }
        if presentation.playsSound { options.insert(.sound) }
        return options
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        guard let controller else {
            completionHandler(Self.presentationOptions)
            return
        }
        controller.userNotificationCenter(
            center,
            willPresent: notification,
            withCompletionHandler: completionHandler
        )
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard let controller else {
            completionHandler()
            return
        }
        controller.userNotificationCenter(
            center,
            didReceive: response,
            withCompletionHandler: completionHandler
        )
    }
}

enum BundledWakeSound {
    /// `url(forResource:)` does not walk subfolders, so a hit is the bundle root.
    /// The header check refuses a file that would decode as silence.
    static func choice(for fileName: String) -> NotificationSoundChoice {
        let stem = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        guard let url = Bundle.main.url(forResource: stem, withExtension: ext),
              url.lastPathComponent == fileName,
              let data = try? Data(contentsOf: url),
              let header = CAFNotificationSound.header(of: data) else {
            return .systemDefault
        }
        return NotificationSoundLookup.resolve(
            requestedFileName: fileName,
            bundled: [BundledSoundFile(fileName: fileName)],
            header: header
        )
    }

    static func notificationSound(for fileName: String) -> UNNotificationSound {
        switch choice(for: fileName) {
        case .custom(let name):
            return UNNotificationSound(named: UNNotificationSoundName(rawValue: name))
        case .systemDefault:
            return .default
        }
    }
}

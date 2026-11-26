import ActivityKit
import AppIntents
import Foundation
import JingleCore
import UserNotifications

struct DismissJingleAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Dismiss"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Alarm")
    var alarmID: String

    init() {
        alarmID = ""
    }

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    func perform() async throws -> some IntentResult {
        let store = AlarmStore.appGroup()
        var library = store.load()
        library.recordDismissal(alarmID: alarmID, at: Date())
        store.save(library)
        LibraryNotifier.postChanged()
        let center = UNUserNotificationCenter.current()
        let delivered = await center.deliveredNotifications()
        let identifiers = delivered.map(\.request.identifier).filter {
            AlarmNotificationIdentity.alarmID(from: $0) == alarmID
        }
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
        for activity in Activity<JingleAlarmAttributes>.activities where activity.attributes.alarmID == alarmID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return .result()
    }
}

enum LibraryNotifier {
    static func postChanged() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(rawValue: AlarmLibraryEvents.changedNotification as CFString),
            nil,
            nil,
            true
        )
    }
}

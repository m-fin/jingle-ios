import Foundation
import JingleCore
import UserNotifications

final class AlarmNotificationScheduler {
    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    init(center: UNUserNotificationCenter = .current(), calendar: Calendar = .current) {
        self.center = center
        self.calendar = calendar
    }

    func registerCategories() {
        let dismiss = UNNotificationAction(
            identifier: AlarmNotificationPlanner.dismissAction.identifier,
            title: AlarmNotificationPlanner.dismissAction.title,
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: AlarmNotificationIdentity.categoryIdentifier,
            actions: [dismiss],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([category])
    }

    func clearDelivered(for alarmID: String) async {
        let delivered = await center.deliveredNotifications()
        let identifiers = delivered.map(\.request.identifier).filter {
            AlarmNotificationIdentity.alarmID(from: $0) == alarmID
        }
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func reschedule(alarms: [Alarm], now: Date) async {
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter {
            $0.hasPrefix(AlarmNotificationIdentity.prefix) || $0.hasPrefix(AlarmNotificationIdentity.machinePrefix)
        }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        let plans = AlarmNotificationPlanner.requests(for: alarms, now: now, calendar: calendar)
        for plan in plans {
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.body = plan.body
            content.categoryIdentifier = plan.categoryIdentifier
            content.threadIdentifier = AlarmNotificationIdentity.categoryIdentifier
            content.interruptionLevel = .timeSensitive
            content.sound = sound(named: plan.soundName)

            var components = DateComponents()
            components.calendar = calendar
            components.timeZone = calendar.timeZone
            if let fireDate = plan.fireDate {
                let parts = calendar.dateComponents([.year, .month, .day], from: fireDate)
                components.year = parts.year
                components.month = parts.month
                components.day = parts.day
            }
            components.hour = plan.hour
            components.minute = plan.minute
            components.second = 0
            if let weekday = plan.weekday {
                components.weekday = weekday.rawValue
            }
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: plan.repeats)
            let request = UNNotificationRequest(identifier: plan.identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    private func sound(named fileName: String) -> UNNotificationSound {
        let stem = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        if Bundle.main.url(forResource: stem, withExtension: ext) != nil {
            return UNNotificationSound(named: UNNotificationSoundName(rawValue: fileName))
        }
        return .default
    }
}

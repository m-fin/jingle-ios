import Foundation
import JingleCore
import SwiftUI

#if canImport(AlarmKit)
import AlarmKit
import AppIntents
#endif

/// Schedules AlarmKit alarms when iOS 26 allows it. Those alerts ring on the lock
/// screen and while the Ring/Silent switch is on silent. Returns false when the
/// system did not take the alarms, so the caller can schedule a local notification.
enum SystemAlarmScheduler {
    static func sync(_ drafts: [SystemAlarmDraft]) async -> Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            return await AlarmKitBridge.sync(drafts)
        }
        #endif
        return false
    }

    static func cancelRemembered() {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            AlarmKitBridge.cancelRemembered()
        }
        #endif
    }
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
private struct JingleAlarmMetadata: AlarmMetadata {
    var alarmID: String
}

@available(iOS 26.0, *)
private enum AlarmKitBridge {
    static func sync(_ drafts: [SystemAlarmDraft]) async -> Bool {
        let manager = AlarmManager.shared
        guard manager.authorizationState == .authorized else { return false }
        cancel(ids: SystemAlarmLedger.load() + drafts.map(\.systemID))
        if drafts.isEmpty {
            SystemAlarmLedger.save([])
            return true
        }
        for draft in drafts {
            do {
                try await manager.schedule(id: draft.systemID, configuration: configuration(for: draft))
            } catch {
                cancel(ids: drafts.map(\.systemID))
                SystemAlarmLedger.save([])
                return false
            }
        }
        SystemAlarmLedger.save(drafts.map(\.systemID))
        return true
    }

    static func cancelRemembered() {
        cancel(ids: SystemAlarmLedger.load())
        SystemAlarmLedger.save([])
    }

    private static func cancel(ids: [UUID]) {
        for id in Set(ids) {
            try? AlarmManager.shared.cancel(id: id)
        }
    }

    private static func configuration(
        for draft: SystemAlarmDraft
    ) -> AlarmManager.AlarmConfiguration<JingleAlarmMetadata> {
        let stop = AlarmButton(
            text: "Dismiss",
            textColor: .white,
            systemImageName: "stop.circle"
        )
        let label = draft.title
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource("\(label)"),
            stopButton: stop
        )
        let attributes = AlarmAttributes<JingleAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            metadata: JingleAlarmMetadata(alarmID: draft.alarmID),
            tintColor: JingleTheme.orange
        )
        let time = Alarm.Schedule.Relative.Time(hour: draft.hour, minute: draft.minute)
        let schedule: Alarm.Schedule
        if draft.weekdays.isEmpty {
            schedule = .relative(.init(time: time, repeats: .never))
        } else {
            schedule = .relative(.init(time: time, repeats: .weekly(draft.weekdays.map(localeWeekday))))
        }
        let sound: AlertConfiguration.AlertSound
        switch BundledWakeSound.choice(for: draft.soundFileName) {
        case .custom(let name):
            sound = .named(name)
        case .systemDefault:
            sound = .default
        }
        return AlarmManager.AlarmConfiguration(
            countdownDuration: nil,
            schedule: schedule,
            attributes: attributes,
            stopIntent: DismissJingleAlarmIntent(alarmID: draft.alarmID),
            sound: sound
        )
    }

    private static func localeWeekday(_ day: Weekday) -> Locale.Weekday {
        switch day {
        case .sunday: return .sunday
        case .monday: return .monday
        case .tuesday: return .tuesday
        case .wednesday: return .wednesday
        case .thursday: return .thursday
        case .friday: return .friday
        case .saturday: return .saturday
        }
    }
}
#endif

private enum SystemAlarmLedger {
    private static let key = "jingle.systemAlarmIDs"

    static func load() -> [UUID] {
        let stored = UserDefaults.standard.stringArray(forKey: key) ?? []
        return stored.compactMap(UUID.init(uuidString:))
    }

    static func save(_ ids: [UUID]) {
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: key)
    }
}

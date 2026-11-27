import Foundation
import JingleCore
import SwiftUI
import UIKit
import UserNotifications
import WidgetKit

@MainActor
final class AlarmController: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var library: AlarmLibrary = .empty
    @Published var now = Date()
    @Published var readiness = PermissionReadinessEvaluator.evaluate(
        PermissionSignals(authorization: .notDetermined, soundOn: false, timeSensitiveOn: false, liveActivitiesOn: false)
    )
    @Published var ringingAlarmID: String?
    @Published var machineAlarmID: String?
    @Published var editor: EditorDraft?
    @Published var showingSettings = false
    @Published var previewingTone: WakeTone?
    @Published var previewingMachine = false
    @Published var settings: BedsideSettings = .default

    let permissions = AlarmPermissionsManager()
    private let store = AlarmStore.appGroup()
    private let settingsStore = BedsideSettingsStore.appGroup()
    private let scheduler = AlarmNotificationScheduler()
    private let engine = ProgressiveAudioEngine()
    private let liveActivities = LiveActivityController()
    private let libraryObserver = LibraryChangeObserver()
    private var clock: Timer?
    private var didStart = false
    private let calendar = Calendar.current

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        engine.onInterruption = { [weak self] event in
            Task { @MainActor in
                self?.noteAudioInterruption(event)
            }
        }
    }

    var upcoming: UpcomingAlarm? {
        AlarmScheduleCalculator.nextUpcoming(alarms: library.alarms, now: now, calendar: calendar)
    }

    func start() async {
        guard !didStart else { return }
        didStart = true
        library = AlarmLibrarySeeder.seedIfNeeded(store.load())
        settings = settingsStore.load()
        store.save(library)
        scheduler.registerCategories()
        libraryObserver.onChange = { [weak self] in
            self?.reloadFromStore()
        }
        libraryObserver.start()
        let current = await permissions.signals()
        if current.authorization == .notDetermined {
            _ = await permissions.requestAuthorization()
        }
        await refreshPermissions()
        await scheduler.reschedule(alarms: library.alarms, now: Date())
        await liveActivities.sync(library: library, now: Date(), ringingID: nil)
        clock = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func refreshPermissions() async {
        readiness = PermissionReadinessEvaluator.evaluate(await permissions.signals())
    }

    func handlePermissionButton() async {
        if readiness.requestsPromptInsteadOfSettings {
            readiness = PermissionReadinessEvaluator.evaluate(await permissions.requestAuthorization())
            await scheduler.reschedule(alarms: library.alarms, now: Date())
        } else {
            permissions.openSystemSettings()
        }
    }

    func addAlarm() {
        guard library.alarms.count < AlarmLibrary.maximumAlarms else { return }
        editor = EditorDraft(
            alarm: Alarm(
                id: UUID().uuidString.lowercased(),
                hour: 7,
                minute: 0,
                label: "Alarm",
                enabled: true,
                repeatWeekdays: [],
                tone: .pocketOfBells,
                progressiveRampSeconds: 60
            ),
            isNew: true
        )
    }

    func edit(_ alarm: Alarm) {
        editor = EditorDraft(alarm: alarm, isNew: false)
    }

    func save(_ alarm: Alarm) {
        var next = library
        guard next.upsert(alarm.normalized()) else { return }
        library = next
        persistSchedule()
        editor = nil
        stopPreview()
    }

    func delete(_ id: String) {
        library.alarms.removeAll { $0.id == id }
        if ringingAlarmID == id {
            dismissRinging()
        }
        persistSchedule()
        editor = nil
        stopPreview()
    }

    func setEnabled(_ id: String, enabled: Bool) {
        guard let index = library.alarms.firstIndex(where: { $0.id == id }) else { return }
        library.alarms[index].enabled = enabled
        persistSchedule()
    }

    func preview(tone: WakeTone, rampSeconds: Int) {
        if previewingTone == tone {
            stopPreview()
            return
        }
        previewingMachine = false
        previewingTone = tone
        engine.playPreview(tone: tone, rampSeconds: rampSeconds)
    }

    func previewMachine() {
        if previewingMachine {
            stopPreview()
            return
        }
        previewingTone = nil
        previewingMachine = true
        engine.previewMachine()
    }

    func stopPreview() {
        previewingTone = nil
        previewingMachine = false
        engine.stopPreview()
    }

    func updateSettings(_ change: (inout BedsideSettings) -> Void) {
        var next = settings
        change(&next)
        settings = next
        settingsStore.save(next)
    }

    func stopMachine() {
        machineAlarmID = nil
        engine.stopMachine()
    }

    func dismissRinging() {
        guard let id = ringingAlarmID else { return }
        engine.dismiss()
        UIApplication.shared.isIdleTimerDisabled = false
        library.recordDismissal(alarmID: id, at: Date())
        Task { await scheduler.clearDelivered(for: id) }
        ringingAlarmID = nil
        machineAlarmID = nil
        persistSchedule()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func tick() {
        now = Date()
        guard ringingAlarmID == nil, let upcoming else {
            if ringingAlarmID == nil, machineAlarmID != nil, upcoming == nil {
                stopMachine()
            }
            return
        }
        if upcoming.alarm.machineLeadMinutes > 0,
           let start = MachineMode.leadDate(fireDate: upcoming.fireDate, leadMinutes: upcoming.alarm.machineLeadMinutes) {
            let machineDelta = now.timeIntervalSince(start)
            if machineDelta >= 0, now < upcoming.fireDate, machineAlarmID != upcoming.alarm.id {
                beginMachine(alarmID: upcoming.alarm.id)
            }
        }
        let delta = now.timeIntervalSince(upcoming.fireDate)
        if delta >= 0, delta < 50 {
            beginRinging(alarmID: upcoming.alarm.id)
        }
    }

    private func beginMachine(alarmID: String) {
        guard library.alarms.contains(where: { $0.id == alarmID }) else { return }
        if ringingAlarmID != nil { return }
        stopPreview()
        machineAlarmID = alarmID
        engine.playMachine()
    }

    private func beginRinging(alarmID: String) {
        guard let alarm = library.alarms.first(where: { $0.id == alarmID }) else { return }
        if ringingAlarmID == alarmID { return }
        stopPreview()
        ringingAlarmID = alarmID
        machineAlarmID = alarmID
        UIApplication.shared.isIdleTimerDisabled = true
        engine.playAlarm(tone: alarm.tone, rampSeconds: alarm.progressiveRampSeconds, alarmID: alarmID)
        Task {
            await liveActivities.sync(library: library, now: Date(), ringingID: alarmID)
        }
    }

    private func noteAudioInterruption(_ event: PlaybackInterrupt) {
        Task {
            let stillRinging = LiveActivityPolicy.shouldEnd(after: event) ? nil : ringingAlarmID
            await liveActivities.handlePlayback(event, library: library, now: Date(), ringingID: stillRinging)
        }
    }

    private func reloadFromStore() {
        let loaded = store.load()
        library = loaded
        if let dismissal = loaded.dismissal,
           dismissal.alarmID == ringingAlarmID,
           abs(dismissal.at.timeIntervalSinceNow) < 180 {
            engine.dismiss()
            UIApplication.shared.isIdleTimerDisabled = false
            ringingAlarmID = nil
        }
        Task {
            await liveActivities.sync(library: library, now: Date(), ringingID: ringingAlarmID)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func persistSchedule() {
        store.save(library)
        LibraryNotifier.postChanged()
        let snapshot = library
        let ringing = ringingAlarmID
        Task {
            await scheduler.reschedule(alarms: snapshot.alarms, now: Date())
            await liveActivities.sync(library: snapshot, now: Date(), ringingID: ringing)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let identifier = notification.request.identifier
        if let alarmID = AlarmNotificationIdentity.alarmID(from: identifier) {
            if AlarmNotificationIdentity.purpose(from: identifier) == .machine {
                beginMachine(alarmID: alarmID)
            } else {
                beginRinging(alarmID: alarmID)
            }
        }
        let presentation = AlarmNotificationIdentity.purpose(from: identifier) == .machine
            ? AlarmNotificationPlanner.machineForegroundPresentation
            : AlarmNotificationPlanner.foregroundPresentation
        var options: UNNotificationPresentationOptions = []
        if presentation.includesAlert {
            options.insert(.alert)
        }
        if presentation.includesSound {
            options.insert(.sound)
        }
        completionHandler(options)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        let identifier = response.notification.request.identifier
        guard let alarmID = AlarmNotificationIdentity.alarmID(from: identifier) else {
            return
        }
        let isMachine = AlarmNotificationIdentity.purpose(from: identifier) == .machine
        if response.actionIdentifier == AlarmNotificationIdentity.dismissActionIdentifier
            || response.actionIdentifier == UNNotificationDismissActionIdentifier {
            if isMachine {
                stopMachine()
            } else {
                ringingAlarmID = alarmID
                dismissRinging()
            }
        } else if isMachine {
            beginMachine(alarmID: alarmID)
        } else {
            beginRinging(alarmID: alarmID)
        }
    }
}

struct EditorDraft: Identifiable, Equatable {
    var alarm: Alarm
    var isNew: Bool
    var id: String { alarm.id }
}

final class LibraryChangeObserver {
    var onChange: @MainActor () -> Void = {}

    func start() {
        let opaque = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            opaque,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let object = Unmanaged<LibraryChangeObserver>.fromOpaque(observer).takeUnretainedValue()
                Task { @MainActor in
                    object.onChange()
                }
            },
            AlarmLibraryEvents.changedNotification as CFString,
            nil,
            .deliverImmediately
        )
    }

    deinit {
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            CFNotificationName(rawValue: AlarmLibraryEvents.changedNotification as CFString),
            nil
        )
    }
}

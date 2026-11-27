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
    @Published var editor: EditorDraft?
    @Published var previewingTone: WakeTone?

    let permissions = AlarmPermissionsManager()
    private let store = AlarmStore.appGroup()
    private let scheduler = AlarmNotificationScheduler()
    private let engine = ProgressiveAudioEngine()
    private let liveActivities = LiveActivityController()
    private let libraryObserver = LibraryChangeObserver()
    private var clock: Timer?
    private var didStart = false
    private var sceneIsActive = true
    private let calendar = Calendar.current

    override init() {
        super.init()
        JingleNotificationDelegate.shared.controller = self
        JingleNotificationDelegate.shared.install()
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
        store.save(library)
        scheduler.registerCategories()
        libraryObserver.onChange = { [weak self] in
            self?.reloadFromStore()
        }
        libraryObserver.start()
        let current = await permissions.signals()
        if current.authorization == .notDetermined || current.alarmKit == .notDetermined {
            _ = await permissions.requestAuthorization()
        }
        await refreshPermissions()
        await armAlarms(now: Date())
        await liveActivities.sync(library: library, now: Date(), ringingID: nil)
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        clock = timer
    }

    func noteScenePhase(_ phase: ScenePhase) async {
        sceneIsActive = phase == .active
        if phase == .active {
            await refreshPermissions()
            await armAlarms(now: Date())
        } else {
            refreshBedside()
        }
    }

    func refreshPermissions() async {
        readiness = PermissionReadinessEvaluator.evaluate(await permissions.signals())
    }

    func handlePermissionButton() async {
        if readiness.requestsPromptInsteadOfSettings {
            readiness = PermissionReadinessEvaluator.evaluate(await permissions.requestAuthorization())
            await armAlarms(now: Date())
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
        previewingTone = tone
        engine.playPreview(tone: tone, rampSeconds: rampSeconds)
    }

    func stopPreview() {
        previewingTone = nil
        engine.stopPreview()
    }

    func dismissRinging() {
        guard let id = ringingAlarmID else { return }
        engine.dismiss()
        UIApplication.shared.isIdleTimerDisabled = false
        library.recordDismissal(alarmID: id, at: Date())
        Task { await scheduler.clearDelivered(for: id) }
        ringingAlarmID = nil
        persistSchedule()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        refreshBedside()
    }

    private func tick() {
        now = Date()
        guard ringingAlarmID == nil, let upcoming else { return }
        let delta = now.timeIntervalSince(upcoming.fireDate)
        if delta >= 0, delta < 50 {
            beginRinging(alarmID: upcoming.alarm.id)
        }
    }

    private func beginRinging(alarmID: String) {
        let surface: PhoneAlarmSurface = sceneIsActive ? .foreground : .background
        let action = AlarmFireTrigger.action(on: surface, processIsRunning: true)
        guard action.startPlayback else { return }
        guard let alarm = library.alarms.first(where: { $0.id == alarmID }) else { return }
        if ringingAlarmID == alarmID { return }
        stopPreview()
        ringingAlarmID = alarmID
        UIApplication.shared.isIdleTimerDisabled = true
        // `.playback` ignores the Ring/Silent switch for as long as this session is running.
        engine.playAlarm(tone: alarm.tone, rampSeconds: alarm.progressiveRampSeconds, alarmID: alarmID)
        refreshBedside()
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
            refreshBedside()
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
            await armAlarms(now: Date())
            await liveActivities.sync(library: snapshot, now: Date(), ringingID: ringing)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// AlarmKit when it is authorized, otherwise a notification whose sound was
    /// checked against the bundled CAF. A failed system alarm falls back to the notification.
    private func armAlarms(now: Date) async {
        let drafts = SystemAlarmPlanner.drafts(for: library.alarms, now: now, calendar: calendar)
        let authorized = readiness.alarmKit == .authorized
        if authorized, await SystemAlarmScheduler.sync(drafts) {
            await scheduler.reschedule(alarms: [], now: now)
            refreshBedside()
            return
        }
        SystemAlarmScheduler.cancelRemembered()
        await scheduler.reschedule(alarms: library.alarms, now: now)
        refreshBedside()
    }

    private func refreshBedside() {
        let hold = BedsideSessionPolicy.shouldHold(
            alarmKitAuthorized: readiness.alarmKit == .authorized,
            hasEnabledAlarm: library.alarms.contains(where: \.enabled),
            isRinging: ringingAlarmID != nil,
            sceneIsActive: sceneIsActive
        )
        if hold {
            engine.startBedside()
        } else if ringingAlarmID == nil {
            engine.stopBedside()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if let alarmID = AlarmNotificationIdentity.alarmID(from: notification.request.identifier) {
            beginRinging(alarmID: alarmID)
        }
        completionHandler(JingleNotificationDelegate.presentationOptions)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        guard let alarmID = AlarmNotificationIdentity.alarmID(from: response.notification.request.identifier) else {
            return
        }
        if response.actionIdentifier == AlarmNotificationIdentity.dismissActionIdentifier
            || response.actionIdentifier == UNNotificationDismissActionIdentifier {
            ringingAlarmID = alarmID
            dismissRinging()
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

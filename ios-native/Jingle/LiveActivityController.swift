import ActivityKit
import Foundation
import JingleCore

@MainActor
final class LiveActivityController {
    func sync(library: AlarmLibrary, now: Date, ringingID: String?) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if let ringingID, let alarm = library.alarms.first(where: { $0.id == ringingID }) {
            await show(alarm: alarm, fireDate: now, phase: .ringing, detail: "Time to get up")
            return
        }
        guard let upcoming = AlarmScheduleCalculator.nextUpcoming(alarms: library.alarms, now: now) else {
            await endAll()
            return
        }
        let detail = AlarmClockText.countdown(from: now, to: upcoming.fireDate)
        await show(alarm: upcoming.alarm, fireDate: upcoming.fireDate, phase: .countdown, detail: detail)
    }

    /// Audio interruptions never tear this activity down. Dismissal refreshes whatever comes next.
    func handlePlayback(_ event: PlaybackInterrupt, library: AlarmLibrary, now: Date, ringingID: String?) async {
        guard LiveActivityPolicy.shouldEnd(after: event) else { return }
        await sync(library: library, now: now, ringingID: ringingID)
    }

    private func show(alarm: Alarm, fireDate: Date, phase: JingleActivityPhase, detail: String) async {
        let state = JingleAlarmAttributes.ContentState(
            phase: phase,
            label: alarm.label,
            fireDate: fireDate,
            timeText: AlarmClockText.time(hour: alarm.hour, minute: alarm.minute),
            detail: detail
        )
        let content = ActivityContent(
            state: state,
            staleDate: phase == .countdown ? fireDate : nil
        )
        let attributes = JingleAlarmAttributes(alarmID: alarm.id)
        if let existing = Activity<JingleAlarmAttributes>.activities.first(where: { $0.attributes.alarmID == alarm.id }) {
            await existing.update(content)
            for activity in Activity<JingleAlarmAttributes>.activities where activity.id != existing.id {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return
        }
        await endAll()
        do {
            _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
        } catch {
            return
        }
    }

    private func endAll() async {
        for activity in Activity<JingleAlarmAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

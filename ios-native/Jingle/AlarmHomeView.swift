import JingleCore
import SwiftUI

struct PermissionBannerView: View {
    let readiness: PermissionReadiness
    let onButton: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(readiness.bannerMessage)
                .font(.jingleText(15, weight: .medium))
                .foregroundStyle(JingleTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(readiness.ringSwitchNote)
                .font(.jingleText(13))
                .foregroundStyle(JingleTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onButton) {
                Text(readiness.settingsButtonTitle)
                    .font(.jingleText(15, weight: .semibold))
                    .foregroundStyle(JingleTheme.onOrange)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(JingleTheme.orange, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(readiness.settingsButtonTitle)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(JingleTheme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(JingleTheme.orange.opacity(0.35), lineWidth: 1)
        )
    }
}

struct AlarmHomeView: View {
    @EnvironmentObject private var model: AlarmController
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            JingleTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    hero
                    if model.readiness.showsSettingsBanner {
                        PermissionBannerView(readiness: model.readiness) {
                            Task { await model.handlePermissionButton() }
                        }
                    }
                    if let note = model.readiness.liveActivityNote, !model.readiness.showsSettingsBanner {
                        Text(note)
                            .font(.jingleText(13))
                            .foregroundStyle(JingleTheme.muted)
                    }
                    alarmList
                    footnotes
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .task { await model.start() }
        .onChange(of: scenePhase) { _, phase in
            Task { await model.noteScenePhase(phase) }
        }
        .sheet(item: $model.editor) { draft in
            AlarmEditorView(draft: draft)
        }
        .fullScreenCover(isPresented: Binding(
            get: { model.ringingAlarmID != nil },
            set: { presented in
                if !presented { model.dismissRinging() }
            }
        )) {
            RingingView()
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Text("Jingle")
                .font(.jingleTime(28))
                .foregroundStyle(JingleTheme.text)
            Spacer()
            Button(action: model.addAlarm) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(JingleTheme.orangeText)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Add alarm")
            .disabled(model.library.alarms.count >= AlarmLibrary.maximumAlarms)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NEXT ALARM")
                .font(.jingleText(12, weight: .semibold))
                .tracking(2.4)
                .foregroundStyle(JingleTheme.orangeText)
            if let upcoming = model.upcoming {
                Text(AlarmClockText.time(hour: upcoming.alarm.hour, minute: upcoming.alarm.minute))
                    .font(.jingleTime(64))
                    .foregroundStyle(JingleTheme.text)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(upcoming.alarm.label)
                    .font(.jingleText(18, weight: .medium))
                    .foregroundStyle(JingleTheme.text)
                Text("\(AlarmClockText.repeatSummary(upcoming.alarm.repeatWeekdays)) · \(upcoming.alarm.tone.displayName)")
                    .font(.jingleText(15))
                    .foregroundStyle(JingleTheme.muted)
                Text(AlarmClockText.countdown(from: model.now, to: upcoming.fireDate))
                    .font(.jingleText(16, weight: .medium))
                    .foregroundStyle(JingleTheme.orangeText)
                    .padding(.top, 4)
            } else {
                Text("No alarm yet")
                    .font(.jingleTime(40))
                    .foregroundStyle(JingleTheme.text)
                Text("The morning is open.")
                    .font(.jingleText(16))
                    .foregroundStyle(JingleTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var alarmList: some View {
        VStack(spacing: 12) {
            if model.library.alarms.isEmpty {
                Text("Add an alarm when you want a morning.")
                    .font(.jingleText(15))
                    .foregroundStyle(JingleTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(model.library.sortedForDisplay()) { alarm in
                    alarmRow(alarm)
                }
            }
            if model.library.alarms.count >= AlarmLibrary.maximumAlarms {
                Text("Eight alarms is the limit so each one can still be scheduled.")
                    .font(.jingleText(13))
                    .foregroundStyle(JingleTheme.faint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func alarmRow(_ alarm: Alarm) -> some View {
        HStack(spacing: 12) {
            Button {
                model.edit(alarm)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AlarmClockText.time(hour: alarm.hour, minute: alarm.minute))
                        .font(.jingleTime(32))
                        .foregroundStyle(JingleTheme.text)
                    Text("\(alarm.label) · \(AlarmClockText.repeatSummary(alarm.repeatWeekdays)) · \(alarm.tone.displayName)")
                        .font(.jingleText(14))
                        .foregroundStyle(JingleTheme.muted)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(alarm.enabled ? 1 : 0.45)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(alarm.label), \(AlarmClockText.time(hour: alarm.hour, minute: alarm.minute))")
            Toggle(isOn: Binding(
                get: { alarm.enabled },
                set: { model.setEnabled(alarm.id, enabled: $0) }
            )) {
                Text("Enabled")
            }
            .labelsHidden()
            .tint(JingleTheme.orange)
            .accessibilityLabel("Toggle \(alarm.label)")
        }
        .padding(16)
        .background(JingleTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(JingleTheme.stroke, lineWidth: 1)
        )
    }

    private var footnotes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plays alongside the iPhone Clock app, even at the same minute. Once a wake has started, Jingle keeps playing in the background and follows the volume buttons.")
            Text(SilentSwitchGuidance.footnote(alarmKit: model.readiness.alarmKit))
            Text("Designed by Matthew Finley. Alarms stay on this iPhone.")
        }
        .font(.jingleText(13))
        .foregroundStyle(JingleTheme.faint)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 4)
    }
}

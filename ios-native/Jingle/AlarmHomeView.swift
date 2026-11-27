import JingleCore
import SwiftUI

struct PermissionBannerView: View {
    @Environment(\.jinglePalette) private var theme
    let readiness: PermissionReadiness
    let onButton: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(readiness.bannerMessage)
                .font(.jingleText(15, weight: .medium))
                .foregroundStyle(theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(readiness.ringSwitchNote)
                .font(.jingleText(13))
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onButton) {
                Text(readiness.settingsButtonTitle)
                    .font(.jingleText(15, weight: .semibold))
                    .foregroundStyle(theme.onOrange)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(theme.orange, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(readiness.settingsButtonTitle)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.orange.opacity(0.35), lineWidth: 1)
        )
    }
}

struct AlarmHomeView: View {
    @EnvironmentObject private var model: AlarmController
    @Environment(\.jinglePalette) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @State private var isBlanked = false
    @State private var lastInteraction = Date()

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    hero
                    machineBanner
                    if model.readiness.showsSettingsBanner {
                        PermissionBannerView(readiness: model.readiness) {
                            Task { await model.handlePermissionButton() }
                        }
                    }
                    if let note = model.readiness.liveActivityNote, !model.readiness.showsSettingsBanner {
                        Text(note)
                            .font(.jingleText(13))
                            .foregroundStyle(theme.muted)
                    }
                    alarmList
                    footnotes
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            if isBlanked {
                Color.black
                    .ignoresSafeArea()
                    .onTapGesture { wakeFromBlank() }
                    .accessibilityLabel("Tap to wake")
                    .accessibilityAddTraits(.isButton)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0).onChanged { _ in poke() }
        )
        .task { await model.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await model.refreshPermissions() }
                applyDim()
            } else {
                BedsideDisplay.restore()
            }
        }
        .onChange(of: model.now) { _, _ in
            considerBlank()
        }
        .onChange(of: model.settings) { _, _ in
            if !model.settings.autoBlank { isBlanked = false }
            applyDim()
        }
        .onChange(of: model.ringingAlarmID) { _, id in
            if id != nil {
                isBlanked = false
                BedsideDisplay.restore()
            } else {
                poke()
                applyDim()
            }
        }
        .onChange(of: model.editor) { _, _ in poke() }
        .onChange(of: model.showingSettings) { _, _ in poke() }
        .onDisappear { BedsideDisplay.restore() }
        .sheet(item: $model.editor) { draft in
            AlarmEditorView(draft: draft)
        }
        .sheet(isPresented: $model.showingSettings) {
            SettingsView()
        }
        .fullScreenCover(isPresented: Binding(
            get: { model.ringingAlarmID != nil },
            set: { presented in
                if !presented { model.dismissRinging() }
            }
        )) {
            RingingView()
        }
        .preferredColorScheme(theme.preferredColorScheme)
    }

    private var header: some View {
        HStack {
            Text("Jingle")
                .font(.jingleTime(28))
                .foregroundStyle(theme.text)
            Spacer()
            Button {
                model.showingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.orangeText)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Settings")
            Button(action: model.addAlarm) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(theme.orangeText)
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
                .foregroundStyle(theme.orangeText)
            if let upcoming = model.upcoming {
                Text(AlarmClockText.time(hour: upcoming.alarm.hour, minute: upcoming.alarm.minute))
                    .font(.jingleTime(64))
                    .foregroundStyle(theme.text)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(upcoming.alarm.label)
                    .font(.jingleText(18, weight: .medium))
                    .foregroundStyle(theme.text)
                Text("\(AlarmClockText.repeatSummary(upcoming.alarm.repeatWeekdays)) · \(upcoming.alarm.tone.displayName)")
                    .font(.jingleText(15))
                    .foregroundStyle(theme.muted)
                if upcoming.alarm.machineLeadMinutes > 0 {
                    Text("Machine mode \(upcoming.alarm.machineLeadMinutes) min before")
                        .font(.jingleText(14))
                        .foregroundStyle(theme.muted)
                }
                Text(AlarmClockText.countdown(from: model.now, to: upcoming.fireDate))
                    .font(.jingleText(16, weight: .medium))
                    .foregroundStyle(theme.orangeText)
                    .padding(.top, 4)
            } else {
                Text("No alarm yet")
                    .font(.jingleTime(40))
                    .foregroundStyle(theme.text)
                Text("The morning is open.")
                    .font(.jingleText(16))
                    .foregroundStyle(theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var machineBanner: some View {
        if model.ringingAlarmID == nil, let id = model.machineAlarmID,
           let alarm = model.library.alarms.first(where: { $0.id == id }) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MACHINE MODE")
                        .font(.jingleText(12, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(theme.orangeText)
                    Text("Soft start before \(alarm.label).")
                        .font(.jingleText(15, weight: .medium))
                        .foregroundStyle(theme.text)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    model.stopMachine()
                    poke()
                } label: {
                    Text("Stop")
                        .font(.jingleText(15, weight: .semibold))
                        .foregroundStyle(theme.onOrange)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(theme.orange, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop machine mode")
            }
            .padding(16)
            .background(theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(theme.orange.opacity(0.35), lineWidth: 1)
            )
        }
    }

    private var alarmList: some View {
        VStack(spacing: 12) {
            if model.library.alarms.isEmpty {
                Text("Add an alarm when you want a morning.")
                    .font(.jingleText(15))
                    .foregroundStyle(theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(model.library.sortedForDisplay()) { alarm in
                    alarmRow(alarm)
                }
            }
            if model.library.alarms.count >= AlarmLibrary.maximumAlarms {
                Text("Eight alarms is the limit so each one can still be scheduled.")
                    .font(.jingleText(13))
                    .foregroundStyle(theme.faint)
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
                        .foregroundStyle(theme.text)
                    Text("\(alarm.label) · \(AlarmClockText.repeatSummary(alarm.repeatWeekdays)) · \(alarm.tone.displayName)")
                        .font(.jingleText(14))
                        .foregroundStyle(theme.muted)
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
            .tint(theme.orange)
            .accessibilityLabel("Toggle \(alarm.label)")
        }
        .padding(16)
        .background(theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.stroke, lineWidth: 1)
        )
    }

    private var footnotes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plays alongside the iPhone Clock app, even at the same minute. Once a wake has started, Jingle keeps playing in the background and follows the volume buttons.")
            Text("A locked-phone notification still needs the Ring/Silent switch set to Ring.")
            Text("Designed by Matthew Finley. Alarms stay on this iPhone.")
        }
        .font(.jingleText(13))
        .foregroundStyle(theme.faint)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 4)
    }

    private func poke() {
        lastInteraction = Date()
        if isBlanked {
            isBlanked = false
            applyDim()
        }
    }

    private func wakeFromBlank() {
        poke()
    }

    private func considerBlank() {
        guard model.settings.autoBlank, !isBlanked else { return }
        guard model.editor == nil, !model.showingSettings, model.ringingAlarmID == nil else { return }
        guard !model.readiness.requestsPromptInsteadOfSettings else { return }
        guard Date().timeIntervalSince(lastInteraction) >= BedsideSettings.blankAfter else { return }
        isBlanked = true
        applyDim()
    }

    private func applyDim() {
        if scenePhase == .active, model.ringingAlarmID == nil {
            BedsideDisplay.apply(settings: model.settings, isBlanked: isBlanked)
        } else {
            BedsideDisplay.restore()
        }
    }
}

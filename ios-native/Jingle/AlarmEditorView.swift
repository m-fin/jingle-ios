import JingleCore
import SwiftUI

struct AlarmEditorView: View {
    @EnvironmentObject private var model: AlarmController
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Alarm

    init(draft: EditorDraft) {
        _draft = State(initialValue: draft.alarm)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                JingleTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        timePicker
                        labelField
                        weekdaySection
                        toneSection
                        rampSection
                        if !isNew {
                            Button(role: .destructive) {
                                model.delete(draft.id)
                                dismiss()
                            } label: {
                                Text("Delete alarm")
                                    .font(.jingleText(16, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(isNew ? "Add Alarm" : "Edit Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(JingleTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        model.stopPreview()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.save(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear { model.stopPreview() }
    }

    private var isNew: Bool {
        model.editor?.isNew ?? true
    }

    private var timePicker: some View {
        DatePicker(
            "Time",
            selection: Binding(
                get: { timeDate },
                set: { date in
                    let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                    draft.hour = parts.hour ?? draft.hour
                    draft.minute = parts.minute ?? draft.minute
                }
            ),
            displayedComponents: .hourAndMinute
        )
        .datePickerStyle(.wheel)
        .labelsHidden()
        .colorScheme(.dark)
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .accessibilityLabel("Alarm time")
    }

    private var labelField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LABEL")
                .font(.jingleText(12, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(JingleTheme.muted)
            TextField("Alarm", text: $draft.label)
                .font(.jingleText(20, weight: .medium))
                .foregroundStyle(JingleTheme.text)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
        }
    }

    private var weekdaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("REPEAT")
                    .font(.jingleText(12, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(JingleTheme.muted)
                Spacer()
                Text(AlarmClockText.repeatSummary(draft.repeatWeekdays))
                    .font(.jingleText(14, weight: .medium))
                    .foregroundStyle(JingleTheme.orangeText)
            }
            HStack(spacing: 8) {
                ForEach(Weekday.allCases, id: \.self) { day in
                    let on = draft.repeatWeekdays.contains(day)
                    Button {
                        if on {
                            draft.repeatWeekdays.remove(day)
                        } else {
                            draft.repeatWeekdays.insert(day)
                        }
                    } label: {
                        Text(day.letter)
                            .font(.jingleText(15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(on ? JingleTheme.onOrange : JingleTheme.text)
                            .background(on ? JingleTheme.orange : JingleTheme.card, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(day.name)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            Text("Leave every day off to ring once.")
                .font(.jingleText(13))
                .foregroundStyle(JingleTheme.faint)
        }
    }

    private var toneSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WAKE TONE")
                .font(.jingleText(12, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(JingleTheme.muted)
            ForEach(WakeTone.allCases, id: \.self) { tone in
                Button {
                    draft.tone = tone
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(tone.displayName)
                                    .font(.jingleText(17, weight: .semibold))
                                    .foregroundStyle(JingleTheme.text)
                                if tone == .featured {
                                    Text("Featured")
                                        .font(.jingleText(11, weight: .semibold))
                                        .foregroundStyle(JingleTheme.onOrange)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(JingleTheme.orange, in: Capsule())
                                }
                            }
                            Text(tone.detail)
                                .font(.jingleText(13))
                                .foregroundStyle(JingleTheme.muted)
                        }
                        Spacer()
                        if draft.tone == tone {
                            Image(systemName: "checkmark")
                                .foregroundStyle(JingleTheme.orangeText)
                        }
                    }
                    .padding(14)
                    .background(JingleTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(draft.tone == tone ? JingleTheme.orange.opacity(0.8) : JingleTheme.stroke, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            Button {
                model.preview(tone: draft.tone, rampSeconds: draft.progressiveRampSeconds)
            } label: {
                Text(model.previewingTone == draft.tone ? "Stop preview" : "Try this wake")
                    .font(.jingleText(16, weight: .semibold))
                    .foregroundStyle(JingleTheme.onOrange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(JingleTheme.orange, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Try this wake")
        }
    }

    private var rampSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GENTLE RISE")
                .font(.jingleText(12, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(JingleTheme.muted)
            HStack(spacing: 8) {
                ForEach(Self.ramps, id: \.seconds) { option in
                    let on = draft.progressiveRampSeconds == option.seconds
                    Button {
                        draft.progressiveRampSeconds = option.seconds
                    } label: {
                        Text(option.label)
                            .font(.jingleText(14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(on ? JingleTheme.onOrange : JingleTheme.text)
                            .background(on ? JingleTheme.orange : JingleTheme.card, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Volume eases in over this long, then holds.")
                .font(.jingleText(13))
                .foregroundStyle(JingleTheme.faint)
        }
    }

    private var timeDate: Date {
        Calendar.current.date(
            bySettingHour: draft.hour,
            minute: draft.minute,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private static let ramps: [(label: String, seconds: Int)] = [
        ("30 sec", 30),
        ("1 min", 60),
        ("2 min", 120),
        ("5 min", 300),
    ]
}

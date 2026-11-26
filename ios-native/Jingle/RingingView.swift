import JingleCore
import SwiftUI

struct RingingView: View {
    @EnvironmentObject private var model: AlarmController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            JingleTheme.background.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                ZStack {
                    Circle()
                        .stroke(JingleTheme.orange.opacity(0.35), lineWidth: 2)
                        .frame(width: 220, height: 220)
                        .scaleEffect(pulse && !reduceMotion ? 1.16 : 0.9)
                        .opacity(pulse && !reduceMotion ? 0.25 : 0.7)
                    VStack(spacing: 6) {
                        Text(alarm.map { AlarmClockText.time(hour: $0.hour, minute: $0.minute) } ?? "")
                            .font(.jingleTime(48))
                            .foregroundStyle(JingleTheme.text)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text(alarm?.label ?? "Jingle")
                            .font(.jingleText(18, weight: .medium))
                            .foregroundStyle(JingleTheme.muted)
                    }
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: pulse)
                Text("Time to get up")
                    .font(.jingleTime(28))
                    .foregroundStyle(JingleTheme.text)
                Spacer()
                Button(action: model.dismissRinging) {
                    Text("Dismiss")
                        .font(.jingleText(22, weight: .semibold))
                        .foregroundStyle(JingleTheme.onOrange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(JingleTheme.orange, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
                Text("This wake keeps playing if you leave Jingle, and it mixes with the iPhone Clock app.")
                    .font(.jingleText(13))
                    .foregroundStyle(JingleTheme.faint)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
        .onAppear { pulse = true }
        .preferredColorScheme(.dark)
    }

    private var alarm: Alarm? {
        guard let id = model.ringingAlarmID else { return nil }
        return model.library.alarms.first { $0.id == id }
    }
}

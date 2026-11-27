import JingleCore
import SwiftUI

struct RingingView: View {
    @EnvironmentObject private var model: AlarmController
    @Environment(\.jinglePalette) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                ZStack {
                    Circle()
                        .stroke(theme.orange.opacity(0.35), lineWidth: 2)
                        .frame(width: 220, height: 220)
                        .scaleEffect(pulse && !reduceMotion ? 1.16 : 0.9)
                        .opacity(pulse && !reduceMotion ? 0.25 : 0.7)
                    VStack(spacing: 6) {
                        Text(alarm.map { AlarmClockText.time(hour: $0.hour, minute: $0.minute) } ?? "")
                            .font(.jingleTime(48))
                            .foregroundStyle(theme.text)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text(alarm?.label ?? "Jingle")
                            .font(.jingleText(18, weight: .medium))
                            .foregroundStyle(theme.muted)
                    }
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: pulse)
                Text("Time to get up")
                    .font(.jingleTime(28))
                    .foregroundStyle(theme.text)
                Spacer()
                Button(action: model.dismissRinging) {
                    Text("Dismiss")
                        .font(.jingleText(22, weight: .semibold))
                        .foregroundStyle(theme.onOrange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(theme.orange, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
                Text("This wake keeps playing if you leave Jingle, and it mixes with the iPhone Clock app.")
                    .font(.jingleText(13))
                    .foregroundStyle(theme.faint)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
        .onAppear { pulse = true }
        .preferredColorScheme(theme.preferredColorScheme)
    }

    private var alarm: Alarm? {
        guard let id = model.ringingAlarmID else { return nil }
        return model.library.alarms.first { $0.id == id }
    }
}

import ActivityKit
import SwiftUI
import WidgetKit

struct JingleAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: JingleAlarmAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(Color(red: 0.027, green: 0.027, blue: 0.031))
                .activitySystemActionForegroundColor(Color(red: 0.965, green: 0.945, blue: 0.910))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(Color(red: 0.969, green: 0.576, blue: 0.102))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.timeText)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(context.state.label)
                            .font(.headline)
                        countdown(context.state)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if context.state.phase == .ringing {
                            Button(intent: DismissJingleAlarmIntent(alarmID: context.attributes.alarmID)) {
                                Text("Dismiss")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(red: 0.969, green: 0.576, blue: 0.102))
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "bell.fill")
                    .foregroundStyle(Color(red: 0.969, green: 0.576, blue: 0.102))
            } compactTrailing: {
                Text(context.state.timeText)
                    .font(.caption.monospacedDigit())
                    .minimumScaleFactor(0.7)
            } minimal: {
                Image(systemName: "bell.fill")
                    .foregroundStyle(Color(red: 0.969, green: 0.576, blue: 0.102))
            }
            .keylineTint(Color(red: 0.969, green: 0.576, blue: 0.102))
        }
    }

    private func lockScreen(_ context: ActivityViewContext<JingleAlarmAttributes>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "bell.fill")
                .font(.title2)
                .foregroundStyle(Color(red: 0.969, green: 0.576, blue: 0.102))
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.label)
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.965, green: 0.945, blue: 0.910))
                Text(context.state.timeText)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(Color(red: 0.965, green: 0.945, blue: 0.910))
                countdown(context.state)
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.604, green: 0.580, blue: 0.541))
            }
            Spacer(minLength: 8)
            if context.state.phase == .ringing {
                Button(intent: DismissJingleAlarmIntent(alarmID: context.attributes.alarmID)) {
                    Text("Dismiss")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.969, green: 0.576, blue: 0.102))
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func countdown(_ state: JingleAlarmAttributes.ContentState) -> some View {
        if state.phase == .countdown, state.fireDate > Date() {
            Text(timerInterval: Date()...state.fireDate, countsDown: true)
                .monospacedDigit()
        } else {
            Text(status(state))
        }
    }

    private func status(_ state: JingleAlarmAttributes.ContentState) -> String {
        switch state.phase {
        case .ringing:
            return "Time to get up"
        case .countdown:
            if state.fireDate > Date() {
                return state.detail
            }
            return "Coming up"
        }
    }
}

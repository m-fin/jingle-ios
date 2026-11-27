import JingleCore
import SwiftUI
import WidgetKit

struct NextAlarmEntry: TimelineEntry {
    let date: Date
    let timeText: String
    let detail: String
    let countdown: String
    let toneName: String
    let hasAlarm: Bool
}

struct NextAlarmProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextAlarmEntry {
        NextAlarmEntry(date: Date(), timeText: "6:00 AM", detail: "Morning · Weekdays", countdown: "Rings tomorrow", toneName: WakeTone.pocketOfBells.displayName, hasAlarm: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (NextAlarmEntry) -> Void) {
        completion(makeEntry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextAlarmEntry>) -> Void) {
        let now = Date()
        var entries = [makeEntry(at: now)]
        var refresh = Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1800)
        let library = AlarmStore.appGroup().load()
        if let upcoming = AlarmScheduleCalculator.nextUpcoming(alarms: library.alarms, now: now) {
            let justAfter = upcoming.fireDate.addingTimeInterval(1)
            entries.append(makeEntry(at: justAfter))
            refresh = justAfter
        }
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    private func makeEntry(at date: Date) -> NextAlarmEntry {
        let library = AlarmStore.appGroup().load()
        guard let upcoming = AlarmScheduleCalculator.nextUpcoming(alarms: library.alarms, now: date) else {
            return NextAlarmEntry(date: date, timeText: "—", detail: "No alarm", countdown: "The morning is open", toneName: "", hasAlarm: false)
        }
        return NextAlarmEntry(
            date: date,
            timeText: AlarmClockText.time(hour: upcoming.alarm.hour, minute: upcoming.alarm.minute),
            detail: "\(upcoming.alarm.label) · \(AlarmClockText.repeatSummary(upcoming.alarm.repeatWeekdays))",
            countdown: AlarmClockText.countdown(from: date, to: upcoming.fireDate),
            toneName: upcoming.alarm.tone.displayName,
            hasAlarm: true
        )
    }
}

struct NextAlarmWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "app.jingle.ios.next-alarm", provider: NextAlarmProvider()) { entry in
            NextAlarmWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Alarm")
        .description("Shows the next Jingle alarm.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

struct NextAlarmWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextAlarmEntry

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if family == .accessoryCircular || family == .accessoryRectangular {
                    AccessoryWidgetBackground()
                } else {
                    Color(red: 0.027, green: 0.027, blue: 0.031)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: "bell.fill")
                    .font(.caption2)
                Text(shortTime)
                    .font(.headline.monospacedDigit())
                    .minimumScaleFactor(0.6)
                    .widgetAccentable()
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.timeText)
                    .font(.headline.monospacedDigit())
                    .widgetAccentable()
                Text(entry.detail)
                    .font(.caption)
                    .lineLimit(1)
                Text(entry.countdown)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .systemMedium:
            VStack(alignment: .leading, spacing: 6) {
                Text("NEXT ALARM")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.694, blue: 0.353))
                Text(entry.timeText)
                    .font(.system(size: 40, weight: .medium, design: .serif))
                    .foregroundStyle(Color(red: 0.965, green: 0.945, blue: 0.910))
                    .minimumScaleFactor(0.6)
                Text(entry.detail)
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.604, green: 0.580, blue: 0.541))
                Text(entry.hasAlarm ? "\(entry.countdown) · \(entry.toneName)" : entry.countdown)
                    .font(.footnote)
                    .foregroundStyle(Color(red: 0.965, green: 0.945, blue: 0.910))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 4) {
                Text("NEXT")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.694, blue: 0.353))
                Text(entry.timeText)
                    .font(.system(size: 28, weight: .medium, design: .serif))
                    .foregroundStyle(Color(red: 0.965, green: 0.945, blue: 0.910))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(entry.detail)
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.604, green: 0.580, blue: 0.541))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private var shortTime: String {
        entry.timeText.replacingOccurrences(of: " AM", with: "").replacingOccurrences(of: " PM", with: "")
    }
}

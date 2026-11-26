import ActivityKit
import Foundation

public enum JingleActivityPhase: String, Codable, Hashable, Sendable {
    case countdown
    case ringing
}

public struct JingleAlarmAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var phase: JingleActivityPhase
        public var label: String
        public var fireDate: Date
        public var timeText: String
        public var detail: String

        public init(
            phase: JingleActivityPhase,
            label: String,
            fireDate: Date,
            timeText: String,
            detail: String
        ) {
            self.phase = phase
            self.label = label
            self.fireDate = fireDate
            self.timeText = timeText
            self.detail = detail
        }
    }

    public var alarmID: String

    public init(alarmID: String) {
        self.alarmID = alarmID
    }
}

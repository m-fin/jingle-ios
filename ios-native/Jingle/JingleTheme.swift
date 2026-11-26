import SwiftUI

enum JingleTheme {
    static let background = Color(red: 0.027, green: 0.027, blue: 0.031)
    static let card = Color(red: 0.086, green: 0.086, blue: 0.094)
    static let text = Color(red: 0.965, green: 0.945, blue: 0.910)
    static let muted = Color(red: 0.604, green: 0.580, blue: 0.541)
    static let faint = Color(red: 0.416, green: 0.392, blue: 0.361)
    static let orange = Color(red: 0.969, green: 0.576, blue: 0.102)
    static let orangeText = Color(red: 1.0, green: 0.694, blue: 0.353)
    static let onOrange = Color(red: 0.102, green: 0.071, blue: 0.031)
    static let stroke = Color.white.opacity(0.06)
}

extension Font {
    static func jingleTime(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .serif)
    }

    static func jingleText(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

import JingleCore
import SwiftUI

struct JinglePalette: Equatable {
    var background: Color
    var card: Color
    var text: Color
    var muted: Color
    var faint: Color
    var orange: Color
    var orangeText: Color
    var onOrange: Color
    var stroke: Color
    var preferredColorScheme: ColorScheme
}

enum JingleTheme {
    static func palette(_ theme: AppearanceTheme) -> JinglePalette {
        switch theme {
        case .matteBlack:
            return JinglePalette(
                background: Color(red: 0.027, green: 0.027, blue: 0.031),
                card: Color(red: 0.086, green: 0.086, blue: 0.094),
                text: Color(red: 0.965, green: 0.945, blue: 0.910),
                muted: Color(red: 0.604, green: 0.580, blue: 0.541),
                faint: Color(red: 0.416, green: 0.392, blue: 0.361),
                orange: Color(red: 0.969, green: 0.576, blue: 0.102),
                orangeText: Color(red: 1.0, green: 0.694, blue: 0.353),
                onOrange: Color(red: 0.102, green: 0.071, blue: 0.031),
                stroke: Color.white.opacity(0.06),
                preferredColorScheme: .dark
            )
        case .stone:
            return JinglePalette(
                background: Color(red: 0.831, green: 0.808, blue: 0.765),
                card: Color(red: 0.953, green: 0.933, blue: 0.902),
                text: Color(red: 0.165, green: 0.149, blue: 0.125),
                muted: Color(red: 0.435, green: 0.396, blue: 0.357),
                faint: Color(red: 0.557, green: 0.522, blue: 0.478),
                orange: Color(red: 0.702, green: 0.427, blue: 0.196),
                orangeText: Color(red: 0.545, green: 0.325, blue: 0.102),
                onOrange: Color(red: 0.102, green: 0.071, blue: 0.031),
                stroke: Color.black.opacity(0.08),
                preferredColorScheme: .light
            )
        case .bitcoinOrange:
            return JinglePalette(
                background: Color(red: 0.086, green: 0.039, blue: 0.016),
                card: Color(red: 0.169, green: 0.078, blue: 0.027),
                text: Color(red: 1.0, green: 0.941, blue: 0.863),
                muted: Color(red: 0.820, green: 0.580, blue: 0.290),
                faint: Color(red: 0.620, green: 0.400, blue: 0.180),
                orange: Color(red: 0.969, green: 0.576, blue: 0.102),
                orangeText: Color(red: 1.0, green: 0.757, blue: 0.353),
                onOrange: Color(red: 0.102, green: 0.071, blue: 0.031),
                stroke: Color(red: 0.969, green: 0.576, blue: 0.102).opacity(0.28),
                preferredColorScheme: .dark
            )
        }
    }
}

private struct JinglePaletteKey: EnvironmentKey {
    static let defaultValue = JingleTheme.palette(.matteBlack)
}

extension EnvironmentValues {
    var jinglePalette: JinglePalette {
        get { self[JinglePaletteKey.self] }
        set { self[JinglePaletteKey.self] = newValue }
    }
}

extension Font {
    static func jingleTime(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .serif)
    }

    static func jingleText(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

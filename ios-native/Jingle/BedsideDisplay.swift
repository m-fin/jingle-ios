import JingleCore
import UIKit

/// Lowers and restores iPhone brightness for the bedside clock. No-ops if the API is unavailable.
enum BedsideDisplay {
    private static var saved: CGFloat?
    private static var dimmed = false

    static func apply(settings: BedsideSettings, isBlanked: Bool) {
        guard settings.bedsideDim else {
            restore()
            return
        }
        let screen = UIScreen.main
        if !dimmed {
            saved = screen.brightness
            dimmed = true
        }
        let level = isBlanked ? BedsideSettings.blankDimLevel : BedsideSettings.dimLevel
        screen.brightness = CGFloat(max(0, min(1, level)))
    }

    static func restore() {
        guard dimmed else { return }
        if let saved {
            UIScreen.main.brightness = saved
        }
        saved = nil
        dimmed = false
    }
}

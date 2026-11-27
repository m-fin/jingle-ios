import SwiftUI

@main
struct JingleApp: App {
    @StateObject private var model = AlarmController()

    private var palette: JinglePalette {
        JingleTheme.palette(model.settings.theme)
    }

    var body: some Scene {
        WindowGroup {
            AlarmHomeView()
                .environmentObject(model)
                .environment(\.jinglePalette, palette)
                .tint(palette.orange)
                .preferredColorScheme(palette.preferredColorScheme)
        }
    }
}

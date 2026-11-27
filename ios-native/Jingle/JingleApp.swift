import SwiftUI

@main
struct JingleApp: App {
    @StateObject private var model: AlarmController

    init() {
        // The notification delegate has to exist before the first scene, or a
        // foreground delivery is dropped with no sound and no ringing screen.
        JingleNotificationDelegate.shared.install()
        let model = AlarmController()
        JingleNotificationDelegate.shared.controller = model
        _model = StateObject(wrappedValue: model)
    }

    var body: some Scene {
        WindowGroup {
            AlarmHomeView()
                .environmentObject(model)
                .tint(JingleTheme.orange)
        }
    }
}

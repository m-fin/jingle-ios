import SwiftUI

@main
struct JingleApp: App {
    @StateObject private var model = AlarmController()

    var body: some Scene {
        WindowGroup {
            AlarmHomeView()
                .environmentObject(model)
                .tint(JingleTheme.orange)
        }
    }
}

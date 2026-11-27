import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.jinglePalette) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Effective 15 November 2026. Jingle, bundle id app.jingle.ios, is maintained by Matthew Finley.")
                    Text("Jingle is a bedside alarm clock. It keeps what you set on the iPhone that is running it.")
                    section("Data stored on this phone", "Alarms, machine-mode choices, and appearance are saved on the device. Nothing in that store is sent to a server operated for Jingle. The clock reads the iPhone’s own time so the face matches the phone. It does not request location. While the clock screen is open, Jingle can lower screen brightness, then put the previous brightness back. That change stays on the device.")
                    section("Notifications", "Jingle schedules local notifications so an alarm can ring after the screen locks. Remote push is off. Jingle does not upload a push token. A locked iPhone plays the notification sound through iOS. While Jingle is open, it plays the tone in the app.")
                    section("What Jingle does not do", "No account and no sign-in. No analytics and no advertising. No sale or sharing of personal information. No collection of your name, email, contacts, photos, health data, or location. No custom encryption beyond what iOS and the app platform already provide. Wake tones and the machine-mode drone are original audio included in the app.")
                    Text("Questions about this policy can go to the Jingle issues page on GitHub.")
                        .foregroundStyle(theme.muted)
                }
                .font(.jingleText(16))
                .foregroundStyle(theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Privacy policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(theme.preferredColorScheme)
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.jingleText(16, weight: .semibold))
            Text(body)
        }
    }
}

import JingleCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AlarmController
    @Environment(\.jinglePalette) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var showingPrivacy = false

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    appearance
                    bedside
                    about
                }
                .padding(20)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Settings")
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
        .sheet(isPresented: $showingPrivacy) {
            PrivacyPolicyView()
        }
    }

    private var appearance: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("APPEARANCE")
                .font(.jingleText(12, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(theme.muted)
            VStack(spacing: 10) {
                ForEach(AppearanceTheme.allCases, id: \.self) { choice in
                    let on = model.settings.theme == choice
                    Button {
                        model.updateSettings { $0.theme = choice }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(choice.displayName)
                                    .font(.jingleText(16, weight: .semibold))
                                    .foregroundStyle(theme.text)
                                Text(choice.detail)
                                    .font(.jingleText(13))
                                    .foregroundStyle(theme.muted)
                            }
                            Spacer()
                            if on {
                                Text("On")
                                    .font(.jingleText(13, weight: .semibold))
                                    .foregroundStyle(theme.onOrange)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(theme.orange, in: Capsule())
                            }
                        }
                        .padding(16)
                        .background(theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(on ? theme.orange.opacity(0.8) : theme.stroke, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(choice.displayName)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }

    private var bedside: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BEDSIDE")
                .font(.jingleText(12, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(theme.muted)
            VStack(spacing: 0) {
                toggleRow(
                    title: "Blank the display",
                    detail: "Goes fully dark after a quiet moment. Tap to wake.",
                    isOn: Binding(
                        get: { model.settings.autoBlank },
                        set: { value in model.updateSettings { $0.autoBlank = value } }
                    )
                )
                Rectangle().fill(theme.stroke).frame(height: 1)
                toggleRow(
                    title: "Dim the screen",
                    detail: "Lowers brightness on the clock, then restores it.",
                    isOn: Binding(
                        get: { model.settings.bedsideDim },
                        set: { value in model.updateSettings { $0.bedsideDim = value } }
                    )
                )
            }
            .background(theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(theme.stroke, lineWidth: 1)
            )
        }
    }

    private func toggleRow(title: String, detail: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.jingleText(16, weight: .semibold))
                    .foregroundStyle(theme.text)
                Text(detail)
                    .font(.jingleText(13))
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(theme.orange)
        }
        .padding(16)
    }

    private var about: some View {
        VStack(spacing: 8) {
            Text("Jingle")
                .font(.jingleTime(36))
                .foregroundStyle(theme.text)
            Text("Your wake up morning companion.")
                .font(.jingleText(15))
                .foregroundStyle(theme.muted)
            Text("Designed by Matthew Finley. Wake tones and machine mode stay on this phone.")
                .font(.jingleText(13))
                .foregroundStyle(theme.faint)
                .multilineTextAlignment(.center)
            Text("Version \(version) · app.jingle.ios")
                .font(.jingleText(13, weight: .medium))
                .foregroundStyle(theme.faint)
            Button {
                showingPrivacy = true
            } label: {
                Text("Privacy policy")
                    .font(.jingleText(15, weight: .medium))
                    .foregroundStyle(theme.orangeText)
            }
            .padding(.top, 8)
            Text("MIT License")
                .font(.jingleText(13))
                .foregroundStyle(theme.faint)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
    }
}

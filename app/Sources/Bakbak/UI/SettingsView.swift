import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        Form {
            Section("Hotkey") {
                LabeledContent("Hold to talk") {
                    Text(appState.settingsStore.settings.hotkeyLabel)
                }
                Text("Configurable hotkeys come later. Default is Right Option.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Speech recognition") {
                LabeledContent("Engine") {
                    Text("FluidAudio Parakeet")
                }
                LabeledContent("Model") {
                    Text(appState.settingsStore.settings.asrModelVersion)
                }
                LabeledContent("Language") {
                    Text("English")
                }
            }

            Section("History") {
                Stepper(
                    "Keep \(appState.settingsStore.settings.historyLimit) entries",
                    value: Binding(
                        get: { appState.settingsStore.settings.historyLimit },
                        set: { newValue in
                            appState.settingsStore.update { $0.historyLimit = newValue }
                            appState.historyStore.setLimit(newValue)
                        }
                    ),
                    in: 10...500,
                    step: 10
                )
                Button("Clear history", role: .destructive) {
                    appState.historyStore.clear()
                }
            }

            Section("Permissions") {
                LabeledContent("Microphone") {
                    Text(appState.micAuthorized ? "Granted" : "Missing")
                }
                LabeledContent("Accessibility") {
                    Text(appState.accessibilityTrusted ? "Granted" : "Missing")
                }
                Button("Refresh permission status") {
                    appState.refreshPermissions()
                    appState.startHotkeyIfPossible()
                }
                Button("Open Accessibility Settings") {
                    PermissionManager.openAccessibilitySettings()
                }
            }

            Section("About") {
                LabeledContent("App") { Text("Bakbak 0.1.0") }
                Text("Fully local. No paid APIs. Ad-hoc signed — no Apple Developer account required for personal use.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 360, minHeight: 320)
    }
}

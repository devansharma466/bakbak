import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState
    @State private var showDictionary = false

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

            Section("Clean-up (free, on-device)") {
                Toggle(
                    "Clean up transcripts",
                    isOn: Binding(
                        get: { appState.settingsStore.settings.cleanupEnabled },
                        set: { newValue in appState.settingsStore.update { $0.cleanupEnabled = newValue } }
                    )
                )
                Text("Removes um/uh and filler “like”, fixes simple self-corrections (“Tuesday, I mean Wednesday”), adds punctuation and capitals. When off, the raw transcript is pasted (dictionary spellings still apply).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle(
                    "Use Apple Intelligence when available",
                    isOn: Binding(
                        get: { appState.settingsStore.settings.useAppleIntelligence },
                        set: { newValue in appState.settingsStore.update { $0.useAppleIntelligence = newValue } }
                    )
                )
                .disabled(!appState.settingsStore.settings.cleanupEnabled)
                LabeledContent("Apple Intelligence") {
                    Text(CleanupEngineStatus.appleIntelligenceDescription)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Fallback") {
                    Text("Built-in rules (always on-device)")
                }
                LabeledContent("Personal dictionary") {
                    Text("\(appState.dictionaryStore.entries.count) entries")
                }
                Button("Edit dictionary…") { showDictionary = true }
            }

            Section("Meetings") {
                LabeledContent("Retention") {
                    Text("\(appState.settingsStore.settings.meetingRetentionDays) days")
                }
                Text("Meeting transcripts are stored locally and auto-deleted after \(appState.settingsStore.settings.meetingRetentionDays) days. Audio is not kept.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                LabeledContent("Saved meetings") {
                    Text("\(appState.meetingStore.meetings.count)")
                }
                Button("Purge expired now") {
                    let removed = appState.meetingStore.purgeExpired()
                    _ = removed
                }
                Button("Clear all meetings", role: .destructive) {
                    appState.meetingStore.clear()
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
                LabeledContent("Screen Recording") {
                    Text(appState.screenRecordingAuthorized ? "Granted (system audio)" : "Missing (mic-only meetings)")
                }
                Button("Refresh permission status") {
                    appState.refreshPermissions()
                    appState.startHotkeyIfPossible()
                }
                Button("Open Accessibility Settings") {
                    PermissionManager.openAccessibilitySettings()
                }
                Button("Open Screen Recording Settings") {
                    PermissionManager.openScreenRecordingSettings()
                }
                Button("Request Screen Recording") {
                    _ = PermissionManager.requestScreenRecording()
                    appState.refreshPermissions()
                }
            }

            Section("About") {
                LabeledContent("App") { Text("Bakbak 0.4.0") }
                Text("Fully local. No paid APIs. Meeting mode: mic (+ system audio via ScreenCaptureKit when permitted).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 440, minHeight: 560)
        .sheet(isPresented: $showDictionary) {
            DictionaryView(appState: appState)
        }
    }
}

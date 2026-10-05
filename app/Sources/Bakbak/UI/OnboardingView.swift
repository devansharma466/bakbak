import SwiftUI

struct OnboardingView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to Bakbak")
                .font(.title2.bold())
            Text("Personal on-device dictation. Hold Right Option, speak, release — text appears at your cursor. No cloud accounts.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            GroupBox("Permissions") {
                VStack(alignment: .leading, spacing: 12) {
                    permissionRow(
                        title: "Microphone",
                        ok: appState.micAuthorized,
                        grant: {
                            Task {
                                _ = await PermissionManager.requestMicrophone()
                                appState.refreshPermissions()
                            }
                        },
                        openSettings: PermissionManager.openMicrophoneSettings
                    )
                    permissionRow(
                        title: "Accessibility",
                        ok: appState.accessibilityTrusted,
                        grant: {
                            _ = PermissionManager.promptAccessibilityIfNeeded()
                            appState.refreshPermissions()
                        },
                        openSettings: PermissionManager.openAccessibilitySettings
                    )
                }
                .padding(.vertical, 4)
            }

            Text("After granting Accessibility, you may need to toggle Bakbak off/on in System Settings if you rebuild or move the app.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Continue") {
                    appState.refreshPermissions()
                    appState.completeOnboarding()
                    appState.startHotkeyIfPossible()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!appState.micAuthorized)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            appState.refreshPermissions()
            Task {
                if !appState.micAuthorized {
                    _ = await PermissionManager.requestMicrophone()
                    appState.refreshPermissions()
                }
            }
        }
    }

    @ViewBuilder
    private func permissionRow(
        title: String,
        ok: Bool,
        grant: @escaping () -> Void,
        openSettings: @escaping () -> Void
    ) -> some View {
        HStack {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(ok ? .green : .orange)
            Text(title)
            Spacer()
            if ok {
                Text("Granted")
                    .foregroundStyle(.secondary)
            } else {
                Button("Grant", action: grant)
                Button("Open Settings", action: openSettings)
            }
        }
    }
}

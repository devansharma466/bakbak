import SwiftUI

@main
struct BakbakApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appDelegate.appState)
        } label: {
            // Separate view so @Observable recording/meeting state updates the icon.
            MenuBarLabel(appState: appDelegate.appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(appState: appDelegate.appState)
        }
    }
}

private struct MenuBarLabel: View {
    @Bindable var appState: AppState

    var body: some View {
        Group {
            let idle = appState.recordingState == .idle && appState.meetingState == .idle
            if idle, let template = StatusIcon.menuBarTemplateImage() {
                Image(nsImage: template)
            } else {
                Image(systemName: StatusIcon.symbol(for: appState.recordingState, meeting: appState.meetingState))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(appState.meetingState == .recording ? .red : .primary)
            }
        }
        .accessibilityLabel(statusAccessibilityLabel)
    }

    private var statusAccessibilityLabel: String {
        switch appState.meetingState {
        case .recording: return "Bakbak meeting recording"
        case .processing: return "Bakbak transcribing meeting"
        case .error: return "Bakbak meeting error"
        case .idle: break
        }
        switch appState.recordingState {
        case .idle: return "Bakbak"
        case .recording: return "Bakbak recording"
        case .transcribing: return "Bakbak transcribing"
        case .inserting: return "Bakbak inserting"
        case .error: return "Bakbak error"
        }
    }
}

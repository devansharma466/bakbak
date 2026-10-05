import SwiftUI

@main
struct BakbakApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appDelegate.appState)
        } label: {
            // Separate view so @Observable recordingState updates the icon.
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
        Image(systemName: StatusIcon.symbol(for: appState.recordingState))
            .symbolRenderingMode(.hierarchical)
            .accessibilityLabel(statusAccessibilityLabel)
    }

    private var statusAccessibilityLabel: String {
        switch appState.recordingState {
        case .idle: return "Bakbak"
        case .recording: return "Bakbak recording"
        case .transcribing: return "Bakbak transcribing"
        case .inserting: return "Bakbak inserting"
        case .error: return "Bakbak error"
        }
    }
}

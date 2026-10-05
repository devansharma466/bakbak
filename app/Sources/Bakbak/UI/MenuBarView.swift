import SwiftUI

struct MenuBarView: View {
    @Bindable var appState: AppState
    @State private var showSettings = false
    @State private var showHistory = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: StatusIcon.symbol(for: appState.recordingState))
                Text(title(for: appState.recordingState))
                    .fontWeight(.semibold)
                Spacer()
            }

            Text(appState.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if !appState.lastTranscript.isEmpty {
                Divider()
                Text(appState.lastTranscript)
                    .font(.callout)
                    .lineLimit(4)
                    .textSelection(.enabled)
            }

            Divider()

            Button("History…") { showHistory = true }
            Button("Settings…") { showSettings = true }
            Button("Reload ASR model") {
                Task { await appState.warmModels() }
            }
            Button("Refresh permissions") {
                appState.refreshPermissions()
                appState.startHotkeyIfPossible()
            }

            Divider()
            Button("Quit Bakbak") { appState.quit() }
                .keyboardShortcut("q")
        }
        .padding(10)
        .frame(width: 280)
        .sheet(isPresented: $showSettings) {
            SettingsView(appState: appState)
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(appState: appState)
                .padding()
        }
        .sheet(isPresented: $appState.showOnboarding) {
            OnboardingView(appState: appState)
        }
    }

    private func title(for state: RecordingState) -> String {
        switch state {
        case .idle: return "Bakbak"
        case .recording: return "Recording"
        case .transcribing: return "Transcribing"
        case .inserting: return "Inserting"
        case .error: return "Error"
        }
    }
}

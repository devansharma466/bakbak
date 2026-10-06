import SwiftUI

struct MenuBarView: View {
    @Bindable var appState: AppState
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var showDictionary = false
    @State private var showMeetings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if case .recording = appState.meetingState {
                recordingBanner
            } else if !appState.lastTranscript.isEmpty, appState.meetingState == .idle {
                Text(appState.lastTranscript)
                    .font(BakbakTheme.bodyFont(13))
                    .foregroundStyle(BakbakTheme.slate)
                    .lineLimit(3)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BakbakTheme.mist, in: RoundedRectangle(cornerRadius: BakbakTheme.radiusInput, style: .continuous))
            }

            primaryMeetingCTA

            permissionsRow

            VStack(spacing: 2) {
                menuRow("Open Library", icon: "rectangle.stack") {
                    appState.openLibraryWindow?()
                }
                menuRow("Meetings", icon: "person.2") { showMeetings = true }
                menuRow("History", icon: "clock") { showHistory = true }
                menuRow("Dictionary", icon: "book") { showDictionary = true }
            }

            Divider().overlay(BakbakTheme.hairline)

            HStack(spacing: 8) {
                Toggle(
                    "Clean-up",
                    isOn: Binding(
                        get: { appState.settingsStore.settings.cleanupEnabled },
                        set: { newValue in appState.settingsStore.update { $0.cleanupEnabled = newValue } }
                    )
                )
                .toggleStyle(.checkbox)
                .font(BakbakTheme.bodyFont(12))
                .foregroundStyle(BakbakTheme.ink)

                Spacer()

                Button("Settings") { showSettings = true }
                    .font(BakbakTheme.bodyFont(12))
                    .foregroundStyle(BakbakTheme.slate)
                    .buttonStyle(.plain)
            }

            HStack {
                Button("Refresh permissions") {
                    appState.refreshPermissions()
                    appState.startHotkeyIfPossible()
                }
                .font(BakbakTheme.bodyFont(11))
                .foregroundStyle(BakbakTheme.ash)
                .buttonStyle(.plain)

                Spacer()

                Button("Quit") { appState.quit() }
                    .font(BakbakTheme.bodyFont(11))
                    .foregroundStyle(BakbakTheme.ash)
                    .buttonStyle(.plain)
                    .keyboardShortcut("q")
            }
        }
        .padding(14)
        .frame(width: 300)
        .background(BakbakTheme.paper)
        .sheet(isPresented: $showSettings) {
            SettingsView(appState: appState)
        }
        .sheet(isPresented: $showDictionary) {
            DictionaryView(appState: appState)
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(appState: appState)
                .frame(minWidth: 480, minHeight: 360)
        }
        .sheet(isPresented: $showMeetings) {
            MeetingsView(appState: appState)
                .frame(minWidth: 640, minHeight: 420)
        }
        .sheet(isPresented: $appState.showOnboarding) {
            OnboardingView(appState: appState)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            statusGlyph
            VStack(alignment: .leading, spacing: 2) {
                Text(titleText)
                    .font(BakbakTheme.bodyFont(15, weight: .medium))
                    .foregroundStyle(BakbakTheme.ink)
                Text(appState.statusMessage)
                    .font(BakbakTheme.bodyFont(11))
                    .foregroundStyle(BakbakTheme.slate)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }

    private var recordingBanner: some View {
        Text("Recording… stop when you’re done")
            .font(BakbakTheme.bodyFont(12, weight: .medium))
            .foregroundStyle(BakbakTheme.sienna)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BakbakTheme.peach, in: RoundedRectangle(cornerRadius: BakbakTheme.radiusInput, style: .continuous))
    }

    @ViewBuilder
    private var primaryMeetingCTA: some View {
        switch appState.meetingState {
        case .idle, .error:
            BakbakFilledPill(title: "Start meeting", expand: true) {
                Task { await appState.startMeeting() }
            }
            .disabled(appState.recordingState == .recording || appState.recordingState == .transcribing || appState.recordingState == .inserting)
            .opacity(appState.recordingState == .recording || appState.recordingState == .transcribing || appState.recordingState == .inserting ? 0.45 : 1)
            .frame(maxWidth: .infinity)

            if !appState.screenRecordingAuthorized {
                Text("System audio needs Screen Recording — mic-only still works.")
                    .font(BakbakTheme.bodyFont(11))
                    .foregroundStyle(BakbakTheme.ash)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .recording:
            BakbakFilledPill(title: "Stop meeting", expand: true) {
                Task { await appState.stopMeeting() }
            }
            .frame(maxWidth: .infinity)

        case .processing:
            Text("Transcribing meeting…")
                .font(BakbakTheme.bodyFont(13))
                .foregroundStyle(BakbakTheme.slate)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var permissionsRow: some View {
        HStack(spacing: 12) {
            PermissionDot(label: "Mic", ok: appState.micAuthorized)
            PermissionDot(label: "Access", ok: appState.accessibilityTrusted)
            PermissionDot(label: "Screen", ok: appState.screenRecordingAuthorized)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private func menuRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(BakbakTheme.ash)
                    .frame(width: 16)
                Text(title)
                    .font(BakbakTheme.bodyFont(13))
                    .foregroundStyle(BakbakTheme.ink)
                Spacer()
                Text("→")
                    .font(BakbakTheme.bodyFont(13))
                    .foregroundStyle(BakbakTheme.smoke)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var statusGlyph: some View {
        let showParrot = appState.recordingState == .idle && appState.meetingState == .idle
        if showParrot, let template = StatusIcon.menuBarTemplateImage() {
            Image(nsImage: template)
                .resizable()
                .interpolation(.high)
                .frame(width: 14, height: 12)
        } else if case .recording = appState.meetingState {
            Circle()
                .fill(BakbakTheme.ink)
                .frame(width: 8, height: 8)
                .padding(4)
                .overlay(Circle().stroke(BakbakTheme.ink.opacity(0.25), lineWidth: 1))
        } else {
            Image(systemName: StatusIcon.symbol(for: appState.recordingState, meeting: appState.meetingState))
                .foregroundStyle(BakbakTheme.ink)
        }
    }

    private var titleText: String {
        switch appState.meetingState {
        case .recording: return "Meeting"
        case .processing: return "Transcribing"
        case .error: return "Meeting error"
        case .idle: break
        }
        switch appState.recordingState {
        case .idle: return "Bakbak"
        case .recording: return "Recording"
        case .transcribing: return "Transcribing"
        case .inserting: return "Inserting"
        case .error: return "Error"
        }
    }
}

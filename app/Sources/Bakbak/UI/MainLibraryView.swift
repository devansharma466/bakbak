import SwiftUI

/// Main transcripts window — Steep editorial library shell.
struct MainLibraryView: View {
    @Bindable var appState: AppState
    @State private var selectedTab: LibraryTab = .meetings

    enum LibraryTab: Hashable {
        case meetings
        case history
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 20)

            BakbakSegmentedControl(
                tabs: [
                    (.meetings, "Meetings"),
                    (.history, "Dictation")
                ],
                selection: $selectedTab
            )
            .padding(.horizontal, 28)
            .padding(.bottom, 16)
            .frame(maxWidth: 360)
            .frame(maxWidth: .infinity, alignment: .leading)

            Group {
                switch selectedTab {
                case .meetings:
                    MeetingsView(appState: appState)
                case .history:
                    HistoryView(appState: appState)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(BakbakTheme.paper)
        .frame(minWidth: 760, minHeight: 500)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            if let parrot = BakbakTheme.parrotImage() {
                Image(nsImage: parrot)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: BakbakTheme.radiusImage, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Bakbak")
                    .font(BakbakTheme.displayFont(32))
                    .tracking(-0.5)
                    .foregroundStyle(BakbakTheme.ink)
                Text(statusLine)
                    .font(BakbakTheme.bodyFont(14))
                    .foregroundStyle(BakbakTheme.slate)
            }

            Spacer(minLength: 12)

            if case .recording = appState.meetingState {
                Text("Recording…")
                    .font(BakbakTheme.bodyFont(13, weight: .medium))
                    .foregroundStyle(BakbakTheme.sienna)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(BakbakTheme.peach, in: Capsule())
            }
        }
    }

    private var statusLine: String {
        switch appState.meetingState {
        case .recording:
            return "Meeting in progress — stop from the menu bar parrot"
        case .processing:
            return "Transcribing your meeting…"
        case .error:
            return appState.statusMessage
        case .idle:
            break
        }
        if !appState.modelReady {
            return appState.statusMessage
        }
        return appState.statusMessage
    }
}

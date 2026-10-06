import AppKit
import SwiftUI

struct MeetingsView: View {
    @Bindable var appState: AppState
    @State private var selectedID: UUID?
    @State private var renameText: String = ""
    @State private var isRenaming = false
    @State private var hoveredID: UUID?

    var body: some View {
        Group {
            if appState.meetingStore.meetings.isEmpty {
                BakbakEmptyHero(
                    title: "No chatter yet",
                    subtitle: "Start a meeting from the parrot menu. Transcripts stay on this Mac."
                )
            } else {
                HStack(spacing: 0) {
                    cardList
                        .frame(minWidth: 300, idealWidth: 340, maxWidth: 400)
                    Rectangle()
                        .fill(BakbakTheme.hairline)
                        .frame(width: 1)
                    detailPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(BakbakTheme.fog)
            }
        }
        .alert("Rename meeting", isPresented: $isRenaming) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                guard var meeting = selectedMeeting else { return }
                let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                meeting.title = trimmed
                appState.meetingStore.update(meeting)
            }
        }
    }

    private var cardList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(appState.meetingStore.meetings) { meeting in
                    MeetingCard(
                        meeting: meeting,
                        selected: selectedID == meeting.id,
                        hovering: hoveredID == meeting.id,
                        onCopy: { copy(meeting.cleanedTranscript) }
                    )
                    .onTapGesture { selectedID = meeting.id }
                    .onHover { hovering in
                        hoveredID = hovering ? meeting.id : (hoveredID == meeting.id ? nil : hoveredID)
                    }
                    .contextMenu {
                        Button("Copy transcript") { copy(meeting.cleanedTranscript) }
                        if meeting.rawTranscript != meeting.cleanedTranscript {
                            Button("Copy raw transcript") { copy(meeting.rawTranscript) }
                        }
                        Button("Rename…") {
                            selectedID = meeting.id
                            renameText = meeting.title
                            isRenaming = true
                        }
                        Button("Delete", role: .destructive) {
                            appState.meetingStore.remove(id: meeting.id)
                            if selectedID == meeting.id { selectedID = nil }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(BakbakTheme.paper)
    }

    @ViewBuilder
    private var detailPane: some View {
        if let meeting = selectedMeeting {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(meeting.title)
                        .font(BakbakTheme.displayFont(28))
                        .tracking(-0.4)
                        .foregroundStyle(BakbakTheme.ink)

                    HStack(spacing: 8) {
                        BakbakTag(text: BakbakTheme.relativeTime(meeting.createdAt), icon: "clock")
                        BakbakTag(text: BakbakTheme.formatDuration(meeting.durationSeconds), icon: "timer")
                        BakbakTag(
                            text: BakbakTheme.audioSourceLabel(meeting.audioSource),
                            icon: "waveform"
                        )
                    }

                    Text(meeting.cleanedTranscript.isEmpty ? "(No speech detected)" : meeting.cleanedTranscript)
                        .font(BakbakTheme.bodyFont(15))
                        .foregroundStyle(BakbakTheme.ink)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(BakbakTheme.mist, in: RoundedRectangle(cornerRadius: BakbakTheme.radiusCard, style: .continuous))

                    HStack(spacing: 10) {
                        BakbakFilledPill(title: "Copy", compact: true) {
                            copy(meeting.cleanedTranscript)
                        }
                        BakbakGhostPill(title: "Rename", compact: true) {
                            renameText = meeting.title
                            isRenaming = true
                        }
                        Spacer()
                        Button("Delete") {
                            appState.meetingStore.remove(id: meeting.id)
                            selectedID = nil
                        }
                        .font(BakbakTheme.bodyFont(13))
                        .foregroundStyle(BakbakTheme.slate)
                        .buttonStyle(.plain)
                    }
                }
                .padding(28)
            }
            .background(BakbakTheme.fog)
        } else {
            VStack(spacing: 8) {
                Text("Select a meeting")
                    .font(BakbakTheme.displayFont(24))
                    .foregroundStyle(BakbakTheme.ink)
                Text("Transcripts are local and auto-deleted after \(appState.settingsStore.settings.meetingRetentionDays) days.")
                    .font(BakbakTheme.bodyFont(14))
                    .foregroundStyle(BakbakTheme.slate)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BakbakTheme.fog)
        }
    }

    private var selectedMeeting: Meeting? {
        guard let selectedID else { return nil }
        return appState.meetingStore.meetings.first { $0.id == selectedID }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

private struct MeetingCard: View {
    let meeting: Meeting
    let selected: Bool
    let hovering: Bool
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(meeting.title)
                    .font(BakbakTheme.bodyFont(15, weight: .medium))
                    .foregroundStyle(BakbakTheme.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(BakbakTheme.relativeTime(meeting.createdAt))
                    .font(BakbakTheme.bodyFont(12))
                    .foregroundStyle(BakbakTheme.ash)
            }

            HStack(spacing: 6) {
                BakbakTag(text: BakbakTheme.formatDuration(meeting.durationSeconds), icon: "timer")
                BakbakTag(text: BakbakTheme.audioSourceLabel(meeting.audioSource), icon: "waveform")
                Spacer(minLength: 4)
                if hovering || selected {
                    Button("Copy", action: onCopy)
                        .font(BakbakTheme.bodyFont(12, weight: .medium))
                        .foregroundStyle(BakbakTheme.ink)
                        .buttonStyle(.plain)
                }
            }

            Text(previewText)
                .font(BakbakTheme.bodyFont(13))
                .foregroundStyle(BakbakTheme.slate)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: BakbakTheme.radiusCard, style: .continuous)
                .fill(selected ? BakbakTheme.mist : BakbakTheme.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BakbakTheme.radiusCard, style: .continuous)
                .stroke(selected ? BakbakTheme.ink.opacity(0.18) : BakbakTheme.hairline, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(selected || hovering ? 0.06 : 0.03), radius: selected || hovering ? 10 : 4, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: BakbakTheme.radiusCard, style: .continuous))
    }

    private var previewText: String {
        let t = meeting.cleanedTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "No speech detected" : t
    }
}

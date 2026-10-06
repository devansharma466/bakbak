import AppKit
import SwiftUI

struct HistoryView: View {
    @Bindable var appState: AppState
    @State private var hoveredID: UUID?

    var body: some View {
        Group {
            if appState.historyStore.entries.isEmpty {
                BakbakEmptyHero(
                    title: "No chatter yet",
                    subtitle: "Hold Option to dictate. Your cleaned transcripts will land here."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(appState.historyStore.entries) { entry in
                            HistoryCard(
                                entry: entry,
                                hovering: hoveredID == entry.id,
                                onCopy: { copy(entry.cleanedText) }
                            )
                            .onHover { hovering in
                                hoveredID = hovering ? entry.id : (hoveredID == entry.id ? nil : hoveredID)
                            }
                            .contextMenu {
                                Button("Copy") { copy(entry.cleanedText) }
                                if entry.rawText != entry.cleanedText {
                                    Button("Copy raw transcript") { copy(entry.rawText) }
                                }
                                Button("Delete", role: .destructive) {
                                    appState.historyStore.remove(id: entry.id)
                                }
                            }
                        }
                    }
                    .padding(24)
                }
                .background(BakbakTheme.fog)
            }
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

private struct HistoryCard: View {
    let entry: HistoryEntry
    let hovering: Bool
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entry.cleanedText)
                .font(BakbakTheme.bodyFont(15))
                .foregroundStyle(BakbakTheme.ink)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Text(BakbakTheme.relativeTime(entry.createdAt))
                    .font(BakbakTheme.bodyFont(12))
                    .foregroundStyle(BakbakTheme.ash)
                BakbakTag(text: String(format: "%.1fs", entry.durationSeconds), icon: "timer")
                Spacer()
                if hovering {
                    Button("Copy", action: onCopy)
                        .font(BakbakTheme.bodyFont(12, weight: .medium))
                        .foregroundStyle(BakbakTheme.ink)
                        .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: BakbakTheme.radiusCard, style: .continuous)
                .fill(BakbakTheme.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BakbakTheme.radiusCard, style: .continuous)
                .stroke(BakbakTheme.hairline, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(hovering ? 0.06 : 0.03), radius: hovering ? 10 : 4, y: 3)
    }
}

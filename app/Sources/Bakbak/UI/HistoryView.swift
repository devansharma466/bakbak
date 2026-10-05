import AppKit
import SwiftUI

struct HistoryView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if appState.historyStore.entries.isEmpty {
                ContentUnavailableView(
                    "No dictations yet",
                    systemImage: "text.bubble",
                    description: Text("Hold Right Option and speak to create history.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(appState.historyStore.entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.cleanedText)
                                .lineLimit(3)
                            HStack {
                                Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                                Spacer()
                                Text(String(format: "%.1fs", entry.durationSeconds))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .contextMenu {
                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(entry.cleanedText, forType: .string)
                            }
                            Button("Delete", role: .destructive) {
                                appState.historyStore.remove(id: entry.id)
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 360, minHeight: 280)
    }
}

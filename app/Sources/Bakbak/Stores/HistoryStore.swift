import Foundation
import Observation

/// Local-only dictation history (JSON). Audio is not retained.
@MainActor
@Observable
final class HistoryStore {
    private(set) var entries: [HistoryEntry] = []
    private let fileURL: URL
    private var limit: Int

    init(fileURL: URL? = nil, limit: Int = 100) {
        let url = fileURL ?? Self.defaultFileURL()
        self.fileURL = url
        self.limit = max(1, limit)
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder.iso8601.decode([HistoryEntry].self, from: data) {
            self.entries = decoded
        }
    }

    func setLimit(_ limit: Int) {
        self.limit = max(1, limit)
        trim()
        save()
    }

    func append(_ entry: HistoryEntry) {
        entries.insert(entry, at: 0)
        trim()
        save()
    }

    func clear() {
        entries = []
        save()
    }

    func remove(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    private func trim() {
        if entries.count > limit {
            entries = Array(entries.prefix(limit))
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder.pretty.encode(entries)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            NSLog("Bakbak: failed to save history: \(error.localizedDescription)")
        }
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Bakbak/history.json", isDirectory: false)
    }
}

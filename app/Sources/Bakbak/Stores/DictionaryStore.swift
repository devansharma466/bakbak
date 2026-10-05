import Foundation
import Observation

/// Empty personal dictionary store (Phase 2 will wire biasing).
@MainActor
@Observable
final class DictionaryStore {
    private(set) var entries: [DictionaryEntry] = []
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        let url = fileURL ?? Self.defaultFileURL()
        self.fileURL = url
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder.iso8601.decode([DictionaryEntry].self, from: data) {
            self.entries = decoded
        }
    }

    var terms: [String] {
        entries.map(\.term)
    }

    func add(term: String, replacement: String? = nil) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        entries.append(DictionaryEntry(term: trimmed, replacement: replacement))
        save()
    }

    func remove(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder.pretty.encode(entries)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            NSLog("Bakbak: failed to save dictionary: \(error.localizedDescription)")
        }
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Bakbak/dictionary.json", isDirectory: false)
    }
}

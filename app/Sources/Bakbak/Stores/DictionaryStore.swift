import Foundation
import Observation

/// Personal dictionary (JSON under Application Support). Used by cleanup for preferred spellings.
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

    /// Adds a term, or merges aliases into an existing entry with the same spelling.
    func add(term: String, aliases: [String] = []) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let cleanAliases = Self.clean(aliases, excluding: trimmed)
        if let idx = entries.firstIndex(where: { $0.term.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            var entry = entries[idx]
            entry.term = trimmed
            entry.aliases = Self.clean(entry.aliases + cleanAliases, excluding: trimmed)
            entries[idx] = entry
        } else {
            entries.append(DictionaryEntry(term: trimmed, aliases: cleanAliases))
        }
        sortEntries()
        save()
    }

    func update(id: UUID, term: String, aliases: [String]) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[idx].term = trimmed
        entries[idx].aliases = Self.clean(aliases, excluding: trimmed)
        sortEntries()
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

    private func sortEntries() {
        entries.sort { $0.term.localizedCaseInsensitiveCompare($1.term) == .orderedAscending }
    }

    private static func clean(_ aliases: [String], excluding term: String) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for alias in aliases {
            let a = alias.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !a.isEmpty, a.caseInsensitiveCompare(term) != .orderedSame else { continue }
            if seen.insert(a.lowercased()).inserted { out.append(a) }
        }
        return out
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Bakbak/dictionary.json", isDirectory: false)
    }
}

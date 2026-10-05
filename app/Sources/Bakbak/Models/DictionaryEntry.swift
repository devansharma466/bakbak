import Foundation

/// A personal dictionary word/phrase for ASR/cleanup biasing (Phase 2).
struct DictionaryEntry: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var term: String
    var replacement: String?
    var createdAt: Date

    init(id: UUID = UUID(), term: String, replacement: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.term = term
        self.replacement = replacement
        self.createdAt = createdAt
    }
}

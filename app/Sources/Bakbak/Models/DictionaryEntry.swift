import Foundation

/// A personal dictionary entry used to bias cleanup toward preferred spellings.
///
/// - `term`: how it should be written (e.g. "FluidAudio", "Devan", "Bakbak").
/// - `aliases`: what the speech engine tends to produce instead (e.g. "fluid audio", "bak bak").
///   Matching is case-insensitive; spaces/hyphens between words of `term` are matched loosely,
///   so "fluid audio" → "FluidAudio" works without an explicit alias.
struct DictionaryEntry: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var term: String
    var aliases: [String]
    var createdAt: Date

    init(id: UUID = UUID(), term: String, aliases: [String] = [], createdAt: Date = Date()) {
        self.id = id
        self.term = term
        self.aliases = aliases
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, term, aliases, createdAt
        case replacement // Phase 0/1 stub field (spoken term → written replacement)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        let rawTerm = try c.decode(String.self, forKey: .term)
        var decodedAliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
        // Migrate old `replacement` semantics: term (spoken) → replacement (written).
        if let replacement = try c.decodeIfPresent(String.self, forKey: .replacement),
           !replacement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            term = replacement
            if !decodedAliases.contains(rawTerm) { decodedAliases.append(rawTerm) }
        } else {
            term = rawTerm
        }
        aliases = decodedAliases
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(term, forKey: .term)
        try c.encode(aliases, forKey: .aliases)
        try c.encode(createdAt, forKey: .createdAt)
    }

    /// Aliases parsed from a comma-separated UI field.
    static func parseAliases(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

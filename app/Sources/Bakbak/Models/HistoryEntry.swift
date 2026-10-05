import Foundation

/// A past dictation stored locally as JSON (no audio retention by default).
struct HistoryEntry: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var rawText: String
    var cleanedText: String
    var createdAt: Date
    var durationSeconds: Double
    var confidence: Float?

    init(
        id: UUID = UUID(),
        rawText: String,
        cleanedText: String,
        createdAt: Date = Date(),
        durationSeconds: Double,
        confidence: Float? = nil
    ) {
        self.id = id
        self.rawText = rawText
        self.cleanedText = cleanedText
        self.createdAt = createdAt
        self.durationSeconds = durationSeconds
        self.confidence = confidence
    }
}

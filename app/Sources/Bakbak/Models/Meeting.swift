import Foundation

/// A saved meeting transcript (local-only, auto-purged after retention days).
struct Meeting: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var title: String
    var createdAt: Date
    var endedAt: Date
    var durationSeconds: Double
    var rawTranscript: String
    var cleanedTranscript: String
    /// "microphone" or "microphone+system"
    var audioSource: String

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        endedAt: Date = Date(),
        durationSeconds: Double,
        rawTranscript: String,
        cleanedTranscript: String,
        audioSource: String = "microphone"
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.rawTranscript = rawTranscript
        self.cleanedTranscript = cleanedTranscript
        self.audioSource = audioSource
    }

    /// Default title: "Meeting — 5 Oct 2026, 15:30"
    static func defaultTitle(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        return "Meeting — \(formatter.string(from: date))"
    }
}

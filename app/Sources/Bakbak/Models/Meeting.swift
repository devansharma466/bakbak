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
    /// Who said what. Only present when system audio was captured (mic = you, system = them).
    var segments: [MeetingSegment]?
    /// Summary, decisions and action items written on-device by Apple Intelligence.
    var notes: MeetingNotes?

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        endedAt: Date = Date(),
        durationSeconds: Double,
        rawTranscript: String,
        cleanedTranscript: String,
        audioSource: String = "microphone",
        segments: [MeetingSegment]? = nil,
        notes: MeetingNotes? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.rawTranscript = rawTranscript
        self.cleanedTranscript = cleanedTranscript
        self.audioSource = audioSource
        self.segments = segments
        self.notes = notes
    }

    /// Default title: "Meeting — 5 Oct 2026, 15:30"
    static func defaultTitle(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        return "Meeting — \(formatter.string(from: date))"
    }
}

/// Mic = you; system audio = everyone else on the call.
enum MeetingSpeaker: String, Codable, Sendable {
    case you
    case them

    var label: String {
        switch self {
        case .you: return "You"
        case .them: return "Them"
        }
    }
}

/// One speaker turn of a meeting transcript.
struct MeetingSegment: Codable, Equatable, Sendable {
    var speaker: MeetingSpeaker
    var startSeconds: Double
    var endSeconds: Double
    var text: String

    /// Drops empty turns and joins back-to-back turns by the same speaker.
    static func merged(_ segments: [MeetingSegment]) -> [MeetingSegment] {
        var out: [MeetingSegment] = []
        for segment in segments {
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            if var last = out.last, last.speaker == segment.speaker {
                last.text += " " + text
                last.endSeconds = segment.endSeconds
                out[out.count - 1] = last
            } else {
                var copy = segment
                copy.text = text
                out.append(copy)
            }
        }
        return out
    }

    /// "You: …\n\nThem: …" — what Copy and the notes writer see.
    static func transcript(_ segments: [MeetingSegment]) -> String {
        merged(segments)
            .map { "\($0.speaker.label): \($0.text)" }
            .joined(separator: "\n\n")
    }
}

/// On-device meeting notes.
struct MeetingNotes: Codable, Equatable, Sendable {
    var summary: String
    var decisions: [String]
    var actionItems: [String]
    var createdAt: Date

    init(summary: String, decisions: [String], actionItems: [String], createdAt: Date = Date()) {
        self.summary = summary
        self.decisions = decisions
        self.actionItems = actionItems
        self.createdAt = createdAt
    }

    /// Plain-text version for the clipboard.
    var plainText: String {
        var parts = ["Summary\n\(summary)"]
        if !decisions.isEmpty {
            parts.append("Decisions\n" + decisions.map { "- \($0)" }.joined(separator: "\n"))
        }
        if !actionItems.isEmpty {
            parts.append("Action items\n" + actionItems.map { "- \($0)" }.joined(separator: "\n"))
        }
        return parts.joined(separator: "\n\n")
    }
}

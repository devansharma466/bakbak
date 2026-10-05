import Foundation

/// Phase 2 clean-up protocol. Phase 1 uses a pass-through stub.
///
/// Free / on-device only — no paid cloud APIs:
/// 1. Apple Foundation Models / Apple Intelligence when available on the Mac
/// 2. Otherwise a small local MLX model
/// 3. Fallback: regex filler-word strip ("um", "uh", …)
protocol TextCleanupService: Sendable {
    /// Polish raw ASR text. `dictionaryTerms` are personal names/jargon for future biasing.
    func cleanup(_ text: String, dictionaryTerms: [String]) async throws -> String
}

/// Phase 1 stub: returns text unchanged.
struct PassthroughCleanupService: TextCleanupService {
    func cleanup(_ text: String, dictionaryTerms: [String]) async throws -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Phase 2 placeholder — strip common English fillers with regex.
/// Not wired as default yet; kept for the free local cleanup path.
struct RegexFillerCleanupService: TextCleanupService {
    func cleanup(_ text: String, dictionaryTerms: [String]) async throws -> String {
        var result = text
        let patterns = [
            #"\b(um|uh|erm|hmm|ah|like)\b[,.]?"#,
            #"\s{2,}"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: " ")
            }
        }
        return result
            .replacingOccurrences(of: " ,", with: ",")
            .replacingOccurrences(of: " .", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Phase 2 placeholder for Apple Foundation Models / Apple Intelligence.
/// Implement when targeting a macOS that exposes the on-device API.
struct AppleIntelligenceCleanupService: TextCleanupService {
    func cleanup(_ text: String, dictionaryTerms: [String]) async throws -> String {
        // Stub: fall back to regex until Foundation Models are wired in Phase 2.
        try await RegexFillerCleanupService().cleanup(text, dictionaryTerms: dictionaryTerms)
    }
}

/// Phase 2 placeholder for a small on-device MLX model.
struct LocalMLXCleanupService: TextCleanupService {
    func cleanup(_ text: String, dictionaryTerms: [String]) async throws -> String {
        try await RegexFillerCleanupService().cleanup(text, dictionaryTerms: dictionaryTerms)
    }
}

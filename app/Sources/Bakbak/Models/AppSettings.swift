import Foundation

/// Persisted user settings for Bakbak.
struct AppSettings: Codable, Equatable, Sendable {
    /// Hold-to-talk key code. Default: Right Option (61).
    var hotkeyKeyCode: UInt16
    /// Human-readable hotkey label for UI.
    var hotkeyLabel: String
    /// FluidAudio Parakeet model version. English-only v2 by default.
    var asrModelVersion: String
    /// Whether onboarding has been completed.
    var hasCompletedOnboarding: Bool
    /// Maximum number of history entries to keep.
    var historyLimit: Int
    /// Whether to play subtle sound feedback when recording starts/stops.
    var soundFeedbackEnabled: Bool
    /// Phase 2: polish transcripts (fillers, self-corrections, punctuation). Free + on-device.
    var cleanupEnabled: Bool
    /// Phase 2: try Apple Foundation Models (Apple Intelligence) before heuristics, when available.
    /// Off by default — heuristics cover the free path.
    var useAppleIntelligence: Bool
    /// Phase 4: auto-delete meeting transcripts older than this many days.
    var meetingRetentionDays: Int

    static let `default` = AppSettings(
        hotkeyKeyCode: 61, // Right Option
        hotkeyLabel: "Right Option",
        asrModelVersion: "v2",
        hasCompletedOnboarding: false,
        historyLimit: 100,
        soundFeedbackEnabled: true,
        cleanupEnabled: true,
        useAppleIntelligence: false,
        meetingRetentionDays: 30
    )

    init(
        hotkeyKeyCode: UInt16,
        hotkeyLabel: String,
        asrModelVersion: String,
        hasCompletedOnboarding: Bool,
        historyLimit: Int,
        soundFeedbackEnabled: Bool,
        cleanupEnabled: Bool,
        useAppleIntelligence: Bool,
        meetingRetentionDays: Int
    ) {
        self.hotkeyKeyCode = hotkeyKeyCode
        self.hotkeyLabel = hotkeyLabel
        self.asrModelVersion = asrModelVersion
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.historyLimit = historyLimit
        self.soundFeedbackEnabled = soundFeedbackEnabled
        self.cleanupEnabled = cleanupEnabled
        self.useAppleIntelligence = useAppleIntelligence
        self.meetingRetentionDays = meetingRetentionDays
    }

    private enum CodingKeys: String, CodingKey {
        case hotkeyKeyCode, hotkeyLabel, asrModelVersion, hasCompletedOnboarding
        case historyLimit, soundFeedbackEnabled, cleanupEnabled, useAppleIntelligence
        case meetingRetentionDays
    }

    /// Tolerant decoding so older settings.json keeps onboarding state etc.
    init(from decoder: Decoder) throws {
        let d = Self.default
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hotkeyKeyCode = try c.decodeIfPresent(UInt16.self, forKey: .hotkeyKeyCode) ?? d.hotkeyKeyCode
        hotkeyLabel = try c.decodeIfPresent(String.self, forKey: .hotkeyLabel) ?? d.hotkeyLabel
        asrModelVersion = try c.decodeIfPresent(String.self, forKey: .asrModelVersion) ?? d.asrModelVersion
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? d.hasCompletedOnboarding
        historyLimit = try c.decodeIfPresent(Int.self, forKey: .historyLimit) ?? d.historyLimit
        soundFeedbackEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundFeedbackEnabled) ?? d.soundFeedbackEnabled
        cleanupEnabled = try c.decodeIfPresent(Bool.self, forKey: .cleanupEnabled) ?? d.cleanupEnabled
        useAppleIntelligence = try c.decodeIfPresent(Bool.self, forKey: .useAppleIntelligence) ?? d.useAppleIntelligence
        meetingRetentionDays = try c.decodeIfPresent(Int.self, forKey: .meetingRetentionDays) ?? d.meetingRetentionDays
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(hotkeyKeyCode, forKey: .hotkeyKeyCode)
        try c.encode(hotkeyLabel, forKey: .hotkeyLabel)
        try c.encode(asrModelVersion, forKey: .asrModelVersion)
        try c.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try c.encode(historyLimit, forKey: .historyLimit)
        try c.encode(soundFeedbackEnabled, forKey: .soundFeedbackEnabled)
        try c.encode(cleanupEnabled, forKey: .cleanupEnabled)
        try c.encode(useAppleIntelligence, forKey: .useAppleIntelligence)
        try c.encode(meetingRetentionDays, forKey: .meetingRetentionDays)
    }
}

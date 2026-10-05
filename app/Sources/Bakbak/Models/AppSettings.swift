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

    static let `default` = AppSettings(
        hotkeyKeyCode: 61, // Right Option
        hotkeyLabel: "Right Option",
        asrModelVersion: "v2",
        hasCompletedOnboarding: false,
        historyLimit: 100,
        soundFeedbackEnabled: true
    )
}

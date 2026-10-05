import AppKit
import Foundation
import FluidAudio
import Observation

enum RecordingState: Equatable {
    case idle
    case recording
    case transcribing
    case inserting
    case error(String)
}

/// Central observable app state for the menu bar UI and dictation pipeline.
@MainActor
@Observable
final class AppState {
    let settingsStore: SettingsStore
    let dictionaryStore: DictionaryStore
    let historyStore: HistoryStore

    let transcription = TranscriptionService()
    let cleanup: any TextCleanupService = PassthroughCleanupService()
    let textInserter = TextInserter()
    let microphone = MicrophoneCapture()

    private var hotkeyMonitor: HotkeyMonitor?
    private var didBootstrap = false

    var recordingState: RecordingState = .idle
    var lastTranscript: String = ""
    var statusMessage: String = "Ready"
    var showOnboarding: Bool = false
    var modelReady: Bool = false
    var micAuthorized: Bool = false
    var accessibilityTrusted: Bool = false

    var isBusy: Bool {
        switch recordingState {
        case .recording, .transcribing, .inserting: return true
        default: return false
        }
    }

    init() {
        let settings = SettingsStore()
        self.settingsStore = settings
        self.dictionaryStore = DictionaryStore()
        self.historyStore = HistoryStore(limit: settings.settings.historyLimit)
        self.showOnboarding = !settings.settings.hasCompletedOnboarding
        refreshPermissions()
    }

    func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true
        refreshPermissions()
        if !settingsStore.settings.hasCompletedOnboarding {
            showOnboarding = true
        }
        Task { await warmModels() }
        startHotkeyIfPossible()
    }

    func refreshPermissions() {
        micAuthorized = PermissionManager.isMicrophoneAuthorized
        accessibilityTrusted = PermissionManager.isAccessibilityTrusted
    }

    func completeOnboarding() {
        settingsStore.update { $0.hasCompletedOnboarding = true }
        showOnboarding = false
        startHotkeyIfPossible()
    }

    func warmModels() async {
        statusMessage = "Loading Parakeet model…"
        do {
            let version = AsrModelVersion.fromSettings(settingsStore.settings.asrModelVersion)
            try await transcription.prepare(version: version)
            modelReady = true
            statusMessage = "Ready — hold \(settingsStore.settings.hotkeyLabel)"
        } catch {
            modelReady = false
            statusMessage = "Model load failed"
            recordingState = .error(error.localizedDescription)
        }
    }

    func startHotkeyIfPossible() {
        hotkeyMonitor?.stop()
        hotkeyMonitor = nil

        guard PermissionManager.isAccessibilityTrusted else {
            statusMessage = "Grant Accessibility to enable the hotkey"
            return
        }

        let monitor = HotkeyMonitor(keyCode: settingsStore.settings.hotkeyKeyCode)
        do {
            try monitor.start(
                onKeyDown: { [weak self] in
                    Task { @MainActor in self?.beginHoldToTalk() }
                },
                onKeyUp: { [weak self] in
                    Task { @MainActor in self?.endHoldToTalk() }
                }
            )
            hotkeyMonitor = monitor
            if modelReady {
                statusMessage = "Ready — hold \(settingsStore.settings.hotkeyLabel)"
            }
        } catch {
            statusMessage = error.localizedDescription
            recordingState = .error(error.localizedDescription)
        }
    }

    func beginHoldToTalk() {
        guard !isBusy else { return }
        guard micAuthorized || PermissionManager.isMicrophoneAuthorized else {
            statusMessage = "Microphone permission required"
            return
        }
        micAuthorized = true

        do {
            try microphone.start()
            recordingState = .recording
            statusMessage = "Listening…"
        } catch {
            recordingState = .error(error.localizedDescription)
            statusMessage = "Mic error"
        }
    }

    func endHoldToTalk() {
        guard case .recording = recordingState else { return }
        let samples = microphone.stop()
        recordingState = .transcribing
        statusMessage = "Transcribing…"

        Task { await finishDictation(samples: samples) }
    }

    private func finishDictation(samples: [Float]) async {
        // Ignore accidental taps with almost no audio (~0.15 s @ 16 kHz).
        guard samples.count > 2_400 else {
            recordingState = .idle
            statusMessage = "Ready — hold \(settingsStore.settings.hotkeyLabel)"
            return
        }

        do {
            if !modelReady {
                try await transcription.prepare(
                    version: AsrModelVersion.fromSettings(settingsStore.settings.asrModelVersion)
                )
                modelReady = true
            }

            let result = try await transcription.transcribe(samples: samples)
            let dictionaryTerms = dictionaryStore.terms
            let polished = try await cleanup.cleanup(result.text, dictionaryTerms: dictionaryTerms)

            guard !polished.isEmpty else {
                recordingState = .idle
                statusMessage = "No speech detected"
                return
            }

            recordingState = .inserting
            statusMessage = "Inserting…"
            lastTranscript = polished
            _ = textInserter.insert(polished)

            historyStore.append(
                HistoryEntry(
                    rawText: result.text,
                    cleanedText: polished,
                    durationSeconds: result.duration,
                    confidence: result.confidence
                )
            )

            recordingState = .idle
            statusMessage = "Ready — hold \(settingsStore.settings.hotkeyLabel)"
        } catch {
            recordingState = .error(error.localizedDescription)
            statusMessage = error.localizedDescription
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                if case .error = self.recordingState {
                    self.recordingState = .idle
                    self.statusMessage = "Ready — hold \(self.settingsStore.settings.hotkeyLabel)"
                }
            }
        }
    }

    /// Tear down tap/mic. Pass `terminateApp: true` from the Quit menu item only.
    func quit(terminateApp: Bool = true) {
        hotkeyMonitor?.stop()
        hotkeyMonitor = nil
        _ = microphone.stop()
        if terminateApp {
            NSApp.terminate(nil)
        }
    }
}

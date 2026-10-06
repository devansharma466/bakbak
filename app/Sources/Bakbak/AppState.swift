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

enum MeetingState: Equatable {
    case idle
    case recording
    case processing
    case error(String)
}

/// Central observable app state for the menu bar UI, dictation, and meeting pipeline.
@MainActor
@Observable
final class AppState {
    let settingsStore: SettingsStore
    let dictionaryStore: DictionaryStore
    let historyStore: HistoryStore
    let meetingStore: MeetingStore

    let transcription = TranscriptionService()
    /// Phase 2: free, on-device cleanup chosen from Settings each dictation.
    var cleanup: any TextCleanupService {
        let settings = settingsStore.settings
        if settings.cleanupEnabled {
            return BakbakCleanupService(preferAppleIntelligence: settings.useAppleIntelligence)
        }
        // Cleanup off: keep the raw transcript but still honour dictionary spellings.
        return DictionaryOnlyCleanupService()
    }
    let textInserter = TextInserter()
    let microphone = MicrophoneCapture()
    let meetingRecorder = MeetingRecorder()

    private var hotkeyMonitor: HotkeyMonitor?
    private var didBootstrap = false

    var recordingState: RecordingState = .idle
    var meetingState: MeetingState = .idle
    var lastTranscript: String = ""
    var lastMeetingTranscript: String = ""
    var statusMessage: String = "Ready"
    var showOnboarding: Bool = false
    /// Set by AppDelegate to open the Dock/library window from the menu bar.
    var openLibraryWindow: (() -> Void)?
    var modelReady: Bool = false
    var micAuthorized: Bool = false
    var accessibilityTrusted: Bool = false
    var screenRecordingAuthorized: Bool = false

    var isBusy: Bool {
        switch recordingState {
        case .recording, .transcribing, .inserting: return true
        default: break
        }
        switch meetingState {
        case .recording, .processing: return true
        default: return false
        }
    }

    var isMeetingActive: Bool {
        switch meetingState {
        case .recording, .processing: return true
        default: return false
        }
    }

    init() {
        let settings = SettingsStore()
        self.settingsStore = settings
        self.dictionaryStore = DictionaryStore()
        self.historyStore = HistoryStore(limit: settings.settings.historyLimit)
        self.meetingStore = MeetingStore(retentionDays: settings.settings.meetingRetentionDays)
        self.showOnboarding = !settings.settings.hasCompletedOnboarding
        refreshPermissions()
    }

    func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true
        refreshPermissions()
        _ = meetingStore.purgeExpired()
        if !settingsStore.settings.hasCompletedOnboarding {
            showOnboarding = true
        }
        Task { await warmModels() }
        startHotkeyIfPossible()
    }

    func refreshPermissions() {
        micAuthorized = PermissionManager.isMicrophoneAuthorized
        accessibilityTrusted = PermissionManager.isAccessibilityTrusted
        screenRecordingAuthorized = PermissionManager.isScreenRecordingAuthorized
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
            statusMessage = readyStatusMessage()
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
            if modelReady, meetingState == .idle, recordingState == .idle {
                statusMessage = readyStatusMessage()
            }
        } catch {
            statusMessage = error.localizedDescription
            recordingState = .error(error.localizedDescription)
        }
    }

    func beginHoldToTalk() {
        guard !isBusy else { return }
        guard !isMeetingActive else {
            statusMessage = "Stop the meeting before dictating"
            return
        }
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

    // MARK: - Meeting mode (Phase 4)

    func toggleMeeting() {
        switch meetingState {
        case .idle, .error:
            Task { await startMeeting() }
        case .recording:
            Task { await stopMeeting() }
        case .processing:
            break
        }
    }

    func startMeeting() async {
        switch meetingState {
        case .idle, .error:
            break
        case .recording, .processing:
            return
        }

        // Don't start over an in-flight dictation.
        switch recordingState {
        case .recording, .transcribing, .inserting:
            statusMessage = "Finish dictation before starting a meeting"
            return
        default:
            break
        }

        refreshPermissions()
        guard micAuthorized || PermissionManager.isMicrophoneAuthorized else {
            statusMessage = "Microphone permission required for meetings"
            meetingState = .error("Microphone permission required")
            return
        }
        micAuthorized = true

        // Soft-request Screen Recording for system audio (non-blocking fallback to mic-only).
        if !screenRecordingAuthorized {
            _ = PermissionManager.requestScreenRecording()
            refreshPermissions()
        }

        do {
            try await meetingRecorder.start(includeSystemAudio: true)
            meetingState = .recording
            let audioNote = screenRecordingAuthorized ? "mic + system audio" : "mic only"
            statusMessage = "Meeting recording… (\(audioNote))"
        } catch {
            meetingState = .error(error.localizedDescription)
            statusMessage = error.localizedDescription
        }
    }

    func stopMeeting() async {
        guard case .recording = meetingState else { return }
        meetingState = .processing
        statusMessage = "Transcribing meeting…"

        do {
            let capture = try await meetingRecorder.stop()
            // Ignore accidental empty / tiny meetings (~0.5 s).
            guard capture.samples.count > 8_000 else {
                meetingState = .idle
                statusMessage = readyStatusMessage()
                return
            }

            if !modelReady {
                try await transcription.prepare(
                    version: AsrModelVersion.fromSettings(settingsStore.settings.asrModelVersion)
                )
                modelReady = true
            }

            let result = try await transcription.transcribeMeeting(samples: capture.samples)
            let dictionary = dictionaryStore.entries
            if settingsStore.settings.cleanupEnabled {
                statusMessage = "Cleaning up meeting…"
            }
            let polished: String
            do {
                polished = try await cleanup.cleanup(result.text, dictionary: dictionary)
            } catch {
                NSLog("Bakbak: meeting cleanup failed, saving raw text: \(error.localizedDescription)")
                polished = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let meeting = Meeting(
                title: Meeting.defaultTitle(for: capture.startedAt),
                createdAt: capture.startedAt,
                endedAt: capture.endedAt,
                durationSeconds: capture.durationSeconds,
                rawTranscript: result.text,
                cleanedTranscript: polished,
                audioSource: capture.usedSystemAudio ? "microphone+system" : "microphone"
            )
            meetingStore.append(meeting)
            lastMeetingTranscript = polished

            meetingState = .idle
            if polished.isEmpty {
                statusMessage = "Meeting saved (no speech detected)"
            } else {
                statusMessage = "Meeting saved — \(meeting.title)"
            }
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                if self.meetingState == .idle, self.recordingState == .idle {
                    self.statusMessage = self.readyStatusMessage()
                }
            }
        } catch {
            meetingState = .error(error.localizedDescription)
            statusMessage = error.localizedDescription
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if case .error = self.meetingState {
                    self.meetingState = .idle
                    self.statusMessage = self.readyStatusMessage()
                }
            }
        }
    }

    private func finishDictation(samples: [Float]) async {
        // Ignore accidental taps with almost no audio (~0.15 s @ 16 kHz).
        guard samples.count > 2_400 else {
            recordingState = .idle
            statusMessage = readyStatusMessage()
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
            let dictionary = dictionaryStore.entries
            if settingsStore.settings.cleanupEnabled {
                statusMessage = "Cleaning up…"
            }
            let polished: String
            do {
                polished = try await cleanup.cleanup(result.text, dictionary: dictionary)
            } catch {
                // Cleanup must never lose a dictation — fall back to the raw transcript.
                NSLog("Bakbak: cleanup failed, inserting raw text: \(error.localizedDescription)")
                polished = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            }

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
            statusMessage = readyStatusMessage()
        } catch {
            recordingState = .error(error.localizedDescription)
            statusMessage = error.localizedDescription
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                if case .error = self.recordingState {
                    self.recordingState = .idle
                    self.statusMessage = self.readyStatusMessage()
                }
            }
        }
    }

    private func readyStatusMessage() -> String {
        "Ready — hold \(settingsStore.settings.hotkeyLabel)"
    }

    /// Tear down tap/mic/meeting. Pass `terminateApp: true` from the Quit menu item only.
    func quit(terminateApp: Bool = true) {
        hotkeyMonitor?.stop()
        hotkeyMonitor = nil
        _ = microphone.stop()
        Task { await meetingRecorder.cancel() }
        if terminateApp {
            NSApp.terminate(nil)
        }
    }
}

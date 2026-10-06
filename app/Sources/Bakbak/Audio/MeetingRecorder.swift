import CoreGraphics
import Foundation

/// Coordinates mic (+ optional ScreenCaptureKit system audio) for a meeting session.
/// Mic is always required. System audio is best-effort when Screen Recording is granted.
final class MeetingRecorder: @unchecked Sendable {
    /// Mic and system audio are kept apart so the transcript can tell you from them;
    /// `mixed(_:)` sums them on demand rather than holding a third copy of a long meeting.
    struct CaptureResult: Sendable {
        let micSamples: [Float]
        /// Empty when system audio wasn't captured.
        let systemSamples: [Float]
        let durationSeconds: Double
        let startedAt: Date
        let endedAt: Date

        var usedSystemAudio: Bool { !systemSamples.isEmpty }
        var sampleCount: Int { max(micSamples.count, systemSamples.count) }

        /// Mic + system mixed (or mic alone), optionally just one stretch of it.
        func mixed(_ range: Range<Int>? = nil) -> [Float] {
            let range = range ?? 0..<sampleCount
            func slice(_ track: [Float]) -> [Float] {
                let clamped = range.clamped(to: 0..<track.count)
                return Array(track[clamped])
            }
            guard usedSystemAudio else { return slice(micSamples) }
            return MeetingRecorder.mix(mic: slice(micSamples), system: slice(systemSamples))
        }
    }

    enum RecorderError: LocalizedError {
        case alreadyRecording
        case notRecording
        case microphoneFailed(String)

        var errorDescription: String? {
            switch self {
            case .alreadyRecording: return "A meeting is already being recorded."
            case .notRecording: return "No meeting is being recorded."
            case .microphoneFailed(let message): return "Microphone error: \(message)"
            }
        }
    }

    private let microphone = MicrophoneCapture()
    private let systemAudio = SystemAudioCapture()
    private let lock = NSLock()
    private var startedAt: Date?
    private var systemAudioEnabled = false

    var isRecording: Bool {
        microphone.isActive
    }

    /// Start mic capture; attempt system audio if Screen Recording is already authorized.
    func start(includeSystemAudio: Bool = true) async throws {
        guard !syncHasSession() else { throw RecorderError.alreadyRecording }

        do {
            try microphone.start()
        } catch {
            throw RecorderError.microphoneFailed(error.localizedDescription)
        }

        var usedSystem = false
        if includeSystemAudio, CGPreflightScreenCaptureAccess() {
            do {
                try await systemAudio.start()
                usedSystem = true
            } catch {
                NSLog("Bakbak: system audio unavailable, mic-only meeting: \(error.localizedDescription)")
                usedSystem = false
            }
        }

        let used = usedSystem
        syncSetSession(startedAt: Date(), systemAudioEnabled: used)
    }

    /// Stop all captures and return both 16 kHz mono tracks.
    func stop() async throws -> CaptureResult {
        let (started, wantSystem) = try syncClearSession()

        let micSamples = microphone.stop()
        let systemSamples: [Float]
        if wantSystem {
            systemSamples = await systemAudio.stop()
        } else {
            systemSamples = []
        }

        let ended = Date()
        let duration = Double(max(micSamples.count, systemSamples.count)) / 16_000.0
        return CaptureResult(
            micSamples: micSamples,
            systemSamples: systemSamples,
            durationSeconds: duration,
            startedAt: started,
            endedAt: ended
        )
    }

    /// Cancel without returning audio (e.g. quit while recording).
    func cancel() async {
        let wantSystem = syncCancelSession()
        _ = microphone.stop()
        if wantSystem {
            _ = await systemAudio.stop()
        }
    }

    /// Soft-clip sum of mic + attenuated system audio, padded to the longer track.
    static func mix(mic: [Float], system: [Float], systemGain: Float = 0.85) -> [Float] {
        let count = max(mic.count, system.count)
        guard count > 0 else { return [] }
        var out = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let m = i < mic.count ? mic[i] : 0
            let s = i < system.count ? system[i] * systemGain : 0
            let mixed = m + s
            out[i] = max(-1, min(1, mixed))
        }
        return out
    }

    // MARK: - Sync helpers

    private func syncHasSession() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return startedAt != nil
    }

    private func syncSetSession(startedAt: Date, systemAudioEnabled: Bool) {
        lock.lock()
        self.startedAt = startedAt
        self.systemAudioEnabled = systemAudioEnabled
        lock.unlock()
    }

    private func syncClearSession() throws -> (Date, Bool) {
        lock.lock()
        defer { lock.unlock() }
        guard let started = startedAt else {
            throw RecorderError.notRecording
        }
        let wantSystem = systemAudioEnabled
        startedAt = nil
        systemAudioEnabled = false
        return (started, wantSystem)
    }

    private func syncCancelSession() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        startedAt = nil
        let want = systemAudioEnabled
        systemAudioEnabled = false
        return want
    }
}

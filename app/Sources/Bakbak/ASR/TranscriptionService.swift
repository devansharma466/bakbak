import Foundation
import FluidAudio

/// On-device transcription via FluidAudio Parakeet (English-only v2 by default).
actor TranscriptionService {
    enum ServiceError: LocalizedError {
        case notReady
        case emptyAudio
        case modelLoadFailed(String)
        case transcriptionFailed(String)

        var errorDescription: String? {
            switch self {
            case .notReady:
                return "ASR models are not loaded yet."
            case .emptyAudio:
                return "No audio captured."
            case .modelLoadFailed(let message):
                return "Failed to load Parakeet models: \(message)"
            case .transcriptionFailed(let message):
                return "Transcription failed: \(message)"
            }
        }
    }

    enum LoadState: Equatable {
        case idle
        case loading
        case ready
        case failed(String)
    }

    private var asrManager: AsrManager?
    private var modelVersion: AsrModelVersion = .v2
    private(set) var loadState: LoadState = .idle

    /// Default chunk length for long meeting audio (~30 s @ 16 kHz).
    static let defaultChunkSamples = 16_000 * 30
    /// Overlap between chunks to reduce boundary word cuts (~1 s).
    static let defaultOverlapSamples = 16_000

    /// Prefer English-only Parakeet TDT v2 (higher English recall). Override via settings later.
    func prepare(version: AsrModelVersion = .v2) async throws {
        if case .ready = loadState, modelVersion == version, asrManager != nil {
            return
        }
        loadState = .loading
        modelVersion = version
        do {
            // Downloads from Hugging Face on first run (~hundreds of MB), then caches locally.
            let models = try await AsrModels.downloadAndLoad(version: version)
            let manager = AsrManager(config: .default, models: models)
            if !(await manager.isAvailable) {
                try await manager.loadModels(models)
            }
            asrManager = manager
            loadState = .ready
        } catch {
            loadState = .failed(error.localizedDescription)
            asrManager = nil
            throw ServiceError.modelLoadFailed(error.localizedDescription)
        }
    }

    func transcribe(samples: [Float]) async throws -> ASRResult {
        guard !samples.isEmpty else { throw ServiceError.emptyAudio }
        guard let manager = asrManager, await manager.isAvailable else {
            throw ServiceError.notReady
        }

        // FluidAudio ≥0.17 requires an explicit TDT decoder state per utterance.
        var decoderState = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
        do {
            return try await manager.transcribe(samples, decoderState: &decoderState)
        } catch {
            throw ServiceError.transcriptionFailed(error.localizedDescription)
        }
    }

    /// Long-form meeting transcription: chunk → join. Returns plain text + metadata.
    func transcribeMeeting(
        samples: [Float],
        chunkSamples: Int = TranscriptionService.defaultChunkSamples,
        overlapSamples: Int = TranscriptionService.defaultOverlapSamples
    ) async throws -> (text: String, duration: Double, confidence: Float) {
        guard !samples.isEmpty else { throw ServiceError.emptyAudio }

        let duration = Double(samples.count) / 16_000.0

        if samples.count <= chunkSamples {
            let result = try await transcribe(samples: samples)
            return (result.text, duration, result.confidence)
        }

        let step = max(1, chunkSamples - overlapSamples)
        var texts: [String] = []
        var confidences: [Float] = []
        var offset = 0

        while offset < samples.count {
            let end = min(offset + chunkSamples, samples.count)
            let chunk = Array(samples[offset..<end])
            if chunk.count < 2_400 { break }
            let result = try await transcribe(samples: chunk)
            let trimmed = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                texts.append(trimmed)
                confidences.append(result.confidence)
            }
            if end >= samples.count { break }
            offset += step
        }

        let joined = texts.joined(separator: " ")
        let confidence: Float = confidences.isEmpty
            ? 0
            : confidences.reduce(0, +) / Float(confidences.count)
        return (joined, duration, confidence)
    }

    /// Transcribes each speaker turn on its own (mixed audio, so overlapping speech isn't lost).
    func transcribeTurns(
        _ turns: [SpeakerTurnDetector.Turn],
        capture: MeetingRecorder.CaptureResult
    ) async throws -> [MeetingSegment] {
        var segments: [MeetingSegment] = []
        for turn in turns {
            let audio = capture.mixed(turn.range)
            // Parakeet needs a little audio to say anything useful (~0.15 s).
            guard audio.count >= 2_400 else { continue }
            let result = try await transcribeMeeting(samples: audio)
            segments.append(
                MeetingSegment(
                    speaker: turn.speaker,
                    startSeconds: Double(turn.range.lowerBound) / 16_000.0,
                    endSeconds: Double(turn.range.upperBound) / 16_000.0,
                    text: result.text.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
        }
        return segments
    }

    func unload() async {
        if let manager = asrManager {
            await manager.cleanup()
        }
        asrManager = nil
        loadState = .idle
    }
}

extension AsrModelVersion {
    static func fromSettings(_ raw: String) -> AsrModelVersion {
        switch raw.lowercased() {
        case "v2": return .v2
        case "v3": return .v3
        case "ultra": return .ultra
        case "redux": return .redux
        case "phonon2": return .phonon2
        default: return .v2
        }
    }
}

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
            // Models passed via init; loadModels is also fine if constructing empty then loading.
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

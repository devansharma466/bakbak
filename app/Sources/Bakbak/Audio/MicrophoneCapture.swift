import AVFoundation
import Foundation

/// Captures microphone audio via AVAudioEngine and accumulates 16 kHz mono Float32 samples.
final class MicrophoneCapture: @unchecked Sendable {
    enum CaptureError: LocalizedError {
        case engineStartFailed(String)
        case converterUnavailable
        case alreadyRecording
        case notRecording

        var errorDescription: String? {
            switch self {
            case .engineStartFailed(let message):
                return "Could not start audio engine: \(message)"
            case .converterUnavailable:
                return "Could not create audio format converter to 16 kHz mono."
            case .alreadyRecording:
                return "Already recording."
            case .notRecording:
                return "Not recording."
            }
        }
    }

    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var samples: [Float] = []
    private var converter: AVAudioConverter?
    private var isRecording = false
    private let targetSampleRate: Double = 16_000

    var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isRecording
    }

    /// Start capturing. Samples are stored in memory until `stop()`.
    func start() throws {
        lock.lock()
        defer { lock.unlock() }
        guard !isRecording else { throw CaptureError.alreadyRecording }

        samples.removeAll(keepingCapacity: true)

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw CaptureError.converterUnavailable
        }

        converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        guard converter != nil else {
            throw CaptureError.converterUnavailable
        }

        // Buffer size ~100 ms at the hardware rate.
        let bufferSize = AVAudioFrameCount(max(512, inputFormat.sampleRate * 0.1))
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            self?.appendConverted(buffer: buffer, targetFormat: targetFormat)
        }

        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            converter = nil
            throw CaptureError.engineStartFailed(error.localizedDescription)
        }

        isRecording = true
    }

    /// Stop capturing and return 16 kHz mono Float32 samples.
    func stop() -> [Float] {
        lock.lock()
        let wasRecording = isRecording
        isRecording = false
        lock.unlock()

        guard wasRecording else { return [] }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil

        lock.lock()
        let result = samples
        samples = []
        lock.unlock()
        return result
    }

    private func appendConverted(buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat) {
        lock.lock()
        let active = isRecording
        let converter = self.converter
        lock.unlock()
        guard active, let converter else { return }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            return
        }

        var error: NSError?
        var consumed = false
        let status = converter.convert(to: outBuffer, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, error == nil, outBuffer.frameLength > 0,
              let channel = outBuffer.floatChannelData?[0] else {
            return
        }

        let count = Int(outBuffer.frameLength)
        let chunk = Array(UnsafeBufferPointer(start: channel, count: count))
        lock.lock()
        samples.append(contentsOf: chunk)
        lock.unlock()
    }
}

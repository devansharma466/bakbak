import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
@preconcurrency import ScreenCaptureKit

/// Captures system (app) audio via ScreenCaptureKit → 16 kHz mono Float32.
/// Requires Screen Recording permission. No virtual audio driver / BlackHole.
final class SystemAudioCapture: NSObject, @unchecked Sendable {
    enum CaptureError: LocalizedError {
        case noDisplay
        case streamStartFailed(String)
        case alreadyRecording
        case permissionDenied

        var errorDescription: String? {
            switch self {
            case .noDisplay:
                return "No display available for system-audio capture."
            case .streamStartFailed(let message):
                return "Could not start system-audio capture: \(message)"
            case .alreadyRecording:
                return "System audio already recording."
            case .permissionDenied:
                return "Screen Recording permission is required for system audio."
            }
        }
    }

    private let lock = NSLock()
    private var samples: [Float] = []
    private var stream: SCStream?
    private var isRecording = false
    private let targetSampleRate: Double = 16_000
    private var converter: AVAudioConverter?
    private var lastSourceSampleRate: Double = 0
    private let sampleHandlerQueue = DispatchQueue(label: "dev.devansharma.bakbak.system-audio")

    var isActive: Bool {
        syncIsRecording()
    }

    /// Start ScreenCaptureKit audio capture. Throws if Screen Recording is denied or stream fails.
    func start() async throws {
        guard !syncIsRecording() else { throw CaptureError.alreadyRecording }

        guard CGPreflightScreenCaptureAccess() else {
            throw CaptureError.permissionDenied
        }

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            throw CaptureError.streamStartFailed(error.localizedDescription)
        }

        guard let display = content.displays.first else {
            throw CaptureError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48_000
        config.channelCount = 1
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.showsCursor = false

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        do {
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: sampleHandlerQueue)
        } catch {
            throw CaptureError.streamStartFailed(error.localizedDescription)
        }

        do {
            try await stream.startCapture()
        } catch {
            throw CaptureError.streamStartFailed(error.localizedDescription)
        }

        syncBegin(stream: stream)
    }

    /// Stop and return 16 kHz mono Float32 samples (empty if never started).
    func stop() async -> [Float] {
        let (wasRecording, stream) = syncTakeStream()
        guard wasRecording else { return [] }

        if let stream {
            try? await stream.stopCapture()
        }

        return syncTakeSamples()
    }

    // MARK: - Sync lock helpers (safe to call from async; lock stays out of async body)

    private func syncIsRecording() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return isRecording
    }

    private func syncBegin(stream: SCStream) {
        lock.lock()
        self.stream = stream
        samples.removeAll(keepingCapacity: true)
        converter = nil
        lastSourceSampleRate = 0
        isRecording = true
        lock.unlock()
    }

    private func syncTakeStream() -> (Bool, SCStream?) {
        lock.lock()
        let was = isRecording
        isRecording = false
        let stream = self.stream
        self.stream = nil
        lock.unlock()
        return (was, stream)
    }

    private func syncTakeSamples() -> [Float] {
        lock.lock()
        let result = samples
        samples = []
        converter = nil
        lastSourceSampleRate = 0
        lock.unlock()
        return result
    }
}

extension SystemAudioCapture: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid else { return }
        append(sampleBuffer: sampleBuffer)
    }

    private func append(sampleBuffer: CMSampleBuffer) {
        lock.lock()
        let active = isRecording
        lock.unlock()
        guard active else { return }

        guard let formatDesc = sampleBuffer.formatDescription,
              let asbdPtr = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) else {
            return
        }
        let asbd = asbdPtr.pointee
        let sourceRate = asbd.mSampleRate

        let monoFloats: [Float]
        do {
            monoFloats = try sampleBuffer.withAudioBufferList { audioBufferList, _ -> [Float] in
                Self.monoFloats(from: audioBufferList, asbd: asbd)
            }
        } catch {
            return
        }
        guard !monoFloats.isEmpty else { return }

        guard let monoFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sourceRate,
            channels: 1,
            interleaved: false
        ),
        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ),
        let pcmBuffer = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: AVAudioFrameCount(monoFloats.count)),
        let channel = pcmBuffer.floatChannelData?[0] else {
            return
        }
        pcmBuffer.frameLength = AVAudioFrameCount(monoFloats.count)
        monoFloats.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            channel.update(from: base, count: monoFloats.count)
        }

        lock.lock()
        if converter == nil || abs(lastSourceSampleRate - sourceRate) > 0.5 {
            converter = AVAudioConverter(from: monoFormat, to: targetFormat)
            lastSourceSampleRate = sourceRate
        }
        let converter = self.converter
        lock.unlock()
        guard let converter else { return }

        let ratio = targetFormat.sampleRate / sourceRate
        let capacity = AVAudioFrameCount(Double(pcmBuffer.frameLength) * ratio) + 32
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var error: NSError?
        var consumed = false
        let convertStatus = converter.convert(to: outBuffer, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return pcmBuffer
        }

        guard convertStatus != .error, error == nil, outBuffer.frameLength > 0,
              let outChannel = outBuffer.floatChannelData?[0] else {
            return
        }

        let count = Int(outBuffer.frameLength)
        let chunk = Array(UnsafeBufferPointer(start: outChannel, count: count))
        lock.lock()
        samples.append(contentsOf: chunk)
        lock.unlock()
    }

    private static func monoFloats(
        from audioBufferList: UnsafeMutableAudioBufferListPointer,
        asbd: AudioStreamBasicDescription
    ) -> [Float] {
        let channelCount = Int(max(1, asbd.mChannelsPerFrame))
        guard audioBufferList.count > 0 else { return [] }

        if asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0 {
            if asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0 {
                let frames = Int(audioBufferList[0].mDataByteSize) / MemoryLayout<Float>.size
                guard frames > 0 else { return [] }
                var mono = [Float](repeating: 0, count: frames)
                let nCh = min(channelCount, audioBufferList.count)
                for ch in 0..<nCh {
                    guard let data = audioBufferList[ch].mData else { continue }
                    let ptr = data.assumingMemoryBound(to: Float.self)
                    let count = Int(audioBufferList[ch].mDataByteSize) / MemoryLayout<Float>.size
                    for i in 0..<min(frames, count) {
                        mono[i] += ptr[i]
                    }
                }
                if nCh > 0 {
                    let inv = 1.0 / Float(nCh)
                    for i in 0..<frames { mono[i] *= inv }
                }
                return mono
            } else {
                guard let data = audioBufferList[0].mData else { return [] }
                let ptr = data.assumingMemoryBound(to: Float.self)
                let frames = Int(audioBufferList[0].mDataByteSize) / (MemoryLayout<Float>.size * channelCount)
                guard frames > 0 else { return [] }
                var mono = [Float](repeating: 0, count: frames)
                for i in 0..<frames {
                    var sum: Float = 0
                    for ch in 0..<channelCount {
                        sum += ptr[i * channelCount + ch]
                    }
                    mono[i] = sum / Float(channelCount)
                }
                return mono
            }
        }

        if asbd.mBitsPerChannel == 16 {
            guard let data = audioBufferList[0].mData else { return [] }
            let ptr = data.assumingMemoryBound(to: Int16.self)
            let frames = Int(audioBufferList[0].mDataByteSize) / (MemoryLayout<Int16>.size * channelCount)
            guard frames > 0 else { return [] }
            var mono = [Float](repeating: 0, count: frames)
            for i in 0..<frames {
                var sum: Float = 0
                for ch in 0..<channelCount {
                    sum += Float(ptr[i * channelCount + ch]) / Float(Int16.max)
                }
                mono[i] = sum / Float(channelCount)
            }
            return mono
        }

        return []
    }
}

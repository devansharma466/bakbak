import Foundation

/// Splits a meeting into "you" / "them" turns by comparing the mic and system-audio tracks.
///
/// The mic is you; system audio is everyone else on the call. On laptop speakers the mic
/// also hears the call, but far more quietly than the system-audio feed itself, so whichever
/// track is louder in a 100 ms frame owns that frame. Silence belongs to whoever spoke last.
enum SpeakerTurnDetector {
    struct Turn: Equatable, Sendable {
        var speaker: MeetingSpeaker
        /// Sample indices (16 kHz) into the mic / system tracks.
        var range: Range<Int>
    }

    static let frameSamples = 1_600 // 100 ms @ 16 kHz
    /// Turns shorter than this (1 s) fold into the turn before — too short to transcribe well.
    static let minTurnFrames = 10
    /// Start each new turn 200 ms early so its first word isn't clipped.
    static let leadInFrames = 2
    /// Quietest level that counts as sound (~ -50 dBFS RMS).
    static let absoluteFloor: Float = 0.003
    /// Never demand more than this (~ -36 dBFS RMS): someone who talks almost non-stop
    /// pushes the "noise floor" up to speech level, and they must still count as talking.
    static let thresholdCeiling: Float = 0.015

    static func turns(mic: [Float], system: [Float]) -> [Turn] {
        let totalSamples = max(mic.count, system.count)
        let frameCount = (totalSamples + frameSamples - 1) / frameSamples
        guard frameCount > 0 else { return [] }

        let micLevels = rmsFrames(mic, frameCount: frameCount)
        let systemLevels = rmsFrames(system, frameCount: frameCount)
        let micThreshold = activityThreshold(micLevels)
        let systemThreshold = activityThreshold(systemLevels)

        // 1. Who is talking in each frame (nil = silence).
        var labels: [MeetingSpeaker?] = (0..<frameCount).map { f in
            let micOn = micLevels[f] > micThreshold
            let systemOn = systemLevels[f] > systemThreshold
            switch (micOn, systemOn) {
            case (true, true): return micLevels[f] > systemLevels[f] ? .you : .them
            case (true, false): return .you
            case (false, true): return .them
            case (false, false): return nil
            }
        }

        // 2. Silence belongs to whoever spoke last (or first, for leading silence).
        guard let firstSpeaker = labels.first(where: { $0 != nil }) ?? nil else { return [] }
        var current = firstSpeaker
        for f in 0..<frameCount {
            if let label = labels[f] { current = label } else { labels[f] = current }
        }

        // 3. Runs of the same speaker; short runs fold into the previous turn.
        var runs: [(speaker: MeetingSpeaker, start: Int, end: Int)] = []
        for f in 0..<frameCount {
            let speaker = labels[f] ?? firstSpeaker
            if let last = runs.last, last.speaker == speaker {
                runs[runs.count - 1].end = f + 1
            } else {
                runs.append((speaker, f, f + 1))
            }
        }
        var merged: [(speaker: MeetingSpeaker, start: Int, end: Int)] = []
        for run in runs {
            if let last = merged.last, last.speaker == run.speaker || run.end - run.start < minTurnFrames {
                merged[merged.count - 1].end = run.end
            } else {
                merged.append(run)
            }
        }
        // A short first run can't fold backwards; fold it forwards instead.
        if merged.count > 1, merged[0].end - merged[0].start < minTurnFrames {
            merged[1].start = merged[0].start
            merged.removeFirst()
        }

        // 4. Frames → sample ranges. Each turn starts a little early so its first word
        //    isn't clipped, and runs until the next turn starts.
        let startFrames = merged.indices.map { i in
            i == 0 ? 0 : max(merged[i - 1].start + 1, merged[i].start - leadInFrames)
        }
        return merged.indices.compactMap { i in
            let start = startFrames[i] * frameSamples
            let end = i + 1 < merged.count ? startFrames[i + 1] * frameSamples : totalSamples
            let range = start..<min(end, totalSamples)
            return range.isEmpty ? nil : Turn(speaker: merged[i].speaker, range: range)
        }
    }

    /// RMS of each 100 ms frame; frames past the end of a shorter track are silent.
    static func rmsFrames(_ samples: [Float], frameCount: Int) -> [Float] {
        (0..<frameCount).map { f in
            let start = f * frameSamples
            guard start < samples.count else { return 0 }
            let end = min(start + frameSamples, samples.count)
            var sum: Float = 0
            for i in start..<end { sum += samples[i] * samples[i] }
            return (sum / Float(end - start)).squareRoot()
        }
    }

    /// 2.5× the track's noise floor (its 10th-percentile frame), kept between
    /// `absoluteFloor` and `thresholdCeiling`.
    static func activityThreshold(_ levels: [Float]) -> Float {
        guard !levels.isEmpty else { return absoluteFloor }
        let sorted = levels.sorted()
        let floor = sorted[sorted.count / 10]
        return min(thresholdCeiling, max(absoluteFloor, floor * 2.5))
    }
}

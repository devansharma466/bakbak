// Regression checks for meeting speaker turns + notes helpers.
// Run: make check-meeting   (Foundation only — no FluidAudio, no UI, no model calls)
import Foundation

var failures = 0
@MainActor func check(_ name: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
    if ok {
        print("PASS  \(name)")
    } else {
        failures += 1
        print("FAIL  \(name) \(detail())")
    }
}

let rate = 16_000
func tone(_ seconds: Double, amp: Float = 0.1) -> [Float] {
    (0..<Int(seconds * Double(rate))).map { amp * sin(Float($0) * 2 * .pi * 220 / Float(rate)) }
}
func silence(_ seconds: Double) -> [Float] { [Float](repeating: 0, count: Int(seconds * Double(rate))) }
func seconds(_ sample: Int) -> Double { Double(sample) / Double(rate) }
func describe(_ turns: [SpeakerTurnDetector.Turn]) -> String {
    turns.map { "\($0.speaker.label)@\(String(format: "%.1f", seconds($0.range.lowerBound)))" }.joined(separator: " ")
}

// Headphones: you talk, pause, they talk.
do {
    let mic = tone(3) + silence(4)
    let system = silence(3.5) + tone(3.5)
    let turns = SpeakerTurnDetector.turns(mic: mic, system: system)
    check("headphones: you then them", turns.map(\.speaker) == [.you, .them], describe(turns))
    if turns.count == 2 {
        let boundary = seconds(turns[1].range.lowerBound)
        check("headphones: boundary just before they start", boundary > 3.0 && boundary < 3.5, "\(boundary)")
        check("turns cover the whole meeting", turns[0].range.lowerBound == 0 && turns[1].range.upperBound == system.count)
    }
}

// Laptop speakers: the mic also hears them, quietly.
do {
    let mic = tone(3) + silence(0.5) + tone(3.5, amp: 0.02)
    let system = silence(3.5) + tone(3.5)
    let turns = SpeakerTurnDetector.turns(mic: mic, system: system)
    check("speaker bleed still reads as them", turns.map(\.speaker) == [.you, .them], describe(turns))
}

// A 0.3 s "yeah" squeezed between their sentences folds into their turn
// (they talk almost non-stop, so their noise floor is near speech level).
do {
    let mic = silence(3) + tone(0.3) + silence(3)
    let system = tone(3) + silence(0.3) + tone(3)
    let turns = SpeakerTurnDetector.turns(mic: mic, system: system)
    check("short interjection folds into the turn", turns.map(\.speaker) == [.them], describe(turns))
}

// Back and forth.
do {
    let mic = tone(2) + silence(2) + tone(2) + silence(2)
    let system = silence(2) + tone(2) + silence(2) + tone(2)
    let turns = SpeakerTurnDetector.turns(mic: mic, system: system)
    check("back and forth", turns.map(\.speaker) == [.you, .them, .you, .them], describe(turns))
}

// Someone talking non-stop over a noisy mic still counts as talking.
do {
    let noise: [Float] = (0..<(rate * 6)).map { _ in Float.random(in: -0.004...0.004) }
    let mic = zip(noise, tone(3, amp: 0.05) + silence(3)).map { $0 + $1 }
    let system = silence(3) + tone(3, amp: 0.05)
    let turns = SpeakerTurnDetector.turns(mic: mic, system: system)
    check("noisy mic, quieter voices", turns.map(\.speaker) == [.you, .them], describe(turns))
}

// Leading silence belongs to the first speaker; nothing at all gives no turns.
do {
    let turns = SpeakerTurnDetector.turns(mic: silence(2), system: silence(2) + tone(3))
    check("leading silence joins first speaker", turns.map(\.speaker) == [.them] && turns[0].range.lowerBound == 0, describe(turns))
    check("silence gives no turns", SpeakerTurnDetector.turns(mic: silence(3), system: silence(3)).isEmpty)
    check("empty audio gives no turns", SpeakerTurnDetector.turns(mic: [], system: []).isEmpty)
}

// Transcript formatting.
do {
    let segments = [
        MeetingSegment(speaker: .you, startSeconds: 0, endSeconds: 1, text: "Shall we ship"),
        MeetingSegment(speaker: .you, startSeconds: 1, endSeconds: 2, text: "on Friday?"),
        MeetingSegment(speaker: .them, startSeconds: 2, endSeconds: 3, text: "  "),
        MeetingSegment(speaker: .them, startSeconds: 3, endSeconds: 4, text: "Yes."),
    ]
    let text = MeetingSegment.transcript(segments)
    check("transcript merges turns and drops empty ones", text == "You: Shall we ship on Friday?\n\nThem: Yes.", text.debugDescription)
}

// Notes helpers.
do {
    let turn = Array(repeating: "word", count: 500).joined(separator: " ")
    let chunks = MeetingNotesWriter.chunks([turn, turn, turn].joined(separator: "\n\n"), maxWords: 1_200)
    let sizes = chunks.map { $0.split(whereSeparator: \.isWhitespace).count }
    check("chunks break between turns", sizes == [1_000, 500], "\(sizes)")
    let long = Array(repeating: "word", count: 3_000).joined(separator: " ")
    check("one long turn is split", MeetingNotesWriter.chunks(long, maxWords: 1_200).count == 3)
    let tidy = MeetingNotesWriter.tidyList(["- Send the draft", "send the draft.", "None", "  ", "• You: book the room"])
    check("tidyList", tidy == ["Send the draft", "You: book the room"], "\(tidy)")
    let merged = MeetingNotesWriter.tidyList([
        "You: Send release notes", "Them: Send release notes by Thursday", "You: Send the release notes by Thursday.",
        "Them: Ask three friends to test on Macs", "Them: Ask three friends to test the beta on their Macs",
    ])
    check("tidyList folds shorter repeats, keeps owners apart", merged == [
        "Them: Send release notes by Thursday", "You: Send the release notes by Thursday.",
        "Them: Ask three friends to test the beta on their Macs",
    ], "\(merged)")
    let owners = ["you", "Them:", "Theym", " they ", "Priya", "unclear"].map(MeetingNotesWriter.normalizedOwner)
    check("normalizedOwner", owners == ["You", "Them", "Them", "Them", "Priya", ""], "\(owners)")
}

// Old meetings.json (no segments / notes) still loads.
do {
    let json = #"[{"id":"9F1C2B0E-1111-4C55-9A0B-123456789ABC","title":"Old","createdAt":"2026-10-05T12:00:00Z","endedAt":"2026-10-05T12:30:00Z","durationSeconds":1800,"rawTranscript":"hi","cleanedTranscript":"Hi.","audioSource":"microphone"}]"#
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let meetings = try? decoder.decode([Meeting].self, from: Data(json.utf8))
    check("old meetings decode", meetings?.first?.segments == nil && meetings?.first?.notes == nil && meetings?.count == 1)
}

if failures > 0 {
    print("\n\(failures) check(s) failed")
    exit(1)
}
print("\nAll meeting checks passed")

// Regression checks for the free heuristic cleanup path.
// Run: make check-cleanup   (compiles only Foundation-based files; no app/UI needed)
import Foundation

let dictionary = [
    DictionaryEntry(term: "FluidAudio"),
    DictionaryEntry(term: "Bakbak", aliases: ["bak bak", "buck buck"]),
    DictionaryEntry(term: "Devan", aliases: ["Devin", "dev on"]),
    DictionaryEntry(term: "Parakeet"),
]

let cases: [(String, String)] = [
    ("um so I think we should uh ship it", "So I think we should ship it."),
    ("Um, I like pizza.", "I like pizza."),
    ("It was, like, really good, you know.", "It was really good."),
    ("Like, it was huge", "It was huge."),
    ("Things I like", "Things I like."),
    ("do you know where the file is", "Do you know where the file is?"),
    ("what kind of car is that", "What kind of car is that?"),
    ("Meet on Tuesday, I mean Wednesday.", "Meet on Wednesday."),
    ("Send it to John, sorry, Jane", "Send it to Jane."),
    ("I'm late, sorry, traffic was bad", "I'm late, sorry, traffic was bad."),
    ("Let's meet at three no wait four pm", "Let's meet at four pm."),
    ("Email Devan, no wait, Priya about it", "Email Priya about it."),
    ("Let's ask the team, I mean the client", "Let's ask the client."),
    ("I want pizza, I mean, it's been a long day.", "I want pizza, I mean, it's been a long day."),
    ("Buy milk. Actually scratch that. Buy eggs.", "Buy milk. Buy eggs."),
    ("I I think the the build works", "I think the build works."),
    ("ask devin about fluid audio and bak bak", "Ask Devan about FluidAudio and Bakbak."),
    ("we use fluid-audio for asr", "We use FluidAudio for asr."),
    ("Actually, the meeting is at five", "The meeting is at five."),
    ("it costs $99 and uh that's it", "It costs $99 and that's it."),
    ("i think i'm done", "I think I'm done."),
    ("Um, so, like, can you send it", "So can you send it?"),
    ("um", ""),
    // Mid-utterance "actually" / "actually no" corrections (pause-gated).
    ("can you book the meeting for 4pm, actually no 5pm", "Can you book the meeting for 5pm?"),
    ("send it to John, actually Jane", "Send it to Jane."),
    ("for 4pm, actually 5pm", "For 5pm."),
    ("book for 4, wait no 5", "Book for 5."),
    ("book for 4, actually no 5", "Book for 5."),
    ("book for 4pm, no actually 5pm", "Book for 5pm."),
    // Cross-sentence mid-utterance corrections (ASR inserts .!? between original + correction).
    ("Can you book a meeting for 4pm? Actually no 5pm.", "Can you book a meeting for 5pm?"),
    ("Can you book a meeting for 4pm. Actually 5pm.", "Can you book a meeting for 5pm?"),
    ("Can you book a meeting for 4pm? Wait no 5pm.", "Can you book a meeting for 5pm?"),
    ("book for 4pm. Actually no 5pm.", "Book for 5pm."),
    ("send it to John. Actually Jane.", "Send it to Jane."),
    // Must NOT wreck normal "actually" / "no" discourse.
    ("I don't actually know", "I don't actually know."),
    ("There's actually no reason to worry", "There's actually no reason to worry."),
    ("can you book the meeting for 4pm, actually I think we should wait", "Can you book the meeting for 4pm, actually I think we should wait?"),
    // Cross-sentence discourse must stay intact (not treated as a short replacement).
    ("End of thought. Actually no reason to go.", "End of thought. Actually no reason to go."),
    ("Hello. Actually, the meeting is at five", "Hello. The meeting is at five."),
    // ASR spells times "P. M." / "a.m."; the dots must not end the sentence or hide the "?".
    ("Can you send me the notes by three? No, wait, four P. M.", "Can you send me the notes by four pm?"),
    ("Meet at 4 P.M. Then call Sam.", "Meet at 4 pm. Then call Sam."),
    ("the train leaves at 6 a.m.", "The train leaves at 6 am."),
    ("is it 9 A. M. or 10", "Is it 9 am or 10?"),
]

let service = HeuristicCleanupService()
var failures = 0
for (input, expected) in cases {
    let output = try await service.cleanup(input, dictionary: dictionary)
    if output == expected {
        print("PASS  \(input)")
    } else {
        failures += 1
        print("FAIL  \(input)\n      expected: \(expected)\n      got:      \(output)")
    }
}

// Old Phase 0/1 dictionary JSON (term → replacement) migrates to term + aliases.
let legacy = #"[{"id":"9F1C2B0E-1111-4C55-9A0B-123456789ABC","term":"dev on","replacement":"Devan","createdAt":"2026-10-05T12:00:00Z"}]"#
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
let migrated = try decoder.decode([DictionaryEntry].self, from: Data(legacy.utf8))
if migrated.first?.term == "Devan", migrated.first?.aliases == ["dev on"] {
    print("PASS  legacy dictionary migration")
} else {
    failures += 1
    print("FAIL  legacy dictionary migration: \(migrated)")
}

print(failures == 0 ? "\nAll cleanup checks passed." : "\n\(failures) cleanup check(s) failed.")
exit(failures == 0 ? 0 : 1)

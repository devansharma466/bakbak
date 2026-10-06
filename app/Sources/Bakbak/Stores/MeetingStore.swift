import Foundation
import Observation

/// Local meeting library with age-based retention (default 30 days).
@MainActor
@Observable
final class MeetingStore {
    private(set) var meetings: [Meeting] = []
    private let fileURL: URL
    private var retentionDays: Int

    init(fileURL: URL? = nil, retentionDays: Int = 30) {
        let url = fileURL ?? Self.defaultFileURL()
        self.fileURL = url
        self.retentionDays = max(1, retentionDays)
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder.iso8601.decode([Meeting].self, from: data) {
            self.meetings = decoded
        }
        purgeExpired()
    }

    func setRetentionDays(_ days: Int) {
        retentionDays = max(1, days)
        purgeExpired()
        save()
    }

    func append(_ meeting: Meeting) {
        meetings.insert(meeting, at: 0)
        purgeExpired()
        save()
    }

    func update(_ meeting: Meeting) {
        guard let index = meetings.firstIndex(where: { $0.id == meeting.id }) else { return }
        meetings[index] = meeting
        save()
    }

    func remove(id: UUID) {
        meetings.removeAll { $0.id == id }
        save()
    }

    func clear() {
        meetings = []
        save()
    }

    /// Drop meetings older than retention window. Call on launch and after saves.
    @discardableResult
    func purgeExpired(now: Date = Date()) -> Int {
        let cutoff = now.addingTimeInterval(-Double(retentionDays) * 24 * 60 * 60)
        let before = meetings.count
        meetings.removeAll { $0.createdAt < cutoff }
        let removed = before - meetings.count
        if removed > 0 {
            save()
        }
        return removed
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder.pretty.encode(meetings)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            NSLog("Bakbak: failed to save meetings: \(error.localizedDescription)")
        }
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Bakbak/meetings.json", isDirectory: false)
    }
}

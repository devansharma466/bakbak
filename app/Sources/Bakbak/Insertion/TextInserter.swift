import AppKit
import Carbon.HIToolbox
import Foundation

/// Inserts text at the focused cursor via pasteboard + simulated ⌘V, then restores the clipboard.
@MainActor
final class TextInserter {
    enum InsertionResult: Equatable {
        case pasted
        case copiedOnly
    }

    /// Virtual key code for "V" on ANSI layout (works across layouts when used as virtualKey).
    static let pasteKeyCode: CGKeyCode = 9
    static let defaultRestoreDelay: TimeInterval = 0.35

    private let restoreDelay: TimeInterval

    init(restoreDelay: TimeInterval = TextInserter.defaultRestoreDelay) {
        self.restoreDelay = restoreDelay
    }

    @discardableResult
    func insert(_ text: String) -> InsertionResult {
        guard !text.isEmpty else { return .copiedOnly }

        let pasteboard = NSPasteboard.general
        let saved = savePasteboardItems(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let writeChangeCount = pasteboard.changeCount

        simulatePaste()

        let delay = restoreDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // Do not clobber if the user (or another app) copied something else.
            guard pasteboard.changeCount == writeChangeCount else { return }
            self.restorePasteboardItems(pasteboard, items: saved)
        }

        return .pasted
    }

    private func simulatePaste() {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: Self.pasteKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: Self.pasteKeyCode, keyDown: false)
        else {
            return
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func savePasteboardItems(_ pasteboard: NSPasteboard) -> [[(NSPasteboard.PasteboardType, Data)]] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.map { item in
            item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            }
        }
    }

    private func restorePasteboardItems(
        _ pasteboard: NSPasteboard,
        items: [[(NSPasteboard.PasteboardType, Data)]]
    ) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        let restored = items.map { entries -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entries {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(restored)
    }
}

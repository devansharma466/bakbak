import AppKit
import Foundation

/// Hold-to-talk via NSEvent global + local monitors (default: Option).
/// Global monitor is required — local-only succeeds without Accessibility and lies.
final class HotkeyMonitor: @unchecked Sendable {
    typealias Handler = @Sendable () -> Void

    private let keyCode: UInt16
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var modifierPressed = false
    private var onKeyDown: Handler?
    private var onKeyUp: Handler?

    /// True only when the Accessibility-backed global monitor is live.
    var isArmed: Bool { globalMonitor != nil }

    init(keyCode: UInt16 = 61) {
        self.keyCode = keyCode
    }

    func start(onKeyDown: @escaping Handler, onKeyUp: @escaping Handler) throws {
        stop()
        self.onKeyDown = onKeyDown
        self.onKeyUp = onKeyUp

        let handler: (NSEvent) -> Void = { [weak self] event in
            self?.handle(event)
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: handler)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            handler(event)
            return event
        }

        guard globalMonitor != nil else {
            if let localMonitor {
                NSEvent.removeMonitor(localMonitor)
                self.localMonitor = nil
            }
            throw MonitorError.accessibilityNotGranted
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        modifierPressed = false
        onKeyDown = nil
        onKeyUp = nil
    }

    private func handle(_ event: NSEvent) {
        let watchingOption = keyCode == 58 || keyCode == 61
        if watchingOption {
            // Also catch release via other flagsChanged when Option drops.
            if !(event.keyCode == 58 || event.keyCode == 61) {
                if modifierPressed {
                    let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                    if !flags.contains(.option) {
                        modifierPressed = false
                        onKeyUp?()
                    }
                }
                return
            }
        } else {
            guard event.keyCode == keyCode else { return }
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isPressed: Bool
        switch keyCode {
        case 58, 61:
            isPressed = flags.contains(.option)
        case 54, 55:
            isPressed = flags.contains(.command)
        case 59, 62:
            isPressed = flags.contains(.control)
        case 56, 60:
            isPressed = flags.contains(.shift)
        case 63:
            isPressed = flags.contains(.function)
        default:
            isPressed = flags.contains(.option)
        }

        if isPressed == modifierPressed { return }
        modifierPressed = isPressed
        if isPressed {
            onKeyDown?()
        } else {
            onKeyUp?()
        }
    }

    enum MonitorError: LocalizedError {
        case accessibilityNotGranted

        var errorDescription: String? {
            "Could not install global hotkey. Remove old Bakbak rows in Accessibility, re-add this Bakbak.app, then Refresh permissions."
        }
    }
}

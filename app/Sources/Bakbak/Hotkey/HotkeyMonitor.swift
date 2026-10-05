import AppKit
import CoreGraphics
import Foundation

/// Global hold-to-talk via a CGEvent tap on a modifier key (default: Right Option, keyCode 61).
///
/// Requires Accessibility trust. Re-grant after re-signing or moving the .app bundle.
final class HotkeyMonitor: @unchecked Sendable {
    typealias Handler = @Sendable () -> Void

    enum MonitorError: LocalizedError {
        case tapCreateFailed

        var errorDescription: String? {
            switch self {
            case .tapCreateFailed:
                return "Could not create CGEvent tap. Grant Accessibility permission to Bakbak and restart."
            }
        }
    }

    private let keyCode: CGKeyCode
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var modifierPressed = false
    private var onKeyDown: Handler?
    private var onKeyUp: Handler?

    /// Right Option = 61, Left Option = 58, Fn/Globe = 63.
    init(keyCode: CGKeyCode = 61) {
        self.keyCode = keyCode
    }

    func start(onKeyDown: @escaping Handler, onKeyUp: @escaping Handler) throws {
        stop()
        self.onKeyDown = onKeyDown
        self.onKeyUp = onKeyUp

        let mask = (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: hotkeyEventCallback,
            userInfo: refcon
        ) else {
            throw MonitorError.tapCreateFailed
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        modifierPressed = false
        onKeyDown = nil
        onKeyUp = nil
    }

    fileprivate func handle(event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        // Re-enable if macOS disabled the tap (timeout / user input lag).
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let code = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        guard code == keyCode else {
            return Unmanaged.passUnretained(event)
        }

        // Modifier-only keys (Option/Cmd/Ctrl/Shift/Fn) deliver flagsChanged for press+release.
        if isModifierOnlyKey(code) {
            guard type == .flagsChanged else {
                return Unmanaged.passUnretained(event)
            }
            if modifierPressed {
                modifierPressed = false
                DispatchQueue.main.async { [weak self] in self?.onKeyUp?() }
            } else {
                modifierPressed = true
                DispatchQueue.main.async { [weak self] in self?.onKeyDown?() }
            }
        } else {
            if type == .keyDown, event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                DispatchQueue.main.async { [weak self] in self?.onKeyDown?() }
            } else if type == .keyUp {
                DispatchQueue.main.async { [weak self] in self?.onKeyUp?() }
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func isModifierOnlyKey(_ code: CGKeyCode) -> Bool {
        // rightcmd 54, cmd 55, shift 56, option 58, ctrl 59,
        // rightshift 60, rightoption 61, rightctrl 62, fn/globe 63
        [54, 55, 56, 58, 59, 60, 61, 62, 63].contains(code)
    }
}

private func hotkeyEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else {
        return Unmanaged.passUnretained(event)
    }
    let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
    return monitor.handle(event: event, type: type)
}

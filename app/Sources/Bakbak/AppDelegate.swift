import AppKit
import SwiftUI

/// Ensures hotkey + model warm-up start at launch (not only when the menu is opened).
/// Also owns the main library window opened from Dock / Applications / Launchpad.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let appState = AppState()

    private var libraryWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start as menubar agent (LSUIElement). Dock icon appears when we show the library
        // window via `.regular` activation policy.
        NSApp.setActivationPolicy(.accessory)
        appState.openLibraryWindow = { [weak self] in
            self?.showLibraryWindow()
        }
        appState.bootstrap()

        // Cold start from Dock / Applications / Launchpad should show the library —
        // not silently leave only the menu-bar parrot.
        showLibraryWindow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.quit(terminateApp: false)
    }

    /// Dock icon click (or Finder/Launchpad reopen) while already running.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag || libraryWindow?.isVisible != true {
            showLibraryWindow()
        } else {
            libraryWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
    }

    /// Bring up (or focus) the Meetings + History library window and allow a Dock icon.
    func showLibraryWindow() {
        NSApp.setActivationPolicy(.regular)

        if let libraryWindow {
            libraryWindow.makeKeyAndOrderFront(nil)
        } else {
            let root = MainLibraryView(appState: appState)
            let hosting = NSHostingController(rootView: root)
            let window = NSWindow(contentViewController: hosting)
            window.title = "Bakbak"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 820, height: 560))
            window.minSize = NSSize(width: 700, height: 460)
            window.backgroundColor = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
            window.titlebarAppearsTransparent = true
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.setFrameAutosaveName("BakbakLibraryWindow")
            window.makeKeyAndOrderFront(nil)
            libraryWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closed = notification.object as? NSWindow, closed === libraryWindow else { return }
        // Back to menubar-only: hide Dock icon again while the parrot stays in the menu bar.
        NSApp.setActivationPolicy(.accessory)
    }
}

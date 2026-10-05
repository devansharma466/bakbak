import AppKit

/// Ensures hotkey + model warm-up start at launch (not only when the menu is opened).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menubar-only app: hide from Dock (also set via LSUIElement in Info.plist).
        NSApp.setActivationPolicy(.accessory)
        appState.bootstrap()
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.quit(terminateApp: false)
    }
}

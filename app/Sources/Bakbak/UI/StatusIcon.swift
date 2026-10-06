import AppKit
import SwiftUI

enum StatusIcon {
    /// SF Symbol name reflecting recording / meeting / transcribing state.
    static func symbol(for state: RecordingState, meeting: MeetingState = .idle) -> String {
        switch meeting {
        case .recording:
            return "record.circle.fill"
        case .processing:
            return "ellipsis.circle"
        case .error:
            return "exclamationmark.triangle.fill"
        case .idle:
            break
        }

        switch state {
        case .idle:
            return "waveform"
        case .recording:
            return "mic.fill"
        case .transcribing:
            return "ellipsis.circle"
        case .inserting:
            return "doc.on.clipboard"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    /// Black parrot silhouette for the menu bar. macOS tints template images.
    @MainActor
    static func menuBarTemplateImage() -> NSImage? {
        if let cached {
            return cached
        }
        let image = loadMenuBarTemplate()
        cached = image
        return image
    }

    @MainActor
    private static var cached: NSImage?

    private static func loadMenuBarTemplate() -> NSImage? {
        let names = ["bakbak-menubar@2x", "bakbak-menubar"]
        for name in names {
            if let url = Bundle.main.url(forResource: name, withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                image.isTemplate = true
                if name.contains("@2x") {
                    image.size = NSSize(width: max(image.size.width / 2, 18), height: max(image.size.height / 2, 15))
                }
                return image
            }
            // Fallback: resource copied with literal filename including @2x
            if let base = Bundle.main.resourceURL {
                let url = base.appendingPathComponent("\(name).png")
                if FileManager.default.fileExists(atPath: url.path),
                   let image = NSImage(contentsOf: url) {
                    image.isTemplate = true
                    if name.contains("@2x") {
                        image.size = NSSize(width: max(image.size.width / 2, 18), height: max(image.size.height / 2, 15))
                    }
                    return image
                }
            }
        }
        return nil
    }
}

import SwiftUI

enum StatusIcon {
    /// SF Symbol name reflecting recording / transcribing state.
    static func symbol(for state: RecordingState) -> String {
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
}

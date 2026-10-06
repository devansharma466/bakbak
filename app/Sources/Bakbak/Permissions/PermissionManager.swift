import AppKit
import AVFoundation
import ApplicationServices
import CoreGraphics
import Foundation

/// Microphone + Accessibility + Screen Recording permission helpers.
@MainActor
enum PermissionManager {
    enum MicrophoneStatus: Equatable {
        case authorized
        case denied
        case notDetermined
        case restricted
    }

    static var microphoneStatus: MicrophoneStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .authorized
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    static var isMicrophoneAuthorized: Bool {
        microphoneStatus == .authorized
    }

    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Screen Recording (needed for ScreenCaptureKit system audio).
    /// Note: TCC may report false until the user has been prompted at least once.
    nonisolated static var isScreenRecordingAuthorized: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Request mic access. Returns whether granted.
    static func requestMicrophone() async -> Bool {
        switch microphoneStatus {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        }
    }

    /// Prompt the system Accessibility trust dialog when untrusted.
    @discardableResult
    static func promptAccessibilityIfNeeded() -> Bool {
        if AXIsProcessTrusted() { return true }
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Prompt Screen Recording access (shows system dialog once; otherwise open Settings).
    @discardableResult
    nonisolated static func requestScreenRecording() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        return CGRequestScreenCaptureAccess()
    }

    static func openMicrophoneSettings() {
        openPrivacyPane("Privacy_Microphone")
    }

    static func openAccessibilitySettings() {
        openPrivacyPane("Privacy_Accessibility")
    }

    static func openScreenRecordingSettings() {
        openPrivacyPane("Privacy_ScreenCapture")
    }

    private static func openPrivacyPane(_ anchor: String) {
        // Modern System Settings deep link (Ventura+), with preference-pane fallback.
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?\(anchor)",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?\(anchor)"
        ]
        for candidate in candidates {
            if let url = URL(string: candidate) {
                NSWorkspace.shared.open(url)
                return
            }
        }
    }
}

import Foundation
import AVFoundation
import ApplicationServices
import AppKit

struct PermissionManagerSystemCalls: Sendable {
    var supportsAudioApplicationAPI: @Sendable () -> Bool
    var audioApplicationRecordPermission: @Sendable () -> AVAudioApplication.recordPermission
    var requestAudioApplicationRecordPermission: @Sendable (@Sendable @escaping (Bool) -> Void) -> Void
    var audioDeviceAuthorizationStatus: @Sendable () -> AVAuthorizationStatus
    var requestAudioDeviceAccess: @Sendable (@Sendable @escaping (Bool) -> Void) -> Void
    var isAccessibilityTrusted: @Sendable () -> Bool
    var requestAccessibilityTrust: @Sendable (Bool) -> Bool
    var openURL: @Sendable (URL) -> Bool

    static let live = PermissionManagerSystemCalls(
        supportsAudioApplicationAPI: {
            if #available(macOS 14.0, *) {
                return true
            }
            return false
        },
        audioApplicationRecordPermission: {
            if #available(macOS 14.0, *) {
                return AVAudioApplication.shared.recordPermission
            }
            return .undetermined
        },
        requestAudioApplicationRecordPermission: { handler in
            if #available(macOS 14.0, *) {
                AVAudioApplication.requestRecordPermission(completionHandler: handler)
                return
            }
            handler(false)
        },
        audioDeviceAuthorizationStatus: {
            AVCaptureDevice.authorizationStatus(for: .audio)
        },
        requestAudioDeviceAccess: { handler in
            AVCaptureDevice.requestAccess(for: .audio, completionHandler: handler)
        },
        isAccessibilityTrusted: {
            AXIsProcessTrusted()
        },
        requestAccessibilityTrust: { shouldPrompt in
            let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            let options = [promptKey: shouldPrompt] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        },
        openURL: { url in
            NSWorkspace.shared.open(url)
        }
    )
}

final class PermissionManager: PermissionServiceProtocol, @unchecked Sendable {
    private let systemCalls: PermissionManagerSystemCalls
    private let accessibilitySettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    init(systemCalls: PermissionManagerSystemCalls = .live) {
        self.systemCalls = systemCalls
    }

    func hasMicrophonePermission() -> Bool {
        if systemCalls.supportsAudioApplicationAPI() {
            switch systemCalls.audioApplicationRecordPermission() {
            case .granted:
                return true
            case .undetermined, .denied:
                return false
            @unknown default:
                return false
            }
        }

        return systemCalls.audioDeviceAuthorizationStatus() == .authorized
    }

    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            if systemCalls.supportsAudioApplicationAPI() {
                systemCalls.requestAudioApplicationRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
                return
            }

            systemCalls.requestAudioDeviceAccess { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func hasAccessibilityPermission() -> Bool {
        systemCalls.isAccessibilityTrusted()
    }

    func requestAccessibilityPermission() async -> Bool {
        systemCalls.requestAccessibilityTrust(true)
    }

    @discardableResult
    func openAccessibilitySettings() -> Bool {
        systemCalls.openURL(accessibilitySettingsURL)
    }
}

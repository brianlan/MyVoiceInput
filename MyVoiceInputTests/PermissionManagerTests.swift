#if canImport(XCTest)
import XCTest
import AVFoundation
@testable import MyVoiceInput

final class PermissionManagerTests: XCTestCase {
    func testHasMicrophonePermissionUsesAudioApplicationStatusWhenSupported() {
        let manager = PermissionManager(systemCalls: .init(
            supportsAudioApplicationAPI: { true },
            audioApplicationRecordPermission: { .granted },
            requestAudioApplicationRecordPermission: { _ in },
            audioDeviceAuthorizationStatus: { .denied },
            requestAudioDeviceAccess: { _ in },
            isAccessibilityTrusted: { false },
            requestAccessibilityTrust: { _ in false },
            openURL: { _ in false }
        ))

        XCTAssertTrue(manager.hasMicrophonePermission())
    }

    func testHasMicrophonePermissionFallsBackToCaptureAuthorizationStatus() {
        let manager = PermissionManager(systemCalls: .init(
            supportsAudioApplicationAPI: { false },
            audioApplicationRecordPermission: { .denied },
            requestAudioApplicationRecordPermission: { _ in },
            audioDeviceAuthorizationStatus: { .authorized },
            requestAudioDeviceAccess: { _ in },
            isAccessibilityTrusted: { false },
            requestAccessibilityTrust: { _ in false },
            openURL: { _ in false }
        ))

        XCTAssertTrue(manager.hasMicrophonePermission())
    }

    func testRequestMicrophonePermissionUsesAudioApplicationAPIWhenSupported() async {
        var didRequestAudioApplicationPermission = false
        var didRequestCaptureDevicePermission = false

        let manager = PermissionManager(systemCalls: .init(
            supportsAudioApplicationAPI: { true },
            audioApplicationRecordPermission: { .undetermined },
            requestAudioApplicationRecordPermission: { completion in
                didRequestAudioApplicationPermission = true
                completion(true)
            },
            audioDeviceAuthorizationStatus: { .notDetermined },
            requestAudioDeviceAccess: { completion in
                didRequestCaptureDevicePermission = true
                completion(false)
            },
            isAccessibilityTrusted: { false },
            requestAccessibilityTrust: { _ in false },
            openURL: { _ in false }
        ))

        let granted = await manager.requestMicrophonePermission()

        XCTAssertTrue(granted)
        XCTAssertTrue(didRequestAudioApplicationPermission)
        XCTAssertFalse(didRequestCaptureDevicePermission)
    }

    func testRequestMicrophonePermissionUsesCaptureDeviceFallbackWhenUnavailable() async {
        var didRequestAudioApplicationPermission = false
        var didRequestCaptureDevicePermission = false

        let manager = PermissionManager(systemCalls: .init(
            supportsAudioApplicationAPI: { false },
            audioApplicationRecordPermission: { .undetermined },
            requestAudioApplicationRecordPermission: { completion in
                didRequestAudioApplicationPermission = true
                completion(true)
            },
            audioDeviceAuthorizationStatus: { .notDetermined },
            requestAudioDeviceAccess: { completion in
                didRequestCaptureDevicePermission = true
                completion(true)
            },
            isAccessibilityTrusted: { false },
            requestAccessibilityTrust: { _ in false },
            openURL: { _ in false }
        ))

        let granted = await manager.requestMicrophonePermission()

        XCTAssertTrue(granted)
        XCTAssertFalse(didRequestAudioApplicationPermission)
        XCTAssertTrue(didRequestCaptureDevicePermission)
    }

    func testAccessibilityStatusAndRequestAndOpenSettings() async {
        var capturedPromptFlag: Bool?
        var openedURL: URL?

        let manager = PermissionManager(systemCalls: .init(
            supportsAudioApplicationAPI: { true },
            audioApplicationRecordPermission: { .granted },
            requestAudioApplicationRecordPermission: { _ in },
            audioDeviceAuthorizationStatus: { .authorized },
            requestAudioDeviceAccess: { _ in },
            isAccessibilityTrusted: { true },
            requestAccessibilityTrust: { shouldPrompt in
                capturedPromptFlag = shouldPrompt
                return false
            },
            openURL: { url in
                openedURL = url
                return true
            }
        ))

        XCTAssertTrue(manager.hasAccessibilityPermission())

        let granted = await manager.requestAccessibilityPermission()
        XCTAssertFalse(granted)
        XCTAssertEqual(capturedPromptFlag, true)

        XCTAssertTrue(manager.openAccessibilitySettings())
        XCTAssertEqual(openedURL?.absoluteString, "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }
}
#endif

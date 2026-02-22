#if canImport(XCTest)
import XCTest
@testable import MyVoiceInput
#if canImport(KeyboardShortcuts)
import KeyboardShortcuts
#endif

final class AppStateTests: XCTestCase {
    func testRecordingStateTransitionsFromIdleToRecordingToTranscribing() {
        let appState = AppState()

        XCTAssertEqual(appState.recordingState, .idle)
        appState.startRecording()
        XCTAssertEqual(appState.recordingState, .recording)
        appState.stopRecording()
        XCTAssertEqual(appState.recordingState, .transcribing)
    }

#if canImport(KeyboardShortcuts)
    @MainActor
    func testCoordinatorHotkeyDownUpDrivesStateToIdleForShortRecording() async {
        let appState = AppState()
        let shortcutsClient = CoordinatorMockShortcutsClient()
        let hotkeyManager = HotkeyManager(shortcutsClient: shortcutsClient.client)

        let coordinator = AppWiringCoordinator(
            appState: appState,
            hotkeyManager: hotkeyManager,
            audioCaptureService: AudioCaptureServiceSpy(),
            permissionService: MockPermissionService(),
            audioFeedbackService: AudioFeedbackServiceSpy(),
            recordingIndicatorController: RecordingIndicatorControllerSpy()
        )

        shortcutsClient.triggerKeyDown()
        await waitUntil("recording state") {
            appState.recordingState == .recording
        }

        shortcutsClient.triggerKeyUp()
        await waitUntil("short recording returns to idle") {
            appState.recordingState == .idle
        }

        _ = coordinator
    }
#endif

    @MainActor
    func testCoordinatorSettingsSelectedMicrophonePropagatesToAudioCaptureService() async {
        let appState = AppState()
        let audioCaptureSpy = AudioCaptureServiceSpy()
        let coordinator = AppWiringCoordinator(
            appState: appState,
            hotkeyManager: NoopHotkeyManager(),
            audioCaptureService: audioCaptureSpy,
            audioFeedbackService: AudioFeedbackServiceSpy(),
            recordingIndicatorController: RecordingIndicatorControllerSpy()
        )

        var updatedSettings = appState.settings
        updatedSettings.selectedMicrophoneID = "mic-42"
        appState.updateSettings(updatedSettings)

        await waitUntil("selected microphone propagated") {
            audioCaptureSpy.selectedInputDeviceIDs.contains("mic-42")
        }

        _ = coordinator
    }

    private func waitUntil(_ description: String, timeoutNanoseconds: UInt64 = 1_000_000_000, condition: @escaping @MainActor () -> Bool) async {
        let start = ContinuousClock.now
        while true {
            if await condition() {
                return
            }
            if ContinuousClock.now - start > .nanoseconds(Int64(timeoutNanoseconds)) {
                XCTFail("Timed out waiting for \(description)")
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

private final class RecordingIndicatorControllerSpy: RecordingIndicatorControlling {
    private(set) var showCalls = 0
    private(set) var hideCalls = 0

    func show() {
        showCalls += 1
    }

    func hide() {
        hideCalls += 1
    }
}

private final class AudioFeedbackServiceSpy: AudioFeedbackPlaying {
    private(set) var startCalls = 0
    private(set) var stopCalls = 0
    private(set) var errorCalls = 0

    func playStartSound() {
        startCalls += 1
    }

    func playStopSound() {
        stopCalls += 1
    }

    func playErrorSound() {
        errorCalls += 1
    }
}

private final class MockPermissionService: PermissionServiceProtocol {
    func requestMicrophonePermission() async -> Bool { true }
    func hasMicrophonePermission() -> Bool { true }
    func requestAccessibilityPermission() async -> Bool { true }
    func hasAccessibilityPermission() -> Bool { true }
}

private final class AudioCaptureServiceSpy: AudioCaptureServiceProtocol, @unchecked Sendable {
    private(set) var selectedInputDeviceIDs: [String?] = []
    private(set) var startCaptureCallCount = 0

    var stopCaptureData: Data?
    var isCapturing: Bool { false }

    func selectInputDevice(id: String?) {
        selectedInputDeviceIDs.append(id)
    }

    func startCapture() async throws {
        startCaptureCallCount += 1
    }

    func stopCapture() async -> Data? {
        stopCaptureData
    }
}

#if canImport(KeyboardShortcuts)
private final class CoordinatorMockShortcutsClient {
    private var keyDownHandler: (() -> Void)?
    private var keyUpHandler: (() -> Void)?

    lazy var client = HotkeyKeyboardShortcutsClient(
        onKeyDown: { [weak self] _, handler in
            self?.keyDownHandler = handler
        },
        onKeyUp: { [weak self] _, handler in
            self?.keyUpHandler = handler
        },
        getShortcut: { _ in nil }
    )

    func triggerKeyDown() {
        keyDownHandler?()
    }

    func triggerKeyUp() {
        keyUpHandler?()
    }
}
#endif
#endif

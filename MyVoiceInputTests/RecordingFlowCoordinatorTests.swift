#if canImport(XCTest)
import XCTest
@testable import MyVoiceInput

@MainActor
final class RecordingFlowCoordinatorTests: XCTestCase {
    func testHotkeyFlowHappyPathStreamsChunksToTextInsertion() async {
        let appState = AppState()
        var settings = appState.settings
        settings.apiEndpoint = "http://localhost/test"
        settings.modelName = "stream-model"
        appState.updateSettings(settings)

        let hotkey = TestHotkeyManager()
        let capture = TestAudioCaptureService(stopCaptureData: Data(repeating: 0x01, count: 8_192))
        let encoder = TestMP3EncoderService(encodedOutput: Data([0xAA, 0xBB]))
        let transcription = TestTranscriptionService(streamChunks: ["hello", " world"])
        let insertion = TestTextInsertionService()
        let feedback = TestAudioFeedbackService()
        let indicator = TestRecordingIndicatorController()

        let coordinator = RecordingFlowCoordinator(
            appState: appState,
            hotkeyManager: hotkey,
            audioCaptureService: capture,
            mp3EncoderService: encoder,
            transcriptionService: transcription,
            textInsertionService: insertion,
            errorHandlingService: makeNonBlockingErrorHandlingService(),
            audioFeedbackService: feedback,
            recordingIndicatorController: indicator,
            sampleRate: 16_000,
            minimumPCMBytes: 32
        )

        hotkey.triggerStart()
        await waitUntil("recording started") { appState.recordingState == .recording }

        hotkey.triggerStop()
        await waitUntil("flow completed") { appState.recordingState == .idle }

        XCTAssertEqual(capture.startCaptureCallCount, 1)
        XCTAssertEqual(capture.stopCaptureCallCount, 1)
        XCTAssertEqual(encoder.lastSampleRate, 16_000)
        XCTAssertEqual(encoder.lastPCMInput, Data(repeating: 0x01, count: 8_192))
        XCTAssertEqual(transcription.lastEndpoint, "http://localhost/test")
        XCTAssertEqual(transcription.lastModel, "stream-model")
        XCTAssertEqual(transcription.lastAudioData, Data([0xAA, 0xBB]))
        XCTAssertEqual(insertion.insertedTexts, ["hello", " world"])
        XCTAssertEqual(feedback.startCalls, 1)
        XCTAssertEqual(feedback.stopCalls, 1)
        XCTAssertEqual(feedback.errorCalls, 0)
        XCTAssertEqual(indicator.showCalls, 1)
        XCTAssertGreaterThanOrEqual(indicator.hideCalls, 1)

        _ = coordinator
    }

    func testTimeoutErrorSetsErrorStateAndCleansIndicator() async {
        let appState = AppState()
        let hotkey = TestHotkeyManager()
        let capture = TestAudioCaptureService(stopCaptureData: Data(repeating: 0x03, count: 8_192))
        let encoder = TestMP3EncoderService(encodedOutput: Data([0x10]))
        let transcription = TestTranscriptionService(streamChunks: [], transcribeError: URLError(.timedOut))
        let insertion = TestTextInsertionService()
        let feedback = TestAudioFeedbackService()
        let indicator = TestRecordingIndicatorController()

        let coordinator = RecordingFlowCoordinator(
            appState: appState,
            hotkeyManager: hotkey,
            audioCaptureService: capture,
            mp3EncoderService: encoder,
            transcriptionService: transcription,
            textInsertionService: insertion,
            errorHandlingService: makeNonBlockingErrorHandlingService(),
            audioFeedbackService: feedback,
            recordingIndicatorController: indicator,
            minimumPCMBytes: 32
        )

        hotkey.triggerStart()
        await waitUntil("recording started") { appState.recordingState == .recording }

        hotkey.triggerStop()
        await waitUntil("error state set") {
            if case .error = appState.recordingState {
                return true
            }
            return false
        }

        if case .error(let message) = appState.recordingState {
            XCTAssertFalse(message.isEmpty)
        } else {
            XCTFail("Expected error state")
        }

        XCTAssertEqual(insertion.insertedTexts, [])
        XCTAssertEqual(feedback.errorCalls, 1)
        XCTAssertGreaterThanOrEqual(indicator.hideCalls, 1)

        _ = coordinator
    }

    func testShortRecordingSkipsTranscriptionAndReturnsIdle() async {
        let appState = AppState()
        let hotkey = TestHotkeyManager()
        let capture = TestAudioCaptureService(stopCaptureData: Data(repeating: 0x05, count: 8))
        let encoder = TestMP3EncoderService(encodedOutput: Data([0x22]))
        let transcription = TestTranscriptionService(streamChunks: ["should-not-run"])
        let insertion = TestTextInsertionService()
        let feedback = TestAudioFeedbackService()
        let indicator = TestRecordingIndicatorController()

        let coordinator = RecordingFlowCoordinator(
            appState: appState,
            hotkeyManager: hotkey,
            audioCaptureService: capture,
            mp3EncoderService: encoder,
            transcriptionService: transcription,
            textInsertionService: insertion,
            errorHandlingService: makeNonBlockingErrorHandlingService(),
            audioFeedbackService: feedback,
            recordingIndicatorController: indicator,
            minimumPCMBytes: 32
        )

        hotkey.triggerStart()
        await waitUntil("recording started") { appState.recordingState == .recording }

        hotkey.triggerStop()
        await waitUntil("idle after short recording") { appState.recordingState == .idle }

        XCTAssertEqual(encoder.encodeCallCount, 0)
        XCTAssertEqual(transcription.transcribeCallCount, 0)
        XCTAssertEqual(insertion.insertedTexts, [])
        XCTAssertEqual(feedback.startCalls, 1)
        XCTAssertEqual(feedback.stopCalls, 1)
        XCTAssertEqual(feedback.errorCalls, 0)

        _ = coordinator
    }

    private func waitUntil(_ description: String, timeoutNanoseconds: UInt64 = 2_000_000_000, condition: @escaping @MainActor () -> Bool) async {
        let start = ContinuousClock.now
        while true {
            if condition() {
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

private final class TestHotkeyManager: HotkeyManaging {
    var onRecordingStart: (() -> Void)?
    var onRecordingStop: (() -> Void)?

    func triggerStart() {
        onRecordingStart?()
    }

    func triggerStop() {
        onRecordingStop?()
    }
}

private final class TestAudioCaptureService: AudioCaptureServiceProtocol, @unchecked Sendable {
    private(set) var startCaptureCallCount = 0
    private(set) var stopCaptureCallCount = 0

    var startError: Error?
    var stopCaptureData: Data?
    var isCapturing: Bool { false }

    init(stopCaptureData: Data?) {
        self.stopCaptureData = stopCaptureData
    }

    func selectInputDevice(id: String?) {}

    func startCapture() async throws {
        startCaptureCallCount += 1
        if let startError {
            throw startError
        }
    }

    func stopCapture() async -> Data? {
        stopCaptureCallCount += 1
        return stopCaptureData
    }
}

private final class TestMP3EncoderService: MP3EncoderService {
    private(set) var encodeCallCount = 0
    private(set) var lastPCMInput: Data?
    private(set) var lastSampleRate: Int?

    let encodedOutput: Data
    var encodeError: Error?

    init(encodedOutput: Data) {
        self.encodedOutput = encodedOutput
        super.init()
    }

    override func encode(pcmData: Data, sampleRate: Int) async throws -> Data {
        encodeCallCount += 1
        lastPCMInput = pcmData
        lastSampleRate = sampleRate
        if let encodeError {
            throw encodeError
        }
        return encodedOutput
    }
}

private final class TestTranscriptionService: TranscriptionServiceProtocol, @unchecked Sendable {
    private(set) var transcribeCallCount = 0
    private(set) var lastAudioData: Data?
    private(set) var lastEndpoint: String?
    private(set) var lastModel: String?

    let streamChunks: [String]
    var transcribeError: Error?

    init(streamChunks: [String], transcribeError: Error? = nil) {
        self.streamChunks = streamChunks
        self.transcribeError = transcribeError
    }

    func transcribe(audioData: Data, endpoint: String, model: String) async throws -> AsyncStream<String> {
        transcribeCallCount += 1
        lastAudioData = audioData
        lastEndpoint = endpoint
        lastModel = model

        if let transcribeError {
            throw transcribeError
        }

        return AsyncStream { continuation in
            for chunk in streamChunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
    }
}

private final class TestTextInsertionService: TextInsertionServiceProtocol, @unchecked Sendable {
    private(set) var insertedTexts: [String] = []

    func insertText(_ text: String) async throws {
        insertedTexts.append(text)
    }
}

private final class TestAudioFeedbackService: AudioFeedbackPlaying {
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

private final class TestRecordingIndicatorController: RecordingIndicatorControlling {
    private(set) var showCalls = 0
    private(set) var hideCalls = 0

    func show() {
        showCalls += 1
    }

    func hide() {
        hideCalls += 1
    }
}

@MainActor
private func makeNonBlockingErrorHandlingService() -> ErrorHandlingService {
    ErrorHandlingService(dependencies: .init(
        presentAlert: { _ in false },
        openURL: { _ in true }
    ))
}
#endif

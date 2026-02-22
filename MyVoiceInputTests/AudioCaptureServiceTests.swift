#if canImport(XCTest)
import XCTest
import AVFoundation
@testable import MyVoiceInput

final class AudioCaptureServiceTests: XCTestCase {
    func testStartCaptureSetsIsCapturingTrue() async throws {
        let fakeNode = FakeAudioInputNode()
        let fakeEngine = FakeAudioEngine(inputNode: fakeNode)
        let service = AudioCaptureService(engine: fakeEngine)

        XCTAssertFalse(service.isCapturing)

        try await service.startCapture()

        XCTAssertTrue(service.isCapturing)
        XCTAssertEqual(fakeNode.installTapCallCount, 1)
        XCTAssertEqual(fakeEngine.startCallCount, 1)
    }

    func testStopCaptureReturnsBufferedPCMDataAndResetsState() async throws {
        let fakeNode = FakeAudioInputNode()
        let fakeEngine = FakeAudioEngine(inputNode: fakeNode)
        let service = AudioCaptureService(engine: fakeEngine)

        try await service.startCapture()
        fakeNode.emit(buffer: makeBuffer(samples: [0.1, -0.2, 0.3, -0.4]))

        let data = await service.stopCapture()

        XCTAssertFalse(service.isCapturing)
        XCTAssertEqual(fakeNode.removeTapCallCount, 1)
        XCTAssertEqual(fakeEngine.stopCallCount, 1)
        XCTAssertNotNil(data)
        XCTAssertEqual(floatSamples(from: data), [0.1, -0.2, 0.3, -0.4])
    }

    func testStopCaptureWhenNotCapturingReturnsNil() async {
        let fakeNode = FakeAudioInputNode()
        let fakeEngine = FakeAudioEngine(inputNode: fakeNode)
        let service = AudioCaptureService(engine: fakeEngine)

        let data = await service.stopCapture()

        XCTAssertNil(data)
        XCTAssertEqual(fakeNode.removeTapCallCount, 0)
        XCTAssertEqual(fakeEngine.stopCallCount, 0)
    }

    func testStartCaptureThrowsForUnknownSelectedInputDeviceID() async {
        let fakeNode = FakeAudioInputNode()
        let fakeEngine = FakeAudioEngine(inputNode: fakeNode)
        let service = AudioCaptureService(
            engine: fakeEngine,
            inputDevicesProvider: { [AudioDevice(name: "Built-in", id: "known")] },
            deviceIDResolver: { _ in nil }
        )

        service.selectInputDevice(id: "missing")

        do {
            try await service.startCapture()
            XCTFail("Expected startCapture to throw")
        } catch let error as AudioCaptureServiceError {
            XCTAssertEqual(error, .invalidInputDeviceID("missing"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeBuffer(samples: [Float32]) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44_100, channels: 1, interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        let channel = buffer.floatChannelData![0]
        for (index, sample) in samples.enumerated() {
            channel[index] = sample
        }
        return buffer
    }

    private func floatSamples(from data: Data?) -> [Float32] {
        guard let data, !data.isEmpty else { return [] }
        let count = data.count / MemoryLayout<Float32>.stride
        return data.withUnsafeBytes { rawBuffer in
            let pointer = rawBuffer.bindMemory(to: Float32.self)
            return Array(pointer.prefix(count))
        }
    }
}

private final class FakeAudioInputNode: AudioEngineInputNodeProtocol {
    private(set) var installTapCallCount = 0
    private(set) var removeTapCallCount = 0
    private var tapBlock: AVAudioNodeTapBlock?
    private let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44_100, channels: 1, interleaved: false)!

    func inputFormat(forBus bus: AVAudioNodeBus) -> AVAudioFormat {
        format
    }

    func installTap(onBus bus: AVAudioNodeBus, bufferSize: AVAudioFrameCount, format: AVAudioFormat?, block: @escaping AVAudioNodeTapBlock) {
        installTapCallCount += 1
        tapBlock = block
    }

    func removeTap(onBus bus: AVAudioNodeBus) {
        removeTapCallCount += 1
        tapBlock = nil
    }

    func emit(buffer: AVAudioPCMBuffer) {
        tapBlock?(buffer, AVAudioTime(sampleTime: 0, atRate: 44_100))
    }
}

private final class FakeAudioEngine: AudioEngineProtocol {
    enum FakeError: Error {
        case startFailure
    }

    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    var shouldFailStart = false
    var isRunning = false
    let inputNode: AudioEngineInputNodeProtocol

    init(inputNode: AudioEngineInputNodeProtocol) {
        self.inputNode = inputNode
    }

    func setInputDevice(_ deviceID: AudioDeviceID) throws {}

    func prepare() {}

    func start() throws {
        startCallCount += 1
        if shouldFailStart {
            throw FakeError.startFailure
        }
        isRunning = true
    }

    func stop() {
        stopCallCount += 1
        isRunning = false
    }
}
#endif

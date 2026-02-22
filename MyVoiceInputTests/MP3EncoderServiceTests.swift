#if canImport(XCTest)
import XCTest
@testable import MyVoiceInput

final class MP3EncoderServiceTests: XCTestCase {
    func testEncodeThrowsOnEmptyInput() async {
        let service = MP3EncoderService()

        do {
            _ = try await service.encode(pcmData: Data(), sampleRate: 44_100)
            XCTFail("Expected empty input to throw")
        } catch let error as EncodingError {
            XCTAssertEqual(error, .emptyInput)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testEncodeReturnsMP3DataWithExpectedHeader() async throws {
#if canImport(SwiftLAME)
        let service = MP3EncoderService()
        let pcmData = makePCMData(frameCount: 4_410, frequency: 440, sampleRate: 44_100)

        let encoded = try await service.encode(pcmData: pcmData, sampleRate: 44_100)

        XCTAssertFalse(encoded.isEmpty)
        XCTAssertTrue(hasMP3Header(encoded), "Encoded MP3 should start with ID3 or MPEG sync bytes")
#else
        throw XCTSkip("SwiftLAME module unavailable in current build environment")
#endif
    }

    private func makePCMData(frameCount: Int, frequency: Float32, sampleRate: Float32) -> Data {
        var samples = Array(repeating: Float32.zero, count: frameCount)
        let angularStep = (2 * Float32.pi * frequency) / sampleRate
        for index in 0..<frameCount {
            samples[index] = sinf(Float32(index) * angularStep) * 0.25
        }

        return samples.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
    }

    private func hasMP3Header(_ data: Data) -> Bool {
        if data.count >= 3, Array(data.prefix(3)) == [0x49, 0x44, 0x33] {
            return true
        }

        if data.count >= 2, Array(data.prefix(2)) == [0xFF, 0xFB] {
            return true
        }

        return false
    }
}
#endif

import Foundation
import AVFoundation
#if canImport(SwiftLAME)
import SwiftLAME
#endif

enum EncodingError: Error, Equatable {
    case emptyInput
    case invalidSampleRate(Int)
    case invalidPCMByteCount(Int)
    case unableToCreateAudioFormat
    case unableToCreatePCMBuffer
    case swiftLameUnavailable
}

class MP3EncoderService {
    private enum PCMInput {
        static let channelCount: AVAudioChannelCount = 1
        static let bytesPerSample = MemoryLayout<Float32>.size
        static let bitrateKbps: Int32 = 128
    }

    func encode(pcmData: Data, sampleRate: Int) async throws -> Data {
        guard !pcmData.isEmpty else {
            throw EncodingError.emptyInput
        }
        guard sampleRate > 0 else {
            throw EncodingError.invalidSampleRate(sampleRate)
        }
        guard pcmData.count.isMultiple(of: PCMInput.bytesPerSample) else {
            throw EncodingError.invalidPCMByteCount(pcmData.count)
        }

        let tempDirectory = FileManager.default.temporaryDirectory
        let tempID = UUID().uuidString
        let wavURL = tempDirectory.appendingPathComponent("\(tempID)-input.wav")
        let mp3URL = tempDirectory.appendingPathComponent("\(tempID)-output.mp3")

        defer {
            try? FileManager.default.removeItem(at: wavURL)
            try? FileManager.default.removeItem(at: mp3URL)
        }

        try writeWAVFile(pcmData: pcmData, sampleRate: sampleRate, destinationURL: wavURL)

#if canImport(SwiftLAME)
        let encoder = try SwiftLameEncoder(
            sourceUrl: wavURL,
            configuration: .init(
                sampleRate: .custom(Int32(sampleRate)),
                bitrateMode: .constant(PCMInput.bitrateKbps),
                quality: .best
            ),
            destinationUrl: mp3URL
        )
        try await encoder.encode(priority: .userInitiated)

        return try Data(contentsOf: mp3URL)
#else
        throw EncodingError.swiftLameUnavailable
#endif
    }

    private func writeWAVFile(pcmData: Data, sampleRate: Int, destinationURL: URL) throws {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(sampleRate),
            channels: PCMInput.channelCount,
            interleaved: false
        ) else {
            throw EncodingError.unableToCreateAudioFormat
        }

        let frameCount = pcmData.count / PCMInput.bytesPerSample
        guard let pcmBuffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(frameCount)
        ) else {
            throw EncodingError.unableToCreatePCMBuffer
        }

        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)
        let channel = pcmBuffer.floatChannelData![0]

        pcmData.withUnsafeBytes { rawBuffer in
            let sourceSamples = rawBuffer.bindMemory(to: Float32.self)
            for index in 0..<frameCount {
                channel[index] = sourceSamples[index]
            }
        }

        let audioFile = try AVAudioFile(forWriting: destinationURL, settings: format.settings)
        try audioFile.write(from: pcmBuffer)
    }
}

import Foundation

protocol TranscriptionServiceProtocol: Sendable {
    func transcribe(audioData: Data, endpoint: String, model: String, language: String?) async throws -> AsyncStream<String>
}

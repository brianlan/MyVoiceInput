import Foundation

protocol TranscriptionServiceProtocol: Sendable {
    func transcribe(audioData: Data, endpoint: String, model: String) async throws -> AsyncStream<String>
}

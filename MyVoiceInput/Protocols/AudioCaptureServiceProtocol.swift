import Foundation
import AVFoundation

protocol AudioCaptureServiceProtocol: Sendable {
    func selectInputDevice(id: String?)
    func startCapture() async throws
    func stopCapture() async -> Data?
    func consumePendingWarning() -> String?
    var isCapturing: Bool { get }
}

extension AudioCaptureServiceProtocol {
    func consumePendingWarning() -> String? {
        nil
    }
}

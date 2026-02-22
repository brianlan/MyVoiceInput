import Foundation
import AVFoundation

protocol AudioCaptureServiceProtocol: Sendable {
    func selectInputDevice(id: String?)
    func startCapture() async throws
    func stopCapture() async -> Data?
    var isCapturing: Bool { get }
}

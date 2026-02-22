import Foundation

struct AppSettings: Sendable {
    var hotkeyKeyCode: UInt16
    var hotkeyModifiers: UInt
    var apiEndpoint: String
    var modelName: String
    var selectedMicrophoneID: String?
    var autoStartEnabled: Bool

    static let `default` = AppSettings(
        hotkeyKeyCode: 49,
        hotkeyModifiers: 0,
        apiEndpoint: "http://127.0.0.1:8010/v1/audio/transcriptions",
        modelName: "base",
        selectedMicrophoneID: nil,
        autoStartEnabled: false
    )
}

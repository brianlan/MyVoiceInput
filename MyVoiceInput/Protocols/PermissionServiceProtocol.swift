import Foundation

protocol PermissionServiceProtocol: Sendable {
    func requestMicrophonePermission() async -> Bool
    func hasMicrophonePermission() -> Bool
    func requestAccessibilityPermission() async -> Bool
    func hasAccessibilityPermission() -> Bool
}

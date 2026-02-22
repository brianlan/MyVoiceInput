import Foundation

enum AppError: Error, Equatable {
    case microphonePermissionMissing
    case accessibilityPermissionMissing
    case apiConnectionFailed(endpoint: String)
    case apiResponseError(message: String)
    case encodingFailed
    case unknown

    var userMessage: String {
        switch self {
        case .microphonePermissionMissing:
            return "Microphone access is required to start recording."
        case .accessibilityPermissionMissing:
            return "Accessibility access is required to insert transcribed text."
        case .apiConnectionFailed(let endpoint):
            return "Cannot connect to transcription service at \(endpoint)."
        case .apiResponseError(let message):
            return message
        case .encodingFailed:
            return "Could not prepare audio for transcription. Please try again."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }

    var logMessage: String {
        switch self {
        case .microphonePermissionMissing:
            return "Microphone permission missing"
        case .accessibilityPermissionMissing:
            return "Accessibility permission missing"
        case .apiConnectionFailed(let endpoint):
            return "API connection failed at endpoint: \(endpoint)"
        case .apiResponseError(let message):
            return "API response error: \(message)"
        case .encodingFailed:
            return "Audio encoding failed"
        case .unknown:
            return "Unknown app error"
        }
    }

    var alertTitle: String {
        switch self {
        case .microphonePermissionMissing:
            return "Microphone Permission Needed"
        case .accessibilityPermissionMissing:
            return "Accessibility Permission Needed"
        case .apiConnectionFailed, .apiResponseError, .encodingFailed, .unknown:
            return "MyVoiceInput"
        }
    }

    var settingsDestination: SettingsDestination? {
        switch self {
        case .microphonePermissionMissing:
            return .microphone
        case .accessibilityPermissionMissing:
            return .accessibility
        case .apiConnectionFailed, .apiResponseError, .encodingFailed, .unknown:
            return nil
        }
    }

}

enum SettingsDestination: Equatable {
    case microphone
    case accessibility

    var url: URL {
        switch self {
        case .microphone:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        case .accessibility:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        }
    }
}

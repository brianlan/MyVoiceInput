import AppKit
import Foundation
import OSLog

@MainActor
final class ErrorHandlingService {
    struct AlertPayload: Equatable {
        let title: String
        let message: String
        let primaryButtonTitle: String
        let secondaryButtonTitle: String
    }

    struct Dependencies {
        var presentAlert: @MainActor (AlertPayload) -> Bool
        var openURL: @Sendable (URL) -> Bool

        static let live = Dependencies(
            presentAlert: { payload in
                let alert = NSAlert()
                alert.alertStyle = .critical
                alert.messageText = payload.title
                alert.informativeText = payload.message
                alert.addButton(withTitle: payload.primaryButtonTitle)
                if !payload.secondaryButtonTitle.isEmpty {
                    alert.addButton(withTitle: payload.secondaryButtonTitle)
                }
                return alert.runModal() == .alertFirstButtonReturn
            },
            openURL: { url in
                NSWorkspace.shared.open(url)
            }
        )
    }

    private let logger: Logger
    private let dependencies: Dependencies

    init(
        logger: Logger = Logger(subsystem: "com.myvoiceinput.app", category: "error-handling"),
        dependencies: Dependencies = .live
    ) {
        self.logger = logger
        self.dependencies = dependencies
    }

    @discardableResult
    func handle(error: Error, endpoint: String) -> AppError {
        let appError = mapToAppError(error, endpoint: endpoint)
        report(appError: appError, underlyingError: error)
        return appError
    }

    @discardableResult
    func handle(appError: AppError) -> AppError {
        report(appError: appError, underlyingError: nil)
        return appError
    }

    private func report(appError: AppError, underlyingError: Error?) {
        logger.error("\(appError.logMessage, privacy: .public)")
        if let underlyingError {
            logger.error("Underlying error: \(String(describing: underlyingError), privacy: .private(mask: .hash))")
        }

        let destination = appError.settingsDestination
        let payload = makeAlertPayload(for: appError)
        let shouldOpenSettings = dependencies.presentAlert(payload)
        if shouldOpenSettings, let destination {
            _ = dependencies.openURL(destination.url)
        }
    }

    private func makeAlertPayload(for appError: AppError) -> AlertPayload {
        if appError.settingsDestination != nil {
            return AlertPayload(
                title: appError.alertTitle,
                message: appError.userMessage,
                primaryButtonTitle: "Open System Settings",
                secondaryButtonTitle: "Cancel"
            )
        }

        return AlertPayload(
            title: appError.alertTitle,
            message: appError.userMessage,
            primaryButtonTitle: "OK",
            secondaryButtonTitle: ""
        )
    }

    private func mapToAppError(_ error: Error, endpoint: String) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        if let insertionError = error as? TextInsertionServiceError,
           insertionError == .accessibilityPermissionDenied {
            return .accessibilityPermissionMissing
        }

        if error is EncodingError {
            return .encodingFailed
        }

        if error is URLError {
            return .apiConnectionFailed(endpoint: endpoint)
        }

        if let transcriptionError = error as? TranscriptionServiceError {
            switch transcriptionError {
            case .invalidEndpoint(let invalidEndpoint):
                return .apiConnectionFailed(endpoint: invalidEndpoint)
            case .invalidHTTPResponse:
                return .apiResponseError(message: "The transcription service returned an invalid response.")
            case .unexpectedStatusCode(let statusCode):
                return .apiResponseError(message: "The transcription service returned status code \(statusCode).")
            case .unsupportedContentType:
                return .apiResponseError(message: "The transcription service returned an unsupported response format.")
            case .malformedSSEEvent, .malformedJSONPayload:
                return .apiResponseError(message: "The transcription response could not be processed.")
            }
        }

        return .unknown
    }
}

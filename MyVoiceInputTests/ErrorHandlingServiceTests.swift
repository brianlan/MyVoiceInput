#if canImport(XCTest)
import XCTest
@testable import MyVoiceInput

@MainActor
final class ErrorHandlingServiceTests: XCTestCase {
    func testMapsConnectionErrorToEndpointAwareAppError() {
        var capturedAlert: ErrorHandlingService.AlertPayload?
        var openedURL: URL?

        let service = ErrorHandlingService(
            dependencies: .init(
                presentAlert: { payload in
                    capturedAlert = payload
                    return false
                },
                openURL: { url in
                    openedURL = url
                    return true
                }
            )
        )

        let appError = service.handle(error: URLError(.cannotFindHost), endpoint: "http://localhost/v1/audio/transcriptions")

        XCTAssertEqual(appError, .apiConnectionFailed(endpoint: "http://localhost/v1/audio/transcriptions"))
        XCTAssertEqual(capturedAlert?.message, "Cannot connect to transcription service at http://localhost/v1/audio/transcriptions.")
        XCTAssertEqual(capturedAlert?.primaryButtonTitle, "OK")
        XCTAssertNil(openedURL)
    }

    func testMapsTranscriptionStatusCodeErrorToFriendlyMessage() {
        var capturedAlert: ErrorHandlingService.AlertPayload?
        var openedURL: URL?

        let service = ErrorHandlingService(
            dependencies: .init(
                presentAlert: { payload in
                    capturedAlert = payload
                    return false
                },
                openURL: { url in
                    openedURL = url
                    return true
                }
            )
        )

        let appError = service.handle(error: TranscriptionServiceError.unexpectedStatusCode(503), endpoint: "http://localhost")

        XCTAssertEqual(
            appError,
            .apiResponseError(message: "The transcription service returned status code 503.")
        )
        XCTAssertEqual(capturedAlert?.primaryButtonTitle, "OK")
        XCTAssertEqual(capturedAlert?.secondaryButtonTitle, "")
        XCTAssertNil(openedURL)
    }

    func testCriticalPermissionErrorInvokesAlertAndSettingsOpen() {
        var capturedAlert: ErrorHandlingService.AlertPayload?
        var openedURL: URL?

        let service = ErrorHandlingService(
            dependencies: .init(
                presentAlert: { payload in
                    capturedAlert = payload
                    return true
                },
                openURL: { url in
                    openedURL = url
                    return true
                }
            )
        )

        let appError = service.handle(appError: .accessibilityPermissionMissing)

        XCTAssertEqual(appError, .accessibilityPermissionMissing)
        XCTAssertEqual(capturedAlert?.title, "Accessibility Permission Needed")
        XCTAssertEqual(capturedAlert?.primaryButtonTitle, "Open System Settings")
        XCTAssertEqual(
            openedURL,
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        )
    }
}
#endif

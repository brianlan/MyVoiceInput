#if canImport(XCTest)
import XCTest
@testable import MyVoiceInput

final class AudioFeedbackServiceTests: XCTestCase {
    func testPlayStartSoundDoesNotThrow() {
        let service = AudioFeedbackService.shared
        XCTAssertNoThrow(service.playStartSound())
    }
    
    func testPlayStopSoundDoesNotThrow() {
        let service = AudioFeedbackService.shared
        XCTAssertNoThrow(service.playStopSound())
    }
    
    func testPlayErrorSoundDoesNotThrow() {
        let service = AudioFeedbackService.shared
        XCTAssertNoThrow(service.playErrorSound())
    }
    
    func testMultipleRapidCallsDoNotCrash() {
        let service = AudioFeedbackService.shared
        for _ in 0..<10 {
            service.playStartSound()
            service.playStopSound()
            service.playErrorSound()
        }
    }
}
#endif

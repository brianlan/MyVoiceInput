import Foundation

enum RecordingState: Sendable, Equatable {
    case idle
    case recording
    case transcribing
    case inserting
    case error(String)
}

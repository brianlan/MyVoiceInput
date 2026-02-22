import Foundation

protocol TextInsertionServiceProtocol: Sendable {
    func insertText(_ text: String) async throws
}

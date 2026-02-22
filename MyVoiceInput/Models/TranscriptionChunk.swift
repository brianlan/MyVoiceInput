import Foundation

struct TranscriptionChunk: Sendable {
    let content: String?
    let isFinished: Bool

    init(content: String? = nil, isFinished: Bool = false) {
        self.content = content
        self.isFinished = isFinished
    }

    static func parse(from line: String) -> TranscriptionChunk? {
        guard line.hasPrefix("data: ") else { return nil }
        let jsonString = String(line.dropFirst(6))
        if jsonString == "[DONE]" {
            return TranscriptionChunk(isFinished: true)
        }
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any],
              let content = delta["content"] as? String else {
            return nil
        }
        return TranscriptionChunk(content: content)
    }
}

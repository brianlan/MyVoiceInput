import Foundation
import os.log

enum TranscriptionServiceError: Error {
    case invalidEndpoint(String)
    case invalidHTTPResponse
    case unexpectedStatusCode(Int)
    case unsupportedContentType(String?)
    case malformedSSEEvent
    case malformedJSONPayload
}

final class TranscriptionService: TranscriptionServiceProtocol, @unchecked Sendable {
    private let session: URLSession
    private let logger = Logger(subsystem: "com.myvoiceinput.app", category: "transcription")

    init(session: URLSession = .shared) {
        self.session = session
    }

    func transcribe(audioData: Data, endpoint: String, model: String, language: String?) async throws -> AsyncStream<String> {
        let languageCode = language?.trimmingCharacters(in: .whitespacesAndNewlines)
        logger.info("Starting transcription - endpoint: \(endpoint), model: '\(model)', language: '\(languageCode ?? "auto")', audio size: \(audioData.count) bytes")
        
        guard let url = URL(string: endpoint) else {
            throw TranscriptionServiceError.invalidEndpoint(endpoint)
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        let body = makeMultipartBody(audioData: audioData, model: model, boundary: boundary, language: languageCode)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionServiceError.invalidHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            // Read error response body for logging
            var errorBody = ""
            for try await byte in bytes {
                if let char = String(bytes: [byte], encoding: .utf8) {
                    errorBody.append(char)
                }
            }
            logger.error("HTTP error \(httpResponse.statusCode): \(errorBody)")
            throw TranscriptionServiceError.unexpectedStatusCode(httpResponse.statusCode)
        }

        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")?.lowercased()
        guard contentType?.contains("text/event-stream") == true else {
            throw TranscriptionServiceError.unsupportedContentType(contentType)
        }

        return AsyncStream<String> { continuation in
            Task {
                var parser = SSEParser()

                do {
                    for try await byte in bytes {
                        let events = try parser.append(byte: byte)
                        for event in events {
                            switch event {
                            case .delta(let text):
                                continuation.yield(text)
                            case .done:
                                continuation.finish()
                                return
                            }
                        }
                    }

                    let remainingEvents = try parser.finish()
                    for event in remainingEvents {
                        switch event {
                        case .delta(let text):
                            continuation.yield(text)
                        case .done:
                            break
                        }
                    }
                } catch {
                }

                continuation.finish()
            }
        }
    }

    private func makeMultipartBody(audioData: Data, model: String?, boundary: String, language: String?) -> Data {
        var body = Data()

        body.appendMultipartLine("--\(boundary)")
        body.appendMultipartLine("Content-Disposition: form-data; name=\"file\"; filename=\"audio.mp3\"")
        body.appendMultipartLine("Content-Type: audio/mpeg")
        body.appendMultipartLine("")
        body.append(audioData)
        body.appendMultipartLine("")

        // Only add model if provided and not empty
        if let model, !model.isEmpty {
            body.appendMultipartLine("--\(boundary)")
            body.appendMultipartLine("Content-Disposition: form-data; name=\"model\"")
            body.appendMultipartLine("")
            body.appendMultipartLine(model)
        }

        body.appendMultipartLine("--\(boundary)")
        body.appendMultipartLine("Content-Disposition: form-data; name=\"stream\"")
        body.appendMultipartLine("")
        body.appendMultipartLine("true")

        if let language, !language.isEmpty {
            body.appendMultipartLine("--\(boundary)")
            body.appendMultipartLine("Content-Disposition: form-data; name=\"language\"")
            body.appendMultipartLine("")
            body.appendMultipartLine(language)
        }

        body.appendMultipartLine("--\(boundary)--")
        return body
    }
}

private extension Data {
    mutating func appendMultipartLine(_ value: String) {
        append(Data(value.utf8))
        append(Data("\r\n".utf8))
    }
}

private struct SSEParser {
    enum Event {
        case delta(String)
        case done
    }

    private var buffer = Data()

    mutating func append(byte: UInt8) throws -> [Event] {
        buffer.append(byte)
        return try drainEvents()
    }

    mutating func finish() throws -> [Event] {
        guard !buffer.isEmpty else {
            return []
        }

        let events = try parseEvent(buffer)
        buffer.removeAll(keepingCapacity: true)
        return events
    }

    private mutating func drainEvents() throws -> [Event] {
        var events: [Event] = []

        while let delimiter = nextEventDelimiter(in: buffer) {
            let eventBytes = buffer.prefix(delimiter.range.lowerBound)
            buffer.removeSubrange(0..<delimiter.range.upperBound)
            let parsed = try parseEvent(Data(eventBytes))
            events.append(contentsOf: parsed)
        }

        return events
    }

    private func nextEventDelimiter(in data: Data) -> (range: Range<Int>, length: Int)? {
        let bytes = Array(data)
        guard !bytes.isEmpty else {
            return nil
        }

        for index in 0..<bytes.count {
            if index + 1 < bytes.count, bytes[index] == 0x0A, bytes[index + 1] == 0x0A {
                return (index..<(index + 2), 2)
            }
            if index + 1 < bytes.count, bytes[index] == 0x0D, bytes[index + 1] == 0x0D {
                return (index..<(index + 2), 2)
            }
            if index + 3 < bytes.count,
               bytes[index] == 0x0D,
               bytes[index + 1] == 0x0A,
               bytes[index + 2] == 0x0D,
               bytes[index + 3] == 0x0A {
                return (index..<(index + 4), 4)
            }
        }

        return nil
    }

    private func parseEvent(_ eventBytes: Data) throws -> [Event] {
        guard !eventBytes.isEmpty else {
            return []
        }

        guard var rawEvent = String(data: eventBytes, encoding: .utf8) else {
            throw TranscriptionServiceError.malformedSSEEvent
        }
        rawEvent = rawEvent.replacingOccurrences(of: "\r\n", with: "\n")
        rawEvent = rawEvent.replacingOccurrences(of: "\r", with: "\n")

        var dataLines: [String] = []

        rawEvent.split(separator: "\n", omittingEmptySubsequences: false).forEach { lineSubstring in
            let line = String(lineSubstring)

            if line.isEmpty || line.hasPrefix(":") {
                return
            }

            guard line.hasPrefix("data:") else {
                return
            }

            var value = String(line.dropFirst(5))
            if value.first == " " {
                value.removeFirst()
            }
            dataLines.append(value)
        }

        guard !dataLines.isEmpty else {
            return []
        }

        let dataPayload = dataLines.joined(separator: "\n")
        if dataPayload == "[DONE]" {
            return [.done]
        }

        // Try to parse as JSON with expected format
        guard let payloadData = dataPayload.data(using: .utf8),
              let payload = try? JSONDecoder().decode(TranscriptionChunkPayload.self, from: payloadData),
              let content = payload.choices.first?.delta.content else {
            print("Failed to parse: \(dataPayload)")
            return []
        }
        
        // Filter out metadata and tags - only return actual transcription content
        // The API sends: "language", " English", "<asr_text>", then the actual text
        let trimmedContent = content.trimmingCharacters(in: .whitespaces)
        
        // Skip these metadata markers
        if trimmedContent == "language" || 
           trimmedContent == "English" ||
           trimmedContent == "Chinese" ||
           trimmedContent == "<asr_text>" ||
           trimmedContent.hasPrefix("<") && trimmedContent.hasSuffix(">") {
            return []
        }
        
        // Return the actual transcription text
        return [.delta(content)]
    }
}

private struct TranscriptionChunkPayload: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let delta: Delta
    }

    struct Delta: Decodable {
        let content: String?
    }
}

// Alternative payload for APIs that return {"text": "..."} or {"delta": {"text": "..."}}
private struct AlternativeTranscriptionPayload: Decodable {
    let text: String?
    let delta: DeltaPayload?

    struct DeltaPayload: Decodable {
        let text: String?
    }
}

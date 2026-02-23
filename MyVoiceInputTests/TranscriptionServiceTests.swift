#if canImport(XCTest)
import XCTest
import Foundation
@testable import MyVoiceInput

final class TranscriptionServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        URLProtocolStub.reset()
    }

    override func tearDown() {
        URLProtocolStub.reset()
        super.tearDown()
    }

    func testTranscribeYieldsStreamChunksFromSSEEvents() async throws {
        let chunks = [
            "data: {\"choices\":[{\"delta\":{\"content\":\"Hel\"}}]}\r\n\r",
            "\ndata: {\"choices\":[{\"delta\":{\"content\":\"lo\"}}]}\n\n",
            "data: [DONE]\r\n\r\n"
        ]

        URLProtocolStub.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "text/event-stream; charset=utf-8"]
            )!
            return .stream(response, chunks.map { Data($0.utf8) })
        }

        let service = makeService()
        let stream = try await service.transcribe(
            audioData: Data([0x01, 0x02, 0x03]),
            endpoint: "http://localhost/v1/audio/transcriptions",
            model: "base",
            language: nil
        )

        var received: [String] = []
        for await delta in stream {
            received.append(delta)
        }

        XCTAssertEqual(received, ["Hel", "lo"])
    }

    func testTranscribeThrowsOnConnectionFailure() async {
        URLProtocolStub.handler = { _ in
            .failure(URLError(.notConnectedToInternet))
        }

        let service = makeService()

        do {
            _ = try await service.transcribe(
                audioData: Data([0x0]),
                endpoint: "http://localhost/v1/audio/transcriptions",
                model: "base",
                language: nil
            )
            XCTFail("Expected transcribe to throw for connection failure")
        } catch {
            guard let urlError = error as? URLError else {
                XCTFail("Expected URLError but got \(error)")
                return
            }
            XCTAssertEqual(urlError.code, .notConnectedToInternet)
        }
    }

    func testTranscribeBuildsMultipartFormRequest() async throws {
        let audioData = Data([0xAA, 0xBB, 0xCC, 0xDD])

        URLProtocolStub.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "text/event-stream"]
            )!
            return .stream(response, [Data("data: [DONE]\n\n".utf8)])
        }

        let service = makeService()
        let stream = try await service.transcribe(
            audioData: audioData,
            endpoint: "http://localhost/v1/audio/transcriptions",
            model: "qwen-asr",
            language: "en"
        )

        for await _ in stream {
        }

        guard let request = URLProtocolStub.lastRequest else {
            return XCTFail("Expected captured request")
        }

        XCTAssertEqual(request.httpMethod, "POST")
        let contentType = try XCTUnwrap(request.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertTrue(contentType.hasPrefix("multipart/form-data; boundary="))

        let boundary = String(contentType.dropFirst("multipart/form-data; boundary=".count))
        
        let body = extractRequestBody(from: request)
        
        let bodyString = String(decoding: body, as: UTF8.self)

        XCTAssertTrue(bodyString.contains("--\(boundary)\r\n"))
        XCTAssertTrue(bodyString.contains("Content-Disposition: form-data; name=\"file\"; filename=\"audio.mp3\""))
        XCTAssertTrue(bodyString.contains("Content-Type: audio/mpeg"))
        XCTAssertTrue(bodyString.contains("Content-Disposition: form-data; name=\"model\""))
        XCTAssertTrue(bodyString.contains("qwen-asr"))
        XCTAssertTrue(bodyString.contains("Content-Disposition: form-data; name=\"stream\""))
        XCTAssertTrue(bodyString.contains("\r\ntrue\r\n"))
        
        XCTAssertTrue(bodyString.contains("Content-Disposition: form-data; name=\"language\""))
        XCTAssertTrue(bodyString.contains("\r\nen\r\n"))
        
        XCTAssertTrue(bodyString.contains("--\(boundary)--\r\n"))
        XCTAssertNotNil(body.range(of: audioData))
    }

    func testTranscribeOmitsLanguageFieldWhenNotProvided() async throws {
        URLProtocolStub.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "text/event-stream"]
            )!
            return .stream(response, [Data("data: [DONE]\n\n".utf8)])
        }

        let service = makeService()
        let stream = try await service.transcribe(
            audioData: Data([0x01]),
            endpoint: "http://localhost/v1/audio/transcriptions",
            model: "",
            language: nil
        )

        for await _ in stream {
        }

        guard let request = URLProtocolStub.lastRequest else {
            return XCTFail("Expected captured request")
        }

        let body = extractRequestBody(from: request)
        let bodyString = String(decoding: body, as: UTF8.self)
        XCTAssertFalse(bodyString.contains("Content-Disposition: form-data; name=\"language\""))
    }

    private func makeService() -> TranscriptionService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        return TranscriptionService(session: URLSession(configuration: config))
    }

    private func extractRequestBody(from request: URLRequest) -> Data {
        if let httpBody = request.httpBody {
            return httpBody
        }

        guard let bodyStream = request.httpBodyStream else {
            XCTFail("No body or bodyStream found")
            return Data()
        }

        var body = Data()
        bodyStream.open()
        defer { bodyStream.close() }

        let bufferSize = 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while bodyStream.hasBytesAvailable {
            let read = bodyStream.read(&buffer, maxLength: bufferSize)
            if read > 0 {
                body.append(contentsOf: buffer[0..<read])
            } else if read < 0 {
                XCTFail("Stream read error")
                return Data()
            } else {
                break
            }
        }
        return body
    }
}

private final class URLProtocolStub: URLProtocol {
    enum Response {
        case stream(HTTPURLResponse, [Data])
        case failure(Error)
    }

    static var handler: ((URLRequest) -> Response)?
    static var lastRequest: URLRequest?

    private var streamTask: Task<Void, Never>?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        Self.lastRequest = request
        switch handler(request) {
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)

        case .stream(let response, let chunks):
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            streamTask = Task {
                for chunk in chunks {
                    client?.urlProtocol(self, didLoad: chunk)
                    try? await Task.sleep(nanoseconds: 1_000_000)
                }
                client?.urlProtocolDidFinishLoading(self)
            }
        }
    }

    override func stopLoading() {
        streamTask?.cancel()
        streamTask = nil
    }

    static func reset() {
        handler = nil
        lastRequest = nil
    }
}
#endif

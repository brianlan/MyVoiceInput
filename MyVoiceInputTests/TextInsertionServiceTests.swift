#if canImport(XCTest)
import XCTest
@testable import MyVoiceInput

final class TextInsertionServiceTests: XCTestCase {
    func testInsertTextRestoresClipboardWhenChangeCountUnchanged() async throws {
        let harness = TextInsertionTestHarness()
        harness.snapshot = ClipboardSnapshot(items: [["public.utf8-plain-text": Data("before".utf8)]], changeCount: 3)
        harness.writeChangeCount = 4
        harness.currentChangeCount = 4

        let service = TextInsertionService(dependencies: harness.makeDependencies())
        try await service.insertText("hello")

        XCTAssertEqual(harness.writtenTexts, ["hello"])
        XCTAssertEqual(harness.postPasteCallCount, 1)
        XCTAssertEqual(harness.restoredSnapshots, [harness.snapshot])
        XCTAssertEqual(harness.sleepDurations, [150_000_000])
    }

    func testInsertTextDoesNotRestoreClipboardWhenChangeCountChanges() async throws {
        let harness = TextInsertionTestHarness()
        harness.snapshot = ClipboardSnapshot(items: [["public.utf8-plain-text": Data("before".utf8)]], changeCount: 8)
        harness.writeChangeCount = 9
        harness.currentChangeCount = 10

        let service = TextInsertionService(dependencies: harness.makeDependencies())
        try await service.insertText("hello")

        XCTAssertEqual(harness.writtenTexts, ["hello"])
        XCTAssertTrue(harness.restoredSnapshots.isEmpty)
    }

    func testInsertTextThrowsWhenAccessibilityPermissionMissing() async {
        let harness = TextInsertionTestHarness()
        harness.hasAccessibilityPermission = false

        let service = TextInsertionService(dependencies: harness.makeDependencies())

        do {
            try await service.insertText("hello")
            XCTFail("Expected accessibility permission failure")
        } catch let error as TextInsertionServiceError {
            XCTAssertEqual(error, .accessibilityPermissionDenied)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertTrue(harness.writtenTexts.isEmpty)
        XCTAssertEqual(harness.postPasteCallCount, 0)
    }

    func testInsertTextRestoresClipboardAndThrowsWhenPasteEventPostingFails() async {
        let harness = TextInsertionTestHarness()
        harness.snapshot = ClipboardSnapshot(items: [["public.utf8-plain-text": Data("before".utf8)]], changeCount: 1)
        harness.postPasteResult = false

        let service = TextInsertionService(dependencies: harness.makeDependencies())

        do {
            try await service.insertText("hello")
            XCTFail("Expected paste posting failure")
        } catch let error as TextInsertionServiceError {
            XCTAssertEqual(error, .unableToPostPasteCommand)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(harness.restoredSnapshots, [harness.snapshot])
        XCTAssertTrue(harness.sleepDurations.isEmpty)
    }

    func testInsertTextStreamInsertsChunksWithInterChunkDelay() async throws {
        let harness = TextInsertionTestHarness()
        harness.snapshot = ClipboardSnapshot(items: [["public.utf8-plain-text": Data("before".utf8)]], changeCount: 2)
        harness.writeChangeCount = 7
        harness.currentChangeCount = 7

        let service = TextInsertionService(dependencies: harness.makeDependencies())
        let stream = AsyncStream<String> { continuation in
            continuation.yield("a")
            continuation.yield("b")
            continuation.yield("c")
            continuation.finish()
        }

        try await service.insertTextStream(stream)

        XCTAssertEqual(harness.writtenTexts, ["a", "b", "c"])
        XCTAssertEqual(harness.postPasteCallCount, 3)
        XCTAssertEqual(harness.sleepDurations.filter { $0 == 50_000_000 }.count, 2)
        XCTAssertEqual(harness.sleepDurations.filter { $0 == 150_000_000 }.count, 3)
    }
}

private final class TextInsertionTestHarness: @unchecked Sendable {
    private let lock = NSLock()

    var hasAccessibilityPermission = true
    var snapshot = ClipboardSnapshot(items: [], changeCount: 0)
    var writeChangeCount = 1
    var currentChangeCount = 1
    var postPasteResult = true

    private(set) var writtenTexts: [String] = []
    private(set) var restoredSnapshots: [ClipboardSnapshot] = []
    private(set) var sleepDurations: [UInt64] = []
    private(set) var postPasteCallCount = 0

    func makeDependencies() -> TextInsertionServiceDependencies {
        TextInsertionServiceDependencies(
            hasAccessibilityPermission: { [weak self] in
                self?.withLock { self?.hasAccessibilityPermission ?? false } ?? false
            },
            snapshotClipboard: { [weak self] in
                self?.withLock { self?.snapshot ?? ClipboardSnapshot(items: [], changeCount: 0) } ?? ClipboardSnapshot(items: [], changeCount: 0)
            },
            writeClipboardText: { [weak self] text in
                self?.withLock {
                    self?.writtenTexts.append(text)
                    return self?.writeChangeCount ?? 0
                } ?? 0
            },
            currentClipboardChangeCount: { [weak self] in
                self?.withLock { self?.currentChangeCount ?? 0 } ?? 0
            },
            restoreClipboard: { [weak self] snapshot in
                self?.withLock {
                    self?.restoredSnapshots.append(snapshot)
                }
            },
            postPasteCommand: { [weak self] in
                self?.withLock {
                    self?.postPasteCallCount += 1
                    return self?.postPasteResult ?? false
                } ?? false
            },
            sleep: { [weak self] nanoseconds in
                self?.withLock {
                    self?.sleepDurations.append(nanoseconds)
                }
            }
        )
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
#endif

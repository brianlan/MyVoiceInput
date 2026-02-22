#if canImport(XCTest) && canImport(KeyboardShortcuts)
import XCTest
import KeyboardShortcuts
@testable import MyVoiceInput

final class HotkeyManagerTests: XCTestCase {
    func testKeyDownTriggersRecordingStart() {
        let mockClient = MockShortcutsClient()
        let manager = HotkeyManager(shortcutsClient: mockClient.client)
        var startCount = 0

        manager.onRecordingStart = {
            startCount += 1
        }

        mockClient.triggerKeyDown()

        XCTAssertEqual(startCount, 1)
    }

    func testRepeatedKeyDownTriggersStartOnlyOnceWhileHeld() {
        let mockClient = MockShortcutsClient()
        let manager = HotkeyManager(shortcutsClient: mockClient.client)
        var startCount = 0

        manager.onRecordingStart = {
            startCount += 1
        }

        mockClient.triggerKeyDown()
        mockClient.triggerKeyDown()
        mockClient.triggerKeyDown()

        XCTAssertEqual(startCount, 1)
    }

    func testKeyUpTriggersStopOnlyAfterStart() {
        let mockClient = MockShortcutsClient()
        let manager = HotkeyManager(shortcutsClient: mockClient.client)
        var stopCount = 0

        manager.onRecordingStop = {
            stopCount += 1
        }

        mockClient.triggerKeyUp()
        XCTAssertEqual(stopCount, 0)

        mockClient.triggerKeyDown()
        mockClient.triggerKeyUp()
        XCTAssertEqual(stopCount, 1)
    }

    func testShortcutNameIsStableAndShortcutLookupOccursOnInit() {
        XCTAssertEqual(KeyboardShortcuts.Name.holdToTalk, KeyboardShortcuts.Name("holdToTalk"))

        let mockClient = MockShortcutsClient()
        _ = HotkeyManager(shortcutsClient: mockClient.client)

        XCTAssertEqual(mockClient.getShortcutCallCount, 1)
        XCTAssertEqual(mockClient.requestedNames, [.holdToTalk])
    }
}

private final class MockShortcutsClient {
    private var keyDownHandler: (() -> Void)?
    private var keyUpHandler: (() -> Void)?

    var getShortcutCallCount = 0
    var requestedNames: [KeyboardShortcuts.Name] = []

    lazy var client = HotkeyKeyboardShortcutsClient(
        onKeyDown: { [weak self] _, handler in
            self?.keyDownHandler = handler
        },
        onKeyUp: { [weak self] _, handler in
            self?.keyUpHandler = handler
        },
        getShortcut: { [weak self] name in
            self?.getShortcutCallCount += 1
            self?.requestedNames.append(name)
            return nil
        }
    )

    func triggerKeyDown() {
        keyDownHandler?()
    }

    func triggerKeyUp() {
        keyUpHandler?()
    }
}
#endif

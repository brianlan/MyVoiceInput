#if canImport(KeyboardShortcuts)
import Foundation
import KeyboardShortcuts

struct HotkeyKeyboardShortcutsClient {
    var onKeyDown: (KeyboardShortcuts.Name, @escaping () -> Void) -> Void
    var onKeyUp: (KeyboardShortcuts.Name, @escaping () -> Void) -> Void
    var getShortcut: (KeyboardShortcuts.Name) -> KeyboardShortcuts.Shortcut?

    static let live = Self(
        onKeyDown: { name, handler in
            KeyboardShortcuts.onKeyDown(for: name, action: handler)
        },
        onKeyUp: { name, handler in
            KeyboardShortcuts.onKeyUp(for: name, action: handler)
        },
        getShortcut: { name in
            KeyboardShortcuts.getShortcut(for: name)
        }
    )
}

final class HotkeyManager {
    var onRecordingStart: (() -> Void)?
    var onRecordingStop: (() -> Void)?

    private let shortcutsClient: HotkeyKeyboardShortcutsClient
    private var isShortcutHeld = false

    init(shortcutsClient: HotkeyKeyboardShortcutsClient = .live) {
        self.shortcutsClient = shortcutsClient
        registerHandlers()
        _ = shortcutsClient.getShortcut(.holdToTalk)
    }

    private func registerHandlers() {
        shortcutsClient.onKeyDown(.holdToTalk) { [weak self] in
            self?.handleKeyDown()
        }

        shortcutsClient.onKeyUp(.holdToTalk) { [weak self] in
            self?.handleKeyUp()
        }
    }

    private func handleKeyDown() {
        guard !isShortcutHeld else {
            return
        }

        isShortcutHeld = true
        onRecordingStart?()
    }

    private func handleKeyUp() {
        guard isShortcutHeld else {
            return
        }

        isShortcutHeld = false
        onRecordingStop?()
    }
}
#endif

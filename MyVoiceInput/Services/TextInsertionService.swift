import Foundation
import AppKit
import ApplicationServices

enum TextInsertionServiceError: Error, Equatable {
    case accessibilityPermissionDenied
    case unableToPostPasteCommand
}

struct ClipboardSnapshot: Equatable, Sendable {
    let items: [[String: Data]]
    let changeCount: Int
}

struct TextInsertionServiceDependencies: Sendable {
    var hasAccessibilityPermission: @Sendable () -> Bool
    var snapshotClipboard: @Sendable () async -> ClipboardSnapshot
    var writeClipboardText: @Sendable (String) async -> Int
    var currentClipboardChangeCount: @Sendable () async -> Int
    var restoreClipboard: @Sendable (ClipboardSnapshot) async -> Void
    var postPasteCommand: @Sendable () -> Bool
    var sleep: @Sendable (UInt64) async -> Void

    static let live = TextInsertionServiceDependencies(
        hasAccessibilityPermission: {
            AXIsProcessTrusted()
        },
        snapshotClipboard: {
            await MainActor.run {
                let pasteboard = NSPasteboard.general
                let items = (pasteboard.pasteboardItems ?? []).map { item in
                    var entry: [String: Data] = [:]
                    for type in item.types {
                        if let data = item.data(forType: type) {
                            entry[type.rawValue] = data
                        }
                    }
                    return entry
                }
                return ClipboardSnapshot(items: items, changeCount: pasteboard.changeCount)
            }
        },
        writeClipboardText: { text in
            await MainActor.run {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
                return pasteboard.changeCount
            }
        },
        currentClipboardChangeCount: {
            await MainActor.run {
                NSPasteboard.general.changeCount
            }
        },
        restoreClipboard: { snapshot in
            await MainActor.run {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()

                guard !snapshot.items.isEmpty else {
                    return
                }

                let restoredItems = snapshot.items.map { dataByType -> NSPasteboardItem in
                    let item = NSPasteboardItem()
                    for (rawType, data) in dataByType {
                        item.setData(data, forType: NSPasteboard.PasteboardType(rawType))
                    }
                    return item
                }

                pasteboard.writeObjects(restoredItems)
            }
        },
        postPasteCommand: {
            guard
                let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true),
                let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false)
            else {
                return false
            }

            keyDown.flags = .maskCommand
            keyUp.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
            return true
        },
        sleep: { nanoseconds in
            try? await Task.sleep(nanoseconds: nanoseconds)
        }
    )
}

final class TextInsertionService: TextInsertionServiceProtocol, @unchecked Sendable {
    private enum Timing {
        static let restoreDelayNanoseconds: UInt64 = 150_000_000
        static let streamChunkDelayNanoseconds: UInt64 = 50_000_000
    }

    private let dependencies: TextInsertionServiceDependencies

    init(dependencies: TextInsertionServiceDependencies = .live) {
        self.dependencies = dependencies
    }

    func insertText(_ text: String) async throws {
        guard dependencies.hasAccessibilityPermission() else {
            throw TextInsertionServiceError.accessibilityPermissionDenied
        }

        let snapshot = await dependencies.snapshotClipboard()
        let injectedChangeCount = await dependencies.writeClipboardText(text)

        guard dependencies.postPasteCommand() else {
            await dependencies.restoreClipboard(snapshot)
            throw TextInsertionServiceError.unableToPostPasteCommand
        }

        await dependencies.sleep(Timing.restoreDelayNanoseconds)

        let currentChangeCount = await dependencies.currentClipboardChangeCount()
        if currentChangeCount == injectedChangeCount {
            await dependencies.restoreClipboard(snapshot)
        }
    }

    func insertTextStream(_ stream: AsyncStream<String>) async throws {
        var isFirstChunk = true
        for await chunk in stream {
            if !isFirstChunk {
                await dependencies.sleep(Timing.streamChunkDelayNanoseconds)
            }

            try await insertText(chunk)
            isFirstChunk = false
        }
    }
}

import AppKit
import SwiftUI

final class RecordingIndicatorWindow: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.ignoresMouseEvents = true
        
        let hostingView = NSHostingView(rootView: RecordingIndicatorView())
        self.contentView = hostingView
    }
    
    // Ensure we don't become key
    override var canBecomeKey: Bool {
        return false
    }
    
    override var canBecomeMain: Bool {
        return false
    }
}

@MainActor
final class RecordingIndicatorWindowController: ObservableObject {
    private let window: RecordingIndicatorWindow
    
    init() {
        self.window = RecordingIndicatorWindow()
    }
    
    func show() {
        updatePositionNearCursor()
        window.orderFrontRegardless()
    }
    
    func hide() {
        window.orderOut(nil)
    }
    
    private func updatePositionNearCursor() {
        let mouseLocation = NSEvent.mouseLocation
        
        // Calculate size based on content
        // We can force a layout pass or rely on the hosting view to have sized itself
        if let view = window.contentView {
            view.layoutSubtreeIfNeeded()
        }
        
        let windowSize = window.frame.size
        // Default offset: 24 points below and 24 points to the right of cursor
        var newOrigin = CGPoint(x: mouseLocation.x + 24, y: mouseLocation.y - windowSize.height - 24)
        
        // Ensure it stays on screen (basic check)
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            
            // Check right edge
            if newOrigin.x + windowSize.width > screenFrame.maxX {
                newOrigin.x = mouseLocation.x - windowSize.width - 24
            }
            
            // Check bottom edge
            if newOrigin.y < screenFrame.minY {
                newOrigin.y = mouseLocation.y + 24
            }
        }
        
        window.setFrameOrigin(newOrigin)
    }
}

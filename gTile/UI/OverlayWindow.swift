import AppKit
import SwiftUI

/// NSPanel subclass that provides a non-activating, floating overlay window.
final class OverlayWindow: NSPanel {
    /// Called when the user presses Escape.
    var onEscape: (() -> Void)?
    /// Called when the user presses an arrow key. Direction: 0=left, 1=right, 2=down, 3=up. Modifiers: option, shift.
    var onArrowKey: ((_ direction: Int, _ option: Bool, _ shift: Bool) -> Void)?
    /// Called when the user presses Enter/Return.
    var onEnter: (() -> Void)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.isReleasedWhenClosed = false
        self.isMovableByWindowBackground = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        let mods = event.modifierFlags
        let opt = mods.contains(.option)
        let shift = mods.contains(.shift)
        switch event.keyCode {
        case 53: onEscape?()
        case 123: onArrowKey?(0, opt, shift)
        case 124: onArrowKey?(1, opt, shift)
        case 125: onArrowKey?(2, opt, shift)
        case 126: onArrowKey?(3, opt, shift)
        case 36, 76: onEnter?()
        default: super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}

/// Creates and manages an overlay window with SwiftUI content.
final class OverlayWindowController {
    let window: OverlayWindow
    private let hostingView: NSHostingView<AnyView>

    init<Content: View>(content: Content, frame: NSRect = NSRect(x: 0, y: 0, width: 300, height: 250)) {
        let window = OverlayWindow(contentRect: frame)
        self.window = window

        let hostingView = NSHostingView(rootView: AnyView(content))
        hostingView.frame = window.contentView?.bounds ?? frame
        hostingView.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(hostingView)
        self.hostingView = hostingView
    }

    func show() {
        window.orderFrontRegardless()
    }

    func hide() {
        window.orderOut(nil)
    }

    var isVisible: Bool {
        window.isVisible
    }

    func placeAt(x: Double, y: Double) {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let nsY = primaryHeight - y - Double(window.frame.height)
        window.setFrameOrigin(NSPoint(x: x, y: nsY))
    }

    func updateContent<Content: View>(_ content: Content) {
        hostingView.rootView = AnyView(content)
    }
}

import AppKit

/// Semi-transparent NSPanel that shows a preview of where the window will be placed.
///
/// This is the macOS equivalent of mTile's Preview UI component.
final class PreviewWindow: NSPanel {
    private let previewView: NSView
    private let animateTransitions = false

    init() {
        let initialFrame = NSRect(x: 0, y: 0, width: 100, height: 100)
        self.previewView = NSView(frame: initialFrame)

        super.init(
            contentRect: initialFrame,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.isReleasedWhenClosed = false
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        // Configure preview appearance
        previewView.wantsLayer = true
        previewView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
        previewView.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.5).cgColor
        previewView.layer?.borderWidth = 2
        previewView.layer?.cornerRadius = 8

        contentView = previewView
    }

    /// Sets the preview area in AX coordinates (top-left origin).
    /// Pass nil to hide the preview.
    var previewArea: Rectangle? {
        didSet {
            if previewArea == oldValue { return }

            if let area = previewArea {
                let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
                let nsY = primaryHeight - area.y - area.height

                let frame = NSRect(
                    x: area.x, y: nsY,
                    width: area.width, height: area.height
                )

                // Avoid unnecessary frame work when the requested frame is
                // effectively unchanged (e.g., repeated key presses at bounds).
                if !framesApproximatelyEqual(self.frame, frame) {
                    setFrame(frame, display: true, animate: animateTransitions)
                }
                if !isVisible {
                    orderFrontRegardless()
                }
            } else {
                if isVisible {
                    orderOut(nil)
                }
            }
        }
    }

    private func framesApproximatelyEqual(
        _ lhs: NSRect,
        _ rhs: NSRect,
        epsilon: CGFloat = 0.5
    ) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) <= epsilon &&
        abs(lhs.origin.y - rhs.origin.y) <= epsilon &&
        abs(lhs.size.width - rhs.size.width) <= epsilon &&
        abs(lhs.size.height - rhs.size.height) <= epsilon
    }
}

import AppKit

/// Abstraction that represents monitor settings, analogous to mTile's Screen type.
struct Screen {
    let index: Int
    let scale: CGFloat
    let resolution: Rectangle
    let workArea: Rectangle
}

/// Multi-monitor abstraction wrapping NSScreen.
///
/// macOS uses a bottom-left origin coordinate system for NSScreen,
/// but the Accessibility API uses top-left origin. This service handles
/// the conversion.
///
/// All conversions pivot on the height of the *origin screen* (the display
/// whose Cocoa origin is (0,0), i.e. the one carrying the menu bar). The origin
/// screen is resolved explicitly rather than assuming `NSScreen.screens.first`,
/// so conversions stay correct regardless of the order macOS returns screens in
/// and for arrangements that place a monitor above the primary (which produce
/// legitimately negative AX Y coordinates).
final class DisplayService {

    /// Returns the list of connected monitors with their work areas.
    /// Work areas are returned in Accessibility API coordinates (top-left origin).
    var monitors: [Screen] {
        NSScreen.screens.enumerated().map { (index, screen) in
            let resolution = DisplayService.screenFrameInAXCoordinates(screen)
            let workArea = DisplayService.visibleFrameInAXCoordinates(screen)

            return Screen(
                index: index,
                scale: screen.backingScaleFactor,
                resolution: resolution,
                workArea: workArea
            )
        }
    }

    /// Returns the index (within `NSScreen.screens`) of the origin/primary
    /// monitor, i.e. the display whose Cocoa origin is (0,0).
    var primaryMonitorIndex: Int {
        DisplayService.originScreenIndex()
    }

    /// The current mouse pointer location in AX coordinates.
    var pointerLocation: CGPoint {
        DisplayService.axPoint(fromCocoa: NSEvent.mouseLocation)
    }

    /// The monitor index that the pointer resides on.
    var pointerMonitorIndex: Int {
        let point = pointerLocation
        let screens = NSScreen.screens

        // Half-open containment so a pointer exactly on a shared seam between two
        // monitors is attributed to a single screen rather than the first match.
        for (index, screen) in screens.enumerated() {
            let frame = DisplayService.screenFrameInAXCoordinates(screen)
            if point.x >= frame.x && point.x < frame.x + frame.width &&
               point.y >= frame.y && point.y < frame.y + frame.height {
                return index
            }
        }

        // No exact hit (e.g. pointer on an outer edge): pick the nearest screen
        // center instead of blindly defaulting to the primary.
        return DisplayService.nearestScreenIndex(to: point, screens: screens)
    }

    // MARK: - Coordinate Conversion (single source of truth)

    /// The origin screen: the display whose Cocoa origin is (0,0). Falls back to
    /// the first screen if none reports a zero origin (should not happen).
    static func originScreen() -> NSScreen? {
        NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.screens.first
    }

    /// Index of `originScreen()` within `NSScreen.screens` (0 if unavailable).
    static func originScreenIndex() -> Int {
        NSScreen.screens.firstIndex { $0.frame.origin == .zero } ?? 0
    }

    /// The pivot height used for every NS <-> AX flip: the origin screen's height.
    static func primaryHeight() -> CGFloat {
        originScreen()?.frame.height ?? 0
    }

    /// Converts an NSScreen frame to AX coordinates (top-left origin).
    static func screenFrameInAXCoordinates(_ screen: NSScreen) -> Rectangle {
        axRect(fromCocoa: screen.frame, primaryHeight: primaryHeight())
    }

    /// Converts an NSScreen's visible frame to AX coordinates (top-left origin).
    static func visibleFrameInAXCoordinates(_ screen: NSScreen) -> Rectangle {
        axRect(fromCocoa: screen.visibleFrame, primaryHeight: primaryHeight())
    }

    /// Converts an NSPoint (bottom-left origin) to AX coordinates (top-left origin).
    static func axPoint(fromCocoa point: NSPoint) -> CGPoint {
        axPoint(fromCocoa: point, primaryHeight: primaryHeight())
    }

    /// Converts an AX top edge back to a Cocoa (bottom-left origin) frame origin Y.
    static func cocoaOriginY(axY: Double, height: Double) -> CGFloat {
        cocoaOriginY(axY: axY, height: height, primaryHeight: primaryHeight())
    }

    // MARK: - Pure conversion math (testable, no NSScreen dependency)

    /// Forward flip of a Cocoa rect into AX space given the pivot height.
    static func axRect(fromCocoa frame: CGRect, primaryHeight: CGFloat) -> Rectangle {
        Rectangle(
            x: Double(frame.origin.x),
            y: Double(primaryHeight - frame.origin.y - frame.height),
            width: Double(frame.width),
            height: Double(frame.height)
        )
    }

    /// Forward flip of a Cocoa point into AX space given the pivot height.
    static func axPoint(fromCocoa point: NSPoint, primaryHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    /// Inverse flip: AX top edge -> Cocoa frame-origin Y given the pivot height.
    static func cocoaOriginY(axY: Double, height: Double, primaryHeight: CGFloat) -> CGFloat {
        primaryHeight - CGFloat(axY) - CGFloat(height)
    }

    // MARK: - Diagnostics

    /// Logs the current display configuration to stdout. Useful for diagnosing
    /// multi-monitor coordinate issues (e.g. a monitor placed above the primary,
    /// which produces negative AX Y coordinates).
    func logDisplayConfiguration(_ context: String) {
        let screens = NSScreen.screens
        let originIdx = DisplayService.originScreenIndex()
        print("mTile: display config (\(context)) — \(screens.count) screen(s), primaryHeight=\(DisplayService.primaryHeight()), originScreenIndex=\(originIdx)")
        for (index, screen) in screens.enumerated() {
            let cocoa = screen.frame
            let ax = DisplayService.screenFrameInAXCoordinates(screen)
            let isOrigin = index == originIdx ? " [origin]" : ""
            print("mTile:   screen[\(index)]\(isOrigin) cocoaFrame=\(cocoa) axRect=(x:\(ax.x), y:\(ax.y), w:\(ax.width), h:\(ax.height))")
        }
    }

    /// Index of the screen whose center is nearest to the given AX point.
    static func nearestScreenIndex(to point: CGPoint, screens: [NSScreen]) -> Int {
        nearestIndex(to: point, rects: screens.map { screenFrameInAXCoordinates($0) })
    }

    // MARK: - Pure monitor-attribution math (testable, no NSScreen dependency)

    /// Chooses the monitor a frame belongs to from precomputed AX screen rects:
    /// the screen with the largest overlap area, falling back to the screen
    /// nearest the frame's center when there is no overlap at all.
    static func monitorIndex(forFrame frame: Rectangle, screenRects: [Rectangle]) -> Int {
        guard !screenRects.isEmpty else { return 0 }

        var bestIndex = 0
        var bestArea = 0.0
        for (index, rect) in screenRects.enumerated() {
            if let overlap = frame.intersection(rect), overlap.area > bestArea {
                bestArea = overlap.area
                bestIndex = index
            }
        }

        if bestArea == 0 {
            let center = CGPoint(x: frame.x + frame.width / 2, y: frame.y + frame.height / 2)
            return nearestIndex(to: center, rects: screenRects)
        }

        return bestIndex
    }

    /// Index of the rect whose center is nearest (squared distance) to the point.
    static func nearestIndex(to point: CGPoint, rects: [Rectangle]) -> Int {
        guard !rects.isEmpty else { return 0 }
        var bestIndex = 0
        var bestDistance = Double.infinity
        for (index, rect) in rects.enumerated() {
            let cx = rect.x + rect.width / 2
            let cy = rect.y + rect.height / 2
            let dx = Double(point.x) - cx
            let dy = Double(point.y) - cy
            let distance = dx * dx + dy * dy
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        return bestIndex
    }
}

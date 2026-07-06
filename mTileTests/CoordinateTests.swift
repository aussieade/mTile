import XCTest
import AppKit
@testable import mTile

/// Tests for the NS <-> AX coordinate conversion and monitor attribution.
///
/// These exercise the pure math (which takes an explicit `primaryHeight` / screen
/// rects) so they run without real `NSScreen` hardware. The scenario of interest
/// is a second monitor placed *above* the primary, which is the only arrangement
/// that produces negative AX Y coordinates.
final class CoordinateTests: XCTestCase {

    // Primary display: 1920x1080 at Cocoa origin (0,0). Pivot height = 1080.
    private let primaryHeight: CGFloat = 1080

    // MARK: - Forward flip (Cocoa -> AX)

    func testPrimaryScreenIsZeroBasedInAX() {
        let cocoa = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let ax = DisplayService.axRect(fromCocoa: cocoa, primaryHeight: primaryHeight)

        XCTAssertEqual(ax.x, 0)
        XCTAssertEqual(ax.y, 0)
        XCTAssertEqual(ax.width, 1920)
        XCTAssertEqual(ax.height, 1080)
    }

    func testMonitorAboveProducesNegativeAXY() {
        // A second 1920x1080 monitor stacked above the primary sits at Cocoa
        // origin (0, 1080) and must map to AX Y range [-1080, 0].
        let cocoa = CGRect(x: 0, y: 1080, width: 1920, height: 1080)
        let ax = DisplayService.axRect(fromCocoa: cocoa, primaryHeight: primaryHeight)

        XCTAssertEqual(ax.y, -1080)
        XCTAssertEqual(ax.y + ax.height, 0)
    }

    func testMonitorAboveWithDifferentHeight() {
        // Unequal heights: 2560x1440 above a 1920x1080 primary.
        let cocoa = CGRect(x: 0, y: 1080, width: 2560, height: 1440)
        let ax = DisplayService.axRect(fromCocoa: cocoa, primaryHeight: primaryHeight)

        XCTAssertEqual(ax.y, -1440) // primaryHeight - 1080 - 1440
        XCTAssertEqual(ax.y + ax.height, 0)
    }

    // MARK: - Round trips

    func testPointRoundTripIsIdentity() {
        for cocoaY in [0.0, 500.0, 1080.0, 1600.0, 2160.0] {
            let point = NSPoint(x: 42, y: cocoaY)
            let ax = DisplayService.axPoint(fromCocoa: point, primaryHeight: primaryHeight)
            // Inverse of a point is cocoaOriginY with height 0.
            let back = DisplayService.cocoaOriginY(axY: Double(ax.y), height: 0, primaryHeight: primaryHeight)
            XCTAssertEqual(Double(back), cocoaY, accuracy: 0.0001)
        }
    }

    func testRectRoundTripIsIdentity() {
        // Includes the above-monitor rect with negative AX Y.
        let rects = [
            CGRect(x: 0, y: 0, width: 1920, height: 1080),
            CGRect(x: 0, y: 1080, width: 1920, height: 1080),
            CGRect(x: 300, y: 400, width: 640, height: 480),
        ]
        for cocoa in rects {
            let ax = DisplayService.axRect(fromCocoa: cocoa, primaryHeight: primaryHeight)
            let backOriginY = DisplayService.cocoaOriginY(
                axY: ax.y, height: ax.height, primaryHeight: primaryHeight)
            XCTAssertEqual(Double(backOriginY), Double(cocoa.origin.y), accuracy: 0.0001)
        }
    }

    // MARK: - Monitor attribution

    // AX rects for a primary with a monitor stacked above it.
    private var primaryAX: Rectangle { Rectangle(x: 0, y: 0, width: 1920, height: 1080) }
    private var aboveAX: Rectangle { Rectangle(x: 0, y: -1080, width: 1920, height: 1080) }

    func testAttributionWindowFullyOnUpperMonitor() {
        let window = Rectangle(x: 100, y: -1000, width: 400, height: 300)
        let index = DisplayService.monitorIndex(
            forFrame: window, screenRects: [primaryAX, aboveAX])
        XCTAssertEqual(index, 1) // upper monitor
    }

    func testAttributionWindowFullyOnPrimary() {
        let window = Rectangle(x: 100, y: 200, width: 400, height: 300)
        let index = DisplayService.monitorIndex(
            forFrame: window, screenRects: [primaryAX, aboveAX])
        XCTAssertEqual(index, 0)
    }

    func testAttributionStraddlingSeamPicksLargerOverlap() {
        // Window spans AX Y [-100, 200]: 100px on the upper screen, 200px on the
        // primary. Larger overlap is the primary.
        let window = Rectangle(x: 100, y: -100, width: 400, height: 300)
        let index = DisplayService.monitorIndex(
            forFrame: window, screenRects: [primaryAX, aboveAX])
        XCTAssertEqual(index, 0)
    }

    func testAttributionOffscreenFallsBackToNearest() {
        // Fully above the upper monitor (no overlap with either screen).
        let window = Rectangle(x: 100, y: -2000, width: 200, height: 200)
        let index = DisplayService.monitorIndex(
            forFrame: window, screenRects: [primaryAX, aboveAX])
        XCTAssertEqual(index, 1) // nearest is the upper monitor
    }
}

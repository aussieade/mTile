import AppKit
import Combine
import SwiftUI

/// Events emitted by the overlay system.
enum OverlayEvent {
    case selection(monitorIdx: Int, gridSize: GridSize, selection: GridSelection)
    case visibility(visible: Bool)
}

/// Responsible for rendering the mTile overlay on each connected monitor.
///
/// Port of OverlayManager.ts.
final class OverlayController {
    private let windowManager: WindowManager
    private let preferences: UserPreferences
    private let previewWindow: PreviewWindow

    private var overlays: [OverlayWindowController] = []
    private var overlayStates: [OverlayState] = []
    private var interactionStates: [GridInteractionState] = []
    private var callbacks: [(OverlayEvent) -> Void] = []
    private var syncInProgress = false

    private(set) var activeMonitorIndex: Int?
    private(set) var presets: [GridSize]
    private(set) var gridSize: GridSize
    private var presetIndex: Int = 0

    var isVisible: Bool {
        overlays.contains { $0.isVisible }
    }

    /// The window that was focused before the overlay was shown.
    /// This is the actual target for window operations.
    private(set) var targetWindow: AXUIElement?
    /// PID of the target window's app, used for re-acquisition if AXUIElement becomes stale.
    private(set) var targetWindowPID: pid_t = 0

    struct OverlayState {
        var selection: GridSelection?
        // hoverTile is now tracked in GridInteractionState (@Published)
        var monitorIndex: Int
    }

    init(windowManager: WindowManager, preferences: UserPreferences) {
        self.windowManager = windowManager
        self.preferences = preferences
        self.previewWindow = PreviewWindow()

        let gridSizeConf = preferences.gridSizes
        let parsedPresets = GridSizeListParser(input: gridSizeConf).parse() ?? []
        self.presets = parsedPresets.isEmpty ? DefaultGridSizes : parsedPresets
        self.gridSize = self.presets.first ?? DefaultGridSizes[0]

        renderOverlays()
    }

    /// Returns the target window, re-acquiring from the stored PID if the
    /// original AXUIElement reference has become stale.
    func validatedTargetWindow() -> AXUIElement? {
        if let tw = targetWindow,
           windowManager.accessibilityService.windowFrame(tw) != nil {
            return tw
        }

        // Re-acquire from the same app
        if targetWindowPID != 0 {
            let appElement = AXUIElementCreateApplication(targetWindowPID)
            var focusedWindow: AnyObject?
            if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success {
                let reacquired = focusedWindow as! AXUIElement
                targetWindow = reacquired
                return reacquired
            }
        }

        return nil
    }

    // MARK: - Public Interface

    func subscribe(_ callback: @escaping (OverlayEvent) -> Void) {
        callbacks.append(callback)
    }

    func toggleOverlays(hide: Bool? = nil) {
        let currentlyVisible = overlays.contains { $0.isVisible }
        let shouldHide = hide ?? currentlyVisible

        if shouldHide {
            syncInProgress = true
            overlays.forEach { $0.hide() }
            previewWindow.previewArea = nil
            syncInProgress = false
            // Clear selections and anchors
            for i in 0..<overlayStates.count {
                overlayStates[i].selection = nil
                interactionStates[safe: i]?.hoverTile = nil
            }
            for state in interactionStates {
                state.anchor = nil
                state.keyboardCursor = nil
            }
            targetWindow = nil
            targetWindowPID = 0
            dispatch(.visibility(visible: false))
            return
        }

        guard !overlays.isEmpty else { return }

        // Capture the focused window BEFORE showing overlay (which steals focus).
        // Use focusedWindowExcludingSelf to avoid capturing our own overlay panel.
        targetWindow = windowManager.accessibilityService.focusedWindowExcludingSelf()
        if let tw = targetWindow {
            targetWindowPID = windowManager.accessibilityService.windowPID(tw)
            let title = windowManager.accessibilityService.windowTitle(tw) ?? "<no title>"
            print("mTile: captured targetWindow: '\(title)' PID=\(targetWindowPID)")
        } else {
            targetWindowPID = 0
            print("mTile: WARNING - no target window captured!")
            // Debug: what does frontmostApplication report?
            if let app = NSWorkspace.shared.frontmostApplication {
                print("mTile:   frontmostApp='\(app.localizedName ?? "?")' pid=\(app.processIdentifier) myPID=\(ProcessInfo.processInfo.processIdentifier)")
            }
        }

        placeOverlays()

        syncInProgress = true
        overlays.forEach { $0.show() }
        // Make the overlay on the target window's monitor key so keyboard input
        // (arrows/Enter) and the preview appear on the monitor the user is on.
        let keyIndex = targetWindow.map {
            windowManager.accessibilityService.windowMonitorIndex($0)
        } ?? windowManager.pointerMonitorIndex
        if keyIndex < overlays.count {
            overlays[keyIndex].window.makeKey()
        } else {
            overlays.first?.window.makeKey()
        }
        syncInProgress = false
        dispatch(.visibility(visible: true))
    }

    func setSelection(_ selection: GridSelection?, monitorIdx: Int) {
        guard monitorIdx < overlayStates.count else { return }

        // Keep activeMonitorIndex correct even when the selection value is
        // unchanged, so a subsequent .confirm reads the right monitor's
        // selection instead of a stale index.
        if selection != nil {
            activeMonitorIndex = monitorIdx
        }

        // Avoid rebuilding overlay content when nothing semantically changed.
        if overlayStates[monitorIdx].selection == selection {
            return
        }

        overlayStates[monitorIdx].selection = selection

        if let selection = selection {
            let area = windowManager.selectionToArea(
                selection, gridSize: gridSize, monitorIdx: monitorIdx, preview: true)
            previewWindow.previewArea = area
        } else {
            activeMonitorIndex = nil
            previewWindow.previewArea = nil
        }

        refreshOverlay(at: monitorIdx)
    }

    func getSelection(_ monitorIdx: Int) -> GridSelection? {
        guard monitorIdx < overlayStates.count else { return nil }
        return overlayStates[monitorIdx].selection
    }

    func iteratePreset() {
        guard !presets.isEmpty else { return }

        presetIndex = (presetIndex + 1) % presets.count
        gridSize = presets[presetIndex]

        for i in 0..<overlayStates.count {
            overlayStates[i].selection = nil
        }
        for state in interactionStates {
            state.anchor = nil
        }
        refreshAllOverlays()
    }

    func updatePresets(_ newPresets: [GridSize]) {
        presets = newPresets.isEmpty ? DefaultGridSizes : newPresets
        presetIndex = 0
        if let first = presets.first {
            gridSize = first
        }
        refreshAllOverlays()
    }

    // MARK: - Private Methods

    private func dispatch(_ event: OverlayEvent) {
        for callback in callbacks {
            callback(event)
        }
    }

    private func renderOverlays() {
        destroyOverlays()

        let monitors = windowManager.monitors
        for (index, _) in monitors.enumerated() {
            overlayStates.append(OverlayState(monitorIndex: index))
            let interactionState = GridInteractionState()
            interactionStates.append(interactionState)

            let controller = OverlayWindowController(
                content: makeOverlayView(for: index, interactionState: interactionState),
                frame: NSRect(x: 0, y: 0, width: 300, height: 280)
            )

            // Wire Escape key
            controller.window.onEscape = { [weak self] in
                self?.toggleOverlays(hide: true)
            }

            // Wire arrow keys for keyboard navigation
            controller.window.onArrowKey = { [weak self, weak interactionState] direction, optionHeld, shiftHeld in
                guard let self = self, let state = interactionState else { return }
                let maxCol = self.gridSize.cols - 1
                let maxRow = self.gridSize.rows - 1

                // Compute delta from direction
                var dCol = 0, dRow = 0
                switch direction {
                case 0: dCol = -1  // Left
                case 1: dCol = 1   // Right
                case 2: dRow = 1   // Down
                case 3: dRow = -1  // Up
                default: break
                }

                if optionHeld, let anchor = state.anchor {
                    // Option+Arrow: shift the entire selection (anchor + cursor),
                    // clamping each side independently so it shrinks at borders.
                    let cur = state.keyboardCursor ?? anchor
                    let newAnchorCol = min(max(anchor.col + dCol, 0), maxCol)
                    let newAnchorRow = min(max(anchor.row + dRow, 0), maxRow)
                    let newCurCol = min(max(cur.col + dCol, 0), maxCol)
                    let newCurRow = min(max(cur.row + dRow, 0), maxRow)

                    if newAnchorCol == anchor.col && newAnchorRow == anchor.row &&
                       newCurCol == cur.col && newCurRow == cur.row { return }

                    state.anchor = GridOffset(col: newAnchorCol, row: newAnchorRow)
                    state.keyboardCursor = GridOffset(col: newCurCol, row: newCurRow)
                } else if shiftHeld {
                    // Shift+Arrow: expand selection from current cursor.
                    // If no anchor yet, plant it at current cursor position first.
                    let cur = state.keyboardCursor ?? self.initialKeyboardCursor(for: index)
                    if state.anchor == nil {
                        state.anchor = cur
                    }
                    let newCol = min(max(cur.col + dCol, 0), maxCol)
                    let newRow = min(max(cur.row + dRow, 0), maxRow)
                    state.keyboardCursor = GridOffset(col: newCol, row: newRow)
                } else {
                    // Plain arrow: move cursor only
                    let cur = state.keyboardCursor ?? self.initialKeyboardCursor(for: index)
                    let newCol = min(max(cur.col + dCol, 0), maxCol)
                    let newRow = min(max(cur.row + dRow, 0), maxRow)
                    state.keyboardCursor = GridOffset(col: newCol, row: newRow)
                }

                // Update preview window
                let cursor = state.keyboardCursor!
                let previewAnchor = state.anchor ?? cursor
                let previewSel = GridSelection(anchor: previewAnchor, target: cursor)
                let area = self.windowManager.selectionToArea(
                    previewSel, gridSize: self.gridSize, monitorIdx: index, preview: true)
                self.previewWindow.previewArea = area
            }

            // Wire Enter key — confirms the current keyboard selection in a
            // single press (README: "Enter to select"). A plain-arrow cursor
            // confirms a single cell; a Shift+Arrow range (anchor set) confirms
            // the range. Enter before any navigation does nothing.
            controller.window.onEnter = { [weak self, weak interactionState] in
                guard let self = self, let state = interactionState else { return }
                // Keyboard cursor takes priority; fall back to mouse hover so a
                // hover-then-Enter also confirms. Nothing selected yet -> no-op.
                guard let cursor = state.keyboardCursor ?? state.hoverTile else { return }
                let anchor = state.anchor ?? cursor
                let selection = GridSelection(anchor: anchor, target: cursor)
                state.anchor = nil
                state.keyboardCursor = nil
                // Set the selection on the overlay state so onUserAction(.confirm) can read it
                self.setSelection(selection, monitorIdx: index)
                self.dispatch(.selection(
                    monitorIdx: index,
                    gridSize: self.gridSize,
                    selection: selection
                ))
            }

            overlays.append(controller)
        }
    }

    private func destroyOverlays() {
        let wasVisible = overlays.contains { $0.isVisible }
        overlays.forEach { $0.hide() }
        overlays.removeAll()
        overlayStates.removeAll()
        interactionStates.removeAll()

        if wasVisible {
            dispatch(.visibility(visible: false))
        }
    }

    private func makeOverlayView(for monitorIdx: Int, interactionState: GridInteractionState) -> OverlayView {
        let selectionBinding = Binding<GridSelection?>(
            get: { [weak self] in self?.overlayStates[safe: monitorIdx]?.selection },
            set: { [weak self] (newValue: GridSelection?) in
                guard let self = self else { return }
                if monitorIdx < self.overlayStates.count {
                    self.overlayStates[monitorIdx].selection = newValue
                }
                if let selection = newValue {
                    self.activeMonitorIndex = monitorIdx
                    let area = self.windowManager.selectionToArea(
                        selection, gridSize: self.gridSize, monitorIdx: monitorIdx, preview: true)
                    self.previewWindow.previewArea = area
                }
            }
        )

        let gridSizeBinding = Binding<GridSize>(
            get: { [weak self] in self?.gridSize ?? DefaultGridSizes[0] },
            set: { [weak self] (newValue: GridSize) in
                self?.gridSize = newValue
                self?.refreshAllOverlays()
            }
        )

        let focusedTitle = windowManager.focusedWindow.flatMap {
            windowManager.accessibilityService.windowTitle($0)
        } ?? "mTile"

        return OverlayView(
            title: focusedTitle,
            presets: presets,
            gridSize: gridSizeBinding,
            selection: selectionBinding,
            interactionState: interactionState,
            onSelectionComplete: { [weak self] selection in
                guard let self = self else { return }
                self.dispatch(.selection(
                    monitorIdx: monitorIdx,
                    gridSize: self.gridSize,
                    selection: selection
                ))
            },
            onHoverChanged: { [weak self] tile in
                guard let self = self else { return }
                if let tile = tile {
                    let previewAnchor = interactionState.anchor ?? tile
                    let previewSel = GridSelection(anchor: previewAnchor, target: tile)
                    let area = self.windowManager.selectionToArea(
                        previewSel, gridSize: self.gridSize, monitorIdx: monitorIdx, preview: true)
                    self.previewWindow.previewArea = area
                } else if interactionState.anchor == nil {
                    self.previewWindow.previewArea = nil
                }
            },
            onClose: { [weak self] in
                self?.toggleOverlays(hide: true)
            }
        )
    }

    private func placeOverlays() {
        let monitors = windowManager.monitors
        let focused = windowManager.focusedWindow

        for (index, monitor) in monitors.enumerated() {
            guard index < overlays.count else { break }

            let overlay = overlays[index]
            let workArea = monitor.workArea
            let overlayWidth = 300.0
            let overlayHeight = 280.0

            if let focused = focused {
                let focusedMonitor = windowManager.accessibilityService.windowMonitorIndex(focused)
                if focusedMonitor == index, let frame = windowManager.accessibilityService.windowFrame(focused) {
                    let anchorX = clamp(
                        frame.x + frame.width / 2 - overlayWidth / 2,
                        min: workArea.x,
                        max: workArea.x + workArea.width - overlayWidth
                    )
                    let anchorY = clamp(
                        frame.y + frame.height / 2 - overlayHeight / 2,
                        min: workArea.y,
                        max: workArea.y + workArea.height - overlayHeight
                    )
                    overlay.placeAt(x: anchorX, y: anchorY)
                    continue
                }
            }

            let centerX = workArea.x + workArea.width / 2 - overlayWidth / 2
            let centerY = workArea.y + workArea.height / 2 - overlayHeight / 2
            overlay.placeAt(x: centerX, y: centerY)
        }
    }

    private func refreshOverlay(at index: Int) {
        guard index < overlays.count, index < interactionStates.count else { return }
        overlays[index].updateContent(makeOverlayView(for: index, interactionState: interactionStates[index]))
    }

    private func refreshAllOverlays() {
        for i in 0..<overlays.count {
            refreshOverlay(at: i)
        }
    }

    /// Matches gTile's "no forced top-left start" behavior by seeding keyboard
    /// actions from the target window's current grid fit (NW corner) when possible.
    private func initialKeyboardCursor(for monitorIdx: Int) -> GridOffset {
        guard let window = validatedTargetWindow(),
              windowManager.accessibilityService.windowMonitorIndex(window) == monitorIdx else {
            return GridOffset(col: 0, row: 0)
        }

        let fit = windowManager.windowToSelection(window, gridSize: gridSize)
        return GridOffset(
            col: min(fit.anchor.col, fit.target.col),
            row: min(fit.anchor.row, fit.target.row)
        )
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

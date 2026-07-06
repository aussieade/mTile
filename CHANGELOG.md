# Changelog

## [Unreleased]

### Fixed
- Multi-monitor tiling when a display is stacked above the primary. Coordinate conversion now
  pivots on the actual origin display (the one at Cocoa origin `(0,0)`) via a single shared
  converter, instead of assuming `NSScreen.screens.first` is primary, so arrangements that
  produce negative AX Y coordinates map correctly.
- Windows on a shared monitor seam are no longer misattributed to the primary display; monitor
  attribution now uses largest-overlap (falling back to nearest screen) rather than a
  center-point test that defaulted to monitor 0.
- Keyboard focus now goes to the grid overlay on the target window's monitor, instead of always
  the primary monitor, so arrow keys and the preview respond on the monitor you are on.
- Enter now confirms the keyboard selection in a single press (matching the documented "Enter
  to select" behaviour) and tiles the window on the correct monitor, instead of requiring two
  presses or silently doing nothing. Overlay key events (Enter, arrows, Escape) are now
  intercepted at the panel's `sendEvent`, so Return reaches the confirm handler instead of being
  swallowed by the SwiftUI content view before it can bubble up.

### Added
- Display-configuration diagnostics logged at startup and on screen changes to aid
  multi-monitor troubleshooting.
- When a tiling action finds no target window, mTile now re-checks the Accessibility grant and,
  if it is missing, logs a clear message and re-prompts, instead of silently doing nothing.
  (Ad-hoc signed rebuilds can leave the Accessibility entry checked while the grant no longer
  applies to the new binary; re-adding the app in System Settings restores it.)

## [v1.6.0] - 2026-03-06

### Added
- Launch-at-login support in Settings (`General -> Launch mTile at login`)
- Startup synchronization of login-item registration with the saved preference

### Fixed
- Release DMG build now targets generic macOS, producing a universal (`x86_64` + `arm64`) app binary
- Release builds now produce a proper ad-hoc signed app bundle (stable bundle identifier/code identity for macOS permissions)
- Release workflow now verifies built app architectures before packaging

### Improved
- Faster selection movement by removing preview-window animation during high-frequency updates
- Reduced redundant overlay refresh work when selection state is unchanged
- Keyboard-driven selection no longer starts at top-left by default; initial cursor now seeds from the target window's current grid fit

### Removed
- Autotile feature (overlay buttons, menu actions, shortcuts, and Autotile settings tab)

## [v1.2.0] - 2026-02-28

### Added
- Shift+Arrow to expand selection from current cursor without needing Enter first (like text selection in editors)

## [v1.1.0] - 2026-02-28

### Added
- Keyboard navigation for grid selection (arrow keys + Enter)
- Option+Arrow to shift entire selection within the grid (shrinks at borders)
- Build script for DMG packaging (`scripts/build-dmg.sh`)

### Fixed
- Global hotkey (Cmd+Option+G) now works reliably using Carbon RegisterEventHotKey
- Target window identification: overlay panel can no longer be tiled instead of the user's window
- Grid hover highlighting: only selected/hovered cells are highlighted, not the entire grid
- Hover preview is now reactive (uses @Published state for SwiftUI updates)
- Grid layout no longer has visual offset (switched to VStack/HStack)
- Overlay always closes after tiling a window

### Improved
- Grid hover performance: single NSTrackingArea + Canvas rendering instead of per-tile SwiftUI views

### Removed
- Non-functional settings: autoClose, followCursor, showGridLines, selectionTimeout

## [v1.0.0] - 2026-02-28

### Added
- Initial release: full port of mTile GNOME extension to native macOS
- Grid-based window tiling via menu bar overlay
- 8-phase implementation: models, parsers, platform services, window management, overlay UI, hotkey management, overlay controller, app orchestration
- Configurable grid sizes, resize presets, autotile layouts
- Settings UI with General, Insets, Presets, Autotile, and Shortcuts tabs
- Accessibility API (AXUIElement) for window management
- Non-activating NSPanel overlays that don't steal focus

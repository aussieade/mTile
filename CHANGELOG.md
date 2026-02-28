# Changelog

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

# mTile

A mostly vibecoded port of [gTile](https://github.com/gTile/gTile) to macOS. gTile is my favorite window tiler on Ubuntu/GNOME and I missed it on macOS, so here we are.

This brings the core functionality of gTile to macOS as a native Swift app - grid-based window tiling with easy shortcuts from your menu bar.

<!-- TODO: Add demo video -->

## Features

- Grid overlay for tiling windows (Cmd+Option+G)
- Click or keyboard-driven grid selection
- Arrow keys to navigate, Enter to select, Shift+Arrow to expand selection
- Option+Arrow to shift the entire selection around
- Configurable grid sizes (e.g. 8x6, 6x4, 4x4)
- Resize presets and autotile layouts
- Window spacing and monitor insets
- Lives in your menu bar, stays out of the way

## Install

Grab the DMG from the [releases page](https://github.com/protortyp/gTile-macos/releases), or build it yourself:

```sh
xcodegen generate
./scripts/build-dmg.sh
```

You'll need to grant accessibility permissions when prompted.

## Building from source

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
# also exists as nix package: https://search.nixos.org/packages?channel=25.11&query=xcode&show=xcodegen
xcodegen generate
open mTile.xcodeproj
```

## Credits

All credit for the original concept and design goes to the [gTile project](https://github.com/gTile/gTile) and its contributors.

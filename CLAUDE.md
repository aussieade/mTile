# gTile macOS

## Build

```sh
xcodegen generate
xcodebuild -project gTile.xcodeproj -scheme gTile -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build
```

Or use `./scripts/build-dmg.sh` to build and package a DMG.

## Type-check (quick)

```sh
swiftc -typecheck -target arm64-apple-macosx14.0 -sdk $(xcrun --show-sdk-path) gTile/**/*.swift
```

## Versioning

We use semantic versioning (semver): `MAJOR.MINOR.PATCH`

- **MAJOR**: breaking changes or major rewrites
- **MINOR**: new features, significant improvements
- **PATCH**: bug fixes, small improvements

Not every commit gets a version tag. Only tag releases that represent meaningful changes (features, bug fixes, cleanup). Tag with `git tag vX.Y.Z` on the release commit.

## Commits

- Do NOT add Co-Authored-By lines to commit messages
- Keep commit messages concise and descriptive

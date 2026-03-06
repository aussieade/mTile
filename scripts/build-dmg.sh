#!/bin/zsh
set -euo pipefail

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$PROJECT/build"

echo "==> Generating Xcode project..."
cd "$PROJECT"
xcodegen generate

echo "==> Building release..."
xcodebuild \
  -project "$PROJECT/mTile.xcodeproj" \
  -scheme mTile \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$BUILD" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build | tail -5

echo "==> Packaging DMG..."
APP="$BUILD/Build/Products/Release/mTile.app"

if [[ ! -d "$APP" ]]; then
  echo "Build product not found at: $APP"
  exit 1
fi

echo "==> Verifying app architectures..."
lipo -info "$APP/Contents/MacOS/mTile"

rm -rf "$BUILD/dmg-staging"
mkdir -p "$BUILD/dmg-staging"
cp -r "$APP" "$BUILD/dmg-staging/"
ln -s /Applications "$BUILD/dmg-staging/Applications"

hdiutil create \
  -volname "mTile" \
  -srcfolder "$BUILD/dmg-staging" \
  -ov -format UDZO \
  "$BUILD/mTile.dmg"

rm -rf "$BUILD/dmg-staging"

echo ""
echo "Done: $BUILD/mTile.dmg"

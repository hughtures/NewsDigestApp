#!/usr/bin/env bash
# Builds a Release app and packages it into dist/NewsDigest.dmg.
#
# The result is ad-hoc signed only. To ship to other people without a Gatekeeper
# warning you additionally need to:
#   1. sign with a "Developer ID Application" certificate (CODE_SIGN_IDENTITY below),
#   2. notarize:  xcrun notarytool submit dist/NewsDigest.dmg --keychain-profile <profile> --wait
#   3. staple:    xcrun stapler staple dist/NewsDigest.dmg
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

xcodebuild -project "News Digest.xcodeproj" -scheme "News Digest" -configuration Release \
  -derivedDataPath "$BUILD_DIR" CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" build

APP="$BUILD_DIR/Build/Products/Release/News Digest.app"
STAGE="$BUILD_DIR/stage"
mkdir -p "$STAGE" dist
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f dist/NewsDigest.dmg
hdiutil create -volname "News Digest" -srcfolder "$STAGE" -ov -format UDZO dist/NewsDigest.dmg
echo "Created dist/NewsDigest.dmg"

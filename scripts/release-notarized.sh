#!/bin/bash
# Build, Developer-ID-sign, notarize and staple a distributable Dropclock.dmg.
#
# Prerequisites (one-time):
#   1. A "Developer ID Application" certificate installed in the login keychain
#      (developer.apple.com > Certificates; the team's Account Holder must create it).
#   2. notarytool credentials stored in the keychain:
#        xcrun notarytool store-credentials "$NOTARY_PROFILE" \
#          --apple-id <apple-id> --team-id <TEAM_ID> --password <app-specific-password>
#
# Usage:
#   SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" DEVELOPMENT_TEAM=TEAMID \
#   NOTARY_PROFILE=DropclockNotary scripts/release-notarized.sh [output-dir]
set -euo pipefail

: "${SIGN_IDENTITY:?set SIGN_IDENTITY to the Developer ID Application identity}"
: "${DEVELOPMENT_TEAM:?set DEVELOPMENT_TEAM to the 10-character team id}"
: "${NOTARY_PROFILE:?set NOTARY_PROFILE to the notarytool keychain profile name}"

REPO="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$REPO/build/release}"
DERIVED="$OUT/DerivedData"
STAGING="$OUT/dmg-root"
DMG="$OUT/Dropclock.dmg"

rm -rf "$OUT"
mkdir -p "$OUT"

echo "== Building Release with hardened runtime and Developer ID signing"
xcodebuild \
  -project "$REPO/Dropclock.xcodeproj" \
  -scheme Dropclock \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
  build | grep -E "error:|warning: .*sign|BUILD"

APP="$DERIVED/Build/Products/Release/Dropclock.app"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "== Creating DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname Dropclock -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
codesign --sign "$SIGN_IDENTITY" --timestamp "$DMG"

echo "== Notarizing (waits for Apple)"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait

echo "== Stapling and verifying"
xcrun stapler staple "$DMG"
spctl -a -t open --context context:primary-signature -vv "$DMG"

echo "Done: $DMG"

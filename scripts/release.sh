#!/bin/bash
# MuteKey Release Script
# Usage: ./scripts/release.sh
#
# What it does:
#   1. Archives MuteKey.xcodeproj with Xcode
#   2. Exports with Developer ID (no notarization yet)
#   3. Notarizes the app with Apple
#   4. Staples the notarization ticket
#   5. Creates a ZIP
#   6. Signs the ZIP with Sparkle (edSignature)
#   7. Prints the values you need for appcast.xml

set -e

# ── Config ────────────────────────────────────────────────────────────────────
APPLE_ID="benkrammer@icloud.com"
TEAM_ID="679Q2PFMG2"
SCHEME="MuteKey"
PROJECT="MuteKey.xcodeproj"
EXPORT_OPTIONS="scripts/ExportOptions.plist"
BUILD_DIR="/tmp/MuteKey-Release"
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

# Read version from Info.plist
VERSION=$(defaults read "$ROOT_DIR/MuteKey/Info.plist" CFBundleShortVersionString)
BUILD=$(defaults read "$ROOT_DIR/MuteKey/Info.plist" CFBundleVersion)
ZIP_NAME="MuteKey-${VERSION}.zip"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " MuteKey Release v${VERSION} (build ${BUILD})"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── 1. Archive ────────────────────────────────────────────────────────────────
echo ""
echo "▶ Step 1/6: Archiving..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$BUILD_DIR/MuteKey.xcarchive" \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  -quiet

echo "  ✅ Archive created"

# ── 2. Export ─────────────────────────────────────────────────────────────────
echo ""
echo "▶ Step 2/6: Exporting..."
xcodebuild -exportArchive \
  -archivePath "$BUILD_DIR/MuteKey.xcarchive" \
  -exportPath "$BUILD_DIR/export" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -quiet

APP_PATH="$BUILD_DIR/export/MuteKey.app"
echo "  ✅ App exported to $APP_PATH"

# ── 3. Notarize ───────────────────────────────────────────────────────────────
echo ""
echo "▶ Step 3/6: Creating ZIP for notarization..."
cd "$BUILD_DIR/export"
ditto -c -k --keepParent "MuteKey.app" "MuteKey-notarize.zip"
cd "$ROOT_DIR"

echo "  Submitting to Apple Notary Service (this takes 1–5 minutes)..."
xcrun notarytool submit "$BUILD_DIR/export/MuteKey-notarize.zip" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID" \
  --keychain-profile "notarytool-mutekey" \
  --wait

echo "  ✅ Notarized"

# ── 4. Staple ─────────────────────────────────────────────────────────────────
echo ""
echo "▶ Step 4/6: Stapling..."
xcrun stapler staple "$APP_PATH"
echo "  ✅ Stapled"

# ── 5. Create release ZIP ─────────────────────────────────────────────────────
echo ""
echo "▶ Step 5/6: Creating release ZIP..."
cd "$BUILD_DIR/export"
ditto -c -k --keepParent "MuteKey.app" "$ZIP_NAME"
mv "$ZIP_NAME" "$ROOT_DIR/$ZIP_NAME"
cd "$ROOT_DIR"
echo "  ✅ $ZIP_NAME created"

# ── 6. Sparkle sign ───────────────────────────────────────────────────────────
echo ""
echo "▶ Step 6/6: Signing with Sparkle..."
SIGN_OUTPUT=$(./scripts/sign_update.sh "$ZIP_NAME")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " ✅ Release v${VERSION} ready!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo " ZIP:  $ZIP_NAME"
echo ""
echo " Sparkle output (paste into appcast.xml):"
echo "$SIGN_OUTPUT"
echo ""
echo " Next steps:"
echo "  1. Upload $ZIP_NAME to GitHub Releases as tag v${VERSION}"
echo "  2. Update appcast.xml in Gist with the values above"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

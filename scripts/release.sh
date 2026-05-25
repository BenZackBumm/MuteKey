#!/bin/bash
# MuteKey Release Script
# Usage: ./scripts/release.sh
#
# What it does:
#   1. Archives MuteKey.xcodeproj with Xcode
#   2. Exports with Developer ID
#   3. Notarizes the app with Apple
#   4. Staples the notarization ticket to the app
#   5. Creates a DMG with app + Applications symlink
#   6. Notarizes and staples the DMG itself
#   7. Signs the DMG with Sparkle (edSignature)
#   8. Prints the values you need for appcast.xml

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
DMG_NAME="MuteKey-${VERSION}.dmg"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " MuteKey Release v${VERSION} (build ${BUILD})"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── 1. Archive ────────────────────────────────────────────────────────────────
echo ""
echo "▶ Step 1/7: Archiving..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$BUILD_DIR/MuteKey.xcarchive" \
  -allowProvisioningUpdates \
  -quiet

echo "  ✅ Archive created"

# ── 2. Export ─────────────────────────────────────────────────────────────────
echo ""
echo "▶ Step 2/7: Exporting..."
xcodebuild -exportArchive \
  -archivePath "$BUILD_DIR/MuteKey.xcarchive" \
  -exportPath "$BUILD_DIR/export" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -quiet

APP_PATH="$BUILD_DIR/export/MuteKey.app"
echo "  ✅ App exported to $APP_PATH"

# ── 3. Notarize ───────────────────────────────────────────────────────────────
echo ""
echo "▶ Step 3/7: Creating ZIP for notarization..."
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
echo "▶ Step 4/7: Stapling app..."
xcrun stapler staple "$APP_PATH"
echo "  ✅ Stapled"

# ── 5. Create release DMG ─────────────────────────────────────────────────────
echo ""
echo "▶ Step 5/7: Creating release DMG..."

TMP_DMG="/tmp/MuteKey-installer"
VOLUME_NAME="MuteKey"

# Create writable DMG (hdiutil appends .dmg automatically)
hdiutil detach "/Volumes/$VOLUME_NAME" 2>/dev/null || true
rm -f "${TMP_DMG}.dmg"
hdiutil create -size 100m -volname "$VOLUME_NAME" -fs HFS+ "$TMP_DMG"

# Mount it
MOUNT_DEV=$(hdiutil attach -readwrite -noverify -noautoopen "${TMP_DMG}.dmg" | grep "^/dev/" | awk 'NR==1 {print $1}')
MOUNT_POINT="/Volumes/$VOLUME_NAME"

# Copy app preserving all attributes and code signature (ditto, not cp -r)
ditto "$APP_PATH" "$MOUNT_POINT/MuteKey.app"
ln -s /Applications "$MOUNT_POINT/Applications"

# Customize window layout via AppleScript
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {400, 100, 980, 540}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        set position of item "MuteKey.app" of container window to {150, 200}
        set position of item "Applications" of container window to {390, 200}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
APPLESCRIPT

# Detach and convert to compressed read-only DMG
chmod -Rf go-w "$MOUNT_POINT"
sync
hdiutil detach "$MOUNT_DEV"
rm -f "$ROOT_DIR/$DMG_NAME"
hdiutil convert "${TMP_DMG}.dmg" -format UDZO -imagekey zlib-level=9 -o "$ROOT_DIR/$DMG_NAME"
rm -f "${TMP_DMG}.dmg"

echo "  ✅ $DMG_NAME created"

# ── 6. Notarize + staple DMG ──────────────────────────────────────────────────
echo ""
echo "▶ Step 6/7: Notarizing DMG..."
xcrun notarytool submit "$ROOT_DIR/$DMG_NAME" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID" \
  --keychain-profile "notarytool-mutekey" \
  --wait
echo "  ✅ DMG notarized"

echo "  Stapling DMG..."
xcrun stapler staple "$ROOT_DIR/$DMG_NAME"
echo "  ✅ DMG stapled"

# ── 7. Sparkle sign ───────────────────────────────────────────────────────────
echo ""
echo "▶ Step 7/7: Signing with Sparkle..."
SIGN_OUTPUT=$(./scripts/sign_update.sh "$DMG_NAME")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " ✅ Release v${VERSION} ready!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo " DMG:  $DMG_NAME"
echo ""
echo " Sparkle output (paste into appcast.xml):"
echo "$SIGN_OUTPUT"
echo ""
echo " Next steps:"
echo "  1. Upload $DMG_NAME to GitHub Releases as tag v${VERSION}"
echo "  2. Update appcast.xml in Gist with the values above"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

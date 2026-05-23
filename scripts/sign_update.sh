#!/bin/bash
# Usage: ./scripts/sign_update.sh ZackMute.zip
# Signs the release zip and prints the sparkle:edSignature to paste into appcast.xml.

set -e

SIGN_UPDATE="$(find ~/Library/Developer/Xcode/DerivedData -name 'sign_update' -path '*/Sparkle/*' 2>/dev/null | head -1)"

if [ -z "$SIGN_UPDATE" ]; then
    echo "Error: sign_update tool not found. Build the project in Xcode first."
    exit 1
fi

if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-ZackMute.zip>"
    exit 1
fi

echo "Signing $1 ..."
"$SIGN_UPDATE" "$1"

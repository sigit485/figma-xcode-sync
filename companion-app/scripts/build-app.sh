#!/bin/bash
set -e

APP_NAME="XcodeAssetSync"
BUILD_DIR="$(dirname "$0")/../build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"

echo "→ Building release binary..."
cd "$(dirname "$0")/.."
swift build -c release

echo "→ Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"

cp ".build/release/$APP_NAME" "$CONTENTS/MacOS/$APP_NAME"
cp "Resources/Info.plist"      "$CONTENTS/Info.plist"

# Optional: code sign with Developer ID if certificate is available
if security find-identity -v -p codesigning 2>/dev/null | grep -q "Developer ID"; then
    CERT=$(security find-identity -v -p codesigning | grep "Developer ID" | head -1 | awk -F'"' '{print $2}')
    echo "→ Signing with: $CERT"
    codesign --deep --force --sign "$CERT" \
        --entitlements "Resources/entitlements.plist" \
        "$APP_DIR" 2>/dev/null || echo "  (signing failed — app will work but Gatekeeper will prompt)"
else
    echo "  (no Developer ID found — users may need to right-click → Open on first launch)"
fi

echo ""
echo "✓ Built: $APP_DIR"
echo ""
echo "  To test locally:  open $APP_DIR"
echo "  To distribute:    zip -r build/$APP_NAME.zip build/$APP_NAME.app"

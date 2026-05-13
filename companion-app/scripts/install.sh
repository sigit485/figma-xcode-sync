#!/bin/bash
set -e

BINARY_NAME="xcode-asset-sync"
INSTALL_DIR="/usr/local/bin"
PLIST_NAME="com.xcode-asset-sync.plist"
PLIST_SRC="$(dirname "$0")/$PLIST_NAME"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_NAME"

echo "→ Building release binary..."
cd "$(dirname "$0")/.."
swift build -c release

echo "→ Installing binary to $INSTALL_DIR/$BINARY_NAME..."
sudo cp .build/release/XcodeAssetSync "$INSTALL_DIR/$BINARY_NAME"

echo "→ Installing Launch Agent..."
cp "$PLIST_SRC" "$PLIST_DEST"

# Unload first in case it was previously loaded
launchctl unload "$PLIST_DEST" 2>/dev/null || true
launchctl load "$PLIST_DEST"

echo ""
echo "✓ Done! xcode-asset-sync is now running in the background."
echo "  It will auto-start on every login."
echo ""
echo "  Next: Open System Settings → Privacy & Security → Accessibility"
echo "  and enable 'xcode-asset-sync' so it can detect your active Xcode file."
echo ""
echo "  Logs: tail -f /tmp/xcode-asset-sync.log"
echo "  Stop: launchctl unload $PLIST_DEST"

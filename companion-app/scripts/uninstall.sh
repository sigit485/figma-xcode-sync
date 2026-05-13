#!/bin/bash
PLIST_DEST="$HOME/Library/LaunchAgents/com.xcode-asset-sync.plist"

launchctl unload "$PLIST_DEST" 2>/dev/null || true
rm -f "$PLIST_DEST"
sudo rm -f /usr/local/bin/xcode-asset-sync

echo "✓ xcode-asset-sync uninstalled."

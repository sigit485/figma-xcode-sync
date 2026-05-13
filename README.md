# Figma → Xcode Asset Sync

Sync icons from Figma directly into your Xcode `.xcassets` — no drag and drop, no manual export.

Select frames in Figma, click **Sync**, and assets appear in your Xcode project instantly.

![Plugin UI](https://raw.githubusercontent.com/sigit485/figma-xcode-sync/main/docs/preview.png)

---

## How it works

```
Figma Plugin  ──→  localhost:9876  ──→  YourApp.xcassets/
  (select)       (companion app)       home_ic_avatar.imageset/
  (click sync)   (auto-detects           ├── home_ic_avatar.png
                  active .xcassets)      ├── home_ic_avatar@2x.png
                                         ├── home_ic_avatar@3x.png
                                         └── Contents.json
```

The companion app runs silently in the background. It detects which `.xcassets` you have open in Xcode and writes there automatically — no configuration needed.

---

## Install

### Companion App (macOS)

**Requirements:** macOS 13+

1. Download **[XcodeAssetSync.zip](https://github.com/sigit485/figma-xcode-sync/releases/latest)**
2. Unzip → double-click `XcodeAssetSync.app`
3. Click **Install** in the dialog
4. Grant **Accessibility** permission when prompted

The app runs silently in the background and auto-starts on every login. No menu bar icon, no Dock presence.

> **First time on macOS:** If Gatekeeper blocks the app, right-click → Open → Open.

### Figma Plugin

**Option A — From Figma Community** *(coming soon)*
Search for "Xcode Asset Sync" in Figma Plugins.

**Option B — Development / Self-hosted**

```bash
cd figma-plugin
npm install && npm run build
```

In Figma: Menu → Plugins → Development → **Import plugin from manifest** → select `figma-plugin/manifest.json`

---

## Usage

1. Open your Xcode project and click on the target `.xcassets` in the Project Navigator
2. Switch to Figma and open the plugin
3. Select one or more icon frames
4. Choose format: **PNG** (1×/2×/3×) or **SVG**
5. Choose rendering: **Original** (colored) or **Template** (tintable via UIColor)
6. Click **Sync to Xcode**

Assets are written immediately. Xcode auto-detects the change.

---

## Auto-detect

The companion app uses the macOS Accessibility API to read which `.xcassets` is currently active in Xcode — even when Xcode is in the background. You can sync from Figma without switching windows.

**Fallback:** If no `.xcassets` is detected (Xcode not open), the app falls back to the project config file.

---

## Optional: Project config

For teams or multi-module projects, create `.xcode-asset-sync.json` at your project root:

```json
{
  "projectRootPath": "/Users/yourname/Code/YourApp",
  "modules": {
    "home":     "YourApp/Modules/Home/Assets/HomeAssets.xcassets",
    "profile":  "YourApp/Modules/Profile/Assets/ProfileAssets.xcassets",
    "settings": "YourApp/Modules/Settings/Assets/SettingsAssets.xcassets"
  },
  "naming": "{module}_ic_{name}",
  "defaultFormat": "png",
  "defaultScales": [1, 2, 3]
}
```

Commit this file so your whole team shares the mapping.

---

## Naming

Icons are named `{page}_ic_{frame}` by default.

| Figma page | Frame name  | Output name             |
|------------|-------------|-------------------------|
| home       | avatar      | `home_ic_avatar`        |
| profile    | user-check  | `profile_ic_user_check` |

---

## Security

- HTTP server listens on `localhost` only — not reachable from the network
- Each launch generates a random 32-char auth token
- Plugin sends token in `X-Auth-Token` header on every request

---

## Uninstall

```bash
launchctl unload ~/Library/LaunchAgents/com.xcode-asset-sync.plist
rm ~/Library/LaunchAgents/com.xcode-asset-sync.plist
rm -rf ~/Applications/XcodeAssetSync.app
```

---

## Build from source

```bash
# Companion app
cd companion-app
bash scripts/build-app.sh
open build/XcodeAssetSync.app

# Figma plugin
cd figma-plugin
npm install && npm run build
```

---

## Roadmap

- [ ] Figma Community plugin listing
- [ ] Auto-detect `.xcassets` from `.xcodeproj` (no Accessibility API needed)
- [ ] Conflict detection: diff before overwrite
- [ ] App Icon set export
- [ ] Sparkle auto-update

---

## License

MIT

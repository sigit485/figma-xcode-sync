import Cocoa
import ApplicationServices
import AppKit

if AppInstaller.isRunningFromInstallLocation {
    // ── DAEMON MODE ───────────────────────────────────────────────────────────
    // Running from ~/Applications — start silently as background daemon.

    // Request AX permission (no-op if already granted; shows prompt if not)
    let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    AXIsProcessTrustedWithOptions(opts)

    let config = ProjectConfig.load()
    let server = AssetHTTPServer(config: config)
    server.start()

    print("[XcodeAssetSync] Listening on port \(AssetHTTPServer.port)")
    RunLoop.main.run()

} else {
    // ── INSTALL MODE ─────────────────────────────────────────────────────────
    // Running from Downloads or elsewhere — show one-time install wizard.

    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    AppInstaller.runInstallUI()
    app.run()
}

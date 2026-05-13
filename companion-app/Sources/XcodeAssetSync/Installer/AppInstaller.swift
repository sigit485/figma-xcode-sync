import Cocoa
import ApplicationServices

/// Handles first-launch installation: copies .app to ~/Applications,
/// installs launchd plist, and requests Accessibility permission.
enum AppInstaller {

    static let installURL: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Applications/XcodeAssetSync.app")

    static let launchAgentPlistURL: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/LaunchAgents/com.xcode-asset-sync.plist")

    /// True when running from the installed location (daemon mode).
    static var isRunningFromInstallLocation: Bool {
        let current = URL(fileURLWithPath: Bundle.main.bundlePath).standardizedFileURL
        return current == installURL.standardizedFileURL
    }

    // MARK: - Install flow

    static func runInstallUI() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Install Xcode Asset Sync"
        alert.informativeText = """
            This will:
            • Copy the app to ~/Applications
            • Run it automatically in the background on every login
            • Ask for Accessibility permission so it can detect your active Xcode files

            After installing, just open a .xcassets in Xcode and click Sync in the Figma plugin — it works automatically.
            """
        alert.addButton(withTitle: "Install")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .informational

        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try copyAppToApplications()
                installLaunchAgent()
                requestAccessibilityPermission()
                showSuccessAndQuit()
            } catch {
                showError(error)
            }
        } else {
            NSApp.terminate(nil)
        }
    }

    // MARK: - Steps

    private static func copyAppToApplications() throws {
        let fm = FileManager.default
        let appsDir = installURL.deletingLastPathComponent()

        if !fm.fileExists(atPath: appsDir.path) {
            try fm.createDirectory(at: appsDir, withIntermediateDirectories: true)
        }
        if fm.fileExists(atPath: installURL.path) {
            try fm.removeItem(at: installURL)
        }
        try fm.copyItem(
            at: URL(fileURLWithPath: Bundle.main.bundlePath),
            to: installURL
        )
    }

    private static func installLaunchAgent() {
        let execPath = installURL
            .appendingPathComponent("Contents/MacOS/XcodeAssetSync").path

        let plist: [String: Any] = [
            "Label": "com.xcode-asset-sync",
            "ProgramArguments": [execPath],
            "RunAtLoad": true,
            "KeepAlive": true,
            "StandardOutPath": "/tmp/xcode-asset-sync.log",
            "StandardErrorPath": "/tmp/xcode-asset-sync.log",
        ]

        // Unload any previous version
        run(launchctl: ["unload", launchAgentPlistURL.path])

        (plist as NSDictionary).write(to: launchAgentPlistURL, atomically: true)
        run(launchctl: ["load", launchAgentPlistURL.path])
    }

    private static func requestAccessibilityPermission() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }

    private static func showSuccessAndQuit() {
        let alert = NSAlert()
        alert.messageText = "Xcode Asset Sync is running!"
        alert.informativeText = """
            The app is now installed and running in the background.

            If prompted, grant Accessibility permission in System Settings → Privacy & Security → Accessibility.

            You're all set — open a .xcassets in Xcode, then sync from the Figma plugin.
            """
        alert.addButton(withTitle: "Done")
        alert.alertStyle = .informational
        alert.runModal()
        NSApp.terminate(nil)
    }

    private static func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Installation failed"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
        NSApp.terminate(nil)
    }

    // MARK: - Helpers

    @discardableResult
    private static func run(launchctl args: [String]) -> Int32 {
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = args
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
        return task.terminationStatus
    }
}

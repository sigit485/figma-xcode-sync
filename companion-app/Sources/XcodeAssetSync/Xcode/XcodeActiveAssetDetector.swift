import Cocoa
import ApplicationServices

/// Queries the running Xcode process via AXUIElement to find the .xcassets
/// folder currently active in the editor. Works even when Xcode is in the background.
enum XcodeActiveAssetDetector {

    static func detectActiveXcassetsPath() -> URL? {
        guard let xcode = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == "com.apple.dt.Xcode" }) else { return nil }
        guard let docPath = activeDocumentPath(for: xcode.processIdentifier) else { return nil }
        return xcassetsAncestor(of: URL(fileURLWithPath: docPath))
    }

    // MARK: - Private

    private static func activeDocumentPath(for pid: pid_t) -> String? {
        let axApp = AXUIElementCreateApplication(pid)

        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let windowRef else { return nil }

        var docRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(windowRef as! AXUIElement, kAXDocumentAttribute as CFString, &docRef) == .success,
              let docStr = docRef as? String else { return nil }

        if docStr.hasPrefix("file://") {
            return URL(string: docStr)?.path
        }
        return docStr
    }

    /// Walks up from `url` until it finds an ancestor with `.xcassets` extension.
    private static func xcassetsAncestor(of url: URL) -> URL? {
        var current = url
        while current.path != "/" {
            if current.pathExtension == "xcassets" { return current }
            current = current.deletingLastPathComponent()
        }
        return nil
    }
}

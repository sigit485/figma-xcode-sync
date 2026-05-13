import Foundation

/// Writes icon assets into an Xcode .xcassets catalog.
/// Creates the .imageset folder + scale PNGs or SVG + Contents.json.
struct AssetWriter {

    enum WriteError: Error, LocalizedError {
        case missingXcassetsPath(module: String)
        case invalidBase64(iconName: String)
        case fileSystemError(String)

        var errorDescription: String? {
            switch self {
            case .missingXcassetsPath(let m): return "No xcassets path configured for module '\(m)'"
            case .invalidBase64(let n):       return "Invalid base64 data for icon '\(n)'"
            case .fileSystemError(let msg):   return msg
            }
        }
    }

    struct WriteResult {
        let name: String
        let path: String
        let skipped: Bool
        let reason: String?
    }

    private let config: ProjectConfig

    init(config: ProjectConfig) {
        self.config = config
    }

    // ── Public entry point ────────────────────────────────────────────────────

    func write(request: ImportRequest) -> (results: [WriteResult], errors: [WriteError]) {
        write(request: request, xcassetsOverride: nil)
    }

    /// When `xcassetsOverride` is set, all icons are written directly to that
    /// .xcassets folder, bypassing the module-based config lookup.
    func write(request: ImportRequest, xcassetsOverride: URL?) -> (results: [WriteResult], errors: [WriteError]) {
        var results: [WriteResult] = []
        var errors: [WriteError] = []

        for icon in request.icons {
            do {
                let result = try writeIcon(icon, xcassetsOverride: xcassetsOverride)
                results.append(result)
            } catch let err as WriteError {
                errors.append(err)
            } catch {
                errors.append(.fileSystemError(error.localizedDescription))
            }
        }

        return (results, errors)
    }

    // ── Write single icon ─────────────────────────────────────────────────────

    private func writeIcon(_ icon: IconPayload, xcassetsOverride: URL? = nil) throws -> WriteResult {
        let xcassetsURL: URL
        if let override = xcassetsOverride {
            xcassetsURL = override
        } else {
            guard let path = config.xcassetsPath(for: icon.module) else {
                throw WriteError.missingXcassetsPath(module: icon.module)
            }
            xcassetsURL = URL(fileURLWithPath: path)
        }

        // icon.name is already the final asset name (built by Figma plugin's buildIconName)
        let imagesetPath = xcassetsURL
            .appendingPathComponent("\(icon.name).imageset")

        let fm = FileManager.default

        // If imageset already exists, we overwrite (sync behavior)
        if !fm.fileExists(atPath: imagesetPath.path) {
            try fm.createDirectory(at: imagesetPath, withIntermediateDirectories: true)
        }

        if icon.format == "svg" {
            try writeSVG(icon: icon, at: imagesetPath)
        } else {
            try writePNG(icon: icon, at: imagesetPath)
        }

        return WriteResult(name: icon.name, path: imagesetPath.path, skipped: false, reason: nil)
    }

    // ── PNG ───────────────────────────────────────────────────────────────────

    private func writePNG(icon: IconPayload, at imagesetURL: URL) throws {
        guard let scales = icon.scales else { return }

        var images: [[String: String]] = []

        let scaleMap: [(key: String, suffix: String, scale: String)] = [
            ("1x", "",    "1x"),
            ("2x", "@2x", "2x"),
            ("3x", "@3x", "3x"),
        ]

        for entry in scaleMap {
            guard let base64 = scales[entry.key],
                  let data = Data(base64Encoded: base64) else {
                throw WriteError.invalidBase64(iconName: icon.name)
            }

            let filename = "\(icon.name)\(entry.suffix).png"
            let fileURL = imagesetURL.appendingPathComponent(filename)
            try data.write(to: fileURL, options: .atomic)

            images.append([
                "idiom":    "universal",
                "filename": filename,
                "scale":    entry.scale,
            ])
        }

        try writeContentsJSON(
            at: imagesetURL,
            images: images,
            renderingMode: icon.renderingMode
        )
    }

    // ── SVG ───────────────────────────────────────────────────────────────────

    private func writeSVG(icon: IconPayload, at imagesetURL: URL) throws {
        guard let base64 = icon.data,
              let data = Data(base64Encoded: base64) else {
            throw WriteError.invalidBase64(iconName: icon.name)
        }

        let filename = "\(icon.name).svg"
        let fileURL = imagesetURL.appendingPathComponent(filename)
        try data.write(to: fileURL, options: .atomic)

        let images: [[String: String]] = [[
            "idiom":    "universal",
            "filename": filename,
        ]]

        try writeContentsJSON(
            at: imagesetURL,
            images: images,
            renderingMode: icon.renderingMode,
            isSVG: true
        )
    }

    // ── Contents.json ─────────────────────────────────────────────────────────

    private func writeContentsJSON(
        at imagesetURL: URL,
        images: [[String: String]],
        renderingMode: String,
        isSVG: Bool = false
    ) throws {
        let info: [String: Any] = [
            "version": 1,
            "author":  "xcode-asset-sync",
        ]

        var properties: [String: Any] = [:]

        if renderingMode == "template" {
            properties["template-rendering-intent"] = "template"
        }

        if isSVG {
            properties["preserves-vector-representation"] = true
        }

        var contents: [String: Any] = [
            "images": images,
            "info":   info,
        ]

        if !properties.isEmpty {
            contents["properties"] = properties
        }

        let data = try JSONSerialization.data(
            withJSONObject: contents,
            options: [.prettyPrinted, .sortedKeys]
        )

        let contentsURL = imagesetURL.appendingPathComponent("Contents.json")
        try data.write(to: contentsURL, options: .atomic)
    }
}

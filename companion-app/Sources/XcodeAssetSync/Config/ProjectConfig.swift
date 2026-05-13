import Foundation

/// Represents the `.xcode-asset-sync.json` config file at the project root.
/// Teams commit this file so everyone shares the same module → xcassets mapping.
struct ProjectConfig: Codable {

    /// Absolute path to the .xcodeproj or project root folder
    var projectRootPath: String

    /// Map of module name (lowercase) → relative path to .xcassets
    /// e.g. "home" → "Lacak/Modul/Home/Asset/HomeAssets.xcassets"
    var modules: [String: String]

    /// Naming template. Tokens: {module}, {name}
    var naming: String

    /// Default export format if not specified per icon
    var defaultFormat: String

    /// Default scales for PNG export
    var defaultScales: [Int]

    // ── Defaults ──────────────────────────────────────────────────────────────

    static func defaultConfig(projectRoot: String) -> ProjectConfig {
        ProjectConfig(
            projectRootPath: projectRoot,
            modules: [:],
            naming: "{module}_ic_{name}",
            defaultFormat: "png",
            defaultScales: [1, 2, 3]
        )
    }

    // ── Persistence ───────────────────────────────────────────────────────────

    private static let userDefaultsKey = "projectConfigPath"

    static func load() -> ProjectConfig? {
        guard let savedPath = UserDefaults.standard.string(forKey: userDefaultsKey) else {
            return nil
        }
        return loadFrom(rootPath: savedPath)
    }

    static func loadFrom(rootPath: String) -> ProjectConfig? {
        let configURL = URL(fileURLWithPath: rootPath)
            .appendingPathComponent(".xcode-asset-sync.json")

        guard FileManager.default.fileExists(atPath: configURL.path),
              let data = try? Data(contentsOf: configURL) else {
            // No config file yet — return a default
            return defaultConfig(projectRoot: rootPath)
        }

        let decoder = JSONDecoder()
        return try? decoder.decode(ProjectConfig.self, from: data)
    }

    func save() {
        UserDefaults.standard.set(projectRootPath, forKey: ProjectConfig.userDefaultsKey)

        let configURL = URL(fileURLWithPath: projectRootPath)
            .appendingPathComponent(".xcode-asset-sync.json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(self) {
            try? data.write(to: configURL)
        }
    }

    // ── Resolve xcassets path for a module ────────────────────────────────────

    func xcassetsPath(for module: String) -> String? {
        let key = module.lowercased()
        guard let relative = modules[key] else { return nil }
        return URL(fileURLWithPath: projectRootPath)
            .appendingPathComponent(relative)
            .path
    }

    /// Reverse lookup: given an absolute .xcassets path, returns the module key that maps to it.
    func module(forXcassetsPath path: String) -> String? {
        let canonical = URL(fileURLWithPath: path).standardizedFileURL.path
        return modules.first { _, relative in
            URL(fileURLWithPath: projectRootPath)
                .appendingPathComponent(relative)
                .standardizedFileURL.path == canonical
        }?.key
    }

    /// Minimal stub used when no config is needed (xcassets override handles path resolution).
    static func stub() -> ProjectConfig {
        ProjectConfig(projectRootPath: "", modules: [:], naming: "{name}",
                      defaultFormat: "png", defaultScales: [1, 2, 3])
    }

    func applyNaming(module: String, name: String) -> String {
        naming
            .replacingOccurrences(of: "{module}", with: module.lowercased())
            .replacingOccurrences(of: "{name}", with: name.lowercased())
    }
}

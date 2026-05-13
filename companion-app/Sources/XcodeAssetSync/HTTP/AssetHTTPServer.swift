import Foundation
import Swifter

/// Local HTTP server that accepts requests from the Figma plugin.
/// Listens on localhost:9876 only (not exposed to network).
final class AssetHTTPServer {

    static let port: UInt16 = 9876
    static let version = "1.0.0"

    private let server = HttpServer()
    private var config: ProjectConfig?

    // Security token — regenerated each launch, persisted per session
    private let authToken: String = {
        let uuid = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        return String(uuid.prefix(32))
    }()

    init(config: ProjectConfig?) {
        self.config = config
        setupRoutes()
    }

    func updateConfig(_ config: ProjectConfig) {
        self.config = config
    }

    // ── Start / stop ──────────────────────────────────────────────────────────

    func start() {
        do {
            try server.start(Self.port, forceIPv4: true)
            print("[HTTP] Listening on localhost:\(Self.port)")
            printToken()
        } catch {
            print("[HTTP] Failed to start: \(error)")
        }
    }

    func stop() {
        server.stop()
    }

    private func printToken() {
        print("""
        ┌────────────────────────────────────────────┐
        │  Xcode Asset Sync - Auth Token              │
        │  \(authToken)  │
        │  Paste this in the Figma plugin if asked    │
        └────────────────────────────────────────────┘
        """)
    }

    // ── Routes ────────────────────────────────────────────────────────────────

    private func setupRoutes() {

        // Health check — plugin polls this to show connected status
        // OPTIONS handled inline for CORS preflight
        server["/ping"] = { [weak self] request in
            guard let self else { return .internalServerError }
            if request.method == "OPTIONS" { return self.corsPreflightResponse() }
            return self.withCORS(self.pingHandler())
        }

        // Main import endpoint
        server["/import-assets"] = { [weak self] request in
            guard let self else { return .internalServerError }
            if request.method == "OPTIONS" { return self.corsPreflightResponse() }
            return self.withCORS(self.importAssetsHandler(request))
        }

        // Config inspection — plugin can read module list
        server["/config"] = { [weak self] request in
            guard let self else { return .internalServerError }
            if request.method == "OPTIONS" { return self.corsPreflightResponse() }
            return self.withCORS(self.configHandler())
        }
    }

    // ── /ping ─────────────────────────────────────────────────────────────────

    private func pingHandler() -> HttpResponse {
        let response = PingResponse(
            version: Self.version,
            projectPath: config?.projectRootPath,
            modules: config?.modules ?? [:],
            token: authToken
        )
        return jsonResponse(response)
    }

    // ── /import-assets ────────────────────────────────────────────────────────

    private func importAssetsHandler(_ request: HttpRequest) -> HttpResponse {
        // Auth check
        if let tokenHeader = request.headers["x-auth-token"], tokenHeader != authToken {
            return jsonResponse(ErrorResponse(message: "Invalid auth token"), status: .unauthorized)
        }

        // Parse body
        let bodyData = Data(request.body)
        let decoder = JSONDecoder()
        guard let importRequest = try? decoder.decode(ImportRequest.self, from: bodyData) else {
            return jsonResponse(ErrorResponse(message: "Invalid request body"), status: .badRequest)
        }

        // Auto-detect active .xcassets from Xcode via Accessibility API.
        // Works even when Xcode is in the background (query by PID).
        let detectedURL = XcodeActiveAssetDetector.detectActiveXcassetsPath()
        if let detected = detectedURL {
            print("[HTTP] Auto-detected xcassets: \(detected.path)")
        }

        // Need either a detected path OR a configured project
        guard detectedURL != nil || config != nil else {
            return jsonResponse(
                ErrorResponse(message: "No active .xcassets detected in Xcode and no project configured. " +
                              "Open a .xcassets file in Xcode, or select your project from the menu bar."),
                status: .badRequest
            )
        }

        // Write assets — override path takes priority over module-based config lookup
        let writer = AssetWriter(config: config ?? .stub())
        let (results, errors) = writer.write(request: importRequest, xcassetsOverride: detectedURL)

        let response = ImportResponse(
            success: errors.isEmpty,
            results: results.map { IconResult(name: $0.name, path: $0.path) },
            errors: errors.map { IconError(name: "unknown", error: $0.localizedDescription) }
        )

        print("[HTTP] Synced \(results.count) icon(s), \(errors.count) error(s)")
        return jsonResponse(response)
    }

    // ── /config ───────────────────────────────────────────────────────────────

    private func configHandler() -> HttpResponse {
        guard let config else {
            return jsonResponse(ErrorResponse(message: "No project configured"), status: .badRequest)
        }
        return jsonResponse([
            "modules": config.modules,
            "naming": config.naming,
            "defaultFormat": config.defaultFormat,
        ] as [String: Any])
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private func corsPreflightResponse() -> HttpResponse {
        return .raw(204, "No Content", corsHeaders(), { _ in })
    }

    private func withCORS(_ response: HttpResponse) -> HttpResponse {
        // Swifter doesn't have a simple header-injection API,
        // so we wrap non-raw responses into raw with CORS headers
        switch response {
        case .raw(let code, let reason, let existing, let writer):
            var headers = existing ?? [:]
            for (k, v) in corsHeaders() { headers[k] = v }
            return .raw(code, reason, headers, writer)
        default:
            return response
        }
    }

    private func corsHeaders() -> [String: String] {
        return [
            "Access-Control-Allow-Origin":  "*",
            "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type, X-Auth-Token",
        ]
    }

    private func jsonResponse<T: Encodable>(_ value: T, status: HttpResponseStatus = .ok) -> HttpResponse {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(value) else {
            return .internalServerError
        }
        let headers = corsHeaders().merging(["Content-Type": "application/json"]) { $1 }
        return .raw(status.rawValue, status.description, headers) { writer in
            try? writer.write([UInt8](data))
        }
    }

    // Support for raw [String: Any] dict (not Codable)
    private func jsonResponse(_ dict: [String: Any], status: HttpResponseStatus = .ok) -> HttpResponse {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else {
            return .internalServerError
        }
        let headers = corsHeaders().merging(["Content-Type": "application/json"]) { $1 }
        return .raw(status.rawValue, status.description, headers) { writer in
            try? writer.write([UInt8](data))
        }
    }
}

// ── Http status convenience ───────────────────────────────────────────────────

enum HttpResponseStatus {
    case ok, badRequest, unauthorized, internalServerError

    var rawValue: Int {
        switch self {
        case .ok: return 200
        case .badRequest: return 400
        case .unauthorized: return 401
        case .internalServerError: return 500
        }
    }
    var description: String {
        switch self {
        case .ok: return "OK"
        case .badRequest: return "Bad Request"
        case .unauthorized: return "Unauthorized"
        case .internalServerError: return "Internal Server Error"
        }
    }
}

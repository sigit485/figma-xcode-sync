import Foundation

// ── Inbound: Plugin → Companion ───────────────────────────────────────────────

struct ImportRequest: Codable {
    let pageName: String
    let icons: [IconPayload]
}

struct IconPayload: Codable {
    let name: String
    let module: String
    let format: String              // "png" | "svg"
    let renderingMode: String       // "original" | "template"
    let scales: [String: String]?   // PNG: {"1x": base64, "2x": base64, "3x": base64}
    let data: String?               // SVG: base64-encoded SVG
}

// ── Outbound: Companion → Plugin ──────────────────────────────────────────────

struct ImportResponse: Codable {
    let success: Bool
    let results: [IconResult]
    let errors: [IconError]
}

struct IconResult: Codable {
    let name: String
    let path: String
}

struct IconError: Codable {
    let name: String
    let error: String
}

struct PingResponse: Codable {
    let version: String
    let projectPath: String?
    let modules: [String: String]
    let token: String
}

struct ErrorResponse: Codable {
    let message: String
}

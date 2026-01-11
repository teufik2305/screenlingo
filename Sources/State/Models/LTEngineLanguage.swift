import Foundation

/// Language model for LTEngine/LibreTranslate API response
struct LTEngineLanguage: Codable {
    let code: String
    let name: String
    let targets: [String]?
}

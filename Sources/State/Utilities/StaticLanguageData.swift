import Foundation

/// Static language data and mappings
enum StaticLanguageData {
    /// Default supported languages - matches Apple Translation (macOS 15+)
    /// Additional languages like Serbian Latin are included for other services
    static let supportedLanguages: [(code: String, name: String)] = [
        ("ar", "Arabic"),
        ("bs", "Bosnian"),
        ("zh", "Chinese"),
        ("zh-Hans", "Chinese (Simplified)"),
        ("zh-Hant", "Chinese (Traditional)"),
        ("hr", "Croatian"),
        ("nl", "Dutch"),
        ("en", "English"),
        ("fr", "French"),
        ("de", "German"),
        ("hi", "Hindi"),
        ("id", "Indonesian"),
        ("it", "Italian"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("pl", "Polish"),
        ("pt", "Portuguese"),
        ("pt-BR", "Portuguese (Brazil)"),
        ("ru", "Russian"),
        ("sr", "Serbian (Cyrillic)"),
        ("sr-Latn", "Serbian (Latin)"),
        ("es", "Spanish"),
        ("th", "Thai"),
        ("tr", "Turkish"),
        ("uk", "Ukrainian"),
        ("vi", "Vietnamese")
    ]
    
    static func languageName(for code: String) -> String {
        if code == "auto" { return "Auto Detect" }
        return supportedLanguages.first { $0.code == code }?.name ?? code.uppercased()
    }
}

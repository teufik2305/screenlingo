import SwiftUI

class TranslatorState: ObservableObject {
    @AppStorage("sourceLanguage") var sourceLanguage: String = "fr"
    @AppStorage("targetLanguage") var targetLanguage: String = "en"
    @AppStorage("overlayOpacity") var overlayOpacity: Double = 0.95
    @AppStorage("fontSize") var fontSize: Double = 20
    @AppStorage("hideOnHover") var hideOnHover: Bool = false
    @AppStorage("logFilePath") var logFilePath: String = "/tmp/overlay_translator.log"
    @AppStorage("useDeepL") var useDeepL: Bool = false
    @AppStorage("deepLApiKey") var deepLApiKey: String = ""
    
    // Ignore list - stored as comma-separated string in UserDefaults
    @AppStorage("ignoredPatterns") private var ignoredPatternsString: String = ""
    
    var ignoredPatterns: [String] {
        get {
            ignoredPatternsString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces).lowercased() }
        }
        set {
            ignoredPatternsString = newValue.joined(separator: ",")
        }
    }
    
    func addIgnoredPattern(_ pattern: String) {
        var patterns = ignoredPatterns
        let normalized = pattern.trimmingCharacters(in: .whitespaces).lowercased()
        if !normalized.isEmpty && !patterns.contains(normalized) {
            patterns.append(normalized)
            ignoredPatterns = patterns
            objectWillChange.send()
        }
    }
    
    func removeIgnoredPattern(_ pattern: String) {
        var patterns = ignoredPatterns
        patterns.removeAll { $0 == pattern.lowercased() }
        ignoredPatterns = patterns
        objectWillChange.send()
    }
    
    func shouldIgnoreText(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return ignoredPatterns.contains { pattern in
            lowercased.contains(pattern)
        }
    }
    
    static let supportedLanguages: [(code: String, name: String)] = [
        ("en", "English"),
        ("fr", "French"),
        ("de", "German"),
        ("es", "Spanish"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("ru", "Russian"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("zh", "Chinese"),
        ("ar", "Arabic"),
        ("nl", "Dutch"),
        ("pl", "Polish"),
        ("tr", "Turkish"),
        ("uk", "Ukrainian"),
        ("vi", "Vietnamese"),
        ("th", "Thai"),
        ("cs", "Czech"),
        ("da", "Danish"),
        ("fi", "Finnish"),
        ("el", "Greek"),
        ("he", "Hebrew"),
        ("hi", "Hindi"),
        ("hu", "Hungarian"),
        ("id", "Indonesian"),
        ("no", "Norwegian"),
        ("ro", "Romanian"),
        ("sv", "Swedish")
    ]
    
    func languageName(for code: String) -> String {
        Self.supportedLanguages.first { $0.code == code }?.name ?? code.uppercased()
    }
}

import Foundation

/// Result type that includes which translation method was used
struct TranslationResult {
    let text: String
    let usedAppleTranslation: Bool
    let usedLibreTranslate: Bool
    let usedLLM: Bool
    
    init(text: String, usedAppleTranslation: Bool, usedLibreTranslate: Bool = false, usedLLM: Bool = false) {
        self.text = text
        self.usedAppleTranslation = usedAppleTranslation
        self.usedLibreTranslate = usedLibreTranslate
        self.usedLLM = usedLLM
    }
}

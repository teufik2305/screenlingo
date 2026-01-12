import Foundation

/// Result type that includes which translation method was used
struct TranslationResult {
    let text: String
    let usedAppleTranslation: Bool
    let usedLibreTranslate: Bool
    let usedLLM: Bool
    let confidence: Int?  // 0-100, nil if not using confidence mode
    
    init(text: String, usedAppleTranslation: Bool, usedLibreTranslate: Bool = false, usedLLM: Bool = false, confidence: Int? = nil) {
        self.text = text
        self.usedAppleTranslation = usedAppleTranslation
        self.usedLibreTranslate = usedLibreTranslate
        self.usedLLM = usedLLM
        self.confidence = confidence
    }
}

/// Internal result from LLM providers with confidence
struct LLMTranslationResult {
    let text: String
    let confidence: Int  // 0-100
}

import Foundation

/// Protocol that all translation providers must implement
@preconcurrency protocol TranslationProvider: Sendable {
    /// Translate text from source language to target language
    func translate(text: String, from sourceLang: String, to targetLang: String, timeout: TimeInterval) async throws -> String
    
    /// Translate text with confidence score (for LLM providers with confidence mode)
    func translateWithConfidence(text: String, from sourceLang: String, to targetLang: String, timeout: TimeInterval) async throws -> LLMTranslationResult
    
    /// Display name of the provider (e.g., "OpenAI", "Claude", "Google")
    nonisolated var providerName: String { get }
}

/// Default implementation for providers that don't support confidence mode
extension TranslationProvider {
    func translateWithConfidence(text: String, from sourceLang: String, to targetLang: String, timeout: TimeInterval) async throws -> LLMTranslationResult {
        let translation = try await translate(text: text, from: sourceLang, to: targetLang, timeout: timeout)
        return LLMTranslationResult(text: translation, confidence: 100)  // Assume 100% if not supported
    }
}

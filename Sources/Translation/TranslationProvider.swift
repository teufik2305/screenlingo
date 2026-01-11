import Foundation

/// Protocol that all translation providers must implement
@preconcurrency protocol TranslationProvider: Sendable {
    /// Translate text from source language to target language
    func translate(text: String, from sourceLang: String, to targetLang: String, timeout: TimeInterval) async throws -> String
    
    /// Display name of the provider (e.g., "OpenAI", "Claude", "Google")
    nonisolated var providerName: String { get }
}

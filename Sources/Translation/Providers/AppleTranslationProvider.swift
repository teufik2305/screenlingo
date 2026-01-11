import Foundation
import Translation

/// Apple Translation Framework provider (requires macOS 26+)
@available(macOS 26.0, *)
actor AppleTranslationProvider: TranslationProvider {
    nonisolated let providerName: String = "Apple"
    
    func translate(text: String, from sourceLang: String, to targetLang: String, timeout: TimeInterval = 30) async throws -> String {
        let startTime = Date()
        log.debug("[\(providerName)] Translation request: \(sourceLang) -> \(targetLang), text length: \(text.count)", category: .translation)
        
        // Clean up language codes for Apple Translation
        let sourceCode = sourceLang.components(separatedBy: "-").first ?? sourceLang
        let targetCode = targetLang.components(separatedBy: "-").first ?? targetLang
        
        // Convert to Locale.Language
        let source = Locale.Language(identifier: sourceCode)
        let target = Locale.Language(identifier: targetCode)
        
        // Check availability
        let availability = LanguageAvailability()
        let status = await availability.status(from: source, to: target)
        
        switch status {
        case .installed, .supported:
            break
        case .unsupported:
            throw TranslationError.languageNotSupported("\(sourceLang) -> \(targetLang)")
        @unknown default:
            throw TranslationError.appleTranslationUnavailable
        }
        
        // Create session with programmatic API (macOS 26+)
        let session = TranslationSession(installedSource: source, target: target)
        let requests = [TranslationSession.Request(sourceText: text)]
        
        var translatedText = ""
        for try await response in session.translate(batch: requests) {
            translatedText = response.targetText
        }
        
        if translatedText.isEmpty {
            log.error("[\(providerName)] Translation failed: empty response", category: .translation)
            throw TranslationError.translationFailed("Empty response from Apple Translation")
        }
        
        let duration = Date().timeIntervalSince(startTime)
        log.debug("[\(providerName)] Translation completed in \(String(format: "%.0f", duration * 1000))ms", category: .translation)
        
        return translatedText
    }
}

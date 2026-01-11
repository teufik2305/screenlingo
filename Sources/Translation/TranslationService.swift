import Foundation
import Translation

/// Main translation service that routes requests to appropriate providers
actor TranslationService {
    
    // Default API URLs
    static let defaultApiUrl = "https://translate.googleapis.com/translate_a/single"
    static let defaultLibreTranslateUrl = "http://localhost:5000/translate"
    
    // Check if Apple Translation is available (requires macOS 26+)
    static var isAppleTranslationAvailable: Bool {
        if #available(macOS 26.0, *) {
            return true
        }
        return false
    }
    
    // Track if we've logged the fallback warning
    private static var hasLoggedFallbackWarning = false
    
    static func translate(
        text: String,
        from sourceLang: String,
        to targetLang: String,
        useAppleTranslation: Bool = true,
        useLibreTranslate: Bool = false,
        useLLM: Bool = false,
        libreTranslateUrl: String? = nil,
        libreTranslateApiKey: String? = nil,
        llmApiUrl: String? = nil,
        llmApiKey: String? = nil,
        llmModel: String? = nil,
        customApiUrl: String? = nil,
        forceSerbianLatin: Bool = false,
        timeout: TimeInterval = 30
    ) async throws -> TranslationResult {
        
        // Select provider based on settings
        let provider: TranslationProvider
        let usedApple: Bool
        let usedLibre: Bool
        let usedLLM: Bool
        
        // Priority 1: LLM (OpenAI GPT / Claude)
        if useLLM {
            let url = llmApiUrl?.isEmpty == false ? llmApiUrl! : "https://api.openai.com/v1/chat/completions"
            let apiKey = llmApiKey ?? ""
            let model = llmModel?.isEmpty == false ? llmModel! : "gpt-4.1-mini"
            
            provider = createLLMProvider(apiUrl: url, apiKey: apiKey, model: model)
            (usedApple, usedLibre, usedLLM) = (false, false, true)
            log.debug("Using LLM provider: \(url)", category: .translation)
        }
        // Priority 2: LibreTranslate / LTEngine (self-hosted)
        else if useLibreTranslate {
            let url = libreTranslateUrl?.isEmpty == false ? libreTranslateUrl! : defaultLibreTranslateUrl
            let apiKey = libreTranslateApiKey?.isEmpty == false ? libreTranslateApiKey : nil
            
            provider = LibreTranslateProvider(apiUrl: url, apiKey: apiKey)
            (usedApple, usedLibre, usedLLM) = (false, true, false)
            log.debug("Using LibreTranslate provider: \(url)", category: .translation)
        }
        // Priority 3: Apple Translation
        else if useAppleTranslation {
            if #available(macOS 26.0, *) {
                // macOS 26+ - use Apple Translation (NO API)
                provider = AppleTranslationProvider()
                (usedApple, usedLibre, usedLLM) = (true, false, false)
                log.debug("Using Apple Translation (native)", category: .translation)
            } else {
                // macOS < 26 - Apple Translation NOT available, must use API as fallback
                // Log warning once per session
                if !hasLoggedFallbackWarning {
                    log.appleTranslationFallback()
                    hasLoggedFallbackWarning = true
                }
                let apiUrl = customApiUrl?.isEmpty == false ? customApiUrl! : defaultApiUrl
                provider = GoogleTranslateProvider(apiUrl: apiUrl)
                (usedApple, usedLibre, usedLLM) = (false, false, false)
                log.debug("Using Google Translate (fallback): \(apiUrl)", category: .translation)
            }
        }
        // Priority 4: Google Translate API (fallback)
        else {
            let apiUrl = customApiUrl?.isEmpty == false ? customApiUrl! : defaultApiUrl
            provider = GoogleTranslateProvider(apiUrl: apiUrl)
            (usedApple, usedLibre, usedLLM) = (false, false, false)
            log.debug("Using Google Translate: \(apiUrl)", category: .translation)
        }
        
        // Translate
        var translatedText = try await provider.translate(text: text, from: sourceLang, to: targetLang, timeout: timeout)
        
        // Apply Serbian Cyrillic → Latin transliteration if enabled and target is Serbian
        if forceSerbianLatin && targetLang.hasPrefix("sr") && SerbianTransliterator.containsCyrillic(translatedText) {
            translatedText = SerbianTransliterator.toLatin(translatedText)
        }
        
        return TranslationResult(text: translatedText, usedAppleTranslation: usedApple, usedLibreTranslate: usedLibre, usedLLM: usedLLM)
    }
    
    /// Create appropriate LLM provider based on API URL
    private static func createLLMProvider(apiUrl: String, apiKey: String, model: String) -> TranslationProvider {
        // Detect provider from URL
        if apiUrl.lowercased().contains("anthropic") {
            return AnthropicProvider(apiUrl: apiUrl, apiKey: apiKey, model: model)
        } else {
            return OpenAIProvider(apiUrl: apiUrl, apiKey: apiKey, model: model)
        }
    }
    
    // MARK: - Legacy compatibility methods (for Serbian transliteration)
    
    /// Convert Serbian Cyrillic text to Latin script
    static func transliterateSerbianToLatin(_ text: String) -> String {
        SerbianTransliterator.toLatin(text)
    }
    
    /// Check if text contains Serbian Cyrillic characters
    static func containsSerbianCyrillic(_ text: String) -> Bool {
        SerbianTransliterator.containsCyrillic(text)
    }
}

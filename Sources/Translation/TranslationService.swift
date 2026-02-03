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
        llmSystemPrompt: String? = nil,
        llmAutoAppendLanguages: Bool = true,
        llmConfidenceEnabled: Bool = false,
        llmConfidenceThreshold: Int = 70,
        llmMaxRetries: Int = 3,
        customApiUrl: String? = nil,
        googleApiKey: String? = nil,
        googleAccessToken: String? = nil,
        forceSerbianLatin: Bool = false,
        timeout: TimeInterval = 30
    ) async throws -> TranslationResult {
        
        // Select provider based on settings
        let provider: TranslationProvider
        let usedApple: Bool
        let usedLibre: Bool
        let usedLLM: Bool
        
        // Priority 1: LLM (OpenAI GPT / Claude / Gemini / Local-self-hosted LLM)
        if useLLM {
            var url = llmApiUrl?.isEmpty == false ? llmApiUrl! : "https://api.openai.com/v1/chat/completions"
            
            // Validate and sanitize LLM URL
            let (sanitizedUrl, validation) = URLValidator.validateAndSanitize(url)
            if !validation.isUsable {
                log.error("Invalid LLM API URL: \(validation.message ?? "Unknown error"). Using default.", category: .translation)
                url = "https://api.openai.com/v1/chat/completions"
            } else {
                url = sanitizedUrl
            }
            let apiKey = llmApiKey ?? ""
            let model = llmModel?.isEmpty == false ? llmModel! : "gpt-4.1-mini"
            let systemPrompt = llmSystemPrompt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? llmSystemPrompt : nil
            
            provider = createLLMProvider(apiUrl: url, apiKey: apiKey, model: model, systemPrompt: systemPrompt, autoAppendLanguages: llmAutoAppendLanguages)
            (usedApple, usedLibre, usedLLM) = (false, false, true)
            log.debug("Using LLM provider: \(url)", category: .translation)
        }
        // Priority 2: LibreTranslate / LTEngine (self-hosted)
        else if useLibreTranslate {
            var url = libreTranslateUrl?.isEmpty == false ? libreTranslateUrl! : defaultLibreTranslateUrl
            let apiKey = libreTranslateApiKey?.isEmpty == false ? libreTranslateApiKey : nil
            
            // Validate and sanitize LibreTranslate URL
            let (sanitizedUrl, validation) = URLValidator.validateAndSanitize(url)
            if !validation.isUsable {
                log.error("Invalid LibreTranslate URL: \(validation.message ?? "Unknown error"). Using default.", category: .translation)
                url = defaultLibreTranslateUrl
            } else {
                url = sanitizedUrl
            }
            
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
                var apiUrl = customApiUrl?.isEmpty == false ? customApiUrl! : defaultApiUrl
                
                // Check if this is a V3 API URL - use access token for V3, API key for V2/unofficial
                let isV3Api = apiUrl.range(of: #"/v3[a-z0-9]*[/:]"#, options: .regularExpression) != nil
                let credential = isV3Api ? (googleAccessToken ?? "") : (googleApiKey ?? "")
                
                // Debug logging for credential type (don't log actual credentials)
                if isV3Api {
                    log.debug("Google V3 API detected - using access token (length: \(credential.count))", category: .translation)
                } else {
                    log.debug("Google V2/unofficial API - using API key (length: \(credential.count))", category: .translation)
                }
                
                // Validate and sanitize Google API URL
                let (sanitizedUrl, validation) = URLValidator.validateAndSanitize(apiUrl)
                if !validation.isUsable {
                    log.error("Invalid Google API URL: \(validation.message ?? "Unknown error"). Using default.", category: .translation)
                    apiUrl = defaultApiUrl
                } else {
                    apiUrl = sanitizedUrl
                }
                
                provider = GoogleTranslateProvider(apiUrl: apiUrl, apiKey: credential)
                (usedApple, usedLibre, usedLLM) = (false, false, false)
                log.debug("Using Google Translate \(isV3Api ? "V3" : "") (fallback): \(apiUrl)", category: .translation)
            }
        }
        // Priority 4: Google Translate API (fallback)
        else {
            var apiUrl = customApiUrl?.isEmpty == false ? customApiUrl! : defaultApiUrl
            
            // Check if this is a V3 API URL - use access token for V3, API key for V2/unofficial
            let isV3Api = apiUrl.range(of: #"/v3[a-z0-9]*[/:]"#, options: .regularExpression) != nil
            let credential = isV3Api ? (googleAccessToken ?? "") : (googleApiKey ?? "")
            
            // Debug logging for credential type (don't log actual credentials)
            if isV3Api {
                log.debug("Google V3 API detected - using access token (length: \(credential.count))", category: .translation)
            } else {
                log.debug("Google V2/unofficial API - using API key (length: \(credential.count))", category: .translation)
            }
            
            // Validate and sanitize Google API URL
            let (sanitizedUrl, validation) = URLValidator.validateAndSanitize(apiUrl)
            if !validation.isUsable {
                log.error("Invalid Google API URL: \(validation.message ?? "Unknown error"). Using default.", category: .translation)
                apiUrl = defaultApiUrl
            } else {
                apiUrl = sanitizedUrl
            }
            
            provider = GoogleTranslateProvider(apiUrl: apiUrl, apiKey: credential)
            (usedApple, usedLibre, usedLLM) = (false, false, false)
            if isV3Api {
                log.debug("Using Google Translate V3: \(apiUrl)", category: .translation)
            } else {
                log.debug("Using Google Translate: \(apiUrl)", category: .translation)
            }
        }
        
        // Translate
        var translatedText: String
        var confidence: Int? = nil
        
        // Use confidence mode for LLM if enabled
        if usedLLM && llmConfidenceEnabled {
            let result = try await translateWithConfidenceRetry(
                provider: provider,
                text: text,
                from: sourceLang,
                to: targetLang,
                timeout: timeout,
                threshold: llmConfidenceThreshold,
                maxRetries: llmMaxRetries
            )
            translatedText = result.text
            confidence = result.confidence
        } else {
            translatedText = try await provider.translate(text: text, from: sourceLang, to: targetLang, timeout: timeout)
        }
        
        // Apply Serbian Cyrillic → Latin transliteration if enabled and target is Serbian
        if forceSerbianLatin && targetLang.hasPrefix("sr") && SerbianTransliterator.containsCyrillic(translatedText) {
            translatedText = SerbianTransliterator.toLatin(translatedText)
        }
        
        return TranslationResult(text: translatedText, usedAppleTranslation: usedApple, usedLibreTranslate: usedLibre, usedLLM: usedLLM, confidence: confidence)
    }
    
    /// Translate with confidence mode, retrying up to maxRetries times to get best result
    private static func translateWithConfidenceRetry(
        provider: TranslationProvider,
        text: String,
        from sourceLang: String,
        to targetLang: String,
        timeout: TimeInterval,
        threshold: Int,
        maxRetries: Int
    ) async throws -> LLMTranslationResult {
        var bestResult: LLMTranslationResult? = nil
        var lastError: Error? = nil
        
        for attempt in 1...maxRetries {
            do {
                let result = try await provider.translateWithConfidence(
                    text: text,
                    from: sourceLang,
                    to: targetLang,
                    timeout: timeout
                )
                
                log.debug("Confidence attempt \(attempt)/\(maxRetries): \(result.confidence)% (threshold: \(threshold)%)", category: .translation)
                
                // Keep best result
                if bestResult == nil || result.confidence > bestResult!.confidence {
                    bestResult = result
                }
                
                // If confidence meets threshold, return immediately
                if result.confidence >= threshold {
                    if attempt > 1 {
                        log.info("Confidence \(result.confidence)% met threshold on attempt \(attempt)", category: .translation)
                    }
                    return result
                }
                
                // If this is the last attempt, return best result
                if attempt == maxRetries {
                    log.info("Max retries reached, using best confidence: \(bestResult!.confidence)%", category: .translation)
                    return bestResult!
                }
                
            } catch {
                lastError = error
                log.warning("Confidence attempt \(attempt) failed: \(error.localizedDescription)", category: .translation)
                
                // If we have a good result already, return it
                if let best = bestResult, best.confidence >= threshold / 2 {
                    return best
                }
            }
        }
        
        // Return best result if we have one, otherwise throw
        if let best = bestResult {
            return best
        }
        throw lastError ?? TranslationError.translationFailed("All confidence attempts failed")
    }
    
    /// Create appropriate LLM provider based on API URL
    private static func createLLMProvider(apiUrl: String, apiKey: String, model: String, systemPrompt: String?, autoAppendLanguages: Bool) -> TranslationProvider {
        let url = apiUrl.lowercased()
        
        // Detect provider from URL
        if url.contains("anthropic") {
            return AnthropicProvider(apiUrl: apiUrl, apiKey: apiKey, model: model, customSystemPrompt: systemPrompt, autoAppendLanguages: autoAppendLanguages)
        } else if url.contains("generativelanguage.googleapis.com") && !url.contains("/openai/") {
            // Native Gemini API (not OpenAI-compatible endpoint)
            return GeminiProvider(apiUrl: apiUrl, apiKey: apiKey, model: model, customSystemPrompt: systemPrompt, autoAppendLanguages: autoAppendLanguages)
        } else {
            // OpenAI and OpenAI-compatible APIs (including Gemini's OpenAI endpoint, Ollama, etc.)
            return OpenAIProvider(apiUrl: apiUrl, apiKey: apiKey, model: model, customSystemPrompt: systemPrompt, autoAppendLanguages: autoAppendLanguages)
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

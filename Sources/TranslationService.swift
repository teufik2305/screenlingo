import Foundation
import Translation

enum TranslationError: Error, LocalizedError {
    case networkError(String)
    case invalidResponse
    case translationFailed(String)
    case appleTranslationUnavailable
    case languageNotSupported(String)
    case invalidApiKey(String)
    case billingError(String)
    case rateLimitExceeded(String)
    case modelNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message): return "Network error: \(message)"
        case .invalidResponse: return "Invalid response"
        case .translationFailed(let message): return "Translation failed: \(message)"
        case .appleTranslationUnavailable: return "Apple Translation requires macOS 26.0 or newer"
        case .languageNotSupported(let lang): return "Language not supported: \(lang)"
        case .invalidApiKey(let provider): return "Invalid API key for \(provider). Please check your API key in Settings."
        case .billingError(let provider): return "\(provider) billing issue: Please check your account has credits/payment method."
        case .rateLimitExceeded(let provider): return "\(provider) rate limit exceeded. Please wait a moment and try again."
        case .modelNotFound(let model): return "Model '\(model)' not found. Please check the model name."
        }
    }
}

// Result type that includes which translation method was used
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

actor TranslationService {
    
    // Default API URLs
    static let defaultApiUrl = "https://translate.googleapis.com/translate_a/single"
    static let defaultLibreTranslateUrl = "http://localhost:5000/translate"
    
    // Serbian Cyrillic to Latin transliteration map
    private static let serbianCyrillicToLatin: [Character: String] = [
        "А": "A", "Б": "B", "В": "V", "Г": "G", "Д": "D", "Ђ": "Đ", "Е": "E", "Ж": "Ž",
        "З": "Z", "И": "I", "Ј": "J", "К": "K", "Л": "L", "Љ": "Lj", "М": "M", "Н": "N",
        "Њ": "Nj", "О": "O", "П": "P", "Р": "R", "С": "S", "Т": "T", "Ћ": "Ć", "У": "U",
        "Ф": "F", "Х": "H", "Ц": "C", "Ч": "Č", "Џ": "Dž", "Ш": "Š",
        "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "ђ": "đ", "е": "e", "ж": "ž",
        "з": "z", "и": "i", "ј": "j", "к": "k", "л": "l", "љ": "lj", "м": "m", "н": "n",
        "њ": "nj", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "ћ": "ć", "у": "u",
        "ф": "f", "х": "h", "ц": "c", "ч": "č", "џ": "dž", "ш": "š"
    ]
    
    // Convert Serbian Cyrillic text to Latin script
    static func transliterateSerbianToLatin(_ text: String) -> String {
        var result = ""
        for char in text {
            if let latin = serbianCyrillicToLatin[char] {
                result += latin
            } else {
                result.append(char)
            }
        }
        return result
    }
    
    // Check if text contains Serbian Cyrillic characters
    static func containsSerbianCyrillic(_ text: String) -> Bool {
        text.contains { serbianCyrillicToLatin[$0] != nil }
    }
    
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
        forceSerbianLatin: Bool = false
    ) async throws -> TranslationResult {
        
        var result: TranslationResult
        
        // Priority 1: LLM (OpenAI GPT / Claude)
        if useLLM {
            let url = llmApiUrl?.isEmpty == false ? llmApiUrl! : "https://api.openai.com/v1/chat/completions"
            let apiKey = llmApiKey ?? ""
            let model = llmModel?.isEmpty == false ? llmModel! : "gpt-4.1-mini"
            let translatedText = try await translateWithLLM(text: text, from: sourceLang, to: targetLang, apiUrl: url, apiKey: apiKey, model: model)
            result = TranslationResult(text: translatedText, usedAppleTranslation: false, usedLibreTranslate: false, usedLLM: true)
        }
        // Priority 2: LibreTranslate / LTEngine (self-hosted)
        else if useLibreTranslate {
            let url = libreTranslateUrl?.isEmpty == false ? libreTranslateUrl! : defaultLibreTranslateUrl
            let apiKey = libreTranslateApiKey?.isEmpty == false ? libreTranslateApiKey : nil
            let translatedText = try await translateWithLibreTranslate(text: text, from: sourceLang, to: targetLang, apiUrl: url, apiKey: apiKey)
            result = TranslationResult(text: translatedText, usedAppleTranslation: false, usedLibreTranslate: true)
        }
        // Priority 3: Apple Translation
        else if useAppleTranslation {
            if #available(macOS 26.0, *) {
                // macOS 26+ - use Apple Translation (NO API)
                let translatedText = try await translateWithAppleFramework(text: text, from: sourceLang, to: targetLang)
                result = TranslationResult(text: translatedText, usedAppleTranslation: true)
            } else {
                // macOS < 26 - Apple Translation NOT available, must use API as fallback
                // Log warning once per session
                if !hasLoggedFallbackWarning {
                    log.appleTranslationFallback()
                    hasLoggedFallbackWarning = true
                }
                let apiUrl = customApiUrl?.isEmpty == false ? customApiUrl! : defaultApiUrl
                let translatedText = try await translateWithApi(text: text, from: sourceLang, to: targetLang, apiUrl: apiUrl)
                result = TranslationResult(text: translatedText, usedAppleTranslation: false)
            }
        }
        // Priority 4: Google Translate API (fallback)
        else {
            let apiUrl = customApiUrl?.isEmpty == false ? customApiUrl! : defaultApiUrl
            let translatedText = try await translateWithApi(text: text, from: sourceLang, to: targetLang, apiUrl: apiUrl)
            result = TranslationResult(text: translatedText, usedAppleTranslation: false)
        }
        
        // Apply Serbian Cyrillic → Latin transliteration if enabled and target is Serbian
        if forceSerbianLatin && targetLang.hasPrefix("sr") && containsSerbianCyrillic(result.text) {
            let latinText = transliterateSerbianToLatin(result.text)
            return TranslationResult(text: latinText, usedAppleTranslation: result.usedAppleTranslation, usedLibreTranslate: result.usedLibreTranslate, usedLLM: result.usedLLM)
        }
        
        return result
    }
    
    // MARK: - Apple Translation Framework (macOS 26+)
    
    @available(macOS 26.0, *)
    private static func translateWithAppleFramework(text: String, from sourceLang: String, to targetLang: String) async throws -> String {
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
            throw TranslationError.translationFailed("Empty response from Apple Translation")
        }
        
        return translatedText
    }
    
    // MARK: - LibreTranslate / LTEngine API
    
    private static func translateWithLibreTranslate(text: String, from sourceLang: String, to targetLang: String, apiUrl: String, apiKey: String?) async throws -> String {
        // Preserve full language codes including script variants (e.g., sr-Latn for Latin Serbian)
        // Only strip region codes like pt-BR -> pt if the server doesn't support them
        let source = sourceLang
        let target = targetLang
        
        // Ensure URL ends with /translate
        var finalUrl = apiUrl
        if !finalUrl.hasSuffix("/translate") {
            finalUrl = finalUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/translate"
        }
        
        guard let url = URL(string: finalUrl) else {
            throw TranslationError.invalidResponse
        }
        
        // Build JSON body
        var body: [String: Any] = [
            "q": text,
            "source": source,
            "target": target,
            "format": "text"
        ]
        
        // Add API key if provided
        if let key = apiKey, !key.isEmpty {
            body["api_key"] = key
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            throw TranslationError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.timeoutInterval = 30  // LLM-based translation may take longer
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            // Try to parse error message
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorJson["error"] as? String {
                throw TranslationError.translationFailed(errorMessage)
            }
            // Provide helpful error for common issues
            if httpResponse.statusCode == 405 {
                throw TranslationError.networkError("HTTP 405 - Check LTEngine URL (should end with /translate)")
            }
            throw TranslationError.networkError("HTTP \(httpResponse.statusCode)")
        }
        
        // Parse LibreTranslate response: {"translatedText": "..."}
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let translatedText = json["translatedText"] as? String else {
            throw TranslationError.invalidResponse
        }
        
        return translatedText
    }
    
    // MARK: - LLM Translation (OpenAI GPT / Anthropic Claude)
    
    private static func translateWithLLM(text: String, from sourceLang: String, to targetLang: String, apiUrl: String, apiKey: String, model: String) async throws -> String {
        guard let url = URL(string: apiUrl) else {
            throw TranslationError.invalidResponse
        }
        
        // Detect provider from URL
        let isAnthropic = apiUrl.lowercased().contains("anthropic")
        
        // Build the translation prompt
        let sourceLanguageName = sourceLang == "auto" ? "the source language (auto-detect)" : languageDisplayName(sourceLang)
        let targetLanguageName = languageDisplayName(targetLang)
        
        let systemPrompt = "You are a professional translator. Translate the following text from \(sourceLanguageName) to \(targetLanguageName). Only respond with the translation, nothing else. Do not include explanations, notes, or quotation marks around the translation."
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonData: Data
        
        if isAnthropic {
            // Anthropic Claude API format
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            
            let body: [String: Any] = [
                "model": model,
                "max_tokens": 4096,
                "system": systemPrompt,
                "messages": [
                    ["role": "user", "content": text]
                ]
            ]
            jsonData = try JSONSerialization.data(withJSONObject: body)
        } else {
            // OpenAI-compatible API format (works with OpenAI, Ollama, LM Studio, etc.)
            if !apiKey.isEmpty {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
            
            let body: [String: Any] = [
                "model": model,
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": text]
                ],
                "temperature": 0.3,
                "max_tokens": 4096
            ]
            jsonData = try JSONSerialization.data(withJSONObject: body)
        }
        
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            // Determine provider name for error messages
            let providerName: String
            if isAnthropic {
                providerName = "Claude"
            } else if apiUrl.contains("generativelanguage.googleapis") || apiUrl.contains("gemini") {
                providerName = "Gemini"
            } else if apiUrl.contains("openai") {
                providerName = "OpenAI"
            } else if apiUrl.contains("localhost") || apiUrl.contains("127.0.0.1") {
                providerName = "Local LLM"
            } else {
                providerName = "LLM"
            }
            
            // Parse error response for specific error types
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // OpenAI/Gemini format: {"error": {"message": "...", "type": "...", "code": "..."}}
                if let error = errorJson["error"] as? [String: Any] {
                    let message = error["message"] as? String ?? "Unknown error"
                    let errorType = error["type"] as? String ?? ""
                    let errorCode = error["code"] as? String ?? ""
                    
                    // Check for specific error types
                    if httpResponse.statusCode == 401 || errorType == "authentication_error" || errorCode == "invalid_api_key" {
                        throw TranslationError.invalidApiKey(providerName)
                    }
                    if httpResponse.statusCode == 402 || errorCode == "insufficient_quota" || message.lowercased().contains("billing") || message.lowercased().contains("quota") || message.lowercased().contains("credits") {
                        throw TranslationError.billingError(providerName)
                    }
                    if httpResponse.statusCode == 429 || errorType == "rate_limit_error" || errorCode == "rate_limit_exceeded" {
                        throw TranslationError.rateLimitExceeded(providerName)
                    }
                    if errorCode == "model_not_found" || message.lowercased().contains("model") && message.lowercased().contains("not found") {
                        throw TranslationError.modelNotFound(model)
                    }
                    
                    throw TranslationError.translationFailed("\(providerName): \(message)")
                }
                
                // Anthropic format: {"type": "error", "error": {"type": "...", "message": "..."}}
                if let errorType = errorJson["type"] as? String, errorType == "error",
                   let errorDetails = errorJson["error"] as? [String: Any] {
                    let message = errorDetails["message"] as? String ?? "Unknown error"
                    let detailType = errorDetails["type"] as? String ?? ""
                    
                    if httpResponse.statusCode == 401 || detailType == "authentication_error" {
                        throw TranslationError.invalidApiKey(providerName)
                    }
                    if detailType == "invalid_request_error" && (message.lowercased().contains("credit") || message.lowercased().contains("billing")) {
                        throw TranslationError.billingError(providerName)
                    }
                    if httpResponse.statusCode == 429 || detailType == "rate_limit_error" {
                        throw TranslationError.rateLimitExceeded(providerName)
                    }
                    if message.lowercased().contains("model") && message.lowercased().contains("not found") {
                        throw TranslationError.modelNotFound(model)
                    }
                    
                    throw TranslationError.translationFailed("\(providerName): \(message)")
                }
                
                // Simple error string
                if let errorMessage = errorJson["error"] as? String {
                    throw TranslationError.translationFailed("\(providerName): \(errorMessage)")
                }
            }
            
            // Fallback for common HTTP status codes
            switch httpResponse.statusCode {
            case 401:
                throw TranslationError.invalidApiKey(providerName)
            case 402:
                throw TranslationError.billingError(providerName)
            case 429:
                throw TranslationError.rateLimitExceeded(providerName)
            case 404:
                throw TranslationError.modelNotFound(model)
            default:
                throw TranslationError.networkError("\(providerName) returned HTTP \(httpResponse.statusCode)")
            }
        }
        
        // Parse response based on provider
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TranslationError.invalidResponse
        }
        
        var translatedText: String?
        
        if isAnthropic {
            // Anthropic Claude response format
            // {"content": [{"type": "text", "text": "..."}], ...}
            if let content = json["content"] as? [[String: Any]],
               let firstContent = content.first,
               let text = firstContent["text"] as? String {
                translatedText = text
            }
        } else {
            // OpenAI-compatible response format
            // {"choices": [{"message": {"content": "..."}}], ...}
            if let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                translatedText = content
            }
        }
        
        guard let result = translatedText?.trimmingCharacters(in: .whitespacesAndNewlines), !result.isEmpty else {
            throw TranslationError.invalidResponse
        }
        
        return result
    }
    
    // Helper to get display name for language code
    private static func languageDisplayName(_ code: String) -> String {
        let languageNames: [String: String] = [
            "ar": "Arabic", "zh": "Chinese", "zh-Hans": "Simplified Chinese", "zh-Hant": "Traditional Chinese",
            "nl": "Dutch", "en": "English", "fr": "French", "de": "German", "hi": "Hindi",
            "id": "Indonesian", "it": "Italian", "ja": "Japanese", "ko": "Korean", "pl": "Polish",
            "pt": "Portuguese", "pt-BR": "Brazilian Portuguese", "ru": "Russian",
            "sr": "Serbian", "sr-Latn": "Serbian (Latin)", "es": "Spanish", "th": "Thai",
            "tr": "Turkish", "uk": "Ukrainian", "vi": "Vietnamese",
            "bs": "Bosnian", "hr": "Croatian", "cs": "Czech", "da": "Danish", "fi": "Finnish",
            "el": "Greek", "he": "Hebrew", "hu": "Hungarian", "no": "Norwegian", "ro": "Romanian",
            "sk": "Slovak", "sl": "Slovenian", "sv": "Swedish", "bg": "Bulgarian", "et": "Estonian",
            "lv": "Latvian", "lt": "Lithuanian", "mt": "Maltese", "ga": "Irish"
        ]
        return languageNames[code] ?? code.uppercased()
    }
    
    // MARK: - API Translation (Google Translate unofficial API)
    
    private static func translateWithApi(text: String, from sourceLang: String, to targetLang: String, apiUrl: String) async throws -> String {
        // Preserve full language codes including script variants (e.g., sr-Latn for Latin Serbian)
        // Google Translate supports script variants like sr-Latn, zh-Hans, zh-Hant
        let source = sourceLang
        let target = targetLang
        
        // Build URL
        var components = URLComponents(string: apiUrl)!
        components.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: source),
            URLQueryItem(name: "tl", value: target),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: text)
        ]
        
        guard let url = components.url else {
            throw TranslationError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TranslationError.networkError("HTTP error")
        }
        
        // Parse the response - it's a nested array
        // Format: [[["translation","original",null,null,N],...],null,"source_lang",...]
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let translationArray = json.first as? [Any] else {
            throw TranslationError.invalidResponse
        }
        
        // Extract all translation parts and join them
        var translations: [String] = []
        for item in translationArray {
            if let part = item as? [Any],
               let translatedText = part.first as? String {
                translations.append(translatedText)
            }
        }
        
        guard !translations.isEmpty else {
            throw TranslationError.invalidResponse
        }
        
        return translations.joined()
    }
}

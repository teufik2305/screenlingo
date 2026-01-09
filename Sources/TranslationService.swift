import Foundation
import Translation

enum TranslationError: Error, LocalizedError {
    case networkError(String)
    case invalidResponse
    case translationFailed(String)
    case appleTranslationUnavailable
    case languageNotSupported(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message): return "Network error: \(message)"
        case .invalidResponse: return "Invalid response"
        case .translationFailed(let message): return "Translation failed: \(message)"
        case .appleTranslationUnavailable: return "Apple Translation requires macOS 26.0 or newer"
        case .languageNotSupported(let lang): return "Language not supported: \(lang)"
        }
    }
}

// Result type that includes which translation method was used
struct TranslationResult {
    let text: String
    let usedAppleTranslation: Bool
    let usedLibreTranslate: Bool
    
    init(text: String, usedAppleTranslation: Bool, usedLibreTranslate: Bool = false) {
        self.text = text
        self.usedAppleTranslation = usedAppleTranslation
        self.usedLibreTranslate = usedLibreTranslate
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
        libreTranslateUrl: String? = nil,
        libreTranslateApiKey: String? = nil,
        customApiUrl: String? = nil,
        forceSerbianLatin: Bool = false
    ) async throws -> TranslationResult {
        
        var result: TranslationResult
        
        // Priority 1: LibreTranslate / LTEngine (self-hosted)
        if useLibreTranslate {
            let url = libreTranslateUrl?.isEmpty == false ? libreTranslateUrl! : defaultLibreTranslateUrl
            let apiKey = libreTranslateApiKey?.isEmpty == false ? libreTranslateApiKey : nil
            let translatedText = try await translateWithLibreTranslate(text: text, from: sourceLang, to: targetLang, apiUrl: url, apiKey: apiKey)
            result = TranslationResult(text: translatedText, usedAppleTranslation: false, usedLibreTranslate: true)
        }
        // Priority 2: Apple Translation
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
        // Priority 3: Google Translate API (fallback)
        else {
            let apiUrl = customApiUrl?.isEmpty == false ? customApiUrl! : defaultApiUrl
            let translatedText = try await translateWithApi(text: text, from: sourceLang, to: targetLang, apiUrl: apiUrl)
            result = TranslationResult(text: translatedText, usedAppleTranslation: false)
        }
        
        // Apply Serbian Cyrillic → Latin transliteration if enabled and target is Serbian
        if forceSerbianLatin && targetLang.hasPrefix("sr") && containsSerbianCyrillic(result.text) {
            let latinText = transliterateSerbianToLatin(result.text)
            return TranslationResult(text: latinText, usedAppleTranslation: result.usedAppleTranslation, usedLibreTranslate: result.usedLibreTranslate)
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

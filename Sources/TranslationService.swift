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
}

actor TranslationService {
    
    // Default API URL
    static let defaultApiUrl = "https://translate.googleapis.com/translate_a/single"
    
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
        customApiUrl: String? = nil
    ) async throws -> TranslationResult {
        
        // If user wants Apple Translation
        if useAppleTranslation {
            if #available(macOS 26.0, *) {
                // macOS 26+ - use Apple Translation (NO API)
                let result = try await translateWithAppleFramework(text: text, from: sourceLang, to: targetLang)
                return TranslationResult(text: result, usedAppleTranslation: true)
            } else {
                // macOS < 26 - Apple Translation NOT available, must use API as fallback
                // Log warning once per session
                if !hasLoggedFallbackWarning {
                    log.appleTranslationFallback()
                    hasLoggedFallbackWarning = true
                }
                let apiUrl = customApiUrl?.isEmpty == false ? customApiUrl! : defaultApiUrl
                let result = try await translateWithApi(text: text, from: sourceLang, to: targetLang, apiUrl: apiUrl)
                return TranslationResult(text: result, usedAppleTranslation: false)
            }
        } else {
            // User explicitly chose API
            let apiUrl = customApiUrl?.isEmpty == false ? customApiUrl! : defaultApiUrl
            let result = try await translateWithApi(text: text, from: sourceLang, to: targetLang, apiUrl: apiUrl)
            return TranslationResult(text: result, usedAppleTranslation: false)
        }
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
    
    // MARK: - API Translation (Google Translate unofficial API)
    
    private static func translateWithApi(text: String, from sourceLang: String, to targetLang: String, apiUrl: String) async throws -> String {
        // Clean up language codes
        let source = sourceLang.components(separatedBy: "-").first ?? sourceLang
        let target = targetLang.components(separatedBy: "-").first ?? targetLang
        
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

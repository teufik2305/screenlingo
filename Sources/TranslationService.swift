import Foundation

enum TranslationError: Error, LocalizedError {
    case networkError(String)
    case invalidResponse
    case translationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message): return "Network error: \(message)"
        case .invalidResponse: return "Invalid response"
        case .translationFailed(let message): return "Translation failed: \(message)"
        }
    }
}

actor TranslationService {
    
    static func translate(text: String, from sourceLang: String, to targetLang: String) async throws -> String {
        // Use Google Translate's unofficial API (fast, reliable, no rate limits for reasonable use)
        return try await translateWithGoogle(text: text, from: sourceLang, to: targetLang)
    }
    
    // MARK: - Google Translate (unofficial API)
    
    private static func translateWithGoogle(text: String, from sourceLang: String, to targetLang: String) async throws -> String {
        // Clean up language codes
        let source = sourceLang.components(separatedBy: "-").first ?? sourceLang
        let target = targetLang.components(separatedBy: "-").first ?? targetLang
        
        // Build URL
        var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single")!
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

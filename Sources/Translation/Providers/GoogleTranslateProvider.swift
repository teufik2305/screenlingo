import Foundation

/// Google Translate (unofficial API) translation provider
actor GoogleTranslateProvider: TranslationProvider {
    let apiUrl: String
    nonisolated let providerName: String = "Google"
    
    init(apiUrl: String) {
        self.apiUrl = apiUrl
    }
    
    func translate(text: String, from sourceLang: String, to targetLang: String, timeout: TimeInterval = 10) async throws -> String {
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
        request.timeoutInterval = timeout
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        let startTime = Date()
        log.debug("[\(providerName)] API request: \(source) -> \(target), text length: \(text.count)", category: .api)
        let (data, response) = try await URLSession.shared.data(for: request)
        let duration = Date().timeIntervalSince(startTime)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            log.warning("[\(providerName)] API error: HTTP \(statusCode) in \(String(format: "%.0f", duration * 1000))ms", category: .api)
            throw TranslationError.networkError("HTTP error")
        }
        
        log.debug("[\(providerName)] API response: HTTP 200 in \(String(format: "%.0f", duration * 1000))ms", category: .api)
        
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

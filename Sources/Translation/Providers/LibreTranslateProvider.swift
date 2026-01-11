import Foundation

/// LibreTranslate / LTEngine translation provider
actor LibreTranslateProvider: TranslationProvider {
    let apiUrl: String
    let apiKey: String?
    nonisolated let providerName: String = "LibreTranslate"
    
    init(apiUrl: String, apiKey: String?) {
        self.apiUrl = apiUrl
        self.apiKey = apiKey
    }
    
    func translate(text: String, from sourceLang: String, to targetLang: String, timeout: TimeInterval = 30) async throws -> String {
        // Preserve full language codes including script variants (e.g., sr-Latn for Latin Serbian)
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
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let startTime = Date()
        log.debug("[\(providerName)] API request: \(source) -> \(target), text length: \(text.count)", category: .api)
        let (data, response) = try await URLSession.shared.data(for: request)
        let duration = Date().timeIntervalSince(startTime)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            log.warning("[\(providerName)] API error: HTTP \(httpResponse.statusCode) in \(String(format: "%.0f", duration * 1000))ms", category: .api)
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
        
        log.debug("[\(providerName)] API response: HTTP 200 in \(String(format: "%.0f", duration * 1000))ms", category: .api)
        
        // Parse LibreTranslate response: {"translatedText": "..."}
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let translatedText = json["translatedText"] as? String else {
            throw TranslationError.invalidResponse
        }
        
        return translatedText
    }
}

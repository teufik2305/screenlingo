import Foundation

/// Anthropic Claude translation provider
actor AnthropicProvider: TranslationProvider {
    let apiUrl: String
    let apiKey: String
    let model: String
    nonisolated let providerName: String = "Claude"
    
    init(apiUrl: String, apiKey: String, model: String) {
        self.apiUrl = apiUrl
        self.apiKey = apiKey
        self.model = model
    }
    
    func translate(text: String, from sourceLang: String, to targetLang: String, timeout: TimeInterval = 30) async throws -> String {
        guard let url = URL(string: apiUrl) else {
            throw TranslationError.invalidResponse
        }
        
        // Build the translation prompt
        let sourceLanguageName = sourceLang == "auto" ? "the source language (auto-detect)" : LanguageNameMapper.displayName(for: sourceLang)
        let targetLanguageName = LanguageNameMapper.displayName(for: targetLang)
        
        let systemPrompt = "You are a professional translator. Translate the following text from \(sourceLanguageName) to \(targetLanguageName). Only respond with the translation, nothing else. Do not include explanations, notes, or quotation marks around the translation."
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
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
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let startTime = Date()
        log.debug("[\(providerName)] API request: \(sourceLang) -> \(targetLang), text length: \(text.count)", category: .api)
        let (data, response) = try await URLSession.shared.data(for: request)
        let duration = Date().timeIntervalSince(startTime)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            log.warning("[\(providerName)] API error: HTTP \(httpResponse.statusCode) in \(String(format: "%.0f", duration * 1000))ms", category: .api)
            try handleError(data: data, statusCode: httpResponse.statusCode)
            throw TranslationError.networkError("\(providerName) returned HTTP \(httpResponse.statusCode)")
        }
        
        log.debug("[\(providerName)] API response: HTTP 200 in \(String(format: "%.0f", duration * 1000))ms", category: .api)
        
        // Parse Anthropic Claude response format
        // {"content": [{"type": "text", "text": "..."}], ...}
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw TranslationError.invalidResponse
        }
        
        let result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else {
            throw TranslationError.invalidResponse
        }
        
        return result
    }
    
    private func handleError(data: Data, statusCode: Int) throws {
        // Parse Anthropic error format: {"type": "error", "error": {"type": "...", "message": "..."}}
        if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorType = errorJson["type"] as? String, errorType == "error",
           let errorDetails = errorJson["error"] as? [String: Any] {
            let message = errorDetails["message"] as? String ?? "Unknown error"
            let detailType = errorDetails["type"] as? String ?? ""
            
            if statusCode == 401 || detailType == "authentication_error" {
                throw TranslationError.invalidApiKey(providerName)
            }
            if detailType == "invalid_request_error" && (message.lowercased().contains("credit") || message.lowercased().contains("billing")) {
                throw TranslationError.billingError(providerName)
            }
            if statusCode == 429 || detailType == "rate_limit_error" {
                throw TranslationError.rateLimitExceeded(providerName)
            }
            if message.lowercased().contains("model") && message.lowercased().contains("not found") {
                throw TranslationError.modelNotFound(model)
            }
            
            throw TranslationError.translationFailed("\(providerName): \(message)")
        }
        
        // Fallback for common HTTP status codes
        switch statusCode {
        case 401:
            throw TranslationError.invalidApiKey(providerName)
        case 402:
            throw TranslationError.billingError(providerName)
        case 429:
            throw TranslationError.rateLimitExceeded(providerName)
        case 404:
            throw TranslationError.modelNotFound(model)
        default:
            break
        }
    }
}

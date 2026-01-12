import Foundation

/// OpenAI GPT translation provider (also works with OpenAI-compatible APIs like Ollama, LM Studio)
actor OpenAIProvider: TranslationProvider {
    let apiUrl: String
    let apiKey: String
    let model: String
    let customSystemPrompt: String?
    let autoAppendLanguages: Bool
    nonisolated let providerName: String
    
    init(apiUrl: String, apiKey: String, model: String, customSystemPrompt: String? = nil, autoAppendLanguages: Bool = true) {
        self.apiUrl = apiUrl
        self.apiKey = apiKey
        self.model = model
        self.customSystemPrompt = customSystemPrompt
        self.autoAppendLanguages = autoAppendLanguages
        
        // Determine provider name from URL
        if apiUrl.contains("localhost") || apiUrl.contains("127.0.0.1") {
            self.providerName = "Local LLM"
        } else if apiUrl.contains("openai") {
            self.providerName = "OpenAI"
        } else {
            self.providerName = "LLM"
        }
    }
    
    func translate(text: String, from sourceLang: String, to targetLang: String, timeout: TimeInterval = 30) async throws -> String {
        guard let url = URL(string: apiUrl) else {
            throw TranslationError.invalidResponse
        }
        
        // Build the translation prompt
        let sourceLanguageName = sourceLang == "auto" ? "the source language (auto-detect)" : LanguageNameMapper.displayName(for: sourceLang)
        let targetLanguageName = LanguageNameMapper.displayName(for: targetLang)
        
        var systemPrompt = customSystemPrompt ?? "You are a professional translator. Translate the following text from \(sourceLanguageName) to \(targetLanguageName). Only respond with the translation, nothing else. Do not include explanations, notes, or quotation marks around the translation."
        
        // Auto-append language context if placeholders are missing and auto-append is enabled
        if let custom = customSystemPrompt, autoAppendLanguages {
            let hasBothPlaceholders = custom.contains("{source}") && custom.contains("{target}")
            if !hasBothPlaceholders {
                systemPrompt += " Translate from {source} to {target}."
            }
        }
        
        // Replace placeholders in prompt
        let finalSystemPrompt = systemPrompt
            .replacingOccurrences(of: "{source}", with: sourceLanguageName)
            .replacingOccurrences(of: "{target}", with: targetLanguageName)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // OpenAI-compatible API format
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": finalSystemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.3,
            "max_tokens": 4096
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
        
        // Parse OpenAI-compatible response format
        // {"choices": [{"message": {"content": "..."}}], ...}
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw TranslationError.invalidResponse
        }
        
        let result = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else {
            throw TranslationError.invalidResponse
        }
        
        return result
    }
    
    func translateWithConfidence(text: String, from sourceLang: String, to targetLang: String, timeout: TimeInterval = 30) async throws -> LLMTranslationResult {
        guard let url = URL(string: apiUrl) else {
            throw TranslationError.invalidResponse
        }
        
        let sourceLanguageName = sourceLang == "auto" ? "the source language (auto-detect)" : LanguageNameMapper.displayName(for: sourceLang)
        let targetLanguageName = LanguageNameMapper.displayName(for: targetLang)
        
        // Confidence mode prompt - request JSON output
        let systemPrompt = """
        You are a professional translator. Translate the following text from \(sourceLanguageName) to \(targetLanguageName).
        
        Respond ONLY with a JSON object in this exact format (no markdown, no extra text):
        {"translation": "your translation here", "confidence": 85}
        
        The confidence score (0-100) should reflect:
        - 90-100: Clear, unambiguous text with accurate translation
        - 70-89: Good translation but some ambiguity or context uncertainty
        - 50-69: Partial or uncertain translation (unclear text, slang, or missing context)
        - 0-49: Very uncertain (garbage text, unreadable, or not actual language)
        
        If the text appears to be garbage, random characters, or not real text, return low confidence.
        """
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
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
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let startTime = Date()
        log.debug("[\(providerName)] API request (confidence): \(sourceLang) -> \(targetLang), text length: \(text.count)", category: .api)
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
        
        // Parse response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw TranslationError.invalidResponse
        }
        
        // Parse the JSON from content
        let result = parseConfidenceResponse(content)
        log.debug("[\(providerName)] API response: HTTP 200 in \(String(format: "%.0f", duration * 1000))ms, confidence: \(result.confidence)%", category: .api)
        
        return result
    }
    
    /// Parse JSON response with translation and confidence
    private func parseConfidenceResponse(_ content: String) -> LLMTranslationResult {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try to parse as JSON
        if let data = trimmed.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let translation = json["translation"] as? String {
            let confidence = json["confidence"] as? Int ?? 50
            return LLMTranslationResult(text: translation, confidence: min(100, max(0, confidence)))
        }
        
        // Try to extract JSON from markdown code block
        if let jsonMatch = trimmed.range(of: "\\{[^}]+\\}", options: .regularExpression) {
            let jsonStr = String(trimmed[jsonMatch])
            if let data = jsonStr.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let translation = json["translation"] as? String {
                let confidence = json["confidence"] as? Int ?? 50
                return LLMTranslationResult(text: translation, confidence: min(100, max(0, confidence)))
            }
        }
        
        // Fallback: treat entire response as translation with low confidence
        log.warning("[\(providerName)] Failed to parse confidence JSON, using raw response", category: .api)
        return LLMTranslationResult(text: trimmed, confidence: 50)
    }
    
    private func handleError(data: Data, statusCode: Int) throws {
        // Parse error response for specific error types
        if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = errorJson["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Unknown error"
            let errorType = error["type"] as? String ?? ""
            let errorCode = error["code"] as? String ?? ""
            
            // Check for specific error types
            if statusCode == 401 || errorType == "authentication_error" || errorCode == "invalid_api_key" {
                throw TranslationError.invalidApiKey(providerName)
            }
            if statusCode == 402 || errorCode == "insufficient_quota" || message.lowercased().contains("billing") || message.lowercased().contains("quota") || message.lowercased().contains("credits") {
                throw TranslationError.billingError(providerName)
            }
            if statusCode == 429 || errorType == "rate_limit_error" || errorCode == "rate_limit_exceeded" {
                throw TranslationError.rateLimitExceeded(providerName)
            }
            if errorCode == "model_not_found" || (message.lowercased().contains("model") && message.lowercased().contains("not found")) {
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

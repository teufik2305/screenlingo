import Foundation

/// Google Translate (unofficial API) translation provider
actor GoogleTranslateProvider: TranslationProvider {
    let apiUrl: String
    let apiKey: String
    nonisolated let providerName: String = "Google"
    
    init(apiUrl: String, apiKey: String) {
        self.apiUrl = apiUrl
        self.apiKey = apiKey
    }
    
    /// Check if URL matches v3 API pattern (v3, v3beta1, v3p1beta1, etc.)
    private func isV3Api(_ url: String) -> Bool {
        // More robust pattern matching for v3 API URLs
        // Pattern: /v3[letters/numbers/_]*[/:]
        // This should match URLs like:
        // - /v3/
        // - /v3beta1/
        // - /v3p1beta1/
        // - etc.
        if let regex = try? NSRegularExpression(pattern: #"/v3[a-zA-Z0-9_]*[/:]"#, options: .caseInsensitive) {
            let range = NSRange(url.startIndex..., in: url)
            return regex.firstMatch(in: url, range: range) != nil
        }
        return false
    }
    
    func translate(text: String, from sourceLang: String, to targetLang: String, timeout: TimeInterval = 10) async throws -> String {
        // Check which API version to use based on URL
        if isV3Api(apiUrl) {
            // Cloud Translation API v3 (requires OAuth2 access token)
            return try await translateWithV3API(text: text, from: sourceLang, to: targetLang, timeout: timeout)
        } else if apiUrl.contains("/v2") || (apiUrl.contains("translation.googleapis.com") && !isV3Api(apiUrl)) {
            // Cloud Translation API v2 (Basic) - supports API keys
            return try await translateWithV2API(text: text, from: sourceLang, to: targetLang, timeout: timeout)
        } else {
            // Free unofficial API (translate.googleapis.com/translate_a/single)
            return try await translateWithUnofficialAPI(text: text, from: sourceLang, to: targetLang, timeout: timeout)
        }
    }
    
    private func translateWithUnofficialAPI(text: String, from sourceLang: String, to targetLang: String, timeout: TimeInterval = 10) async throws -> String {
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
    
    /// Cloud Translation API v3 (Advanced) - requires OAuth2, NOT API keys
    private func translateWithV3API(text: String, from sourceLang: String, to targetLang: String, timeout: TimeInterval = 10) async throws -> String {
        guard var components = URLComponents(string: apiUrl) else {
            throw TranslationError.invalidResponse
        }
        
        guard let url = components.url else {
            throw TranslationError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        
        // V3 API requires OAuth2 Bearer token, not API key
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            log.debug("[\(providerName)] V3 API: Authorization header set (token length: \(apiKey.count))", category: .api)
        } else {
            log.warning("[\(providerName)] V3 API: No access token provided!", category: .api)
        }
        
        // V3 API requires x-goog-user-project header for quota/billing when using Application Default Credentials
        // Extract project ID from URL (format: .../v3/projects/{project-id}:translateText)
        if let projectMatch = apiUrl.range(of: #"projects/([^/:]+)"#, options: .regularExpression) {
            let projectPart = String(apiUrl[projectMatch])
            // projectPart is like "projects/gen-lang-client-0456449051", extract just the ID
            if let projectId = projectPart.split(separator: "/").last {
                request.setValue(String(projectId), forHTTPHeaderField: "x-goog-user-project")
                log.debug("[\(providerName)] V3 API: x-goog-user-project header set to: \(projectId)", category: .api)
            }
        }
        
        var body: [String: Any] = [
            "contents": [text],
            "targetLanguageCode": targetLang,
            "mimeType": "text/plain"
        ]
        
        if !sourceLang.isEmpty && sourceLang != "auto" {
            body["sourceLanguageCode"] = sourceLang
        }
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            throw TranslationError.invalidResponse
        }
        request.httpBody = httpBody
        
        let startTime = Date()
        log.debug("[\(providerName)] V3 API request: \(sourceLang) -> \(targetLang), text length: \(text.count)", category: .api)
        let (data, response) = try await URLSession.shared.data(for: request)
        let duration = Date().timeIntervalSince(startTime)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            log.warning("[\(providerName)] V3 API error: HTTP \(statusCode) in \(String(format: "%.0f", duration * 1000))ms", category: .api)
            throw TranslationError.networkError("HTTP \(statusCode)")
        }
        
        log.debug("[\(providerName)] V3 API response: HTTP 200 in \(String(format: "%.0f", duration * 1000))ms", category: .api)
        
        // V3 response: {"translations": [{"translatedText": "..."}]}
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let translations = json["translations"] as? [[String: Any]],
              let firstTranslation = translations.first,
              let translatedText = firstTranslation["translatedText"] as? String else {
            throw TranslationError.invalidResponse
        }
        
        return translatedText
    }
    
    /// Cloud Translation API v2 (Basic) - supports API keys
    private func translateWithV2API(text: String, from sourceLang: String, to targetLang: String, timeout: TimeInterval = 10) async throws -> String {
        guard var components = URLComponents(string: apiUrl) else {
            throw TranslationError.invalidResponse
        }
        
        // V2 API uses query parameters
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "q", value: text))
        queryItems.append(URLQueryItem(name: "target", value: targetLang))
        if !sourceLang.isEmpty && sourceLang != "auto" {
            queryItems.append(URLQueryItem(name: "source", value: sourceLang))
        }
        queryItems.append(URLQueryItem(name: "format", value: "text"))
        if !apiKey.isEmpty {
            queryItems.append(URLQueryItem(name: "key", value: apiKey))
        }
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw TranslationError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let startTime = Date()
        log.debug("[\(providerName)] V2 API request: \(sourceLang) -> \(targetLang), text length: \(text.count)", category: .api)
        let (data, response) = try await URLSession.shared.data(for: request)
        let duration = Date().timeIntervalSince(startTime)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            log.warning("[\(providerName)] V2 API error: HTTP \(statusCode) in \(String(format: "%.0f", duration * 1000))ms", category: .api)
            throw TranslationError.networkError("HTTP \(statusCode)")
        }
        
        log.debug("[\(providerName)] V2 API response: HTTP 200 in \(String(format: "%.0f", duration * 1000))ms", category: .api)
        
        // V2 response: {"data": {"translations": [{"translatedText": "..."}]}}
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let translations = dataObj["translations"] as? [[String: Any]],
              let firstTranslation = translations.first,
              let translatedText = firstTranslation["translatedText"] as? String else {
            throw TranslationError.invalidResponse
        }
        
        return translatedText
    }
}
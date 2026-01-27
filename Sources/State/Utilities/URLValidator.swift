import Foundation

/// URL validation and sanitization for API endpoints
/// Prevents invalid URLs from causing app loops and crashes
enum URLValidator {
    
    // MARK: - Validation Result
    
    enum ValidationResult {
        case valid
        case invalid(reason: String)
        case warning(reason: String)  // URL might work but looks suspicious
        
        var isUsable: Bool {
            switch self {
            case .valid, .warning: return true
            case .invalid: return false
            }
        }
        
        var message: String? {
            switch self {
            case .valid: return nil
            case .invalid(let reason), .warning(let reason): return reason
            }
        }
    }
    
    // MARK: - Placeholder Patterns
    
    /// Common placeholder patterns found in documentation/examples that should never be used
    private static let placeholderPatterns: [String] = [
        // Google Cloud placeholders
        "PROJECT_ID",
        "GEN_LANG_PROJECT_ID",
        "YOUR_PROJECT_ID",
        "YOUR-PROJECT-ID",
        "my-project-id",
        "MY_PROJECT_ID",
        "[PROJECT_ID]",
        "<PROJECT_ID>",
        "${PROJECT_ID}",
        "$PROJECT_ID",
        
        // API Key placeholders
        "YOUR_API_KEY",
        "YOUR-API-KEY",
        "API_KEY_HERE",
        "INSERT_API_KEY",
        "REPLACE_WITH_API_KEY",
        "sk-your-api-key",
        "sk-xxxxxxxx",
        "AIzaSy...",
        
        // Generic placeholders
        "PLACEHOLDER",
        "EXAMPLE",
        "YOUR_",
        "xxx",
        "XXX",
        "TODO",
        "<your",
        "[your",
        "{your",
        "INSERT_",
        "REPLACE_",
        "your-project-id",  // Common template placeholder
        
        // Location placeholders
        "LOCATION_ID",
        "YOUR_LOCATION"
    ]
    
    /// Regex patterns for common invalid URL structures
    private static let invalidPatterns: [(pattern: String, reason: String)] = [
        // Google Cloud v3 API with placeholder project
        (#"projects/[A-Z_]+/locations"#, "URL contains placeholder project ID"),
        (#"projects/\$\{?\w+\}?/locations"#, "URL contains variable placeholder"),
        (#"projects/\[[\w\s]+\]/locations"#, "URL contains bracketed placeholder"),
        (#"projects/<[\w\s]+>/locations"#, "URL contains angle-bracket placeholder"),
        
        // URLs with obvious template markers
        (#"\{\{.*\}\}"#, "URL contains template markers {{}}"),
        (#"\$\{[^}]+\}"#, "URL contains variable ${} placeholder"),
        (#"<%.*%>"#, "URL contains template markers <%%>"),
        
        // Incomplete URLs
        (#"^https?://[^/]+$"#, "URL missing path - may be incomplete"),
    ]
    
    /// Domains that require special validation (not outright blocked)
    private static let specialDomains: [String] = [
        "translation.googleapis.com",  // Google Cloud Translation v2 API
    ]
    
    /// Valid known API base URLs (for reference/suggestions)
    static let knownValidEndpoints: [(name: String, url: String)] = [
        ("Google Translate (free)", "https://translate.googleapis.com/translate_a/single"),
        ("LibreTranslate (local)", "http://localhost:5000/translate"),
        ("LTEngine (local)", "http://localhost:5000/translate"),
    ]
    
    // MARK: - Validation Methods
    
    /// Validate a URL string for use as an API endpoint
    static func validate(_ urlString: String) -> ValidationResult {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Empty is valid (will use default)
        if trimmed.isEmpty {
            return .valid
        }
        
        // Check basic URL validity
        guard let url = URL(string: trimmed) else {
            return .invalid(reason: "Invalid URL format")
        }
        
        // Must have a scheme
        guard let scheme = url.scheme, ["http", "https"].contains(scheme.lowercased()) else {
            return .invalid(reason: "URL must start with http:// or https://")
        }
        
        // Must have a host
        guard let host = url.host, !host.isEmpty else {
            return .invalid(reason: "URL must have a valid host")
        }
        
        // Check for placeholder patterns in the URL
        let uppercased = trimmed.uppercased()
        for placeholder in placeholderPatterns {
            if uppercased.contains(placeholder.uppercased()) {
                return .invalid(reason: "URL contains placeholder '\(placeholder)' - replace with actual value")
            }
        }
        
        // Check regex patterns
        for (pattern, reason) in invalidPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(trimmed.startIndex..., in: trimmed)
                if regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                    return .invalid(reason: reason)
                }
            }
        }
        
        // Check Google Cloud Translation API v3 URLs (matches v3, v3beta1, v3p1beta1, etc.)
        // Only translate.googleapis.com supports v3 (translation.googleapis.com is v2 only)
        let isGoogleTranslationV3 = trimmed.contains("translate.googleapis.com/v3")
        
        if isGoogleTranslationV3 {
            // Must have /projects/ path for Cloud v3 API
            if !trimmed.contains("/projects/") {
                return .invalid(reason: "Cloud Translation v3 API URL must include /projects/{PROJECT_ID}")
            }
            
            // Extract project ID - can be projects/{id}:translateText or projects/{id}/locations/...
            if let projectMatch = trimmed.range(of: #"projects/([^/:]+)"#, options: .regularExpression) {
                let projectId = String(trimmed[projectMatch]).replacingOccurrences(of: "projects/", with: "")
                
                // Check if project ID looks valid (lowercase, hyphens, numbers, 6-30 chars)
                // Google Cloud project IDs must start with a letter, be 6-30 chars, contain only
                // lowercase letters, digits, and hyphens, and cannot end with a hyphen
                let validProjectIdRegex = #"^[a-z][a-z0-9-]{4,28}[a-z0-9]$"#
                if let regex = try? NSRegularExpression(pattern: validProjectIdRegex),
                   regex.firstMatch(in: projectId, range: NSRange(projectId.startIndex..., in: projectId)) != nil {
                    // Valid Cloud v3 URL - no warning needed, UI will show OAuth info
                    return .valid
                } else {
                    return .invalid(reason: "Invalid Google Cloud project ID '\(projectId)'. Must be 6-30 lowercase letters, digits, or hyphens, starting with a letter and not ending with a hyphen.")
                }
            }
            
            // Has /projects/ but couldn't extract project ID
            return .invalid(reason: "Could not parse project ID from URL")
        }
        
        // Check for localhost with unusual ports that might indicate misconfiguration
        if host == "localhost" || host == "127.0.0.1" {
            if let port = url.port, port > 65535 {
                return .invalid(reason: "Invalid port number")
            }
            // Valid localhost URL
            return .valid
        }
        
        // Note: Incomplete v3 URL check is handled above in the isGoogleTranslationV3 block
        
        return .valid
    }
    
    /// Sanitize a URL string by removing common issues
    static func sanitize(_ urlString: String) -> String {
        var result = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove trailing slashes
        while result.hasSuffix("/") {
            result = String(result.dropLast())
        }
        
        // Remove common accidental prefixes
        result = result.replacingOccurrences(of: "URL:", with: "")
        result = result.replacingOccurrences(of: "url:", with: "")
        
        // Remove quotes that might be accidentally pasted
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))
        
        // Remove whitespace that snuck in
        result = result.replacingOccurrences(of: " ", with: "")
        
        return result
    }
    
    /// Validate and sanitize, returning the sanitized URL if valid
    static func validateAndSanitize(_ urlString: String) -> (url: String, result: ValidationResult) {
        let sanitized = sanitize(urlString)
        let result = validate(sanitized)
        return (sanitized, result)
    }
    
    /// Check if a URL is safe to use (won't cause infinite loops or crashes)
    static func isSafeToUse(_ urlString: String) -> Bool {
        validate(urlString).isUsable
    }
    
    // MARK: - Specific Validations
    
    /// Validate a Google Translate custom API URL
    static func validateGoogleApiUrl(_ urlString: String) -> ValidationResult {
        let baseResult = validate(urlString)
        // For Google API, we accept both valid and warning results
        return baseResult
    }
    
    /// Validate a LibreTranslate/LTEngine URL
    static func validateLibreTranslateUrl(_ urlString: String) -> ValidationResult {
        let baseResult = validate(urlString)
        guard baseResult.isUsable else { return baseResult }
        
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .valid }
        
        // Should typically end with /translate
        if !trimmed.hasSuffix("/translate") && !trimmed.contains("/translate?") {
            return .warning(reason: "LibreTranslate URLs typically end with '/translate'")
        }
        
        return .valid
    }
    
    /// Validate an LLM API URL
    static func validateLLMApiUrl(_ urlString: String) -> ValidationResult {
        let baseResult = validate(urlString)
        guard baseResult.isUsable else { return baseResult }
        
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .valid }
        
        // Check for common LLM API patterns
        let knownLLMPatterns = [
            "openai.com",
            "anthropic.com",
            "googleapis.com",
            "localhost",
            "127.0.0.1",
            "/v1/chat/completions",
            "/v1/messages",
            "/v1beta",
        ]
        
        let hasKnownPattern = knownLLMPatterns.contains { trimmed.lowercased().contains($0) }
        if !hasKnownPattern {
            return .warning(reason: "URL doesn't match known LLM API patterns - ensure it's correct")
        }
        
        return .valid
    }
}

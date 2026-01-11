import Foundation

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

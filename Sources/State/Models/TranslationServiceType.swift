import SwiftUI

enum TranslationServiceType: Int, CaseIterable {
    case apple = 0
    case ltEngine = 1
    case google = 2
    case llm = 3
    
    var name: String {
        switch self {
        case .apple: return "Apple"
        case .ltEngine: return "LibreTranslate"
        case .google: return "Google"
        case .llm: return "LLM"
        }
    }
    
    var icon: String {
        switch self {
        case .apple: return "apple.logo"
        case .ltEngine: return "server.rack"
        case .google: return "network"
        case .llm: return "brain"
        }
    }
    
    var color: Color {
        switch self {
        case .apple: return .blue
        case .ltEngine: return .green
        case .google: return .orange
        case .llm: return .purple
        }
    }
    
    var shortDescription: String {
        switch self {
        case .apple: return "On-device, private"
        case .ltEngine: return "Open source, flexible"
        case .google: return "Cloud API"
        case .llm: return "GPT / Claude"
        }
    }
    
    var detailedDescription: String {
        switch self {
        case .apple: 
            return "Uses Apple's built-in Translation framework. Runs entirely on your Mac — no data sent to servers. Requires macOS 15+ and language packs to be downloaded. Fast and private."
        case .ltEngine: 
            return "Connects to any LibreTranslate-compatible server (including LTEngine). Can be self-hosted locally or use a remote server. Default: localhost:5000."
        case .google: 
            return "Uses Google Translate's public API (translate.googleapis.com). Fast and reliable with broad language support. Text is sent to Google's servers. No API key required. Works out of the box."
        case .llm:
            return "Uses OpenAI GPT or Anthropic Claude for high-quality AI translation. Auto-detects provider from URL. Supports any OpenAI-compatible API (including local LLMs via Ollama, LM Studio, etc.)."
        }
    }
    
    var supportedLanguagesNote: String {
        switch self {
        case .apple:
            return "Arabic, Chinese (Simplified/Traditional), Dutch, English, French, German, Hindi, Indonesian, Italian, Japanese, Korean, Polish, Portuguese (Brazil), Russian, Spanish, Thai, Turkish, Ukrainian, Vietnamese"
        case .ltEngine:
            return "Languages fetched from your configured server"
        case .google:
            return "Supports 100+ languages including Bosnian, Croatian, Serbian"
        case .llm:
            return "Supports all languages the LLM model understands"
        }
    }
    
    // Language codes supported by each service
    var supportedLanguageCodes: Set<String>? {
        switch self {
        case .apple:
            // Apple Translation supported languages (macOS 15+)
            return ["ar", "zh", "zh-Hans", "zh-Hant", "nl", "en", "fr", "de", "hi", "id", "it", "ja", "ko", "pl", "pt", "pt-BR", "ru", "es", "th", "tr", "uk", "vi"]
        case .ltEngine, .google, .llm:
            return nil  // All languages supported
        }
    }
    
    func isLanguageSupported(_ code: String) -> Bool {
        if code == "auto" { return supportsAutoDetect }
        guard let supported = supportedLanguageCodes else { return true }
        return supported.contains(code)
    }
    
    // Whether this service supports automatic language detection
    var supportsAutoDetect: Bool {
        switch self {
        case .ltEngine, .google, .llm: return true
        case .apple: return false
        }
    }
}

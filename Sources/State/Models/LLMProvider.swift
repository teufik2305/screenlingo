import Foundation

enum LLMProvider: String {
    case openai = "OpenAI"
    case anthropic = "Claude"
    case gemini = "Gemini"
    case local = "Local LLM"  // Ollama, LM Studio, vLLM, etc.
    case other = "OpenAI-compatible"
    
    var defaultModel: String {
        switch self {
        case .openai: return "gpt-4.1-mini"  // Fast & efficient (Apr 2025)
        case .anthropic: return "claude-haiku-4-5"  // Fast & efficient (Oct 2025)
        case .gemini: return "gemini-2.5-flash"  // Fast & efficient (Jun 2025)
        case .local: return "llama4"  // Latest Llama model
        case .other: return "custom-model"  // User should specify their model
        }
    }
}

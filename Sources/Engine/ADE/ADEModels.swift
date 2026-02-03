import Foundation
import CoreGraphics

// MARK: - ADE Provider Types

/// ADE Provider detection - similar to TranslationService LLM detection
enum ADEDetectedProvider: String, CaseIterable, Identifiable {
    case local = "Local"
    case gemini = "Gemini"
    case anthropic = "Claude"
    case openAI = "OpenAI"
    case other = "Other"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .local: return "Local (Ollama, vLLM, etc.)"
        case .gemini: return "Google Gemini"
        case .anthropic: return "Anthropic Claude"
        case .openAI: return "OpenAI"
        case .other: return "Other (OpenAI-compatible)"
        }
    }
    
    var icon: String {
        switch self {
        case .local: return "desktopcomputer"
        case .gemini: return "diamond"
        case .anthropic: return "brain.head.profile"
        case .openAI: return "sparkles"
        case .other: return "server.rack"
        }
    }
    
    var color: String {
        switch self {
        case .local: return "gray"
        case .gemini: return "blue"
        case .anthropic: return "orange"
        case .openAI: return "green"
        case .other: return "purple"
        }
    }
    
    /// Detect provider from URL
    static func detect(from url: String) -> ADEDetectedProvider {
        let lowercased = url.lowercased()
        
        if lowercased.contains("localhost") || lowercased.contains("127.0.0.1") {
            return .local
        } else if lowercased.contains("generativelanguage.googleapis.com") && !lowercased.contains("/openai/") {
            return .gemini
        } else if lowercased.contains("anthropic.com") || lowercased.contains("claude") {
            return .anthropic
        } else if lowercased.contains("openai.com") {
            return .openAI
        } else {
            return .other
        }
    }
}

// MARK: - Extracted Text Block

struct ExtractedTextBlock: Identifiable, Codable {
    let id: UUID
    var text: String
    var boundingBox: CGRect  // Normalized coordinates (0-1)
    var type: TextType
    var speaker: String?     // Character name if identifiable
    var readingOrder: Int    // 1, 2, 3... for proper sequence
    var confidence: Double   // Extraction confidence (0-1)
    var merged: Bool         // Whether this was merged from multiple fragments
    
    enum CodingKeys: String, CodingKey {
        case id, text, boundingBox, type, speaker, readingOrder, confidence, merged
    }
    
    init(
        id: UUID = UUID(),
        text: String,
        boundingBox: CGRect,
        type: TextType = .unknown,
        speaker: String? = nil,
        readingOrder: Int = 0,
        confidence: Double = 1.0,
        merged: Bool = false
    ) {
        self.id = id
        self.text = text
        self.boundingBox = boundingBox
        self.type = type
        self.speaker = speaker
        self.readingOrder = readingOrder
        self.confidence = confidence
        self.merged = merged
    }
}

// MARK: - Text Types

enum TextType: String, Codable, CaseIterable {
    case speech = "speech"
    case narration = "narration"
    case thought = "thought"
    case soundEffect = "sound_effect"
    case title = "title"
    case caption = "caption"
    case signature = "signature"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .speech: return "Speech"
        case .narration: return "Narration"
        case .thought: return "Thought"
        case .soundEffect: return "Sound Effect"
        case .title: return "Title"
        case .caption: return "Caption"
        case .signature: return "Signature"
        case .unknown: return "Unknown"
        }
    }
    
    var icon: String {
        switch self {
        case .speech: return "bubble.left.fill"
        case .narration: return "text.alignleft"
        case .thought: return "cloud.fill"
        case .soundEffect: return "speaker.wave.2.fill"
        case .title: return "textformat.size"
        case .caption: return "rectangle.below.line.horizontal"
        case .signature: return "pencil.line"
        case .unknown: return "questionmark.circle"
        }
    }
}

// MARK: - ADE Request/Response

struct ADERequest {
    let image: CGImage
    let previousBlocks: [ExtractedTextBlock]?  // For temporal consistency
    let languageHint: String?  // Expected language (e.g., "ja", "fr")
}

struct ADEResponse {
    let blocks: [ExtractedTextBlock]
    let processingTime: TimeInterval
    let tokensUsed: Int?
    let model: String
}

// MARK: - ADE Error Types

enum ADEError: Error, LocalizedError {
    case noVisionSupport
    case extractionFailed(String)
    case invalidResponse
    case modelNotAvailable(String)
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .noVisionSupport:
            return "Selected model does not support vision/image input"
        case .extractionFailed(let message):
            return "Extraction failed: \(message)"
        case .invalidResponse:
            return "Invalid response from ADE provider"
        case .modelNotAvailable(let model):
            return "Model '\(model)' is not available"
        case .timeout:
            return "ADE extraction timed out"
        }
    }
}

// MARK: - ADE Settings

struct ADESettings {
    var enabled: Bool = false
    var apiUrl: String = "http://localhost:11434/v1/chat/completions"
    var apiKey: String = ""
    var model: String = "qwen3-vl:8b"
    var timeout: TimeInterval = 30.0
    var enableCaching: Bool = true
    
    // Advanced options
    var mergeFragments: Bool = true
    var correctOCRErrors: Bool = true
    var classifyTextType: Bool = true
    var preserveReadingOrder: Bool = true
    
    /// Detected provider based on URL
    var detectedProvider: ADEDetectedProvider {
        ADEDetectedProvider.detect(from: apiUrl)
    }
    
    /// Default models by provider
    static let defaultModels: [ADEDetectedProvider: String] = [
        .local: "qwen3-vl:8b",
        .gemini: "gemini-2.5-flash",
        .anthropic: "claude-3-haiku-20240307",
        .openAI: "gpt-4o-mini",
        .other: "gpt-4o-mini"
    ]
    
    /// Preset URLs by provider type
    static let presetUrls: [ADEDetectedProvider: String] = [
        .local: "http://localhost:11434/v1/chat/completions",
        .gemini: "https://generativelanguage.googleapis.com/v1beta",
        .anthropic: "https://api.anthropic.com/v1/messages",
        .openAI: "https://api.openai.com/v1/chat/completions",
        .other: ""
    ]
}

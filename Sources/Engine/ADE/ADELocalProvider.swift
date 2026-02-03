import Foundation
import CoreGraphics
import ImageIO

/// Local Ollama provider for ADE - uses vision-capable models
actor ADELocalProvider: ADEProviderInterface {
    private let baseURL: String
    private let model: String
    private let timeout: TimeInterval
    
    init(baseURL: String, model: String, timeout: TimeInterval) {
        self.baseURL = baseURL
        self.model = model
        self.timeout = timeout
    }
    
    func checkAvailability() async throws -> Bool {
        // Build tags URL (works for both endpoint types)
        let tagsURL: URL?
        if baseURL.hasSuffix("/api/generate") {
            tagsURL = URL(string: baseURL)?.deletingLastPathComponent().appendingPathComponent("tags")
        } else {
            // For /v1/chat/completions, try the standard Ollama tags endpoint
            tagsURL = URL(string: "http://localhost:11434/api/tags")
        }
        
        guard let url = tagsURL else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                return models.contains { ($0["name"] as? String)?.hasPrefix(model) == true }
            }
            return false
        } catch {
            log.warning("Ollama not available at \(baseURL): \(error)", category: .ocr)
            return false
        }
    }
    
    func extract(request: ADERequest) async throws -> ADEResponse {
        // Determine if using native Ollama or OpenAI-compatible endpoint
        let isNativeOllama = baseURL.hasSuffix("/api/generate")
        
        let urlString = isNativeOllama ? baseURL : baseURL
        guard let url = URL(string: urlString) else {
            throw ADEError.extractionFailed("Invalid URL: \(baseURL)")
        }
        
        // Convert image to base64
        guard let imageData = request.image.pngData else {
            throw ADEError.extractionFailed("Failed to encode image")
        }
        let base64Image = imageData.base64EncodedString()
        
        // Build prompt
        let prompt = buildExtractionPrompt(languageHint: request.languageHint)
        
        // Build request body based on endpoint type
        let body: [String: Any]
        
        if isNativeOllama {
            // Native Ollama /api/generate endpoint
            body = [
                "model": model,
                "prompt": "\(prompt)\n\n[IMAGE: data:image/png;base64,\(base64Image.prefix(100))...]",
                "images": [base64Image],
                "stream": false,
                "options": [
                    "temperature": 0.1
                ]
            ]
        } else {
            // OpenAI-compatible /v1/chat/completions endpoint
            body = [
                "model": model,
                "messages": [
                    [
                        "role": "user",
                        "content": [
                            ["type": "text", "text": prompt],
                            [
                                "type": "image_url",
                                "image_url": ["url": "data:image/png;base64,\(base64Image)"]
                            ]
                        ]
                    ]
                ],
                "stream": false,
                "options": [
                    "temperature": 0.1
                ]
            ]
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = timeout
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        log.debug("Sending ADE request to Ollama: \(model)", category: .ocr)
        
        let startTime = Date()
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw ADEError.extractionFailed("HTTP \(statusCode)")
        }
        
        // Parse response (handle both native Ollama and OpenAI-compatible formats)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ADEError.invalidResponse
        }
        
        // Extract content based on endpoint type
        let content: String
        if isNativeOllama {
            // Native Ollama /api/generate returns "response"
            guard let responseText = json["response"] as? String else {
                throw ADEError.invalidResponse
            }
            content = responseText
        } else {
            // OpenAI-compatible /v1/chat/completions returns message.content
            guard let message = json["message"] as? [String: Any],
                  let messageContent = message["content"] as? String else {
                throw ADEError.invalidResponse
            }
            content = messageContent
        }
        
        // Extract JSON from response (handle markdown code blocks)
        let jsonString = extractJSON(from: content)
        
        guard let jsonData = jsonString.data(using: .utf8),
              let result = try? JSONDecoder().decode(ADEExtractionResult.self, from: jsonData) else {
            log.warning("Failed to parse ADE response: \(content.prefix(200))", category: .ocr)
            throw ADEError.invalidResponse
        }
        
        let duration = Date().timeIntervalSince(startTime)
        // Token count field differs between endpoints
        let tokensUsed = isNativeOllama 
            ? (json["eval_count"] as? Int) 
            : (json["usage"] as? [String: Int])?["total_tokens"]
        
        // Convert to ExtractedTextBlock
        let blocks = result.textBlocks.enumerated().map { index, block in
            ExtractedTextBlock(
                text: block.text,
                boundingBox: CGRect(
                    x: block.x,
                    y: block.y,
                    width: block.width,
                    height: block.height
                ),
                type: TextType(rawValue: block.type) ?? .unknown,
                speaker: block.speaker,
                readingOrder: block.readingOrder ?? (index + 1),
                confidence: block.confidence ?? 0.9,
                merged: block.merged ?? false
            )
        }
        
        return ADEResponse(
            blocks: blocks,
            processingTime: duration,
            tokensUsed: tokensUsed,
            model: model
        )
    }
    
    // MARK: - Private
    
    private func buildExtractionPrompt(languageHint: String?) -> String {
        let langHint = languageHint.map { "The text is expected to be in \($0.uppercased())." } ?? ""
        
        return """
        You are an expert manga/comic text extraction AI. Your task is to:
        1. Identify ALL text in the image (speech bubbles, narration, sound effects, titles)
        2. Extract the exact text content
        3. Provide normalized bounding box coordinates (0-1 range)
        4. Classify each text block type
        5. Determine reading order (left-to-right, top-to-bottom for manga)
        
        \(langHint)
        
        Text Types:
        - speech: Text inside speech bubbles (characters speaking)
        - narration: Boxed text, usually rectangular, story narration
        - thought: Cloud-shaped bubbles, character thoughts
        - sound_effect: Onomatopoeia (BAM!, POW!, etc.)
        - title: Chapter titles, section headers
        - caption: Small descriptive text
        
        Rules:
        - Return ONLY valid JSON, no markdown, no explanations
        - Merge fragmented text that belongs together
        - Fix obvious OCR errors
        - Preserve original language (don't translate)
        - Coordinates are normalized (0.0 to 1.0)
        - Reading order starts at 1
        - Confidence is 0.0 to 1.0
        
        Output format:
        {
          "textBlocks": [
            {
              "text": "extracted text content",
              "x": 0.1,
              "y": 0.2,
              "width": 0.3,
              "height": 0.1,
              "type": "speech",
              "speaker": "Character Name (if visible)",
              "readingOrder": 1,
              "confidence": 0.95,
              "merged": false
            }
          ]
        }
        """
    }
    
    private func extractJSON(from content: String) -> String {
        // Remove markdown code blocks if present
        var cleaned = content
        
        if let start = cleaned.range(of: "```json"),
           let end = cleaned.range(of: "```", range: start.upperBound..<cleaned.endIndex) {
            cleaned = String(cleaned[start.upperBound..<end.lowerBound])
        } else if let start = cleaned.range(of: "```"),
                  let end = cleaned.range(of: "```", range: start.upperBound..<cleaned.endIndex) {
            cleaned = String(cleaned[start.upperBound..<end.lowerBound])
        }
        
        // Trim whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Find JSON object bounds
        if let start = cleaned.firstIndex(of: "{"),
           let end = cleaned.lastIndex(of: "}") {
            return String(cleaned[start...end])
        }
        
        return cleaned
    }
}

// MARK: - Response Models

private struct ADEExtractionResult: Codable {
    let textBlocks: [ADETextBlock]
}

private struct ADETextBlock: Codable {
    let text: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let type: String
    let speaker: String?
    let readingOrder: Int?
    let confidence: Double?
    let merged: Bool?
}

// MARK: - CGImage Extensions

extension CGImage {
    var pngData: Data? {
        let mutableData = CFDataCreateMutable(nil, 0)
        let pngType = kUTTypePNG as CFString
        guard let destination = CGImageDestinationCreateWithData(
            mutableData!,
            pngType,
            1,
            nil
        ) else { return nil }
        
        CGImageDestinationAddImage(destination, self, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        
        return mutableData as Data?
    }
}

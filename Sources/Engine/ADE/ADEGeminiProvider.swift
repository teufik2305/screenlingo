import Foundation
import CoreGraphics

/// Google Gemini native API provider for ADE
actor ADEGeminiProvider: ADEProviderInterface {
    let apiUrl: String
    let apiKey: String
    let model: String
    
    private static let defaultBaseUrl = "https://generativelanguage.googleapis.com/v1beta"
    
    init(apiUrl: String? = nil, apiKey: String, model: String) {
        let baseUrl = (apiUrl ?? Self.defaultBaseUrl).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.apiUrl = baseUrl
        self.apiKey = apiKey
        self.model = model
    }
    
    func checkAvailability() async throws -> Bool {
        // Just check URL and credentials are set
        return !apiUrl.isEmpty && !apiKey.isEmpty && !model.isEmpty
    }
    
    func extract(request: ADERequest) async throws -> ADEResponse {
        // Build the API URL
        let fullUrl = "\(apiUrl)/models/\(model):generateContent"
        guard var urlComponents = URLComponents(string: fullUrl) else {
            throw ADEError.extractionFailed("Invalid URL")
        }
        urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        
        guard let url = urlComponents.url else {
            throw ADEError.extractionFailed("Invalid URL components")
        }
        
        // Convert image to base64
        guard let imageData = request.image.pngData else {
            throw ADEError.extractionFailed("Failed to encode image")
        }
        let base64Image = imageData.base64EncodedString()
        
        // Build the extraction prompt
        let prompt = buildExtractionPrompt(languageHint: request.languageHint)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 60  // Vision can take longer
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Gemini native API format with image
        let body: [String: Any] = [
            "systemInstruction": [
                "parts": [
                    ["text": prompt]
                ]
            ],
            "contents": [
                [
                    "parts": [
                        [
                            "inlineData": [
                                "mimeType": "image/png",
                                "data": base64Image
                            ]
                        ],
                        [
                            "text": "Extract all text from this image and return as JSON."
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "maxOutputTokens": 4096,
                "responseMimeType": "application/json"
            ]
        ]
        
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let startTime = Date()
        log.debug("[ADE Gemini] Sending request with image: \(base64Image.prefix(50))...", category: .ocr)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ADEError.extractionFailed("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            let statusCode = httpResponse.statusCode
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw ADEError.extractionFailed("Gemini API error: \(message)")
            }
            throw ADEError.extractionFailed("HTTP \(statusCode)")
        }
        
        // Parse Gemini response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw ADEError.invalidResponse
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Parse the JSON response from Gemini
        guard let jsonData = text.data(using: .utf8),
              let result = try? JSONDecoder().decode(ADEExtractionResult.self, from: jsonData) else {
            log.warning("Failed to parse Gemini ADE response: \(text.prefix(200))", category: .ocr)
            throw ADEError.invalidResponse
        }
        
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
            tokensUsed: nil,
            model: model
        )
    }
    
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

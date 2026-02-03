import Foundation
import CoreGraphics

/// Agentic Document Extraction (ADE) - Uses LLM to intelligently extract text from images
actor ADEAgent {
    private let settings: ADESettings
    private static let sharedCache = ADECache()
    private var currentProvider: ADEProviderInterface?
    
    init(settings: ADESettings) {
        self.settings = settings
    }
    
    /// Main extraction entry point
    func extract(from image: CGImage, languageHint: String? = nil) async throws -> [ExtractedTextBlock] {
        guard settings.enabled else {
            throw ADEError.extractionFailed("ADE is not enabled")
        }
        
        // Check cache first
        if settings.enableCaching {
            let imageHash = await Self.sharedCache.hash(image)
            if let cached = await Self.sharedCache.get(hash: imageHash) {
                log.debug("ADE cache hit: \(imageHash.prefix(16))...", category: .ocr)
                return cached
            }
        }
        
        let startTime = Date()
        
        // Get appropriate provider
        let provider = try await getProvider()
        
        // Perform extraction
        let request = ADERequest(
            image: image,
            previousBlocks: nil,
            languageHint: languageHint
        )
        
        let response = try await provider.extract(request: request)
        
        let duration = Date().timeIntervalSince(startTime)
        log.info("ADE extraction completed: \(response.blocks.count) blocks in \(String(format: "%.0f", duration * 1000))ms", category: .ocr)
        
        // Sort by reading order
        let sortedBlocks = response.blocks.sorted { $0.readingOrder < $1.readingOrder }
        
        // Cache result
        if settings.enableCaching {
            let imageHash = await Self.sharedCache.hash(image)
            await Self.sharedCache.set(hash: imageHash, blocks: sortedBlocks)
            log.debug("ADE cached: \(imageHash.prefix(16))... (\(sortedBlocks.count) blocks)", category: .ocr)
        }
        
        return sortedBlocks
    }
    
    /// Quick extraction for settings preview/testing
    func testExtract(from image: CGImage) async -> Result<[ExtractedTextBlock], ADEError> {
        do {
            let blocks = try await extract(from: image)
            return .success(blocks)
        } catch let error as ADEError {
            return .failure(error)
        } catch {
            return .failure(.extractionFailed(error.localizedDescription))
        }
    }
    
    /// Update settings dynamically
    func updateSettings(_ newSettings: ADESettings) {
        // Invalidate provider if settings changed
        if newSettings.apiUrl != settings.apiUrl ||
           newSettings.apiKey != settings.apiKey ||
           newSettings.model != settings.model {
            currentProvider = nil
        }
    }
    
    // MARK: - Provider Factory
    
    /// Create appropriate ADE provider based on URL (like TranslationService)
    private func createADEProvider(settings: ADESettings) -> ADEProviderInterface {
        let detectedProvider = settings.detectedProvider
        log.debug("[ADE] Detected provider: \(detectedProvider.displayName)", category: .ocr)
        
        switch detectedProvider {
        case .local:
            return ADELocalProvider(
                baseURL: settings.apiUrl,
                model: settings.model,
                timeout: settings.timeout
            )
            
        case .gemini:
            return ADEGeminiProvider(
                apiUrl: settings.apiUrl,
                apiKey: settings.apiKey,
                model: settings.model
            )
            
        case .anthropic:
            return ADEAnthropicProvider(
                apiUrl: settings.apiUrl,
                apiKey: settings.apiKey,
                model: settings.model
            )
            
        case .openAI, .other:
            return ADECustomProvider(
                apiURL: settings.apiUrl,
                apiKey: settings.apiKey,
                model: settings.model,
                timeout: settings.timeout
            )
        }
    }
    
    // MARK: - Private
    
    private func getProvider() async throws -> ADEProviderInterface {
        if let provider = currentProvider {
            return provider
        }
        
        // Auto-detect provider from URL (like TranslationService)
        let provider = createADEProvider(settings: settings)
        
        // Verify model availability
        let isAvailable = try await provider.checkAvailability()
        guard isAvailable else {
            throw ADEError.modelNotAvailable(settings.model)
        }
        
        currentProvider = provider
        return provider
    }
}

// MARK: - Provider Interface

protocol ADEProviderInterface {
    func extract(request: ADERequest) async throws -> ADEResponse
    func checkAvailability() async throws -> Bool
}

// MARK: - Simple Cache for ADE

actor ADECache {
    private var cache: [String: [ExtractedTextBlock]] = [:]
    private let maxSize = 50
    private var order: [String] = []
    
    func get(hash: String) -> [ExtractedTextBlock]? {
        return cache[hash]
    }
    
    func set(hash: String, blocks: [ExtractedTextBlock]) {
        // Remove old entries if at capacity
        while order.count >= maxSize {
            let oldest = order.removeFirst()
            cache.removeValue(forKey: oldest)
        }
        
        cache[hash] = blocks
        order.append(hash)
    }
    
    func hash(_ image: CGImage) -> String {
        // Simple perceptual hash - resize and sample pixels
        let width = 32
        let height = 32
        
        guard let resized = image.resized(to: CGSize(width: width, height: height)) else {
            return UUID().uuidString
        }
        
        // Create hash from pixel data
        var hashString = ""
        for y in 0..<height {
            for x in 0..<width {
                if let color = resized.pixelColor(x: x, y: y) {
                    let gray = Int((color.red + color.green + color.blue) / 3.0 * 255)
                    hashString += String(format: "%02x", gray)
                }
            }
        }
        
        return hashString
    }
}

// MARK: - CGImage Extensions

extension CGImage {
    func resized(to newSize: CGSize) -> CGImage? {
        let width = Int(newSize.width)
        let height = Int(newSize.height)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        
        context.interpolationQuality = .high
        context.draw(self, in: CGRect(origin: .zero, size: newSize))
        
        return context.makeImage()
    }
    
    func pixelColor(x: Int, y: Int) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)? {
        let width = self.width
        let height = self.height
        
        guard x >= 0, x < width, y >= 0, y < height else { return nil }
        
        let dataSize = width * height * 4
        var pixelData = [UInt8](repeating: 0, count: dataSize)
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 4 * width,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(self, in: rect)
        
        let index = (y * width + x) * 4
        let r = CGFloat(pixelData[index]) / 255.0
        let g = CGFloat(pixelData[index + 1]) / 255.0
        let b = CGFloat(pixelData[index + 2]) / 255.0
        let a = CGFloat(pixelData[index + 3]) / 255.0
        
        return (r, g, b, a)
    }
}

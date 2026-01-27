import Foundation
import AppKit

struct TranslatedTextBlock {
    let originalText: String
    let translatedText: String
    let boundingBox: CGRect
    let confidence: Float
}

/// Main engine that orchestrates window capture, OCR, and translation
class RealTimeTranslationEngine {
    private let sourceLanguage: String
    private let targetLanguage: String
    private let translatorState: TranslatorState
    private let onUpdate: ([TranslatedTextBlock], NSScreen?) -> Void  // Includes target screen for multi-monitor
    private let onClear: () -> Void
    private let onPermissionError: (() -> Void)?
    
    private var isRunning = false
    private var captureTask: Task<Void, Never>?
    
    // Services
    private let cache: TranslationCache
    private let ocrProcessor: OCRProcessor
    private let windowCapture: WindowCaptureService
    
    // Change detection
    private var lastImageHash: String = ""
    private var lastWindowPID: Int32 = 0
    private var lastAppName: String = ""
    private var contentVersion: Int = 0  // Increments when content changes, used to discard stale translations
    private var consecutiveHashChanges: Int = 0  // Track consecutive hash changes to debounce
    private let hashChangeThreshold: Int = 3  // Require 3 consecutive changes before clearing (reduces flicker from overlay drawing)
    private var lastUpdateTime: Date?  // Track when we last sent an update to avoid clearing too soon
    
    // Timing
    private var isTranslating = false
    
    // Permission tracking
    private var hasNotifiedPermissionError = false
    
    // Track if currently in excluded app to clear overlay when switching to it
    private var isInExcludedApp = false
    
    // Rate limit handling
    private var lastRateLimitTime: Date?
    
    // Request throttling
    private let requestThrottler = RequestThrottler()
    
    // Multi-monitor support: track current screen
    private var currentScreen: NSScreen?
    
    init(sourceLanguage: String, targetLanguage: String, translatorState: TranslatorState, onUpdate: @escaping ([TranslatedTextBlock], NSScreen?) -> Void, onClear: @escaping () -> Void = {}, onPermissionError: (() -> Void)? = nil) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.translatorState = translatorState
        self.onUpdate = onUpdate
        self.onClear = onClear
        self.onPermissionError = onPermissionError
        
        // Initialize services
        self.cache = TranslationCache(maxSize: translatorState.maxCacheSize)
        self.ocrProcessor = OCRProcessor(translatorState: translatorState)
        self.windowCapture = WindowCaptureService()
        
        // Configure logger
        log.configure(
            logFilePath: translatorState.logFilePath, 
            minLevel: translatorState.logLevel,
            enableFileLogging: translatorState.enableFileLogging
        )
        
        // Load cache from file if enabled
        if translatorState.enableCachePersistence {
            let path = translatorState.effectiveCacheFilePath
            _ = cache.load(from: path)
        }
    }
    
    deinit {
        // Save cache to file if enabled
        if translatorState.enableCachePersistence {
            let path = translatorState.effectiveCacheFilePath
            _ = cache.save(to: path)
        }
    }
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        
        log.engineStarted()
        log.info("Source: \(sourceLanguage) -> Target: \(targetLanguage)", category: .engine)
        
        // Start scroll detection if enabled
        if translatorState.scrollDetectionEnabled {
            ScrollMonitor.shared.cooldown = translatorState.scrollCooldown
            ScrollMonitor.shared.onScrollStart = { [weak self] in
                // Clear overlay when scrolling starts
                self?.lastImageHash = ""  // Force re-process after scroll
                self?.onClear()
            }
            ScrollMonitor.shared.startMonitoring()
            log.info("Scroll detection enabled (cooldown: \(Int(translatorState.scrollCooldown * 1000))ms)", category: .engine)
        }
        
        // Log translation service
        if translatorState.useLLM {
            let provider = translatorState.detectedLLMProvider
            log.info("Translation Service: LLM (\(provider))", category: .engine)
            log.info("LLM API: \(translatorState.llmApiUrl)", category: .engine)
            log.info("LLM Model: \(translatorState.llmModel)", category: .engine)
        } else if translatorState.useLibreTranslate {
            log.info("Translation Service: LibreTranslate/LTEngine", category: .engine)
            log.info("LibreTranslate URL: \(translatorState.libreTranslateUrl)", category: .engine)
        } else if translatorState.useAppleTranslation {
            log.info("Translation Service: Apple Translation", category: .engine)
        } else {
            log.info("Translation Service: Google Translate", category: .engine)
            if !translatorState.customApiUrl.isEmpty {
                log.info("Custom API: \(translatorState.customApiUrl)", category: .engine)
            }
        }
        
        // Log performance settings
        log.info("Max Concurrent Translations: \(translatorState.maxConcurrentTranslations)", category: .engine)
        log.info("Translation Delay: \(Int(translatorState.translationDelay * 1000))ms", category: .engine)
        log.info("Rate Limit Backoff: \(translatorState.rateLimitBackoff)s", category: .engine)
        log.info("Cache Persistence: \(translatorState.enableCachePersistence ? "enabled" : "disabled")", category: .engine)
        
        captureTask = Task { [weak self] in
            await self?.runCaptureLoop()
        }
    }
    
    func stop() {
        isRunning = false
        captureTask?.cancel()
        captureTask = nil
        ScrollMonitor.shared.stopMonitoring()
        log.engineStopped()
    }
    
    /// Clear all cached translations
    func clearCache() {
        cache.clear()
        log.info("Translation cache cleared", category: .engine)
    }
    
    func deleteCacheFile() {
        let path = translatorState.effectiveCacheFilePath
        log.info("Deleting cache file at: \(path)", category: .engine)
        let success = cache.deleteFile(at: path)
        if success {
            log.info("Cache file deleted successfully", category: .engine)
        } else {
            log.error("Failed to delete cache file", category: .engine)
        }
    }
    
    func saveCache() {
        if translatorState.enableCachePersistence {
            let path = translatorState.effectiveCacheFilePath
            _ = cache.save(to: path)
        }
    }
    
    /// Get current cache size
    var cacheSize: Int {
        cache.size
    }
    
    private func notifyPermissionError() {
        guard !hasNotifiedPermissionError else { return }
        hasNotifiedPermissionError = true
        DispatchQueue.main.async { [weak self] in
            self?.onPermissionError?()
        }
    }
    
    private func runCaptureLoop() async {
        while isRunning && !Task.isCancelled {
            do {
                guard let captureResult = await windowCapture.captureFrontmost() else {
                    try await Task.sleep(nanoseconds: 200_000_000)
                    continue
                }
                
                // Check if app is excluded
                if translatorState.isAppExcluded(NSWorkspace.shared.frontmostApplication?.bundleIdentifier) {
                    if !isInExcludedApp {
                        isInExcludedApp = true
                        log.appExcluded(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown")
                        log.debug("Engine: App excluded, calling onClear()", category: .ui)
                        await MainActor.run { onClear() }
                    }
                    try await Task.sleep(nanoseconds: 200_000_000)
                    continue
                }
                
                if isInExcludedApp {
                    isInExcludedApp = false
                    lastImageHash = ""
                    consecutiveHashChanges = 0  // Reset on app change
                    log.info("Returned from excluded app, forcing re-translation", category: .engine)
                }
                
                // Clear translations if window changed
                if captureResult.processID != lastWindowPID && lastWindowPID != 0 {
                    log.windowChanged(from: lastAppName, to: captureResult.appName)
                    lastImageHash = ""
                    consecutiveHashChanges = 0  // Reset on window change
                    log.debug("Engine: Window changed, calling onClear()", category: .ui)
                    onClear()
                }
                lastWindowPID = captureResult.processID
                lastAppName = captureResult.appName
                
                // Track screen changes for multi-monitor support
                currentScreen = captureResult.screen
                
                log.windowCaptured(app: captureResult.appName, size: captureResult.bounds.size)
                
                // Skip processing while scrolling (if enabled)
                if translatorState.scrollDetectionEnabled && ScrollMonitor.shared.isScrolling {
                    try await Task.sleep(nanoseconds: UInt64(translatorState.captureInterval * 1_000_000_000))
                    continue
                }
                
                let currentHash = windowCapture.hashImage(captureResult.image)
                if currentHash == lastImageHash {
                    // Hash is same, reset consecutive change counter
                    consecutiveHashChanges = 0
                    try await Task.sleep(nanoseconds: UInt64(translatorState.captureInterval * 1_000_000_000))
                    continue
                }
                
                // Hash changed - increment counter but only clear if threshold reached (debouncing)
                consecutiveHashChanges += 1
                
                // Don't clear too soon after an update - the overlay drawing changes the screen hash
                let updateCooldown: TimeInterval = 0.3  // 300ms cooldown after updates
                let isInCooldown = lastUpdateTime != nil && Date().timeIntervalSince(lastUpdateTime!) < updateCooldown
                
                let contentChanged = !lastImageHash.isEmpty && consecutiveHashChanges >= hashChangeThreshold && !isInCooldown
                
                if contentChanged {
                    contentVersion += 1
                    consecutiveHashChanges = 0  // Reset after clearing
                    log.debug("Engine: Content changed (version \(contentVersion)), calling onClear()", category: .ui)
                    onClear()
                } else if consecutiveHashChanges == 1 {
                    log.debug("Engine: Hash changed but waiting for confirmation (changes: \(consecutiveHashChanges)/\(hashChangeThreshold))", category: .ui)
                } else if isInCooldown && consecutiveHashChanges >= hashChangeThreshold {
                    log.debug("Engine: Hash changed but in cooldown after update, skipping clear", category: .ui)
                    consecutiveHashChanges = 0  // Reset to avoid immediate clear after cooldown
                }
                
                lastImageHash = currentHash
                let translationVersion = contentVersion  // Capture version for this batch
                
                let ocrStart = Date()
                let textObservations = try await ocrProcessor.recognizeText(in: captureResult.image, sourceLanguage: sourceLanguage)
                let ocrDuration = Date().timeIntervalSince(ocrStart)
                log.ocrCompleted(regions: textObservations.count, duration: ocrDuration)
                
                let groupedObservations = ocrProcessor.groupObservations(textObservations)
                
                // Fast path: if all texts are cached, update positions immediately
                let (cachedBlocks, uncachedGroups) = separateCachedGroups(groupedObservations, windowBounds: captureResult.bounds)
                
                // Show cached blocks immediately (always, even if there are uncached)
                if !cachedBlocks.isEmpty {
                    log.debug("Engine: Calling onUpdate with \(cachedBlocks.count) cached blocks (screen: \(currentScreen?.localizedName ?? "nil"))", category: .ui)
                    lastUpdateTime = Date()
                    onUpdate(cachedBlocks, currentScreen)
                }
                
                // Slow path: translate new texts (only if not already translating)
                if !uncachedGroups.isEmpty && !isTranslating {
                    // Check if we're in rate limit backoff period
                    if let lastRateLimit = lastRateLimitTime,
                       Date().timeIntervalSince(lastRateLimit) < translatorState.rateLimitBackoff {
                        // Skip translation during backoff
                        try await Task.sleep(nanoseconds: UInt64(translatorState.captureInterval * 1_000_000_000))
                        continue
                    }
                    
                    isTranslating = true
                    let newBlocks = await translateGroups(uncachedGroups, windowBounds: captureResult.bounds)
                    isTranslating = false
                    
                    // Discard results if content changed while translating (stale positions)
                    guard translationVersion == contentVersion else {
                        log.debug("Discarding stale translation results (content changed)", category: .engine)
                        continue
                    }
                    
                    // Update with all available blocks (cached + new)
                    let allBlocks = cachedBlocks + newBlocks
                    if !allBlocks.isEmpty {
                        log.blocksCreated(allBlocks.count)
                        log.debug("Engine: Calling onUpdate with \(allBlocks.count) total blocks (\(cachedBlocks.count) cached + \(newBlocks.count) new) (screen: \(currentScreen?.localizedName ?? "nil"))", category: .ui)
                        lastUpdateTime = Date()
                        onUpdate(allBlocks, currentScreen)
                    }
                }
                
                try await Task.sleep(nanoseconds: UInt64(translatorState.captureInterval * 1_000_000_000))
                
            } catch {
                log.error("Capture loop error: \(error.localizedDescription)", category: .engine)
                isTranslating = false
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }
    
    /// Separates groups into cached (instant) and uncached (need translation)
    private func separateCachedGroups(_ groups: [[(String, CGRect)]], windowBounds: CGRect) -> (cached: [TranslatedTextBlock], uncached: [[(String, CGRect)]]) {
        var cachedBlocks: [TranslatedTextBlock] = []
        var uncachedGroups: [[(String, CGRect)]] = []
        let minLen = translatorState.minTextLength
        
        for group in groups {
            let combinedText = group.map { $0.0 }.joined(separator: " ")
            
            guard combinedText.count >= minLen else { continue }
            let letterCount = combinedText.filter { $0.isLetter }.count
            guard letterCount >= minLen else { continue }
            
            // Filter out fragments (partial word detections, watermarks)
            if ocrProcessor.isFragment(combinedText) { continue }
            
            if translatorState.shouldIgnoreText(combinedText) { continue }
            if combinedText.contains(".fr/") || combinedText.contains(".com/") { continue }
            if combinedText.contains("|") { continue }
            
            let minX = group.map { $0.1.minX }.min() ?? 0
            let maxX = group.map { $0.1.maxX }.max() ?? 0
            let minY = group.map { $0.1.minY }.min() ?? 0
            let maxY = group.map { $0.1.maxY }.max() ?? 0
            let groupBox = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            
            // Check cache with normalized key
            if let cachedTranslation = cache.get(combinedText) {
                let screenRect = CGRect(
                    x: windowBounds.origin.x + groupBox.origin.x * windowBounds.width,
                    y: windowBounds.origin.y + (1 - groupBox.origin.y - groupBox.height) * windowBounds.height,
                    width: groupBox.width * windowBounds.width,
                    height: groupBox.height * windowBounds.height
                )
                cachedBlocks.append(TranslatedTextBlock(
                    originalText: combinedText,
                    translatedText: cachedTranslation,
                    boundingBox: screenRect,
                    confidence: 1.0
                ))
            } else {
                uncachedGroups.append(group)
            }
        }
        
        return (cachedBlocks, uncachedGroups)
    }
    
    private func translateGroups(_ groups: [[(String, CGRect)]], windowBounds: CGRect) async -> [TranslatedTextBlock] {
        // Prepare valid groups first
        var validGroups: [(text: String, box: CGRect)] = []
        let minLen = translatorState.minTextLength
        
        for group in groups {
            let combinedText = group.map { $0.0 }.joined(separator: " ")
            
            guard combinedText.count >= minLen else { continue }
            let letterCount = combinedText.filter { $0.isLetter }.count
            guard letterCount >= minLen else { continue }
            
            // Filter out fragments
            if ocrProcessor.isFragment(combinedText) { continue }
            
            if translatorState.shouldIgnoreText(combinedText) { continue }
            if combinedText.contains(".fr/") || combinedText.contains(".com/") { continue }
            if combinedText.contains("|") { continue }
            
            let minX = group.map { $0.1.minX }.min() ?? 0
            let maxX = group.map { $0.1.maxX }.max() ?? 0
            let minY = group.map { $0.1.minY }.min() ?? 0
            let maxY = group.map { $0.1.maxY }.max() ?? 0
            let groupBox = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            
            validGroups.append((combinedText, groupBox))
        }
        
        // Translate with concurrency limit to avoid rate limits
        return await withTaskGroup(of: TranslatedTextBlock?.self) { taskGroup in
            var blocks: [TranslatedTextBlock] = []
            var pendingGroups = validGroups
            var activeTaskCount = 0
            let maxConcurrentTranslations = translatorState.maxConcurrentTranslations
            
            while !pendingGroups.isEmpty || activeTaskCount > 0 {
                // Add new tasks up to the limit
                while activeTaskCount < maxConcurrentTranslations && !pendingGroups.isEmpty {
                    let (text, groupBox) = pendingGroups.removeFirst()
                    activeTaskCount += 1
                    
                    taskGroup.addTask { [self] in
                        let translation: String
                        let cachedValue = cache.get(text)
                        
                        if let cached = cachedValue {
                            log.cacheHit(text)
                            log.translationCompleted(text, cached, cached: true, usedAppleTranslation: false, duration: 0)
                            translation = cached
                        } else {
                            // Check if we're in rate limit backoff period
                            if let lastRateLimit = lastRateLimitTime,
                               Date().timeIntervalSince(lastRateLimit) < translatorState.rateLimitBackoff {
                                return nil
                            }
                            
                            // Request throttling - ensures minimum interval between API requests
                            if translatorState.requestThrottleEnabled {
                                await requestThrottler.throttle(minInterval: translatorState.minRequestInterval)
                            } else {
                                // Legacy behavior: small delay between requests
                                let delayNanoseconds = UInt64(translatorState.translationDelay * 1_000_000_000)
                                try? await Task.sleep(nanoseconds: delayNanoseconds)
                            }
                            
                            log.cacheMiss(text)
                            log.translationStarted(text)
                            
                            let startTime = Date()
                            do {
                                let result = try await TranslationService.translate(
                                    text: text,
                                    from: sourceLanguage,
                                    to: targetLanguage,
                                    useAppleTranslation: translatorState.useAppleTranslation,
                                    useLibreTranslate: translatorState.useLibreTranslate,
                                    useLLM: translatorState.useLLM,
                                    libreTranslateUrl: translatorState.libreTranslateUrl.isEmpty ? nil : translatorState.libreTranslateUrl,
                                    libreTranslateApiKey: translatorState.libreTranslateApiKey.isEmpty ? nil : translatorState.libreTranslateApiKey,
                                    llmApiUrl: translatorState.llmApiUrl.isEmpty ? nil : translatorState.llmApiUrl,
                                    llmApiKey: translatorState.currentLlmApiKey.isEmpty ? nil : translatorState.currentLlmApiKey,
                                    llmModel: translatorState.llmModel.isEmpty ? nil : translatorState.llmModel,
                                    llmSystemPrompt: translatorState.effectiveLLMSystemPrompt,
                                    llmAutoAppendLanguages: translatorState.llmAutoAppendLanguages,
                                    llmConfidenceEnabled: translatorState.llmConfidenceEnabled,
                                    llmConfidenceThreshold: translatorState.llmConfidenceThreshold,
                                    llmMaxRetries: translatorState.llmMaxRetries,
                                    customApiUrl: translatorState.customApiUrl.isEmpty ? nil : translatorState.customApiUrl,
                                    googleApiKey: translatorState.googleCredential.isEmpty ? nil : translatorState.googleCredential,
                                    forceSerbianLatin: translatorState.forceSerbianLatin,
                                    timeout: translatorState.apiTimeout
                                )
                                let duration = Date().timeIntervalSince(startTime)
                                translation = result.text
                                log.translationCompleted(text, translation, cached: false, usedAppleTranslation: result.usedAppleTranslation, usedLibreTranslate: result.usedLibreTranslate, usedLLM: result.usedLLM, duration: duration)
                                cache.set(text, translation: translation)
                            } catch let error as TranslationError {
                                if case .rateLimitExceeded = error {
                                    lastRateLimitTime = Date()
                                }
                                log.translationFailed(text, error: error)
                                return nil
                            } catch {
                                log.translationFailed(text, error: error)
                                return nil
                            }
                        }
                        
                        let screenRect = CGRect(
                            x: windowBounds.origin.x + groupBox.origin.x * windowBounds.width,
                            y: windowBounds.origin.y + (1 - groupBox.origin.y - groupBox.height) * windowBounds.height,
                            width: groupBox.width * windowBounds.width,
                            height: groupBox.height * windowBounds.height
                        )
                        
                        return TranslatedTextBlock(
                            originalText: text,
                            translatedText: translation,
                            boundingBox: screenRect,
                            confidence: 1.0
                        )
                    }
                }
                
                // Wait for at least one task to complete
                if let result = await taskGroup.next() {
                    activeTaskCount -= 1
                    if let block = result {
                        blocks.append(block)
                    }
                    
                    // If rate limit was hit, clear pending queue
                    if lastRateLimitTime != nil {
                        pendingGroups.removeAll()
                    }
                }
            }
            
            return blocks
        }
    }
}

// MARK: - Request Throttler

/// Actor to manage request timing and ensure minimum intervals between API calls
actor RequestThrottler {
    private var lastRequestTime: Date?
    
    /// Wait if needed to respect the minimum interval between requests
    func throttle(minInterval: TimeInterval) async {
        if let lastTime = lastRequestTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < minInterval {
                let waitTime = minInterval - elapsed
                log.debug("Throttling request, waiting \(Int(waitTime * 1000))ms", category: .api)
                try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }
        lastRequestTime = Date()
    }
    
    /// Mark that a request was just made (for tracking without waiting)
    func markRequestMade() {
        lastRequestTime = Date()
    }
    
    /// Reset the throttler (e.g., when stopping)
    func reset() {
        lastRequestTime = nil
    }
}

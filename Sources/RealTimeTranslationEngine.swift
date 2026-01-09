import Foundation
import AppKit
import Vision
import CryptoKit
import CoreGraphics

struct TranslatedTextBlock {
    let originalText: String
    let translatedText: String
    let boundingBox: CGRect
    let confidence: Float
}

class RealTimeTranslationEngine {
    private let sourceLanguage: String
    private let targetLanguage: String
    private let translatorState: TranslatorState
    private let onUpdate: ([TranslatedTextBlock]) -> Void
    private let onClear: () -> Void
    private let onPermissionError: (() -> Void)?
    
    private var isRunning = false
    private var captureTask: Task<Void, Never>?
    
    // Thread-safe cache with LRU eviction and fuzzy matching
    private let cacheQueue = DispatchQueue(label: "translation.cache")
    private var _translationCache: [String: String] = [:]
    private var _cacheOrder: [String] = []  // Track insertion order for LRU
    private var translationCache: [String: String] {
        get { cacheQueue.sync { _translationCache } }
        set { cacheQueue.sync { _translationCache = newValue } }
    }
    
    
    /// Normalize text for consistent caching (handles OCR variations)
    private func normalizeForCache(_ text: String) -> String {
        var normalized = text
            .lowercased()
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Normalize common OCR mistakes
        normalized = normalized
            .replacingOccurrences(of: "histore", with: "histoire")
            .replacingOccurrences(of: "tkes", with: "très")
            .replacingOccurrences(of: "untkes", with: "un très")
            .replacingOccurrences(of: "cour!", with: "coeur!")
        
        // Remove extra punctuation spaces
        normalized = normalized
            .replacingOccurrences(of: " !", with: "!")
            .replacingOccurrences(of: " ?", with: "?")
            .replacingOccurrences(of: " .", with: ".")
        
        return normalized
    }
    
    /// Check if text is a watermark (only filter obvious junk, not text fragments)
    private func isFragment(_ text: String) -> Bool {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Only filter watermarks - let everything else through for grouping
        if lower.contains("scans.fr") || lower.contains("scan.fr") || lower.contains("cans.fr") {
            return true
        }
        if lower.contains("japscan") || lower.contains("japstan") || lower.contains("jarstan") {
            return true
        }
        
        return false
    }
    
    private func addToCache(key: String, value: String) {
        let normalizedKey = normalizeForCache(key)
        cacheQueue.sync {
            // If key already exists, just update value
            if _translationCache[normalizedKey] != nil {
                _translationCache[normalizedKey] = value
                return
            }
            
            // Add new entry
            _translationCache[normalizedKey] = value
            _cacheOrder.append(normalizedKey)
            
            // Evict old entries if over limit
            let maxSize = translatorState.maxCacheSize
            while _cacheOrder.count > maxSize {
                let oldKey = _cacheOrder.removeFirst()
                _translationCache.removeValue(forKey: oldKey)
            }
        }
    }
    
    private func getFromCache(key: String) -> String? {
        let normalizedKey = normalizeForCache(key)
        return cacheQueue.sync { _translationCache[normalizedKey] }
    }
    
    /// Clear all cached translations
    func clearCache() {
        cacheQueue.sync {
            _translationCache.removeAll()
            _cacheOrder.removeAll()
        }
        log.info("Translation cache cleared", category: .engine)
    }
    
    /// Get current cache size
    var cacheSize: Int {
        cacheQueue.sync { _translationCache.count }
    }
    
    // Change detection
    private var lastImageHash: String = ""
    private var lastWindowPID: Int32 = 0
    private var lastAppName: String = ""
    
    // Timing - uses configurable settings from TranslatorState
    private var lastTranslationTime: Date = .distantPast
    private var isTranslating = false
    
    // Permission tracking
    private var hasLoggedPermissionError = false
    private var hasNotifiedPermissionError = false
    
    // Track if currently in excluded app to clear overlay when switching to it
    private var isInExcludedApp = false
    
    init(sourceLanguage: String, targetLanguage: String, translatorState: TranslatorState, onUpdate: @escaping ([TranslatedTextBlock]) -> Void, onClear: @escaping () -> Void = {}, onPermissionError: (() -> Void)? = nil) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.translatorState = translatorState
        self.onUpdate = onUpdate
        self.onClear = onClear
        self.onPermissionError = onPermissionError
        
        // Configure logger
        log.configure(
            logFilePath: translatorState.logFilePath, 
            minLevel: translatorState.logLevel,
            enableFileLogging: translatorState.enableFileLogging
        )
    }
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        
        log.engineStarted()
        log.info("Source: \(sourceLanguage) -> Target: \(targetLanguage)", category: .engine)
        log.info("Apple Translation: \(translatorState.useAppleTranslation ? "enabled" : "disabled")", category: .engine)
        if !translatorState.customApiUrl.isEmpty {
            log.info("Custom API: \(translatorState.customApiUrl)", category: .engine)
        }
        
        captureTask = Task { [weak self] in
            await self?.runCaptureLoop()
        }
    }
    
    func stop() {
        isRunning = false
        captureTask?.cancel()
        captureTask = nil
        log.engineStopped()
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
                guard let (image, windowBounds, currentPID, appName) = await captureFrontmostWindow() else {
                    try await Task.sleep(nanoseconds: 200_000_000)
                    continue
                }
                
                // Clear translations if window changed
                if currentPID != lastWindowPID && lastWindowPID != 0 {
                    log.windowChanged(from: lastAppName, to: appName)
                    lastImageHash = ""
                    onClear()
                }
                lastWindowPID = currentPID
                lastAppName = appName
                
                log.windowCaptured(app: appName, size: windowBounds.size)
                
                let currentHash = hashImage(image)
                if currentHash == lastImageHash {
                    try await Task.sleep(nanoseconds: UInt64(translatorState.captureInterval * 1_000_000_000))
                    continue
                }
                lastImageHash = currentHash
                
                let ocrStart = Date()
                let textObservations = try await performOCR(on: image)
                let ocrDuration = Date().timeIntervalSince(ocrStart)
                log.ocrCompleted(regions: textObservations.count, duration: ocrDuration)
                
                let groupedObservations = groupObservations(textObservations)
                
                // Fast path: if all texts are cached, update positions immediately
                let (cachedBlocks, uncachedGroups) = separateCachedGroups(groupedObservations, windowBounds: windowBounds)
                
                if !cachedBlocks.isEmpty {
                    // Update overlay with cached translations immediately
                    onUpdate(cachedBlocks)
                }
                
                // Slow path: translate new texts (only if not already translating)
                if !uncachedGroups.isEmpty && !isTranslating {
                    isTranslating = true
                    let newBlocks = await translateGroups(uncachedGroups, windowBounds: windowBounds)
                    isTranslating = false
                    
                    if !newBlocks.isEmpty {
                        log.blocksCreated(newBlocks.count)
                        // Merge with cached blocks for complete update
                        onUpdate(cachedBlocks + newBlocks)
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
            if isFragment(combinedText) { continue }
            
            if translatorState.shouldIgnoreText(combinedText) { continue }
            if combinedText.contains(".fr/") || combinedText.contains(".com/") { continue }
            if combinedText.contains("|") { continue }
            
            let minX = group.map { $0.1.minX }.min() ?? 0
            let maxX = group.map { $0.1.maxX }.max() ?? 0
            let minY = group.map { $0.1.minY }.min() ?? 0
            let maxY = group.map { $0.1.maxY }.max() ?? 0
            let groupBox = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            
            // Check cache with normalized key
            if let cachedTranslation = getFromCache(key: combinedText) {
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
    
    private func captureFrontmostWindow() async -> (NSImage, CGRect, Int32, String)? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return nil
        }
        
        let appName = frontApp.localizedName ?? frontApp.bundleIdentifier ?? "Unknown"
        
        // Check if app is excluded
        if translatorState.isAppExcluded(frontApp.bundleIdentifier) {
            if !isInExcludedApp {
                isInExcludedApp = true
                log.appExcluded(frontApp.bundleIdentifier ?? "unknown")
                await MainActor.run { onClear() }
            }
            return nil
        }
        
        if isInExcludedApp {
            isInExcludedApp = false
            lastImageHash = ""
            log.info("Returned from excluded app, forcing re-translation", category: .engine)
        }
        
        let pid = frontApp.processIdentifier
        
        // Check screen recording permission
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
            if !hasLoggedPermissionError {
                hasLoggedPermissionError = true
                log.warning("Screen Recording permission required.", category: .engine)
                notifyPermissionError()
            }
            return nil
        }
        
        // Use CGWindowList for both bounds and image capture
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            // This can happen if:
            // 1. Permission was just granted (needs restart)
            // 2. App was rebuilt and old permission entry is stale
            if !hasLoggedPermissionError {
                hasLoggedPermissionError = true
                log.warning("Screen capture failed - permission may be stale after rebuild", category: .engine)
                notifyPermissionError()
            }
            return nil
        }
        
        // Extra check: if windowList is empty, permission might be broken
        if windowList.isEmpty && !hasLoggedPermissionError {
            hasLoggedPermissionError = true
            log.warning("No windows found - permission may be stale after rebuild", category: .engine)
            notifyPermissionError()
            return nil
        }
        
        for window in windowList {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int32,
                  ownerPID == pid,
                  let windowID = window[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0 else { continue }
            
            let bounds = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )
            
            guard bounds.width > 300, bounds.height > 300 else { continue }
            
            // Capture using CGWindowListCreateImage (deprecated but works correctly)
            guard let cgImage = CGWindowListCreateImage(
                bounds, .optionIncludingWindow, windowID, [.boundsIgnoreFraming]
            ) else { continue }
            
            return (NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)), bounds, pid, appName)
        }
        return nil
    }
    
    private func hashImage(_ image: NSImage) -> String {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return UUID().uuidString
        }
        
        var samples: [UInt8] = []
        let stepX = max(1, bitmap.pixelsWide / 15)
        let stepY = max(1, bitmap.pixelsHigh / 15)
        
        for y in stride(from: 0, to: bitmap.pixelsHigh, by: stepY) {
            for x in stride(from: 0, to: bitmap.pixelsWide, by: stepX) {
                if let color = bitmap.colorAt(x: x, y: y) {
                    samples.append(UInt8(color.redComponent * 255))
                }
            }
        }
        
        let hash = SHA256.hash(data: Data(samples))
        return hash.compactMap { String(format: "%02x", $0) }.joined().prefix(12).description
    }
    
    private func performOCR(on image: NSImage) async throws -> [VNRecognizedTextObservation] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "OCR", code: 1)
        }
        
        let useAccurate = translatorState.ocrAccurate
        let sourceLang = sourceLanguage
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: request.results as? [VNRecognizedTextObservation] ?? [])
            }
            
            request.recognitionLevel = useAccurate ? .accurate : .fast
            request.usesLanguageCorrection = useAccurate
            // Build recognition languages based on source language
            var languages = ["\(sourceLang)-\(sourceLang.uppercased())", "en-US"]
            if sourceLang != "en" && sourceLang != "auto" {
                languages.append("en-US")
            }
            request.recognitionLanguages = languages
            
            do {
                try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func groupObservations(_ observations: [VNRecognizedTextObservation]) -> [[(String, CGRect)]] {
        var validObservations: [(String, CGRect, VNRecognizedTextObservation)] = []
        
        // First pass: filter observations
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Filter criteria
            guard text.count >= 2 else { 
                log.textIgnored(text, reason: "too short")
                continue 
            }
            
            if text.contains(".fr/") || text.contains(".com/") || text.contains("http") { 
                log.textIgnored(text, reason: "URL")
                continue 
            }
            
            if text.contains("|") || text.contains("O|") { 
                log.textIgnored(text, reason: "special chars")
                continue 
            }
            
            if translatorState.shouldIgnoreText(text) {
                log.textIgnored(text, reason: "pattern match")
                continue
            }
            
            let letterCount = text.filter { $0.isLetter }.count
            guard letterCount >= 2 else { 
                log.textIgnored(text, reason: "few letters")
                continue 
            }
            
            log.textAccepted(text)
            validObservations.append((text, observation.boundingBox, observation))
        }
        
        // Second pass: group using improved algorithm
        var groups: [[(String, CGRect, VNRecognizedTextObservation)]] = []
        var used = Set<Int>()
        
        // Sort by Y position (top to bottom in normalized coords means high to low)
        let sorted = validObservations.enumerated().sorted { $0.element.1.midY > $1.element.1.midY }
        
        for (idx, (text, box, obs)) in sorted {
            if used.contains(idx) { continue }
            
            var group: [(String, CGRect, VNRecognizedTextObservation)] = [(text, box, obs)]
            used.insert(idx)
            
            // Find all observations that should be grouped with this one
            for (otherIdx, (otherText, otherBox, otherObs)) in sorted {
                if used.contains(otherIdx) { continue }
                
                // Check if this observation belongs to the same text block
                if shouldGroup(box1: box, box2: otherBox, existingGroup: group) {
                    group.append((otherText, otherBox, otherObs))
                    used.insert(otherIdx)
                }
            }
            
            groups.append(group)
        }
        
        return groups.map { group in
            group.sorted { $0.1.minY > $1.1.minY }
                 .map { ($0.0, $0.1) }
        }
    }
    
    /// Simple grouping: only merge text on same horizontal line or directly adjacent vertically with center alignment
    private func shouldGroup(box1: CGRect, box2: CGRect, existingGroup: [(String, CGRect, VNRecognizedTextObservation)]) -> Bool {
        let groupingFactor = translatorState.textGrouping
        
        let groupMinX = existingGroup.map { $0.1.minX }.min() ?? box1.minX
        let groupMaxX = existingGroup.map { $0.1.maxX }.max() ?? box1.maxX
        let groupMinY = existingGroup.map { $0.1.minY }.min() ?? box1.minY
        let groupMaxY = existingGroup.map { $0.1.maxY }.max() ?? box1.maxY
        let groupCenterX = (groupMinX + groupMaxX) / 2
        
        // Max size limit
        let potentialWidth = max(groupMaxX, box2.maxX) - min(groupMinX, box2.minX)
        let potentialHeight = max(groupMaxY, box2.maxY) - min(groupMinY, box2.minY)
        if potentialWidth > 0.30 || potentialHeight > 0.35 { return false }
        
        // Horizontal gap = different bubbles
        let hGap = max(0, max(box2.minX - groupMaxX, groupMinX - box2.maxX))
        if hGap > 0.03 { return false }
        
        // Vertical gap between boxes
        let vGap = max(0, max(box2.minY - groupMaxY, groupMinY - box2.maxY))
        let avgH = (box1.height + box2.height) / 2
        
        // Only group if vertically close AND horizontally aligned (centers within 5%)
        let centerDist = abs(box2.midX - groupCenterX)
        let aligned = centerDist < 0.05 * groupingFactor
        
        return vGap < avgH * 2.5 * groupingFactor && aligned
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
            if isFragment(combinedText) { continue }
            
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
        
        // Translate in parallel
        return await withTaskGroup(of: TranslatedTextBlock?.self) { taskGroup in
            var blocks: [TranslatedTextBlock] = []
            
            for (text, groupBox) in validGroups {
                taskGroup.addTask { [self] in
                    let translation: String
                    let cachedValue = getFromCache(key: text)
                    
                    if let cached = cachedValue {
                        log.cacheHit(text)
                        log.translationCompleted(text, cached, cached: true, usedAppleTranslation: false, duration: 0)
                        translation = cached
                    } else {
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
                                customApiUrl: translatorState.customApiUrl.isEmpty ? nil : translatorState.customApiUrl,
                                forceSerbianLatin: translatorState.forceSerbianLatin
                            )
                            let duration = Date().timeIntervalSince(startTime)
                            translation = result.text
                            log.translationCompleted(text, translation, cached: false, usedAppleTranslation: result.usedAppleTranslation, usedLibreTranslate: result.usedLibreTranslate, usedLLM: result.usedLLM, duration: duration)
                            self.addToCache(key: text, value: translation)
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
            
            for await block in taskGroup {
                if let block = block {
                    blocks.append(block)
                }
            }
            
            return blocks
        }
    }
}

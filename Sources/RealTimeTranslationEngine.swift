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
    
    // Thread-safe cache
    private let cacheQueue = DispatchQueue(label: "translation.cache")
    private var _translationCache: [String: String] = [:]
    private var translationCache: [String: String] {
        get { cacheQueue.sync { _translationCache } }
        set { cacheQueue.sync { _translationCache = newValue } }
    }
    
    // Change detection
    private var lastImageHash: String = ""
    private var lastWindowPID: Int32 = 0
    private var lastAppName: String = ""
    
    // Timing - optimized for speed
    private let captureInterval: TimeInterval = 0.4
    private var lastTranslationTime: Date = .distantPast
    private let translationDelay: TimeInterval = 0.05
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
                if isTranslating {
                    try await Task.sleep(nanoseconds: 100_000_000)
                    continue
                }
                
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
                    try await Task.sleep(nanoseconds: UInt64(captureInterval * 1_000_000_000))
                    continue
                }
                lastImageHash = currentHash
                
                let ocrStart = Date()
                let textObservations = try await performOCR(on: image)
                let ocrDuration = Date().timeIntervalSince(ocrStart)
                log.ocrCompleted(regions: textObservations.count, duration: ocrDuration)
                
                let groupedObservations = groupObservations(textObservations)
                
                isTranslating = true
                let blocks = await translateGroups(groupedObservations, windowBounds: windowBounds)
                isTranslating = false
                
                log.blocksCreated(blocks.count)
                onUpdate(blocks)
                
                try await Task.sleep(nanoseconds: UInt64(captureInterval * 1_000_000_000))
                
            } catch {
                log.error("Capture loop error: \(error.localizedDescription)", category: .engine)
                isTranslating = false
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
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
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: request.results as? [VNRecognizedTextObservation] ?? [])
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["fr-FR", "en-US"]
            
            do {
                try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func groupObservations(_ observations: [VNRecognizedTextObservation]) -> [[(String, CGRect)]] {
        var groups: [[(String, CGRect, VNRecognizedTextObservation)]] = []
        
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
            
            let box = observation.boundingBox
            
            var addedToGroup = false
            for i in 0..<groups.count {
                for (_, existingBox, _) in groups[i] {
                    let verticalGap = abs(box.minY - existingBox.maxY)
                    let verticalGap2 = abs(existingBox.minY - box.maxY)
                    let minVerticalGap = min(verticalGap, verticalGap2)
                    
                    let horizontalOverlap = max(0, min(box.maxX, existingBox.maxX) - max(box.minX, existingBox.minX))
                    let minWidth = min(box.width, existingBox.width)
                    
                    if minVerticalGap < 0.05 && horizontalOverlap > minWidth * 0.3 {
                        groups[i].append((text, box, observation))
                        addedToGroup = true
                        break
                    }
                }
                if addedToGroup { break }
            }
            
            if !addedToGroup {
                groups.append([(text, box, observation)])
            }
        }
        
        return groups.map { group in
            group.sorted { $0.1.minY > $1.1.minY }
                 .map { ($0.0, $0.1) }
        }
    }
    
    private func translateGroups(_ groups: [[(String, CGRect)]], windowBounds: CGRect) async -> [TranslatedTextBlock] {
        // Prepare valid groups first
        var validGroups: [(text: String, box: CGRect)] = []
        
        for group in groups {
            let combinedText = group.map { $0.0 }.joined(separator: " ")
            
            guard combinedText.count >= 3 else { continue }
            let letterCount = combinedText.filter { $0.isLetter }.count
            guard letterCount >= 3 else { continue }
            
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
                    let cachedValue = cacheQueue.sync { _translationCache[text] }
                    
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
                                customApiUrl: translatorState.customApiUrl.isEmpty ? nil : translatorState.customApiUrl
                            )
                            let duration = Date().timeIntervalSince(startTime)
                            translation = result.text
                            log.translationCompleted(text, translation, cached: false, usedAppleTranslation: result.usedAppleTranslation, duration: duration)
                            cacheQueue.sync { _translationCache[text] = translation }
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

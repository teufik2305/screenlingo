import Foundation
import AppKit
import Vision

/// Handles OCR processing and text grouping
class OCRProcessor {
    private let translatorState: TranslatorState
    
    init(translatorState: TranslatorState) {
        self.translatorState = translatorState
    }
    
    /// Perform OCR on an image
    func recognizeText(in image: NSImage, sourceLanguage: String) async throws -> [VNRecognizedTextObservation] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "OCR", code: 1)
        }
        
        let useAccurate = translatorState.ocrAccurate
        
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
            var languages = ["\(sourceLanguage)-\(sourceLanguage.uppercased())", "en-US"]
            if sourceLanguage != "en" && sourceLanguage != "auto" {
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
    
    /// Group OCR observations into logical text blocks
    func groupObservations(_ observations: [VNRecognizedTextObservation]) -> [[(String, CGRect)]] {
        var validObservations: [(String, CGRect, VNRecognizedTextObservation)] = []
        
        // First pass: filter observations
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Filter criteria
            let minLen = translatorState.minTextLength
            guard text.count >= minLen else { 
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
            let minLetters = translatorState.minLetterCount
            guard letterCount >= minLetters else { 
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
    
    /// Check if text is a watermark or fragment
    func isFragment(_ text: String) -> Bool {
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
        if potentialWidth > translatorState.maxBubbleWidth || potentialHeight > translatorState.maxBubbleHeight { 
            return false 
        }
        
        // Horizontal gap = different bubbles
        let hGap = max(0, max(box2.minX - groupMaxX, groupMinX - box2.maxX))
        if hGap > translatorState.horizontalGapThreshold { 
            return false 
        }
        
        // Vertical gap between boxes
        let vGap = max(0, max(box2.minY - groupMaxY, groupMinY - box2.maxY))
        let avgH = (box1.height + box2.height) / 2
        
        // Only group if vertically close AND horizontally aligned
        let centerDist = abs(box2.midX - groupCenterX)
        let aligned = centerDist < translatorState.centerAlignmentThreshold * groupingFactor
        
        return vGap < avgH * translatorState.verticalGapMultiplier * groupingFactor && aligned
    }
}

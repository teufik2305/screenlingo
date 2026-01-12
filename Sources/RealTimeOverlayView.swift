import AppKit

class RealTimeOverlayView: NSView {
    private var textBlocks: [TranslatedTextBlock] = []
    private var hoveredBlockIndex: Int? = nil
    private var hiddenBlockIds: Set<String> = []
    private let translatorState: TranslatorState
    private let onIgnoreText: (String) -> Void
    private let onHiddenChanged: ([(original: String, translated: String)]) -> Void
    private var clickMonitor: Any?
    
    // Position stabilization - prevents "breathing" effect
    private var stablePositions: [String: CGRect] = [:]
    
    // Track actual drawn rectangles for accurate hit testing (in Cocoa global coordinates)
    private var drawnRectsGlobal: [Int: CGRect] = [:]
    
    // Multi-monitor support: the screen this overlay is displaying on
    var targetScreen: NSScreen?
    
    init(frame: NSRect, translatorState: TranslatorState, onIgnoreText: @escaping (String) -> Void, onHiddenChanged: @escaping ([(original: String, translated: String)]) -> Void = { _ in }) {
        self.translatorState = translatorState
        self.onIgnoreText = onIgnoreText
        self.onHiddenChanged = onHiddenChanged
        super.init(frame: frame)
        
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved()
            return event
        }
        
        NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.handleMouseMoved()
        }
        
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleClick()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    /// Convert CG global coordinates to Cocoa global coordinates for hit testing
    /// box: bounding box in CG global coordinates (origin at top-left of primary screen)
    /// Returns: rect in Cocoa global coordinates for mouse hit testing
    private func getHitRect(_ block: TranslatedTextBlock, screenHeight: CGFloat) -> CGRect {
        let box = block.boundingBox
        guard let primaryScreen = NSScreen.screens.first else {
            return CGRect(
                x: box.origin.x,
                y: screenHeight - box.origin.y - box.height,
                width: box.width,
                height: box.height
            )
        }
        
        let primaryHeight = primaryScreen.frame.height
        
        // Convert CG global Y to Cocoa global Y
        // CG: origin at top-left of primary, Y increases downward
        // Cocoa: origin at bottom-left of primary, Y increases upward
        let cocoaY = primaryHeight - box.origin.y - box.height
        
        // Return rect in Cocoa global coordinates (for mouse position comparison)
        return CGRect(
            x: box.origin.x,
            y: cocoaY,
            width: box.width,
            height: box.height
        )
    }
    
    /// Convert CG global coordinates to view-local coordinates for drawing
    /// box: bounding box in CG global coordinates
    /// Returns: center point in view-local coordinates
    private func getLocalCenter(_ box: CGRect) -> CGPoint? {
        guard let screen = targetScreen ?? NSScreen.main,
              let primaryScreen = NSScreen.screens.first else {
            return nil
        }
        
        let primaryHeight = primaryScreen.frame.height
        
        // Convert CG global to Cocoa global
        let cocoaMidY = primaryHeight - box.midY
        
        // Convert Cocoa global to screen-local (view coordinates)
        let localX = box.midX - screen.frame.origin.x
        let localY = cocoaMidY - screen.frame.origin.y
        
        return CGPoint(x: localX, y: localY)
    }
    
    private func handleMouseMoved() {
        let mousePos = NSEvent.mouseLocation
        
        var newHovered: Int? = nil
        for (i, block) in textBlocks.enumerated() {
            if hiddenBlockIds.contains(block.originalText) { continue }
            // Use actual drawn rect for hit testing (more accurate)
            if let drawnRect = drawnRectsGlobal[i], drawnRect.contains(mousePos) {
                newHovered = i
                break
            }
        }
        
        if newHovered != hoveredBlockIndex {
            hoveredBlockIndex = newHovered
            DispatchQueue.main.async { self.needsDisplay = true }
        }
    }
    
    private func handleClick() {
        let mousePos = NSEvent.mouseLocation
        
        for (i, block) in textBlocks.enumerated() {
            if hiddenBlockIds.contains(block.originalText) { continue }
            // Use actual drawn rect for hit testing (more accurate)
            if let drawnRect = drawnRectsGlobal[i], drawnRect.contains(mousePos) {
                DispatchQueue.main.async { self.showContextMenu(for: block) }
                return
            }
        }
    }
    
    private func showContextMenu(for block: TranslatedTextBlock) {
        let menu = NSMenu()
        
        let copyItem = NSMenuItem(title: "Copy Translation", action: #selector(copyTranslation(_:)), keyEquivalent: "")
        copyItem.representedObject = block.translatedText
        copyItem.target = self
        menu.addItem(copyItem)
        
        let copyOriginalItem = NSMenuItem(title: "Copy Original", action: #selector(copyOriginal(_:)), keyEquivalent: "")
        copyOriginalItem.representedObject = block.originalText
        copyOriginalItem.target = self
        menu.addItem(copyOriginalItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let hideItem = NSMenuItem(title: "Hide This Overlay", action: #selector(hideBlock(_:)), keyEquivalent: "")
        hideItem.representedObject = block.originalText
        hideItem.target = self
        menu.addItem(hideItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Always ignore full text
        let preview = block.originalText.count > 25 ? String(block.originalText.prefix(25)) + "..." : block.originalText
        let ignoreItem = NSMenuItem(title: "Always Ignore \"\(preview)\"", action: #selector(ignoreText(_:)), keyEquivalent: "")
        ignoreItem.representedObject = block.originalText
        ignoreItem.target = self
        menu.addItem(ignoreItem)
        
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
    
    @objc private func copyTranslation(_ sender: NSMenuItem) {
        if let text = sender.representedObject as? String {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }
    
    @objc private func copyOriginal(_ sender: NSMenuItem) {
        if let text = sender.representedObject as? String {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }
    
    @objc private func hideBlock(_ sender: NSMenuItem) {
        if let text = sender.representedObject as? String {
            hiddenBlockIds.insert(text)
            needsDisplay = true
            notifyHiddenChanged()
        }
    }
    
    func unhideBlock(_ originalText: String) {
        hiddenBlockIds.remove(originalText)
        needsDisplay = true
        notifyHiddenChanged()
    }
    
    func unhideAll() {
        hiddenBlockIds.removeAll()
        needsDisplay = true
        notifyHiddenChanged()
    }
    
    private func notifyHiddenChanged() {
        // Build list of hidden blocks with their translations
        let hiddenList = textBlocks
            .filter { hiddenBlockIds.contains($0.originalText) }
            .map { (original: $0.originalText, translated: $0.translatedText) }
        onHiddenChanged(hiddenList)
    }
    
    @objc private func ignoreText(_ sender: NSMenuItem) {
        if let text = sender.representedObject as? String {
            onIgnoreText(text)
        }
    }
    
    func updateTextBlocks(_ blocks: [TranslatedTextBlock]) {
        // Stabilize positions to prevent "breathing" effect
        var stabilizedBlocks: [TranslatedTextBlock] = []
        let threshold = CGFloat(translatorState.stabilityThreshold)
        
        for block in blocks {
            let key = block.originalText
            
            if let existingRect = stablePositions[key] {
                // Check if position changed significantly
                let dx = abs(block.boundingBox.midX - existingRect.midX)
                let dy = abs(block.boundingBox.midY - existingRect.midY)
                
                if dx < threshold && dy < threshold {
                    // Keep old position (prevents jitter)
                    stabilizedBlocks.append(TranslatedTextBlock(
                        originalText: block.originalText,
                        translatedText: block.translatedText,
                        boundingBox: existingRect,
                        confidence: block.confidence
                    ))
                } else {
                    // Position changed significantly, update it
                    stablePositions[key] = block.boundingBox
                    stabilizedBlocks.append(block)
                }
            } else {
                // New block, store its position
                stablePositions[key] = block.boundingBox
                stabilizedBlocks.append(block)
            }
        }
        
        // Clean up old positions (for blocks that are gone)
        let currentKeys = Set(blocks.map { $0.originalText })
        stablePositions = stablePositions.filter { currentKeys.contains($0.key) }
        
        self.textBlocks = stabilizedBlocks
        needsDisplay = true
    }
    
    func clearBlocks() {
        self.textBlocks = []
        self.stablePositions = [:]  // Clear stabilization cache
        self.drawnRectsGlobal = [:]  // Clear hit test rects
        hoveredBlockIndex = nil
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        NSColor.clear.setFill()
        bounds.fill()
        
        // Clear previous drawn rects
        drawnRectsGlobal.removeAll()
        
        // Track drawn regions to prevent overlapping duplicates (in local coordinates)
        var drawnLocalRects: [CGRect] = []
        
        // Sort blocks by translation length (prefer longer/more complete translations)
        let sortedIndices = textBlocks.indices.sorted { i, j in
            textBlocks[i].translatedText.count > textBlocks[j].translatedText.count
        }
        
        for i in sortedIndices {
            let block = textBlocks[i]
            if hiddenBlockIds.contains(block.originalText) { continue }
            
            let isHovered = (hoveredBlockIndex == i)
            if translatorState.hideOnHover && isHovered { continue }
            
            // Get the local center to check for overlap before drawing
            guard let localCenter = getLocalCenter(block.boundingBox) else { continue }
            
            // Estimate the rect that would be drawn (approximate)
            let estimatedRect = estimateDrawnRect(for: block, center: localCenter)
            
            // Check if this would overlap significantly with an already-drawn overlay
            let hasSignificantOverlap = drawnLocalRects.contains { existingRect in
                let intersection = existingRect.intersection(estimatedRect)
                guard !intersection.isNull else { return false }
                let overlapArea = intersection.width * intersection.height
                let smallerArea = min(existingRect.width * existingRect.height, estimatedRect.width * estimatedRect.height)
                // Skip if >50% overlap with existing
                return smallerArea > 0 && overlapArea / smallerArea > 0.5
            }
            
            if hasSignificantOverlap { continue }
            
            if let drawnRect = drawBlock(block, isHovered: isHovered) {
                drawnRectsGlobal[i] = drawnRect
                // Store local rect for overlap detection
                if let screen = targetScreen ?? NSScreen.main {
                    let localRect = CGRect(
                        x: drawnRect.origin.x - screen.frame.origin.x,
                        y: drawnRect.origin.y - screen.frame.origin.y,
                        width: drawnRect.width,
                        height: drawnRect.height
                    )
                    drawnLocalRects.append(localRect)
                }
            }
        }
    }
    
    /// Estimate the rect that would be drawn for a block (for overlap detection)
    private func estimateDrawnRect(for block: TranslatedTextBlock, center: CGPoint) -> CGRect {
        let fontSize = max(CGFloat(translatorState.fontSize), 8)
        let text = block.translatedText
        let boxWidth = block.boundingBox.width
        
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let wrapWidth = max(boxWidth, 120)
        
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        para.lineBreakMode = .byWordWrapping
        
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: para]
        let textBounds = text.boundingRect(
            with: CGSize(width: wrapWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: attrs
        )
        
        let paddingH = CGFloat(translatorState.boxPaddingH)
        let paddingV = CGFloat(translatorState.boxPaddingV)
        let rectW = ceil(textBounds.width) + paddingH * 2 + 10
        let rectH = ceil(textBounds.height) + paddingV * 2 + 10
        
        return CGRect(x: center.x - rectW/2, y: center.y - rectH/2, width: rectW, height: rectH)
    }
    
    /// Draw a block and return its drawn rect in Cocoa global coordinates (for hit testing)
    private func drawBlock(_ block: TranslatedTextBlock, isHovered: Bool) -> CGRect? {
        let box = block.boundingBox
        guard box.width > 20, box.height > 15 else { return nil }
        
        // Get local center coordinates for this screen
        guard let localCenter = getLocalCenter(box) else { return nil }
        
        let text = block.translatedText
        let fontSize = max(CGFloat(translatorState.fontSize), 8)
        
        // Check display mode: 0 = box, 1 = outline
        let localRect: CGRect
        if translatorState.overlayDisplayMode == 1 {
            localRect = drawOutlinedText(text: text, center: localCenter, fontSize: fontSize, boxWidth: box.width, isHovered: isHovered)
        } else {
            localRect = drawBoxText(text: text, center: localCenter, fontSize: fontSize, boxWidth: box.width, isHovered: isHovered)
        }
        
        // Convert local rect to Cocoa global coordinates for hit testing
        guard let screen = targetScreen ?? NSScreen.main else { return nil }
        let globalRect = CGRect(
            x: localRect.origin.x + screen.frame.origin.x,
            y: localRect.origin.y + screen.frame.origin.y,
            width: localRect.width,
            height: localRect.height
        )
        
        return globalRect
    }
    
    /// Draw text in a box with background (customizable style)
    /// Returns the drawn rect in view-local coordinates
    private func drawBoxText(text: String, center: CGPoint, fontSize: CGFloat, boxWidth: CGFloat, isHovered: Bool) -> CGRect {
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        
        // Get customization settings
        let paddingH = CGFloat(translatorState.boxPaddingH)
        let paddingV = CGFloat(translatorState.boxPaddingV)
        let cornerRadius = CGFloat(translatorState.boxCornerRadius)
        let backgroundColor = NSColor(hex: translatorState.boxBackgroundColorHex) ?? NSColor.white
        let textColor = NSColor(hex: translatorState.boxTextColorHex) ?? NSColor.black
        let borderWidth = CGFloat(translatorState.boxBorderWidth)
        let borderColor = NSColor(hex: translatorState.boxBorderColorHex) ?? NSColor.black
        let shadowEnabled = translatorState.boxShadowEnabled
        let coverOriginal = translatorState.boxCoverOriginal
        let opacity = CGFloat(translatorState.overlayOpacity)
        
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        para.lineBreakMode = .byWordWrapping
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: para
        ]
        
        // Use original box width, min 120
        let wrapWidth = max(boxWidth, 120)
        let textBounds = text.boundingRect(
            with: CGSize(width: wrapWidth - paddingH * 2, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs
        )
        
        // Add extra line height to prevent clipping at certain font sizes
        let lineHeight = font.ascender - font.descender + font.leading
        let textW = ceil(textBounds.width) + 2
        let textH = ceil(textBounds.height) + ceil(lineHeight * 0.3)
        
        // Rect sized for text with custom padding
        let rectW = textW + paddingH * 2
        let rectH = textH + paddingV * 2
        
        let rect = CGRect(x: center.x - rectW/2, y: center.y - rectH/2, width: rectW, height: rectH)
        
        // Shadow (if enabled)
        if shadowEnabled {
            let shadowPath = NSBezierPath(roundedRect: rect.offsetBy(dx: 1, dy: -1), xRadius: cornerRadius, yRadius: cornerRadius)
            NSColor.black.withAlphaComponent(0.15).setFill()
            shadowPath.fill()
        }
        
        // Solid background to cover original text (if enabled)
        if coverOriginal {
            let coverPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
            backgroundColor.setFill()
            coverPath.fill()
        }
        
        // Semi-transparent background on top
        let bgPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        backgroundColor.withAlphaComponent(opacity).setFill()
        bgPath.fill()
        
        // Border
        if isHovered && !translatorState.hideOnHover {
            NSColor.systemBlue.setStroke()
            bgPath.lineWidth = 2.5
            bgPath.stroke()
        } else if borderWidth > 0 {
            borderColor.setStroke()
            bgPath.lineWidth = borderWidth
            bgPath.stroke()
        }
        
        // Text - centered in rect
        let textRect = CGRect(
            x: rect.midX - textW / 2,
            y: rect.midY - textH / 2,
            width: textW,
            height: textH
        )
        
        text.draw(in: textRect, withAttributes: attrs)
        
        return rect
    }
    
    /// Draw text with outline stroke effect (subtitle style)
    /// Returns the drawn rect in view-local coordinates
    private func drawOutlinedText(text: String, center: CGPoint, fontSize: CGFloat, boxWidth: CGFloat, isHovered: Bool) -> CGRect {
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let outlineWidth = CGFloat(translatorState.outlineWidth)
        
        // Parse colors from hex
        let textColor = NSColor(hex: translatorState.textColorHex) ?? NSColor.white
        let outlineColor = NSColor(hex: translatorState.outlineColorHex) ?? NSColor.black
        
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        para.lineBreakMode = .byWordWrapping
        
        // Calculate text bounds
        let measureAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: para
        ]
        
        let wrapWidth = max(boxWidth, 120)
        let textBounds = text.boundingRect(
            with: CGSize(width: wrapWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: measureAttrs
        )
        
        let textW = ceil(textBounds.width) + outlineWidth * 2
        let textH = ceil(textBounds.height) + outlineWidth * 2
        
        // Text rect centered on the target position
        let textRect = CGRect(
            x: center.x - textW / 2,
            y: center.y - textH / 2,
            width: textW,
            height: textH
        )
        
        // Draw outline by drawing text in 8 directions
        let outlineAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: outlineColor,
            .paragraphStyle: para
        ]
        
        for i in 0..<8 {
            let angle = Double(i) * .pi / 4
            let dx = cos(angle) * Double(outlineWidth)
            let dy = sin(angle) * Double(outlineWidth)
            
            let offsetRect = textRect.offsetBy(dx: CGFloat(dx), dy: CGFloat(dy))
            text.draw(in: offsetRect, withAttributes: outlineAttrs)
        }
        
        // Draw main text on top
        var mainAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: para
        ]
        
        // Add hover effect
        if isHovered && !translatorState.hideOnHover {
            mainAttrs[.foregroundColor] = NSColor.systemBlue
        }
        
        text.draw(in: textRect, withAttributes: mainAttrs)
        
        return textRect
    }
    
    override var isFlipped: Bool { false }
}

// MARK: - NSColor Hex Extension

extension NSColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}


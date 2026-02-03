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
    
    // Hover debouncing - prevents rapid flickering from small mouse movements
    private var hoverDebounceWorkItem: DispatchWorkItem?
    private var pendingHoverState: Int? = nil
    
    // Multi-monitor support: the screen this overlay is displaying on
    var targetScreen: NSScreen?
    
    init(frame: NSRect, translatorState: TranslatorState, onIgnoreText: @escaping (String) -> Void, onHiddenChanged: @escaping ([(original: String, translated: String)]) -> Void = { _ in }) {
        self.translatorState = translatorState
        self.onIgnoreText = onIgnoreText
        self.onHiddenChanged = onHiddenChanged
        super.init(frame: frame)
        
        log.debug("RealTimeOverlayView init - frame: (\(Int(frame.minX)), \(Int(frame.minY)), \(Int(frame.width))x\(Int(frame.height)))", category: .ui)
        
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
        
        log.debug("RealTimeOverlayView: mouse event monitors registered", category: .ui)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
        }
        hoverDebounceWorkItem?.cancel()
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
    
    /// Convert screen coordinates (top-left origin, CGWindowList style) to view-local coordinates
    /// box: bounding box in screen coordinates (origin at top-left of primary screen)
    /// Returns: center point in view-local coordinates
    private func getLocalCenter(_ box: CGRect) -> CGPoint? {
        guard let screen = targetScreen ?? NSScreen.main else {
            return nil
        }
        
        // Input coordinates are in CGWindowList style (origin at top-left of primary screen)
        // We need to convert to view-local coordinates (origin at top-left of view)
        //
        // CGWindowList Y: distance from top of primary screen downward
        // View-local Y: distance from top of this screen downward
        //
        // For multi-monitor:
        // Screen.frame.origin.y in Cocoa is the distance from bottom of primary to bottom of this screen
        // But we need to handle the coordinate transform carefully
        
        // Get the primary screen to calculate the offset
        guard let primaryScreen = NSScreen.screens.first else { return nil }
        let primaryHeight = primaryScreen.frame.height
        
        // Convert CGWindowList Y (from top) to Cocoa Y (from bottom of primary)
        // CGWindowList Y=0 is top of primary, CGWindowList Y=primaryHeight is bottom of primary
        // Cocoa Y: 0 is bottom of primary, primaryHeight is top of primary
        let cocoaGlobalY = primaryHeight - box.midY
        
        // Convert to screen-local
        let localX = box.midX - screen.frame.origin.x
        let localY = cocoaGlobalY - screen.frame.origin.y
        
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
        
        // Only update if hover state actually changed
        if newHovered == hoveredBlockIndex {
            return  // No change, no need to do anything
        }
        
        // Cancel any pending hover update
        hoverDebounceWorkItem?.cancel()
        
        // Debounce only when entering hover (to prevent flicker from small movements)
        // Exit hover immediately for better responsiveness
        if newHovered != nil {
            // Entering hover - debounce to prevent flicker
            pendingHoverState = newHovered
            
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                // Double-check the pending state is still valid
                if self.pendingHoverState == newHovered && self.pendingHoverState != self.hoveredBlockIndex {
                    let oldHovered = self.hoveredBlockIndex
                    self.hoveredBlockIndex = self.pendingHoverState
                    log.debug("Hover changed: \(oldHovered?.description ?? "nil") -> \(self.pendingHoverState?.description ?? "nil"), mouse: (\(Int(mousePos.x)), \(Int(mousePos.y)))", category: .ui)
                    log.debug("Setting needsDisplay=true due to hover change", category: .ui)
                    DispatchQueue.main.async {
                        self.needsDisplay = true
                    }
                }
            }
            hoverDebounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.005, execute: workItem)  // 5ms debounce
        } else {
            // Exiting hover - update immediately (no debounce)
            pendingHoverState = nil
            let oldHovered = hoveredBlockIndex
            hoveredBlockIndex = nil
            if oldHovered != nil {
                log.debug("Hover changed: \(oldHovered?.description ?? "nil") -> nil, mouse: (\(Int(mousePos.x)), \(Int(mousePos.y)))", category: .ui)
                log.debug("Setting needsDisplay=true due to hover change", category: .ui)
                needsDisplay = true
            }
        }
    }
    
    private func handleClick() {
        let mousePos = NSEvent.mouseLocation
        log.debug("handleClick called at (\(Int(mousePos.x)), \(Int(mousePos.y))), checking \(textBlocks.count) blocks, \(drawnRectsGlobal.count) drawn rects", category: .ui)
        
        for (i, block) in textBlocks.enumerated() {
            if hiddenBlockIds.contains(block.originalText) { continue }
            // Use actual drawn rect for hit testing (more accurate)
            if let drawnRect = drawnRectsGlobal[i], drawnRect.contains(mousePos) {
                log.debug("Click hit block \(i) '\(block.originalText.prefix(20))...' at drawn rect (\(Int(drawnRect.minX)), \(Int(drawnRect.minY)), \(Int(drawnRect.width))x\(Int(drawnRect.height)))", category: .ui)
                DispatchQueue.main.async { self.showContextMenu(for: block) }
                return
            }
        }
        log.debug("Click did not hit any block", category: .ui)
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
            log.debug("hideBlock called for '\(text.prefix(30))...' (hidden count: \(hiddenBlockIds.count) -> \(hiddenBlockIds.count + 1))", category: .ui)
            hiddenBlockIds.insert(text)
            log.debug("Setting needsDisplay=true after hideBlock", category: .ui)
            needsDisplay = true
            notifyHiddenChanged()
        }
    }
    
    func unhideBlock(_ originalText: String) {
        let wasHidden = hiddenBlockIds.contains(originalText)
        hiddenBlockIds.remove(originalText)
        log.debug("unhideBlock called for '\(originalText.prefix(30))...' (was hidden: \(wasHidden))", category: .ui)
        log.debug("Setting needsDisplay=true after unhideBlock", category: .ui)
        needsDisplay = true
        notifyHiddenChanged()
    }
    
    func unhideAll() {
        let count = hiddenBlockIds.count
        hiddenBlockIds.removeAll()
        log.debug("unhideAll called (unhid \(count) blocks)", category: .ui)
        log.debug("Setting needsDisplay=true after unhideAll", category: .ui)
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
        log.debug("updateTextBlocks called with \(blocks.count) blocks (current: \(textBlocks.count))", category: .ui)
        
        // Stabilize positions to prevent "breathing" effect
        var stabilizedBlocks: [TranslatedTextBlock] = []
        let threshold = CGFloat(translatorState.stabilityThreshold)
        var stabilizedCount = 0
        var updatedCount = 0
        var newCount = 0
        
        for block in blocks {
            let key = block.originalText
            
            if let existingRect = stablePositions[key] {
                // Check if position changed significantly
                let dx = abs(block.boundingBox.midX - existingRect.midX)
                let dy = abs(block.boundingBox.midY - existingRect.midY)
                
                if dx < threshold && dy < threshold {
                    // Keep old position (prevents jitter)
                    stabilizedCount += 1
                    stabilizedBlocks.append(TranslatedTextBlock(
                        originalText: block.originalText,
                        translatedText: block.translatedText,
                        boundingBox: existingRect,
                        confidence: block.confidence
                    ))
                    log.debug("Position stabilized for '\(key.prefix(20))...': dx=\(String(format: "%.1f", dx)), dy=\(String(format: "%.1f", dy)), threshold=\(String(format: "%.1f", threshold))", category: .ui)
                } else {
                    // Position changed significantly, update it
                    updatedCount += 1
                    stablePositions[key] = block.boundingBox
                    stabilizedBlocks.append(block)
                    log.debug("Position updated for '\(key.prefix(20))...': dx=\(String(format: "%.1f", dx)), dy=\(String(format: "%.1f", dy)), threshold=\(String(format: "%.1f", threshold))", category: .ui)
                }
            } else {
                // New block, store its position
                newCount += 1
                stablePositions[key] = block.boundingBox
                stabilizedBlocks.append(block)
                log.debug("New block added: '\(key.prefix(20))...' at (\(Int(block.boundingBox.midX)), \(Int(block.boundingBox.midY)))", category: .ui)
            }
        }
        
        // Clean up old positions (for blocks that are gone)
        let currentKeys = Set(blocks.map { $0.originalText })
        let removedCount = stablePositions.count - currentKeys.count
        if removedCount > 0 {
            log.debug("Removed \(removedCount) stale position(s) from cache", category: .ui)
        }
        stablePositions = stablePositions.filter { currentKeys.contains($0.key) }
        
        log.debug("Stabilization: \(stabilizedCount) stabilized, \(updatedCount) updated, \(newCount) new", category: .ui)
        
        let blocksChanged = textBlocks.count != stabilizedBlocks.count || 
                           textBlocks.map { $0.originalText } != stabilizedBlocks.map { $0.originalText }
        
        self.textBlocks = stabilizedBlocks
        log.debug("Setting needsDisplay=true after updateTextBlocks (blocks changed: \(blocksChanged))", category: .ui)
        needsDisplay = true
    }
    
    func clearBlocks() {
        log.debug("clearBlocks called (had \(textBlocks.count) blocks, \(stablePositions.count) stable positions, \(drawnRectsGlobal.count) drawn rects)", category: .ui)
        self.textBlocks = []
        self.stablePositions = [:]  // Clear stabilization cache
        self.drawnRectsGlobal = [:]  // Clear hit test rects
        hoveredBlockIndex = nil
        log.debug("Setting needsDisplay=true after clearBlocks", category: .ui)
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        let drawStartTime = Date()
        log.debug("draw() called - dirtyRect: (\(Int(dirtyRect.minX)), \(Int(dirtyRect.minY)), \(Int(dirtyRect.width))x\(Int(dirtyRect.height))), bounds: (\(Int(bounds.minX)), \(Int(bounds.minY)), \(Int(bounds.width))x\(Int(bounds.height))), blocks: \(textBlocks.count), hovered: \(hoveredBlockIndex?.description ?? "nil"), hidden: \(hiddenBlockIds.count)", category: .ui)
        
        super.draw(dirtyRect)
        
        NSColor.clear.setFill()
        bounds.fill()
        
        // Clear previous drawn rects
        let previousDrawnCount = drawnRectsGlobal.count
        drawnRectsGlobal.removeAll()
        log.debug("Cleared \(previousDrawnCount) previous drawn rects", category: .ui)
        
        // Track drawn regions to prevent overlapping duplicates (in local coordinates)
        var drawnLocalRects: [CGRect] = []
        
        // Sort blocks by translation length (prefer longer/more complete translations)
        let sortedIndices = textBlocks.indices.sorted { i, j in
            textBlocks[i].translatedText.count > textBlocks[j].translatedText.count
        }
        
        var drawnCount = 0
        var skippedHidden = 0
        var skippedOverlap = 0
        var skippedNoCenter = 0
        var skippedInvalid = 0
        
        for i in sortedIndices {
            let block = textBlocks[i]
            if hiddenBlockIds.contains(block.originalText) { 
                skippedHidden += 1
                continue 
            }
            
            let isHovered = (hoveredBlockIndex == i)
            // Fix hideOnHover feedback loop: when hideOnHover is enabled and block is hovered,
            // we still draw it but with 0 opacity (completely transparent) so it's still there for hit testing
            // This prevents the mouse from "losing" the block and causing flicker
            let effectiveOpacity: CGFloat
            if translatorState.hideOnHover && isHovered {
                effectiveOpacity = 0.0  // Completely invisible but still there for hit testing
                log.debug("Block \(i) '\(block.originalText.prefix(20))...' is hovered with hideOnHover=true, using opacity 0.0", category: .ui)
            } else {
                effectiveOpacity = CGFloat(translatorState.overlayOpacity)
                log.debug("Block \(i) '\(block.originalText.prefix(20))...' using opacity \(effectiveOpacity) (hideOnHover=\(translatorState.hideOnHover), isHovered=\(isHovered))", category: .ui)
            }
            
            // Get the local center to check for overlap before drawing
            guard let localCenter = getLocalCenter(block.boundingBox) else { 
                skippedNoCenter += 1
                log.debug("Skipping block \(i) '\(block.originalText.prefix(20))...' (no local center)", category: .ui)
                continue 
            }
            
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
            
            if hasSignificantOverlap { 
                skippedOverlap += 1
                log.debug("Skipping block \(i) '\(block.originalText.prefix(20))...' (significant overlap)", category: .ui)
                continue 
            }
            
            if let drawnRect = drawBlock(block, isHovered: isHovered, opacity: effectiveOpacity) {
                drawnRectsGlobal[i] = drawnRect
                drawnCount += 1
                log.debug("Drew block \(i) '\(block.originalText.prefix(20))...' at global (\(Int(drawnRect.minX)), \(Int(drawnRect.minY)), \(Int(drawnRect.width))x\(Int(drawnRect.height))), hovered: \(isHovered), opacity: \(effectiveOpacity)", category: .ui)
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
            } else {
                skippedInvalid += 1
                log.debug("drawBlock returned nil for block \(i) '\(block.originalText.prefix(20))...'", category: .ui)
            }
        }
        
        let drawDuration = Date().timeIntervalSince(drawStartTime) * 1000
        log.debug("draw() completed in \(String(format: "%.2f", drawDuration))ms - drew: \(drawnCount), skipped: hidden=\(skippedHidden), overlap=\(skippedOverlap), noCenter=\(skippedNoCenter), invalid=\(skippedInvalid)", category: .ui)
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
    private func drawBlock(_ block: TranslatedTextBlock, isHovered: Bool, opacity: CGFloat? = nil) -> CGRect? {
        let box = block.boundingBox
        guard box.width > 20, box.height > 15 else { 
            log.debug("drawBlock: block too small (\(Int(box.width))x\(Int(box.height)))", category: .ui)
            return nil 
        }
        
        // Get local center coordinates for this screen
        guard let localCenter = getLocalCenter(box) else { 
            log.debug("drawBlock: failed to get local center for box (\(Int(box.midX)), \(Int(box.midY)))", category: .ui)
            return nil 
        }
        
        let text = block.translatedText
        let fontSize = max(CGFloat(translatorState.fontSize), 8)
        let effectiveOpacity = opacity ?? CGFloat(translatorState.overlayOpacity)
        
        // Check display mode: 0 = box, 1 = outline
        let localRect: CGRect
        if translatorState.overlayDisplayMode == 1 {
            localRect = drawOutlinedText(text: text, center: localCenter, fontSize: fontSize, boxWidth: box.width, isHovered: isHovered, opacity: effectiveOpacity)
        } else {
            localRect = drawBoxText(text: text, center: localCenter, fontSize: fontSize, boxWidth: box.width, isHovered: isHovered, opacity: effectiveOpacity)
        }
        
        // Convert local rect to Cocoa global coordinates for hit testing
        guard let screen = targetScreen ?? NSScreen.main else { 
            log.debug("drawBlock: no screen available", category: .ui)
            return nil 
        }
        let globalRect = CGRect(
            x: localRect.origin.x + screen.frame.origin.x,
            y: localRect.origin.y + screen.frame.origin.y,
            width: localRect.width,
            height: localRect.height
        )
        
        log.debug("drawBlock: drew '\(block.originalText.prefix(20))...' - local: (\(Int(localRect.minX)), \(Int(localRect.minY)), \(Int(localRect.width))x\(Int(localRect.height))), global: (\(Int(globalRect.minX)), \(Int(globalRect.minY)), \(Int(globalRect.width))x\(Int(globalRect.height))), hovered: \(isHovered)", category: .ui)
        
        return globalRect
    }
    
    /// Draw text in a box with background (customizable style)
    /// Returns the drawn rect in view-local coordinates
    private func drawBoxText(text: String, center: CGPoint, fontSize: CGFloat, boxWidth: CGFloat, isHovered: Bool, opacity: CGFloat? = nil) -> CGRect {
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
        let effectiveOpacity = opacity ?? CGFloat(translatorState.overlayOpacity)
        
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
        
        // Only draw visual elements if opacity > 0 (when opacity is 0, we still return rect for hit testing)
        log.debug("drawBoxText: effectiveOpacity=\(effectiveOpacity), will draw: \(effectiveOpacity > 0), hideOnHover=\(translatorState.hideOnHover), isHovered=\(isHovered)", category: .ui)
        
        // Ensure we have a valid graphics context
        guard let context = NSGraphicsContext.current else {
            log.error("drawBoxText: No graphics context available!", category: .ui)
            return rect
        }
        
        if effectiveOpacity > 0 {
            // Shadow (if enabled)
            if shadowEnabled {
                let shadowPath = NSBezierPath(roundedRect: rect.offsetBy(dx: 1, dy: -1), xRadius: cornerRadius, yRadius: cornerRadius)
                NSColor.black.withAlphaComponent(0.15 * effectiveOpacity).setFill()
                shadowPath.fill()
            }
            
            // Background with opacity
            let bgPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
            backgroundColor.withAlphaComponent(effectiveOpacity).setFill()
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
            
            // Apply opacity to text color as well
            var textAttrs = attrs
            if let currentColor = textAttrs[.foregroundColor] as? NSColor {
                textAttrs[.foregroundColor] = currentColor.withAlphaComponent(effectiveOpacity)
            }
            
            text.draw(in: textRect, withAttributes: textAttrs)
            log.debug("drawBoxText: Finished drawing block with opacity \(effectiveOpacity)", category: .ui)
        } else {
            log.debug("drawBoxText: Skipping visual drawing (opacity=0), but returning rect for hit testing", category: .ui)
        }
        
        return rect
    }
    
    /// Draw text with outline stroke effect (subtitle style)
    /// Returns the drawn rect in view-local coordinates
    private func drawOutlinedText(text: String, center: CGPoint, fontSize: CGFloat, boxWidth: CGFloat, isHovered: Bool, opacity: CGFloat? = nil) -> CGRect {
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let outlineWidth = CGFloat(translatorState.outlineWidth)
        
        // Parse colors from hex
        let effectiveOpacity = opacity ?? CGFloat(translatorState.overlayOpacity)
        var textColor = NSColor(hex: translatorState.textColorHex) ?? NSColor.white
        var outlineColor = NSColor(hex: translatorState.outlineColorHex) ?? NSColor.black
        
        // Apply opacity to colors for outline mode
        textColor = textColor.withAlphaComponent(effectiveOpacity)
        outlineColor = outlineColor.withAlphaComponent(effectiveOpacity)
        
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
        
        // Only draw visual elements if opacity > 0 (when opacity is 0, we still return rect for hit testing)
        log.debug("drawOutlinedText: effectiveOpacity=\(effectiveOpacity), will draw: \(effectiveOpacity > 0), hideOnHover=\(translatorState.hideOnHover), isHovered=\(isHovered)", category: .ui)
        
        // Ensure we have a valid graphics context
        guard let context = NSGraphicsContext.current else {
            log.error("drawOutlinedText: No graphics context available!", category: .ui)
            return textRect
        }
        
        if effectiveOpacity > 0 {
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
            log.debug("drawOutlinedText: Finished drawing block with opacity \(effectiveOpacity)", category: .ui)
        } else {
            log.debug("drawOutlinedText: Skipping visual drawing (opacity=0), but returning rect for hit testing", category: .ui)
        }
        
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


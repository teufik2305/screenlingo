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
    
    // Simple: use the original bounding box for hit testing
    private func getHitRect(_ block: TranslatedTextBlock, screenHeight: CGFloat) -> CGRect {
        let box = block.boundingBox
        return CGRect(
            x: box.origin.x,
            y: screenHeight - box.origin.y - box.height,
            width: box.width,
            height: box.height
        )
    }
    
    private func handleMouseMoved() {
        guard let screen = NSScreen.main else { return }
        let mousePos = NSEvent.mouseLocation
        let screenH = screen.frame.height
        
        var newHovered: Int? = nil
        for (i, block) in textBlocks.enumerated() {
            if hiddenBlockIds.contains(block.originalText) { continue }
            if getHitRect(block, screenHeight: screenH).contains(mousePos) {
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
        guard let screen = NSScreen.main else { return }
        let mousePos = NSEvent.mouseLocation
        let screenH = screen.frame.height
        
        for block in textBlocks {
            if hiddenBlockIds.contains(block.originalText) { continue }
            if getHitRect(block, screenHeight: screenH).contains(mousePos) {
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
        hoveredBlockIndex = nil
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        NSColor.clear.setFill()
        bounds.fill()
        
        guard let screen = NSScreen.main else { return }
        let screenH = screen.frame.height
        
        for (i, block) in textBlocks.enumerated() {
            if hiddenBlockIds.contains(block.originalText) { continue }
            
            let isHovered = (hoveredBlockIndex == i)
            if translatorState.hideOnHover && isHovered { continue }
            
            drawBlock(block, screenHeight: screenH, isHovered: isHovered)
        }
    }
    
    private func drawBlock(_ block: TranslatedTextBlock, screenHeight: CGFloat, isHovered: Bool) {
        let box = block.boundingBox
        guard box.width > 20, box.height > 15 else { return }
        
        let text = block.translatedText
        let fontSize = max(CGFloat(translatorState.fontSize), 13)
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        para.lineBreakMode = .byWordWrapping
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,
            .paragraphStyle: para
        ]
        
        // Use original box width, min 120
        let wrapWidth = max(box.width, 120)
        let textBounds = text.boundingRect(
            with: CGSize(width: wrapWidth - 20, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs
        )
        
        // Add extra line height to prevent clipping at certain font sizes
        let lineHeight = font.ascender - font.descender + font.leading
        let textW = ceil(textBounds.width) + 2
        let textH = ceil(textBounds.height) + ceil(lineHeight * 0.3)  // Extra buffer
        
        // Rect sized for text, centered on original box center
        let rectW = textW + 24
        let rectH = textH + 16
        let centerX = box.midX
        let centerY = screenHeight - box.midY
        
        let rect = CGRect(x: centerX - rectW/2, y: centerY - rectH/2, width: rectW, height: rectH)
        
        // Shadow
        let shadowPath = NSBezierPath(roundedRect: rect.offsetBy(dx: 1, dy: -1), xRadius: 5, yRadius: 5)
        NSColor.black.withAlphaComponent(0.12).setFill()
        shadowPath.fill()
        
        // Background
        let bgPath = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
        NSColor.white.withAlphaComponent(CGFloat(translatorState.overlayOpacity)).setFill()
        bgPath.fill()
        
        // Border
        if isHovered && !translatorState.hideOnHover {
            NSColor.systemBlue.setStroke()
            bgPath.lineWidth = 2.5
        } else {
            NSColor.black.withAlphaComponent(0.1).setStroke()
            bgPath.lineWidth = 1
        }
        bgPath.stroke()
        
        // Text - centered in rect (use ceiled dimensions)
        let textRect = CGRect(
            x: rect.midX - textW / 2,
            y: rect.midY - textH / 2,
            width: textW,
            height: textH
        )
        
        text.draw(in: textRect, withAttributes: attrs)
    }
    
    override var isFlipped: Bool { false }
}


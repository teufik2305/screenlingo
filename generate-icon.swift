#!/usr/bin/env swift

import Cocoa
import Foundation

// Generate ScreenLingo app icon - clear text overlay visualization

func createAppIcon(size: Int) -> NSImage {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)
    
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    
    let context = NSGraphicsContext.current!.cgContext
    let s = CGFloat(size)
    let center = CGPoint(x: s/2, y: s/2)
    let padding = s * 0.06
    
    // === BACKGROUND ===
    let cornerRadius = s * 0.22
    let bgRect = CGRect(x: padding, y: padding, width: s - padding*2, height: s - padding*2)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    
    // Rich gradient: indigo to purple
    let bgColors = [
        NSColor(red: 0.25, green: 0.15, blue: 0.5, alpha: 1.0).cgColor,
        NSColor(red: 0.35, green: 0.2, blue: 0.55, alpha: 1.0).cgColor,
        NSColor(red: 0.3, green: 0.25, blue: 0.6, alpha: 1.0).cgColor
    ]
    let bgGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: bgColors as CFArray,
                                 locations: [0, 0.5, 1])!
    
    context.saveGState()
    context.addPath(bgPath)
    context.clip()
    context.drawLinearGradient(bgGradient,
                               start: CGPoint(x: padding, y: s - padding),
                               end: CGPoint(x: s - padding, y: padding),
                               options: [])
    context.restoreGState()
    
    // === GLOSSY TOP SHINE ===
    context.saveGState()
    context.addPath(bgPath)
    context.clip()
    let shineGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: [NSColor.white.withAlphaComponent(0.35).cgColor,
                                            NSColor.white.withAlphaComponent(0.05).cgColor,
                                            NSColor.clear.cgColor] as CFArray,
                                    locations: [0, 0.3, 0.55])!
    context.drawRadialGradient(shineGradient,
                               startCenter: CGPoint(x: s * 0.25, y: s * 0.8),
                               startRadius: 0,
                               endCenter: CGPoint(x: s * 0.4, y: s * 0.65),
                               endRadius: s * 0.6,
                               options: [])
    context.restoreGState()
    
    // === BACK TEXT PANEL (original text - being covered) ===
    let backW = s * 0.55
    let backH = s * 0.5
    let backX = s * 0.12
    let backY = s * 0.38
    let backCorner = s * 0.04
    
    // Back panel - semi-transparent, gray-ish
    context.saveGState()
    context.setFillColor(NSColor(white: 0.85, alpha: 0.7).cgColor)
    let backPath = CGPath(roundedRect: CGRect(x: backX, y: backY, width: backW, height: backH),
                          cornerWidth: backCorner, cornerHeight: backCorner, transform: nil)
    context.addPath(backPath)
    context.fillPath()
    
    // "Original" text lines (Japanese style - vertical could work but horizontal is clearer)
    context.setFillColor(NSColor(white: 0.3, alpha: 0.6).cgColor)
    let lineH = s * 0.035
    for i in 0..<4 {
        let lineY = backY + backH - s * 0.1 - CGFloat(i) * s * 0.1
        let lineW = s * (0.35 - CGFloat(i % 2) * 0.08)
        context.fill(CGRect(x: backX + s * 0.05, y: lineY, width: lineW, height: lineH))
    }
    context.restoreGState()
    
    // === FRONT OVERLAY PANEL (translation - on top) ===
    let frontW = s * 0.6
    let frontH = s * 0.45
    let frontX = s * 0.32
    let frontY = s * 0.18
    let frontCorner = s * 0.05
    
    // Shadow
    context.saveGState()
    context.setShadow(offset: CGSize(width: s * 0.015, height: -s * 0.02),
                      blur: s * 0.045,
                      color: NSColor.black.withAlphaComponent(0.4).cgColor)
    
    let frontPath = CGPath(roundedRect: CGRect(x: frontX, y: frontY, width: frontW, height: frontH),
                           cornerWidth: frontCorner, cornerHeight: frontCorner, transform: nil)
    
    // Glossy white gradient
    context.addPath(frontPath)
    context.clip()
    let frontGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: [NSColor.white.cgColor,
                                            NSColor(white: 0.98, alpha: 1).cgColor,
                                            NSColor(white: 0.95, alpha: 1).cgColor] as CFArray,
                                    locations: [0, 0.5, 1])!
    context.drawLinearGradient(frontGradient,
                               start: CGPoint(x: frontX, y: frontY + frontH),
                               end: CGPoint(x: frontX, y: frontY),
                               options: [])
    context.restoreGState()
    
    // Front panel border
    context.setStrokeColor(NSColor(white: 0.85, alpha: 1).cgColor)
    context.setLineWidth(s * 0.008)
    context.addPath(frontPath)
    context.strokePath()
    
    // === TRANSLATION TEXT in front panel ===
    let textColor = NSColor(red: 0.2, green: 0.15, blue: 0.4, alpha: 1.0)
    context.setFillColor(textColor.cgColor)
    
    // Text lines (representing translated text)
    let textLineH = s * 0.04
    let textX = frontX + s * 0.06
    
    // Line 1 - longest
    context.fill(CGRect(x: textX, y: frontY + frontH - s * 0.12, width: s * 0.4, height: textLineH))
    // Line 2
    context.fill(CGRect(x: textX, y: frontY + frontH - s * 0.2, width: s * 0.35, height: textLineH))
    // Line 3 - shorter
    context.fill(CGRect(x: textX, y: frontY + frontH - s * 0.28, width: s * 0.28, height: textLineH))
    
    // === OVERLAY ARROW INDICATOR ===
    // Arrow showing "overlay on top" concept
    let arrowColor = NSColor(red: 1.0, green: 0.45, blue: 0.25, alpha: 1.0)
    context.setFillColor(arrowColor.cgColor)
    
    let arrowX = s * 0.22
    let arrowY = s * 0.28
    let arrowSize = s * 0.07
    
    // Curved arrow pointing to front panel
    context.saveGState()
    context.setShadow(offset: CGSize(width: 1, height: -1), blur: 2, color: NSColor.black.withAlphaComponent(0.3).cgColor)
    
    let arrow = CGMutablePath()
    arrow.move(to: CGPoint(x: arrowX, y: arrowY + arrowSize))
    arrow.addLine(to: CGPoint(x: arrowX + arrowSize, y: arrowY + arrowSize/2))
    arrow.addLine(to: CGPoint(x: arrowX, y: arrowY))
    arrow.addLine(to: CGPoint(x: arrowX + arrowSize * 0.3, y: arrowY + arrowSize/2))
    arrow.closeSubpath()
    context.addPath(arrow)
    context.fillPath()
    context.restoreGState()
    
    // === TRANSLATION INDICATOR "A→文" ===
    // Shows this is a translator - text on the front panel
    let indicatorY = frontY + s * 0.06
    let fontSize = s * 0.09
    let smallFont = NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let kanjiFont = NSFont.systemFont(ofSize: fontSize * 1.1, weight: .bold)
    let arrowFontSize = fontSize * 0.7
    
    // "A" character
    let aColor = NSColor(red: 0.25, green: 0.2, blue: 0.5, alpha: 0.8)
    let aAttrs: [NSAttributedString.Key: Any] = [.font: smallFont, .foregroundColor: aColor]
    let aStr = NSAttributedString(string: "A", attributes: aAttrs)
    aStr.draw(at: CGPoint(x: frontX + frontW - s * 0.24, y: indicatorY))
    
    // Arrow "→"
    let arrowAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: arrowFontSize, weight: .medium),
        .foregroundColor: NSColor(red: 1.0, green: 0.5, blue: 0.3, alpha: 1.0)
    ]
    let arrowStrText = NSAttributedString(string: "→", attributes: arrowAttrs)
    arrowStrText.draw(at: CGPoint(x: frontX + frontW - s * 0.17, y: indicatorY + s * 0.01))
    
    // "文" kanji
    let kanjiAttrs: [NSAttributedString.Key: Any] = [.font: kanjiFont, .foregroundColor: aColor]
    let kanjiStrText = NSAttributedString(string: "文", attributes: kanjiAttrs)
    kanjiStrText.draw(at: CGPoint(x: frontX + frontW - s * 0.11, y: indicatorY - s * 0.005))
    
    // === GLOSSY SHINE on front panel ===
    context.saveGState()
    context.addPath(frontPath)
    context.clip()
    let panelShine = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: [NSColor.white.withAlphaComponent(0.5).cgColor,
                                         NSColor.clear.cgColor] as CFArray,
                                 locations: [0, 1])!
    context.drawLinearGradient(panelShine,
                               start: CGPoint(x: frontX, y: frontY + frontH),
                               end: CGPoint(x: frontX, y: frontY + frontH * 0.6),
                               options: [])
    context.restoreGState()
    
    // === CORNER ACCENT LINES ===
    context.saveGState()
    context.addPath(bgPath)
    context.clip()
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.1).cgColor)
    context.setLineWidth(s * 0.005)
    for i in 0..<4 {
        let offset = CGFloat(i) * s * 0.02
        context.move(to: CGPoint(x: s - padding - s * 0.1 + offset, y: padding + s * 0.015))
        context.addLine(to: CGPoint(x: s - padding - s * 0.015, y: padding + s * 0.1 - offset))
    }
    context.strokePath()
    context.restoreGState()
    
    NSGraphicsContext.restoreGraphicsState()
    
    let image = NSImage(size: NSSize(width: size, height: size))
    image.addRepresentation(rep)
    return image
}

func savePNG(_ image: NSImage, to path: String) {
    guard let rep = image.representations.first as? NSBitmapImageRep,
          let pngData = rep.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for \(path)")
        return
    }
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("✓ \(path)")
    } catch {
        print("✗ \(path): \(error)")
    }
}

let iconsetPath = "AppIcon.appiconset"
let fm = FileManager.default
if !fm.fileExists(atPath: iconsetPath) {
    try! fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)
}

let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png")
]

print("🎨 Generating ScreenLingo icons...")
for (size, filename) in sizes {
    savePNG(createAppIcon(size: size), to: "\(iconsetPath)/\(filename)")
}

let json = """
{"images":[
{"filename":"icon_16x16.png","idiom":"mac","scale":"1x","size":"16x16"},
{"filename":"icon_16x16@2x.png","idiom":"mac","scale":"2x","size":"16x16"},
{"filename":"icon_32x32.png","idiom":"mac","scale":"1x","size":"32x32"},
{"filename":"icon_32x32@2x.png","idiom":"mac","scale":"2x","size":"32x32"},
{"filename":"icon_128x128.png","idiom":"mac","scale":"1x","size":"128x128"},
{"filename":"icon_128x128@2x.png","idiom":"mac","scale":"2x","size":"128x128"},
{"filename":"icon_256x256.png","idiom":"mac","scale":"1x","size":"256x256"},
{"filename":"icon_256x256@2x.png","idiom":"mac","scale":"2x","size":"256x256"},
{"filename":"icon_512x512.png","idiom":"mac","scale":"1x","size":"512x512"},
{"filename":"icon_512x512@2x.png","idiom":"mac","scale":"2x","size":"512x512"}
],"info":{"author":"xcode","version":1}}
"""
try! json.write(toFile: "\(iconsetPath)/Contents.json", atomically: true, encoding: .utf8)
print("✓ Contents.json\n🎉 Done!")

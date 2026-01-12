import SwiftUI

struct OverlayPreview: View {
    let fontSize: Double
    let opacity: Double
    var displayMode: Int = 0  // 0 = box, 1 = outline
    var outlineWidth: Double = 2.0
    var textColorHex: String = "#FFFFFF"
    var outlineColorHex: String = "#000000"
    
    // Box mode settings
    var boxPaddingH: Double = 12
    var boxPaddingV: Double = 8
    var boxCornerRadius: Double = 5
    var boxBackgroundColorHex: String = "#FFFFFF"
    var boxTextColorHex: String = "#000000"
    var boxBorderWidth: Double = 0
    var boxBorderColorHex: String = "#000000"
    var boxShadowEnabled: Bool = true
    var boxCoverOriginal: Bool = true
    
    private func hexToColor(_ hex: String) -> Color {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        return Color(red: r, green: g, blue: b)
    }
    
    var body: some View {
        ZStack {
            // Simulated "original text" behind the overlay
            VStack(spacing: 4) {
                Text("ORIGINAL TEXT")
                    .font(.system(size: fontSize * 0.9, weight: .bold))
                    .foregroundColor(.gray.opacity(0.6))
                Text("underneath")
                    .font(.system(size: fontSize * 0.7))
                    .foregroundColor(.gray.opacity(0.4))
            }
            
            // Checkerboard pattern to show transparency
            GeometryReader { geo in
                let cellSize: CGFloat = 8
                let cols = Int(ceil(geo.size.width / cellSize))
                let rows = Int(ceil(geo.size.height / cellSize))
                
                Canvas { context, size in
                    for row in 0..<rows {
                        for col in 0..<cols {
                            let isLight = (row + col) % 2 == 0
                            let rect = CGRect(
                                x: CGFloat(col) * cellSize,
                                y: CGFloat(row) * cellSize,
                                width: cellSize,
                                height: cellSize
                            )
                            context.fill(
                                Path(rect),
                                with: .color(isLight ? Color.gray.opacity(0.08) : Color.gray.opacity(0.15))
                            )
                        }
                    }
                }
            }
            .cornerRadius(6)
            
            // Overlay preview based on mode
            if displayMode == 0 {
                // Box mode
                BoxPreview(
                    text: "Preview text",
                    fontSize: fontSize,
                    opacity: opacity,
                    paddingH: boxPaddingH,
                    paddingV: boxPaddingV,
                    cornerRadius: boxCornerRadius,
                    backgroundColor: hexToColor(boxBackgroundColorHex),
                    textColor: hexToColor(boxTextColorHex),
                    borderWidth: boxBorderWidth,
                    borderColor: hexToColor(boxBorderColorHex),
                    shadowEnabled: boxShadowEnabled,
                    coverOriginal: boxCoverOriginal
                )
            } else {
                // Outline mode
                OutlinedText(
                    text: "Preview text",
                    fontSize: fontSize,
                    outlineWidth: outlineWidth,
                    textColor: hexToColor(textColorHex),
                    outlineColor: hexToColor(outlineColorHex)
                )
            }
        }
        .frame(height: 70)
    }
}

/// Box style preview with all customization options
struct BoxPreview: View {
    let text: String
    let fontSize: Double
    let opacity: Double
    let paddingH: Double
    let paddingV: Double
    let cornerRadius: Double
    let backgroundColor: Color
    let textColor: Color
    let borderWidth: Double
    let borderColor: Color
    let shadowEnabled: Bool
    let coverOriginal: Bool
    
    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundColor(textColor)
            .padding(.horizontal, paddingH)
            .padding(.vertical, paddingV)
            .background(
                ZStack {
                    // Solid cover layer (to hide original text)
                    if coverOriginal {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(backgroundColor)
                    }
                    // Semi-transparent layer on top
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(backgroundColor.opacity(opacity))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .shadow(color: shadowEnabled ? .black.opacity(0.15) : .clear, radius: 2, x: 1, y: 1)
    }
}

/// Text with outline stroke effect
struct OutlinedText: View {
    let text: String
    let fontSize: Double
    let outlineWidth: Double
    let textColor: Color
    let outlineColor: Color
    
    var body: some View {
        ZStack {
            // Outline strokes in 8 directions for smooth outline
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) * .pi / 4
                let dx = cos(angle) * outlineWidth
                let dy = sin(angle) * outlineWidth
                
                Text(text)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(outlineColor)
                    .offset(x: dx, y: dy)
            }
            
            // Main text on top
            Text(text)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundColor(textColor)
        }
    }
}


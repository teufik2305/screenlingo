import SwiftUI

struct AppearanceSettingsTab: View {
    @ObservedObject var state: TranslatorState
    
    // MARK: - Color Bindings
    
    private var textColorBinding: Binding<Color> {
        Binding(
            get: { hexToColor(state.textColorHex) },
            set: { state.textColorHex = colorToHex($0) }
        )
    }
    
    private var outlineColorBinding: Binding<Color> {
        Binding(
            get: { hexToColor(state.outlineColorHex) },
            set: { state.outlineColorHex = colorToHex($0) }
        )
    }
    
    private var boxBackgroundColorBinding: Binding<Color> {
        Binding(
            get: { hexToColor(state.boxBackgroundColorHex) },
            set: { state.boxBackgroundColorHex = colorToHex($0) }
        )
    }
    
    private var boxTextColorBinding: Binding<Color> {
        Binding(
            get: { hexToColor(state.boxTextColorHex) },
            set: { state.boxTextColorHex = colorToHex($0) }
        )
    }
    
    private var boxBorderColorBinding: Binding<Color> {
        Binding(
            get: { hexToColor(state.boxBorderColorHex) },
            set: { state.boxBorderColorHex = colorToHex($0) }
        )
    }
    
    // MARK: - Color Helpers
    
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
    
    private func colorToHex(_ color: Color) -> String {
        guard let cgColor = color.cgColor,
              let components = cgColor.components,
              components.count >= 3 else {
            let nsColor = NSColor(color)
            if let converted = nsColor.usingColorSpace(.sRGB) {
                let r = Int(converted.redComponent * 255)
                let g = Int(converted.greenComponent * 255)
                let b = Int(converted.blueComponent * 255)
                return String(format: "#%02X%02X%02X", r, g, b)
            }
            return "#FFFFFF"
        }
        
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                settingsSection("Display Mode") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Style", selection: $state.overlayDisplayMode) {
                            Text("Box").tag(0)
                            Text("Outline").tag(1)
                        }
                        .pickerStyle(.segmented)
                        
                        Text(state.overlayDisplayMode == 0 
                             ? "Text displayed in rounded boxes with background" 
                             : "Text displayed with outline stroke (like subtitles)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                settingsSection("Text") {
                    VStack(alignment: .leading, spacing: 12) {
                        // Font Size
                        HStack {
                            Text("Font Size")
                                .frame(width: 120, alignment: .leading)
                            Slider(value: $state.fontSize, in: 8...32, step: 1)
                            Text("\(Int(state.fontSize))pt")
                                .frame(width: 40)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }
                
                // Box mode settings
                if state.overlayDisplayMode == 0 {
                    settingsSection("Box Style") {
                        VStack(alignment: .leading, spacing: 12) {
                            // Opacity
                            HStack {
                                Text("Opacity")
                                    .frame(width: 120, alignment: .leading)
                                Slider(value: $state.overlayOpacity, in: 0.0...1.0, step: 0.05)
                                Text("\(Int(state.overlayOpacity * 100))%")
                                    .frame(width: 40)
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            // Padding
                            HStack {
                                Text("Horizontal Padding")
                                    .frame(width: 120, alignment: .leading)
                                Slider(value: $state.boxPaddingH, in: 4...24, step: 2)
                                Text("\(Int(state.boxPaddingH))px")
                                    .frame(width: 40)
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            HStack {
                                Text("Vertical Padding")
                                    .frame(width: 120, alignment: .leading)
                                Slider(value: $state.boxPaddingV, in: 2...16, step: 2)
                                Text("\(Int(state.boxPaddingV))px")
                                    .frame(width: 40)
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            // Corner radius
                            HStack {
                                Text("Corner Radius")
                                    .frame(width: 120, alignment: .leading)
                                Slider(value: $state.boxCornerRadius, in: 0...16, step: 1)
                                Text("\(Int(state.boxCornerRadius))px")
                                    .frame(width: 40)
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            Divider()
                            
                            // Colors
                            HStack {
                                Text("Background Color")
                                    .frame(width: 120, alignment: .leading)
                                Spacer()
                                ColorPicker("", selection: boxBackgroundColorBinding)
                                    .labelsHidden()
                            }
                            
                            HStack {
                                Text("Text Color")
                                    .frame(width: 120, alignment: .leading)
                                Spacer()
                                ColorPicker("", selection: boxTextColorBinding)
                                    .labelsHidden()
                            }
                            
                            Divider()
                            
                            // Border
                            HStack {
                                Text("Border Width")
                                    .frame(width: 120, alignment: .leading)
                                Slider(value: $state.boxBorderWidth, in: 0...4, step: 0.5)
                                Text("\(String(format: "%.1f", state.boxBorderWidth))px")
                                    .frame(width: 45)
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            if state.boxBorderWidth > 0 {
                                HStack {
                                    Text("Border Color")
                                        .frame(width: 120, alignment: .leading)
                                    Spacer()
                                    ColorPicker("", selection: boxBorderColorBinding)
                                        .labelsHidden()
                                }
                            }
                            
                            // Shadow
                            Toggle("Drop Shadow", isOn: $state.boxShadowEnabled)
                        }
                    }
                }
                
                // Outline mode settings
                if state.overlayDisplayMode == 1 {
                    settingsSection("Outline Style") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Outline Width")
                                    .frame(width: 120, alignment: .leading)
                                Slider(value: $state.outlineWidth, in: 1...6, step: 0.5)
                                Text("\(String(format: "%.1f", state.outlineWidth))px")
                                    .frame(width: 45)
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("Text Color")
                                    .frame(width: 120, alignment: .leading)
                                Spacer()
                                ColorPicker("", selection: textColorBinding)
                                    .labelsHidden()
                            }
                            
                            HStack {
                                Text("Outline Color")
                                    .frame(width: 120, alignment: .leading)
                                Spacer()
                                ColorPicker("", selection: outlineColorBinding)
                                    .labelsHidden()
                            }
                        }
                    }
                }
                
                settingsSection("Window") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Always on Top", isOn: $state.alwaysOnTop)
                        Text("When enabled, overlay appears above all windows including fullscreen apps.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                settingsSection("Preview") {
                    OverlayPreview(
                        fontSize: state.fontSize,
                        opacity: state.overlayOpacity,
                        displayMode: state.overlayDisplayMode,
                        outlineWidth: state.outlineWidth,
                        textColorHex: state.textColorHex,
                        outlineColorHex: state.outlineColorHex,
                        boxPaddingH: state.boxPaddingH,
                        boxPaddingV: state.boxPaddingV,
                        boxCornerRadius: state.boxCornerRadius,
                        boxBackgroundColorHex: state.boxBackgroundColorHex,
                        boxTextColorHex: state.boxTextColorHex,
                        boxBorderWidth: state.boxBorderWidth,
                        boxBorderColorHex: state.boxBorderColorHex,
                        boxShadowEnabled: state.boxShadowEnabled
                    )
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            
            content()
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
        }
    }
}


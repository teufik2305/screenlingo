import SwiftUI

struct AppearanceSettingsTab: View {
    @ObservedObject var state: TranslatorState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                settingsSection("Overlay Style") {
                    VStack(alignment: .leading, spacing: 12) {
                        // Font Size
                        HStack {
                            Text("Font Size")
                                .frame(width: 100, alignment: .leading)
                            Slider(value: $state.fontSize, in: 12...24, step: 1)
                            Text("\(Int(state.fontSize))pt")
                                .frame(width: 40)
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        // Opacity
                        HStack {
                            Text("Opacity")
                                .frame(width: 100, alignment: .leading)
                            Slider(value: $state.overlayOpacity, in: 0.7...1.0, step: 0.05)
                            Text("\(Int(state.overlayOpacity * 100))%")
                                .frame(width: 40)
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        // Always on Top
                        HStack {
                            Toggle("Always on Top", isOn: $state.alwaysOnTop)
                            Spacer()
                        }
                        Text("When enabled, overlay appears above all windows. Disable to allow other windows to cover the overlay.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Divider()
                        
                        // Single unified preview
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Preview")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            OverlayPreview(fontSize: state.fontSize, opacity: state.overlayOpacity)
                        }
                    }
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

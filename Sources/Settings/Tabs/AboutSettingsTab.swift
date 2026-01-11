import SwiftUI

struct AboutSettingsTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Application
                settingsSection("Application") {
                    HStack(spacing: 16) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .frame(width: 64, height: 64)
                            .cornerRadius(14)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ScreenLingo")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Version 1.0")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Text("Real-time screen translation for macOS")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Spacer()
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

import SwiftUI

struct FiltersSettingsTab: View {
    @ObservedObject var state: TranslatorState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Excluded Apps
                settingsSection("Excluded Apps") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Translation is disabled for these apps:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        ExcludedAppsEditor(state: state)
                    }
                }
                
                // Ignore Patterns
                settingsSection("Ignore Patterns") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Text containing these patterns will be ignored:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        IgnoreListEditor(state: state)
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

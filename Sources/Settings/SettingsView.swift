import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: TranslatorState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            TabView {
                // General Tab
                GeneralSettingsTab(state: state)
                    .tabItem {
                        Label("General", systemImage: "gearshape")
                    }
                
                // Appearance Tab
                AppearanceSettingsTab(state: state)
                    .tabItem {
                        Label("Appearance", systemImage: "paintbrush")
                    }
                
                // Filters Tab
                FiltersSettingsTab(state: state)
                    .tabItem {
                        Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                    }
                
                // Advanced Tab
                AdvancedSettingsTab(state: state)
                    .tabItem {
                        Label("Advanced", systemImage: "wrench.and.screwdriver")
                    }
                
                // About Tab
                AboutSettingsTab()
                    .tabItem {
                        Label("About", systemImage: "info.circle")
                    }
            }
            .padding(.top, 8)
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.return)
            }
            .padding()
        }
        .frame(minWidth: 450, maxWidth: .infinity, minHeight: 500, maxHeight: .infinity)
    }
}

import SwiftUI

struct ExcludedAppsEditor: View {
    @ObservedObject var state: TranslatorState
    @State private var newBundleId = ""
    
    var body: some View {
        VStack(spacing: 8) {
            // Add new app
            HStack {
                TextField("Bundle ID (e.g. com.apple.Safari)", text: $newBundleId)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { addApp() }
                
                Button("Add") { addApp() }
                    .disabled(newBundleId.isEmpty)
            }
            
            // Common apps quick-add
            HStack(spacing: 8) {
                Text("Quick add:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                QuickAddButton(label: "Cursor", bundleId: "com.todesktop.230313mzl4w4u92", state: state)
                QuickAddButton(label: "VS Code", bundleId: "com.microsoft.VSCode", state: state)
                QuickAddButton(label: "Xcode", bundleId: "com.apple.dt.Xcode", state: state)
                QuickAddButton(label: "Terminal", bundleId: "com.apple.Terminal", state: state)
            }
            
            // App list
            if state.excludedAppsManager.excludedApps.isEmpty {
                Text("No excluded apps")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .padding(.vertical, 4)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(state.excludedAppsManager.excludedApps, id: \.self) { bundleId in
                        AppTag(bundleId: bundleId) {
                            state.excludedAppsManager.removeExcludedApp(bundleId)
                        }
                    }
                }
            }
        }
    }
    
    private func addApp() {
        let trimmed = newBundleId.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            state.excludedAppsManager.addExcludedApp(trimmed)
            newBundleId = ""
        }
    }
}

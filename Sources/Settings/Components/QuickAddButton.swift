import SwiftUI

struct QuickAddButton: View {
    let label: String
    let bundleId: String
    @ObservedObject var state: TranslatorState
    
    var isAdded: Bool {
        state.excludedAppsManager.excludedApps.contains(bundleId)
    }
    
    var body: some View {
        Button(action: {
            if isAdded {
                state.excludedAppsManager.removeExcludedApp(bundleId)
            } else {
                state.excludedAppsManager.addExcludedApp(bundleId)
            }
        }) {
            Text(label)
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .tint(isAdded ? .green : .gray)
    }
}

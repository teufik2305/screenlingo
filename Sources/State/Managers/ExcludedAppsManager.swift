import Foundation
import Combine

/// Manages the list of excluded applications
class ExcludedAppsManager: ObservableObject {
    private static let preferencesStore = UserDefaults(suiteName: "com.screenlingo.shared")!
    private static let key = "excludedApps"
    private static let defaultApps = "com.todesktop.230313mzl4w4u92,com.microsoft.VSCode,com.apple.dt.Xcode,com.apple.Terminal,com.googlecode.iterm2"
    
    @Published var excludedApps: [String] = []
    
    init() {
        load()
    }
    
    private func load() {
        let string = Self.preferencesStore.string(forKey: Self.key) ?? Self.defaultApps
        excludedApps = string.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        log.debug("Loaded \(excludedApps.count) excluded apps", category: .state)
    }
    
    private func save() {
        let string = excludedApps.joined(separator: ",")
        Self.preferencesStore.set(string, forKey: Self.key)
    }
    
    func isAppExcluded(_ bundleIdentifier: String?) -> Bool {
        guard let bundleId = bundleIdentifier else { return false }
        return excludedApps.contains { bundleId.lowercased().contains($0.lowercased()) }
    }
    
    func addExcludedApp(_ bundleId: String) {
        let normalized = bundleId.trimmingCharacters(in: .whitespaces)
        if !normalized.isEmpty && !excludedApps.contains(normalized) {
            excludedApps.append(normalized)
            save()
            log.info("Added excluded app: \(normalized)", category: .state)
        }
    }
    
    func removeExcludedApp(_ bundleId: String) {
        excludedApps.removeAll { $0 == bundleId }
        save()
        log.info("Removed excluded app: \(bundleId)", category: .state)
    }
}

import Foundation
import Combine

/// Manages text ignore patterns (regex/substring matching)
class IgnorePatternManager: ObservableObject {
    private static let preferencesStore = UserDefaults(suiteName: "com.screenlingo.shared")!
    private static let key = "ignoredPatterns"
    
    @Published var ignoredPatterns: [String] = []
    
    init() {
        load()
    }
    
    private func load() {
        let string = Self.preferencesStore.string(forKey: Self.key) ?? ""
        ignoredPatterns = string.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces).lowercased() }
        log.debug("Loaded \(ignoredPatterns.count) ignore patterns", category: .state)
    }
    
    private func save() {
        let string = ignoredPatterns.joined(separator: ",")
        Self.preferencesStore.set(string, forKey: Self.key)
    }
    
    func addIgnoredPattern(_ pattern: String) {
        let normalized = pattern.trimmingCharacters(in: .whitespaces).lowercased()
        if !normalized.isEmpty && !ignoredPatterns.contains(normalized) {
            ignoredPatterns.append(normalized)
            save()
            log.info("Added ignore pattern: \(normalized)", category: .state)
        }
    }
    
    func removeIgnoredPattern(_ pattern: String) {
        ignoredPatterns.removeAll { $0 == pattern.lowercased() }
        save()
        log.info("Removed ignore pattern: \(pattern)", category: .state)
    }
    
    func shouldIgnoreText(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return ignoredPatterns.contains { pattern in
            lowercased.contains(pattern)
        }
    }
}

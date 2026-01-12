import Foundation
import Combine

/// Manages text ignore patterns (regex/substring matching)
class IgnorePatternManager: ObservableObject {
    private static let defaultStore = UserDefaults(suiteName: "com.screenlingo.shared")!
    private static let key = "ignoredPatterns"
    
    private let store: UserDefaults
    @Published var ignoredPatterns: [String] = []
    
    /// Initialize with default UserDefaults store (production)
    convenience init() {
        self.init(store: Self.defaultStore)
    }
    
    /// Initialize with custom UserDefaults store (for testing)
    init(store: UserDefaults) {
        self.store = store
        load()
    }
    
    private func load() {
        let string = store.string(forKey: Self.key) ?? ""
        ignoredPatterns = string.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces).lowercased() }
        log.debug("Loaded \(ignoredPatterns.count) ignore patterns", category: .state)
    }
    
    private func save() {
        let string = ignoredPatterns.joined(separator: ",")
        store.set(string, forKey: Self.key)
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

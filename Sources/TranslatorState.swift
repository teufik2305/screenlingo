import SwiftUI

class TranslatorState: ObservableObject {
    @AppStorage("sourceLanguage") var sourceLanguage: String = "fr"
    @AppStorage("targetLanguage") var targetLanguage: String = "en"
    @AppStorage("overlayOpacity") var overlayOpacity: Double = 0.95
    @AppStorage("fontSize") var fontSize: Double = 20
    @AppStorage("hideOnHover") var hideOnHover: Bool = false
    
    // Logging settings
    @AppStorage("logFilePath") var logFilePath: String = "/tmp/overlay_translator.log"
    @AppStorage("logLevel") var logLevelRaw: Int = 1  // 0=debug, 1=info, 2=warning, 3=error
    @AppStorage("enableFileLogging") var enableFileLogging: Bool = true
    
    var logLevel: LogLevel {
        get { LogLevel(rawValue: logLevelRaw) ?? .info }
        set { logLevelRaw = newValue.rawValue }
    }
    
    // Translation settings
    @AppStorage("useAppleTranslation") var useAppleTranslation: Bool = true
    @AppStorage("customApiUrl") var customApiUrl: String = ""
    
    // Legacy settings (kept for compatibility)
    @AppStorage("useDeepL") var useDeepL: Bool = false
    @AppStorage("deepLApiKey") var deepLApiKey: String = ""
    
    // Default API URL constant
    static let defaultApiUrl = "https://translate.googleapis.com/translate_a/single"
    
    // Excluded apps - stored as comma-separated bundle IDs
    @AppStorage("excludedApps") private var excludedAppsString: String = "com.todesktop.230313mzl4w4u92,com.microsoft.VSCode,com.apple.dt.Xcode"
    
    var excludedApps: [String] {
        get {
            excludedAppsString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        }
        set {
            excludedAppsString = newValue.joined(separator: ",")
        }
    }
    
    func isAppExcluded(_ bundleIdentifier: String?) -> Bool {
        guard let bundleId = bundleIdentifier else { return false }
        return excludedApps.contains { bundleId.lowercased().contains($0.lowercased()) }
    }
    
    func addExcludedApp(_ bundleId: String) {
        var apps = excludedApps
        let normalized = bundleId.trimmingCharacters(in: .whitespaces)
        if !normalized.isEmpty && !apps.contains(normalized) {
            apps.append(normalized)
            excludedApps = apps
            objectWillChange.send()
        }
    }
    
    func removeExcludedApp(_ bundleId: String) {
        var apps = excludedApps
        apps.removeAll { $0 == bundleId }
        excludedApps = apps
        objectWillChange.send()
    }
    
    // Ignore list - stored as comma-separated string in UserDefaults
    @AppStorage("ignoredPatterns") private var ignoredPatternsString: String = ""
    
    var ignoredPatterns: [String] {
        get {
            ignoredPatternsString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces).lowercased() }
        }
        set {
            ignoredPatternsString = newValue.joined(separator: ",")
        }
    }
    
    // Computed property for effective API URL
    var effectiveApiUrl: String {
        customApiUrl.isEmpty ? Self.defaultApiUrl : customApiUrl
    }
    
    func addIgnoredPattern(_ pattern: String) {
        var patterns = ignoredPatterns
        let normalized = pattern.trimmingCharacters(in: .whitespaces).lowercased()
        if !normalized.isEmpty && !patterns.contains(normalized) {
            patterns.append(normalized)
            ignoredPatterns = patterns
            objectWillChange.send()
        }
    }
    
    func removeIgnoredPattern(_ pattern: String) {
        var patterns = ignoredPatterns
        patterns.removeAll { $0 == pattern.lowercased() }
        ignoredPatterns = patterns
        objectWillChange.send()
    }
    
    func shouldIgnoreText(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return ignoredPatterns.contains { pattern in
            lowercased.contains(pattern)
        }
    }
    
    static let supportedLanguages: [(code: String, name: String)] = [
        ("en", "English"),
        ("fr", "French"),
        ("de", "German"),
        ("es", "Spanish"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("ru", "Russian"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("zh", "Chinese"),
        ("ar", "Arabic"),
        ("nl", "Dutch"),
        ("pl", "Polish"),
        ("tr", "Turkish"),
        ("uk", "Ukrainian"),
        ("vi", "Vietnamese"),
        ("th", "Thai"),
        ("cs", "Czech"),
        ("da", "Danish"),
        ("fi", "Finnish"),
        ("el", "Greek"),
        ("he", "Hebrew"),
        ("hi", "Hindi"),
        ("hu", "Hungarian"),
        ("id", "Indonesian"),
        ("no", "Norwegian"),
        ("ro", "Romanian"),
        ("sv", "Swedish")
    ]
    
    func languageName(for code: String) -> String {
        Self.supportedLanguages.first { $0.code == code }?.name ?? code.uppercased()
    }
}

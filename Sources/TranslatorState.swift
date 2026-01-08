import SwiftUI

enum InteractionMode: Int, CaseIterable {
    case click = 0
    case hover = 1
    
    var name: String {
        switch self {
        case .click: return "Click"
        case .hover: return "Hover"
        }
    }
    
    var icon: String {
        switch self {
        case .click: return "hand.tap"
        case .hover: return "eye.slash"
        }
    }
    
    var color: Color {
        switch self {
        case .click: return .blue
        case .hover: return .orange
        }
    }
    
    var shortDescription: String {
        switch self {
        case .click: return "Click for menu"
        case .hover: return "Auto-hide"
        }
    }
    
    var detailedDescription: String {
        switch self {
        case .click: return "Click overlay → menu appears (copy, hide, ignore)"
        case .hover: return "Move mouse over overlay → it disappears"
        }
    }
}

enum TranslationServiceType: Int, CaseIterable {
    case apple = 0
    case ltEngine = 1
    case google = 2
    
    var name: String {
        switch self {
        case .apple: return "Apple"
        case .ltEngine: return "LTEngine"
        case .google: return "Google"
        }
    }
    
    var icon: String {
        switch self {
        case .apple: return "apple.logo"
        case .ltEngine: return "server.rack"
        case .google: return "network"
        }
    }
    
    var color: Color {
        switch self {
        case .apple: return .blue
        case .ltEngine: return .green
        case .google: return .orange
        }
    }
    
    var shortDescription: String {
        switch self {
        case .apple: return "On-device, private"
        case .ltEngine: return "Self-hosted"
        case .google: return "Cloud API"
        }
    }
    
    var detailedDescription: String {
        switch self {
        case .apple: 
            return "Uses Apple's built-in Translation framework. Runs entirely on your Mac — no data sent to servers. Requires macOS 15+ and language packs to be downloaded. Fast and private."
        case .ltEngine: 
            return "Connects to your self-hosted LTEngine or LibreTranslate server. You control the data. Requires running the server locally (default: localhost:5000). Supports all languages."
        case .google: 
            return "Uses Google Translate's public API (translate.googleapis.com). Fast and reliable with broad language support. Text is sent to Google's servers. No API key required. Works out of the box."
        }
    }
    
    var supportedLanguagesNote: String {
        switch self {
        case .apple:
            return "Arabic, Chinese, Dutch, English, French, German, Indonesian, Italian, Japanese, Korean, Polish, Portuguese, Russian, Spanish, Thai, Turkish, Ukrainian, Vietnamese"
        case .ltEngine:
            return "Supports all languages available on your LTEngine/LibreTranslate server"
        case .google:
            return "Supports 100+ languages including Bosnian, Croatian, Serbian"
        }
    }
    
    // Language codes supported by each service
    var supportedLanguageCodes: Set<String>? {
        switch self {
        case .apple:
            // Apple Translation supported languages (macOS 15+)
            return ["ar", "zh", "nl", "en", "fr", "de", "id", "it", "ja", "ko", "pl", "pt", "ru", "es", "th", "tr", "uk", "vi"]
        case .ltEngine, .google:
            return nil  // All languages supported
        }
    }
    
    func isLanguageSupported(_ code: String) -> Bool {
        if code == "auto" { return supportsAutoDetect }
        guard let supported = supportedLanguageCodes else { return true }
        return supported.contains(code)
    }
    
    // Whether this service supports automatic language detection
    var supportsAutoDetect: Bool {
        switch self {
        case .ltEngine: return true
        case .apple, .google: return false
        }
    }
}

class TranslatorState: ObservableObject {
    // Use a consistent UserDefaults suite so both direct binary and app bundle share settings
    // Note: Cannot use bundle identifier as suite name, so we use a different name
    static let preferencesStore = UserDefaults(suiteName: "com.screenlingo.shared")!
    
    @AppStorage("sourceLanguage", store: TranslatorState.preferencesStore) var sourceLanguage: String = "fr"
    @AppStorage("targetLanguage", store: TranslatorState.preferencesStore) var targetLanguage: String = "en"
    @AppStorage("overlayOpacity", store: TranslatorState.preferencesStore) var overlayOpacity: Double = 0.95
    @AppStorage("fontSize", store: TranslatorState.preferencesStore) var fontSize: Double = 20
    @AppStorage("interactionMode", store: TranslatorState.preferencesStore) var interactionModeRaw: Int = 0  // 0=click, 1=hover
    
    var interactionMode: InteractionMode {
        get { InteractionMode(rawValue: interactionModeRaw) ?? .click }
        set { 
            interactionModeRaw = newValue.rawValue
            objectWillChange.send()
        }
    }
    
    // Convenience property for backward compatibility
    var hideOnHover: Bool { interactionMode == .hover }
    
    // Logging settings
    @AppStorage("logFilePath", store: TranslatorState.preferencesStore) var logFilePath: String = "/tmp/overlay_translator.log"
    @AppStorage("logLevel", store: TranslatorState.preferencesStore) var logLevelRaw: Int = 1  // 0=debug, 1=info, 2=warning, 3=error
    @AppStorage("enableFileLogging", store: TranslatorState.preferencesStore) var enableFileLogging: Bool = true
    
    var logLevel: LogLevel {
        get { LogLevel(rawValue: logLevelRaw) ?? .info }
        set { logLevelRaw = newValue.rawValue }
    }
    
    // Translation settings
    @AppStorage("translationService", store: TranslatorState.preferencesStore) var translationServiceRaw: Int = 0  // 0=apple, 1=ltEngine, 2=google
    @AppStorage("customApiUrl", store: TranslatorState.preferencesStore) var customApiUrl: String = ""
    
    // LTEngine / LibreTranslate settings
    @AppStorage("libreTranslateUrl", store: TranslatorState.preferencesStore) var libreTranslateUrl: String = "http://localhost:5000/translate"
    @AppStorage("libreTranslateApiKey", store: TranslatorState.preferencesStore) var libreTranslateApiKey: String = ""  // Optional API key
    
    // Computed property for translation service
    var translationService: TranslationServiceType {
        get { TranslationServiceType(rawValue: translationServiceRaw) ?? .apple }
        set { 
            translationServiceRaw = newValue.rawValue
            // Auto-switch to supported language if current one isn't supported
            // Also reset "auto" if new service doesn't support auto detect
            if sourceLanguage == "auto" && !newValue.supportsAutoDetect {
                sourceLanguage = "en"
            } else if !newValue.isLanguageSupported(sourceLanguage) {
                sourceLanguage = "en"
            }
            if !newValue.isLanguageSupported(targetLanguage) {
                targetLanguage = "en"
            }
            objectWillChange.send()
        }
    }
    
    // Convenience properties for backward compatibility
    var useLibreTranslate: Bool { translationService == .ltEngine }
    var useAppleTranslation: Bool { translationService == .apple }
    
    // Legacy settings (kept for compatibility)
    @AppStorage("useDeepL", store: TranslatorState.preferencesStore) var useDeepL: Bool = false
    @AppStorage("deepLApiKey", store: TranslatorState.preferencesStore) var deepLApiKey: String = ""
    
    // Performance settings
    @AppStorage("captureInterval", store: TranslatorState.preferencesStore) var captureInterval: Double = 0.05  // 50ms default - how often to capture screen
    @AppStorage("stabilityThreshold", store: TranslatorState.preferencesStore) var stabilityThreshold: Double = 15  // px - movement below this is ignored to prevent jitter
    @AppStorage("ocrAccurate", store: TranslatorState.preferencesStore) var ocrAccurate: Bool = true  // true=accurate (slower), false=fast
    @AppStorage("maxCacheSize", store: TranslatorState.preferencesStore) var maxCacheSize: Int = 500  // max translations to cache
    @AppStorage("minTextLength", store: TranslatorState.preferencesStore) var minTextLength: Int = 3  // minimum characters to translate
    @AppStorage("textGrouping", store: TranslatorState.preferencesStore) var textGrouping: Double = 1.0  // 0.5=strict, 1.0=normal, 2.0=aggressive
    
    static let clearCacheNotification = Notification.Name("clearTranslationCache")
    
    // Default API URL constants
    static let defaultApiUrl = "https://translate.googleapis.com/translate_a/single"
    static let defaultLibreTranslateUrl = "http://localhost:5000/translate"
    
    // Excluded apps - stored as comma-separated bundle IDs
    @AppStorage("excludedApps", store: TranslatorState.preferencesStore) private var excludedAppsString: String = "com.todesktop.230313mzl4w4u92,com.microsoft.VSCode,com.apple.dt.Xcode"
    
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
    @AppStorage("ignoredPatterns", store: TranslatorState.preferencesStore) private var ignoredPatternsString: String = ""
    
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
        ("bs", "Bosnian"),
        ("hr", "Croatian"),
        ("cs", "Czech"),
        ("da", "Danish"),
        ("nl", "Dutch"),
        ("fi", "Finnish"),
        ("el", "Greek"),
        ("he", "Hebrew"),
        ("hi", "Hindi"),
        ("hu", "Hungarian"),
        ("id", "Indonesian"),
        ("no", "Norwegian"),
        ("pl", "Polish"),
        ("ro", "Romanian"),
        ("sr", "Serbian"),
        ("sv", "Swedish"),
        ("th", "Thai"),
        ("tr", "Turkish"),
        ("uk", "Ukrainian"),
        ("vi", "Vietnamese")
    ]
    
    func languageName(for code: String) -> String {
        if code == "auto" { return "Auto Detect" }
        return Self.supportedLanguages.first { $0.code == code }?.name ?? code.uppercased()
    }
    
    // Get languages filtered by current translation service
    var availableLanguages: [(code: String, name: String)] {
        Self.supportedLanguages.filter { translationService.isLanguageSupported($0.code) }
    }
    
    // Get source languages (includes Auto Detect for LTEngine)
    var availableSourceLanguages: [(code: String, name: String)] {
        var languages = availableLanguages
        if translationService.supportsAutoDetect {
            languages.insert(("auto", "Auto Detect"), at: 0)
        }
        return languages
    }
    
    // Swap source and target languages
    func swapLanguages() {
        // Don't swap if source is auto
        guard sourceLanguage != "auto" else { return }
        let temp = sourceLanguage
        sourceLanguage = targetLanguage
        targetLanguage = temp
        objectWillChange.send()
    }
}

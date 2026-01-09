import SwiftUI

// MARK: - Models

/// Language model for LTEngine/LibreTranslate API response
struct LTEngineLanguage: Codable {
    let code: String
    let name: String
    let targets: [String]?
}

// MARK: - Interaction Mode

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

// MARK: - Translation Service Type

enum TranslationServiceType: Int, CaseIterable {
    case apple = 0
    case ltEngine = 1
    case google = 2
    
    var name: String {
        switch self {
        case .apple: return "Apple"
        case .ltEngine: return "LibreTranslate"
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
        case .ltEngine: return "Open source, flexible"
        case .google: return "Cloud API"
        }
    }
    
    var detailedDescription: String {
        switch self {
        case .apple: 
            return "Uses Apple's built-in Translation framework. Runs entirely on your Mac — no data sent to servers. Requires macOS 15+ and language packs to be downloaded. Fast and private."
        case .ltEngine: 
            return "Connects to any LibreTranslate-compatible server (including LTEngine). Can be self-hosted locally or use a remote server. Default: localhost:5000."
        case .google: 
            return "Uses Google Translate's public API (translate.googleapis.com). Fast and reliable with broad language support. Text is sent to Google's servers. No API key required. Works out of the box."
        }
    }
    
    var supportedLanguagesNote: String {
        switch self {
        case .apple:
            return "Arabic, Chinese (Simplified/Traditional), Dutch, English, French, German, Hindi, Indonesian, Italian, Japanese, Korean, Polish, Portuguese (Brazil), Russian, Spanish, Thai, Turkish, Ukrainian, Vietnamese"
        case .ltEngine:
            return "Languages fetched from your configured server"
        case .google:
            return "Supports 100+ languages including Bosnian, Croatian, Serbian"
        }
    }
    
    // Language codes supported by each service
    var supportedLanguageCodes: Set<String>? {
        switch self {
        case .apple:
            // Apple Translation supported languages (macOS 15+)
            return ["ar", "zh", "zh-Hans", "zh-Hant", "nl", "en", "fr", "de", "hi", "id", "it", "ja", "ko", "pl", "pt", "pt-BR", "ru", "es", "th", "tr", "uk", "vi"]
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
        case .ltEngine, .google: return true
        case .apple: return false
        }
    }
}

// MARK: - Translator State

class TranslatorState: ObservableObject {
    
    // MARK: Static Properties
    
    /// Shared UserDefaults store for consistent settings across app instances
    static let preferencesStore = UserDefaults(suiteName: "com.screenlingo.shared")!
    static let clearCacheNotification = Notification.Name("clearTranslationCache")
    
    // MARK: Dynamic Language Lists (fetched from servers)
    
    // Cached LTEngine languages fetched from the server
    @Published var ltEngineLanguages: [(code: String, name: String)] = []
    @Published var isLoadingLTEngineLanguages: Bool = false
    @Published var ltEngineLanguagesError: String? = nil
    private var lastLTEngineFetchAttempt: Date? = nil
    private let ltEngineFetchCooldown: TimeInterval = 30  // seconds before retry
    
    // Cached Google Translate languages fetched from custom API
    @Published var googleLanguages: [(code: String, name: String)] = []
    @Published var isLoadingGoogleLanguages: Bool = false
    @Published var googleLanguagesError: String? = nil
    private var lastGoogleFetchAttempt: Date? = nil
    private let googleFetchCooldown: TimeInterval = 30  // seconds before retry
    
    // MARK: Language Settings
    
    @AppStorage("sourceLanguage", store: TranslatorState.preferencesStore) var sourceLanguage: String = "fr"
    @AppStorage("targetLanguage", store: TranslatorState.preferencesStore) var targetLanguage: String = "en"
    
    // MARK: Appearance Settings
    
    @AppStorage("overlayOpacity", store: TranslatorState.preferencesStore) var overlayOpacity: Double = 0.95
    @AppStorage("fontSize", store: TranslatorState.preferencesStore) var fontSize: Double = 20
    @AppStorage("interactionMode", store: TranslatorState.preferencesStore) var interactionModeRaw: Int = 0  // 0=click, 1=hover
    
    // MARK: Keyboard Shortcuts
    
    @AppStorage("hotkeyKeyCode", store: TranslatorState.preferencesStore) var hotkeyKeyCode: Int = 17  // 'T' key
    @AppStorage("hotkeyModifiers", store: TranslatorState.preferencesStore) var hotkeyModifiers: Int = 0x101000  // Cmd+Ctrl
    
    var hotkeyDisplayString: String {
        var parts: [String] = []
        let mods = UInt(hotkeyModifiers)
        if mods & UInt(NSEvent.ModifierFlags.control.rawValue) != 0 { parts.append("⌃") }
        if mods & UInt(NSEvent.ModifierFlags.option.rawValue) != 0 { parts.append("⌥") }
        if mods & UInt(NSEvent.ModifierFlags.shift.rawValue) != 0 { parts.append("⇧") }
        if mods & UInt(NSEvent.ModifierFlags.command.rawValue) != 0 { parts.append("⌘") }
        
        let keyName = keyCodeToString(hotkeyKeyCode)
        parts.append(keyName)
        return parts.joined()
    }
    
    private func keyCodeToString(_ keyCode: Int) -> String {
        let keyMap: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
            20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
            29: "0", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
            49: "Space", 36: "↩", 48: "⇥", 51: "⌫", 53: "⎋"
        ]
        return keyMap[keyCode] ?? "?"
    }
    
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
    @AppStorage("googleApiKey", store: TranslatorState.preferencesStore) var googleApiKey: String = ""  // Optional API key for Google Translate
    
    // LTEngine / LibreTranslate settings
    @AppStorage("libreTranslateUrl", store: TranslatorState.preferencesStore) var libreTranslateUrl: String = "http://localhost:5000/translate"
    @AppStorage("libreTranslateApiKey", store: TranslatorState.preferencesStore) var libreTranslateApiKey: String = ""  // Optional API key
    
    // Computed property to get the base URL for LTEngine (removes /translate suffix if present)
    var ltEngineBaseUrl: String {
        var url = libreTranslateUrl.trimmingCharacters(in: .whitespaces)
        if url.hasSuffix("/translate") {
            url = String(url.dropLast("/translate".count))
        }
        if url.hasSuffix("/") {
            url = String(url.dropLast())
        }
        return url.isEmpty ? "http://localhost:5000" : url
    }
    
    // Check if we should retry fetching LTEngine languages
    private var canRetryLTEngineFetch: Bool {
        guard let lastAttempt = lastLTEngineFetchAttempt else { return true }
        return Date().timeIntervalSince(lastAttempt) >= ltEngineFetchCooldown
    }
    
    // Fetch available languages from LTEngine server
    func fetchLTEngineLanguages(force: Bool = false) {
        guard !isLoadingLTEngineLanguages else { return }
        
        // Check cooldown unless forced
        if !force && !canRetryLTEngineFetch {
            return
        }
        
        let urlString = "\(ltEngineBaseUrl)/languages"
        guard let url = URL(string: urlString) else {
            ltEngineLanguagesError = "Invalid URL: \(urlString)"
            return
        }
        
        isLoadingLTEngineLanguages = true
        lastLTEngineFetchAttempt = Date()
        
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                    await MainActor.run {
                        self.ltEngineLanguagesError = "Server error (HTTP \(statusCode))"
                        self.isLoadingLTEngineLanguages = false
                    }
                    return
                }
                
                let languages = try JSONDecoder().decode([LTEngineLanguage].self, from: data)
                let languageTuples = languages.map { ($0.code, $0.name) }
                
                await MainActor.run {
                    self.ltEngineLanguages = languageTuples
                    self.isLoadingLTEngineLanguages = false
                    self.ltEngineLanguagesError = nil
                }
            } catch let error as URLError {
                await MainActor.run {
                    switch error.code {
                    case .notConnectedToInternet:
                        self.ltEngineLanguagesError = "No internet connection"
                    case .cannotConnectToHost, .cannotFindHost:
                        self.ltEngineLanguagesError = "Cannot connect to LTEngine server"
                    case .timedOut:
                        self.ltEngineLanguagesError = "Connection timed out"
                    default:
                        self.ltEngineLanguagesError = "Network error: \(error.localizedDescription)"
                    }
                    self.isLoadingLTEngineLanguages = false
                }
            } catch {
                await MainActor.run {
                    self.ltEngineLanguagesError = error.localizedDescription
                    self.isLoadingLTEngineLanguages = false
                }
            }
        }
    }
    
    // Clear LTEngine error and retry fetching
    func retryLTEngineLanguageFetch() {
        ltEngineLanguagesError = nil
        lastLTEngineFetchAttempt = nil
        fetchLTEngineLanguages(force: true)
    }
    
    // MARK: - Google Translate Custom API Languages
    
    // Computed property to get the base URL for Google custom API
    var googleBaseUrl: String {
        var url = customApiUrl.trimmingCharacters(in: .whitespaces)
        if url.isEmpty {
            return ""  // No custom URL, use default behavior
        }
        // Remove common suffixes to get base URL
        for suffix in ["/translate", "/languages", "/v2", "/v3"] {
            if url.hasSuffix(suffix) {
                url = String(url.dropLast(suffix.count))
            }
        }
        if url.hasSuffix("/") {
            url = String(url.dropLast())
        }
        return url
    }
    
    // Check if we should retry fetching Google languages
    private var canRetryGoogleFetch: Bool {
        guard let lastAttempt = lastGoogleFetchAttempt else { return true }
        return Date().timeIntervalSince(lastAttempt) >= googleFetchCooldown
    }
    
    // Check if custom Google API is configured
    var hasCustomGoogleApi: Bool {
        !customApiUrl.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // Fetch available languages from custom Google Translate API
    func fetchGoogleLanguages(force: Bool = false) {
        guard hasCustomGoogleApi else { return }
        guard !isLoadingGoogleLanguages else { return }
        
        // Check cooldown unless forced
        if !force && !canRetryGoogleFetch {
            return
        }
        
        // Determine the languages endpoint based on URL pattern
        let baseUrl = googleBaseUrl
        var urlString: String
        
        // Check if it looks like a Google Cloud v3 API URL
        if baseUrl.contains("/v3/") || baseUrl.contains("translation.googleapis.com") {
            // Google Cloud Translation API v3: /supportedLanguages endpoint
            urlString = "\(baseUrl)/supportedLanguages"
        } else {
            // LibreTranslate or other: /languages endpoint
            urlString = "\(baseUrl)/languages"
        }
        
        // Add API key as query parameter if provided (for Google Cloud API)
        var finalUrlString = urlString
        if !googleApiKey.isEmpty {
            let separator = urlString.contains("?") ? "&" : "?"
            finalUrlString = "\(urlString)\(separator)key=\(googleApiKey)"
        }
        
        guard let url = URL(string: finalUrlString) else {
            googleLanguagesError = "Invalid URL: \(urlString)"
            return
        }
        
        isLoadingGoogleLanguages = true
        lastGoogleFetchAttempt = Date()
        
        Task {
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 15
                
                // Also add API key as header for services that expect it there
                if !googleApiKey.isEmpty {
                    request.setValue("Bearer \(googleApiKey)", forHTTPHeaderField: "Authorization")
                }
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                    await MainActor.run {
                        self.googleLanguagesError = "Server error (HTTP \(statusCode))"
                        self.isLoadingGoogleLanguages = false
                    }
                    return
                }
                
                // Try to parse as LibreTranslate format first (array of {code, name})
                if let languages = try? JSONDecoder().decode([LTEngineLanguage].self, from: data) {
                    let languageTuples = languages.map { ($0.code, $0.name) }
                    await MainActor.run {
                        self.googleLanguages = languageTuples
                        self.isLoadingGoogleLanguages = false
                        self.googleLanguagesError = nil
                    }
                    return
                }
                
                // Try Google Cloud Translation API v3 format:
                // {"languages": [{"languageCode": "en", "displayName": "English", "supportSource": true, "supportTarget": true}]}
                // Reference: https://docs.cloud.google.com/translate/docs/reference/rest/v3/projects/getSupportedLanguages
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let languagesArray = json["languages"] as? [[String: Any]] {
                    let languageTuples = languagesArray.compactMap { lang -> (String, String)? in
                        guard let code = lang["languageCode"] as? String else { return nil }
                        let name = lang["displayName"] as? String ?? code.uppercased()
                        return (code, name)
                    }
                    if !languageTuples.isEmpty {
                        await MainActor.run {
                            self.googleLanguages = languageTuples
                            self.isLoadingGoogleLanguages = false
                            self.googleLanguagesError = nil
                        }
                        return
                    }
                }
                
                // Try Google Cloud v2 format: {"data": {"languages": [{"language": "en", "name": "English"}]}}
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dataObj = json["data"] as? [String: Any],
                   let languagesArray = dataObj["languages"] as? [[String: Any]] {
                    let languageTuples = languagesArray.compactMap { lang -> (String, String)? in
                        guard let code = lang["language"] as? String else { return nil }
                        let name = lang["name"] as? String ?? code.uppercased()
                        return (code, name)
                    }
                    if !languageTuples.isEmpty {
                        await MainActor.run {
                            self.googleLanguages = languageTuples
                            self.isLoadingGoogleLanguages = false
                            self.googleLanguagesError = nil
                        }
                        return
                    }
                }
                
                // Try simple array format: [{"language": "en"}, ...] or [{"code": "en"}, ...]
                if let languagesArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    let languageTuples = languagesArray.compactMap { lang -> (String, String)? in
                        let code = lang["language"] as? String ?? lang["code"] as? String ?? lang["languageCode"] as? String
                        guard let code = code else { return nil }
                        let name = lang["name"] as? String ?? lang["displayName"] as? String ?? code.uppercased()
                        return (code, name)
                    }
                    if !languageTuples.isEmpty {
                        await MainActor.run {
                            self.googleLanguages = languageTuples
                            self.isLoadingGoogleLanguages = false
                            self.googleLanguagesError = nil
                        }
                        return
                    }
                }
                
                await MainActor.run {
                    self.googleLanguagesError = "Unsupported response format"
                    self.isLoadingGoogleLanguages = false
                }
                
            } catch let error as URLError {
                await MainActor.run {
                    switch error.code {
                    case .notConnectedToInternet:
                        self.googleLanguagesError = "No internet connection"
                    case .cannotConnectToHost, .cannotFindHost:
                        self.googleLanguagesError = "Cannot connect to server"
                    case .timedOut:
                        self.googleLanguagesError = "Connection timed out"
                    default:
                        self.googleLanguagesError = "Network error: \(error.localizedDescription)"
                    }
                    self.isLoadingGoogleLanguages = false
                }
            } catch {
                await MainActor.run {
                    self.googleLanguagesError = error.localizedDescription
                    self.isLoadingGoogleLanguages = false
                }
            }
        }
    }
    
    // Clear Google error and retry fetching
    func retryGoogleLanguageFetch() {
        googleLanguagesError = nil
        lastGoogleFetchAttempt = nil
        fetchGoogleLanguages(force: true)
    }
    
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
            // Fetch languages when service is selected
            if newValue == .ltEngine && ltEngineLanguages.isEmpty {
                fetchLTEngineLanguages()
            }
            if newValue == .google && hasCustomGoogleApi && googleLanguages.isEmpty {
                fetchGoogleLanguages()
            }
            objectWillChange.send()
        }
    }
    
    // Convenience properties for backward compatibility
    var useLibreTranslate: Bool { translationService == .ltEngine }
    var useAppleTranslation: Bool { translationService == .apple }
    
    // Script/transliteration settings
    @AppStorage("forceSerbianLatin", store: TranslatorState.preferencesStore) var forceSerbianLatin: Bool = true  // Convert Cyrillic to Latin for Serbian
    
    // Performance settings
    @AppStorage("captureInterval", store: TranslatorState.preferencesStore) var captureInterval: Double = 0.05  // 50ms default - how often to capture screen
    @AppStorage("stabilityThreshold", store: TranslatorState.preferencesStore) var stabilityThreshold: Double = 15  // px - movement below this is ignored to prevent jitter
    @AppStorage("ocrAccurate", store: TranslatorState.preferencesStore) var ocrAccurate: Bool = true  // true=accurate (slower), false=fast
    @AppStorage("maxCacheSize", store: TranslatorState.preferencesStore) var maxCacheSize: Int = 500  // max translations to cache
    @AppStorage("minTextLength", store: TranslatorState.preferencesStore) var minTextLength: Int = 3  // minimum characters to translate
    @AppStorage("textGrouping", store: TranslatorState.preferencesStore) var textGrouping: Double = 1.0  // 0.5=strict, 1.0=normal, 2.0=aggressive
    
    // MARK: Excluded Apps
    
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
    
    // MARK: Ignore Patterns
    
    @AppStorage("ignoredPatterns", store: TranslatorState.preferencesStore) private var ignoredPatternsString: String = ""
    
    var ignoredPatterns: [String] {
        get {
            ignoredPatternsString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces).lowercased() }
        }
        set {
            ignoredPatternsString = newValue.joined(separator: ",")
        }
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
    
    // MARK: Static Language Data
    
    /// Default supported languages - matches Apple Translation (macOS 15+)
    /// Additional languages like Serbian Latin are included for other services
    static let supportedLanguages: [(code: String, name: String)] = [
        ("ar", "Arabic"),
        ("zh", "Chinese"),
        ("zh-Hans", "Chinese (Simplified)"),
        ("zh-Hant", "Chinese (Traditional)"),
        ("nl", "Dutch"),
        ("en", "English"),
        ("fr", "French"),
        ("de", "German"),
        ("hi", "Hindi"),
        ("id", "Indonesian"),
        ("it", "Italian"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("pl", "Polish"),
        ("pt", "Portuguese"),
        ("pt-BR", "Portuguese (Brazil)"),
        ("ru", "Russian"),
        ("sr", "Serbian (Cyrillic)"),
        ("sr-Latn", "Serbian (Latin)"),
        ("es", "Spanish"),
        ("th", "Thai"),
        ("tr", "Turkish"),
        ("uk", "Ukrainian"),
        ("vi", "Vietnamese")
    ]
    
    func languageName(for code: String) -> String {
        if code == "auto" { return "Auto Detect" }
        // Check fetched languages first based on active service
        if translationService == .ltEngine, let lang = ltEngineLanguages.first(where: { $0.code == code }) {
            return lang.name
        }
        if translationService == .google && hasCustomGoogleApi, let lang = googleLanguages.first(where: { $0.code == code }) {
            return lang.name
        }
        return Self.supportedLanguages.first { $0.code == code }?.name ?? code.uppercased()
    }
    
    // Get languages filtered by current translation service
    var availableLanguages: [(code: String, name: String)] {
        switch translationService {
        case .ltEngine:
            // Use fetched languages from LTEngine, fall back to static list if not loaded
            if !ltEngineLanguages.isEmpty {
                return ltEngineLanguages
            }
            // Trigger fetch if not already loading and cooldown passed
            if !isLoadingLTEngineLanguages && canRetryLTEngineFetch {
                fetchLTEngineLanguages()
            }
            // Return static list as fallback while loading or on error
            return Self.supportedLanguages
        case .google:
            // Use fetched languages from custom Google API if configured
            if hasCustomGoogleApi {
                if !googleLanguages.isEmpty {
                    return googleLanguages
                }
                // Trigger fetch if not already loading and cooldown passed
                if !isLoadingGoogleLanguages && canRetryGoogleFetch {
                    fetchGoogleLanguages()
                }
            }
            // Return static list as fallback
            return Self.supportedLanguages
        case .apple:
            return Self.supportedLanguages.filter { translationService.isLanguageSupported($0.code) }
        }
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

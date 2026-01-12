import SwiftUI
import AppKit
import Combine

// MARK: - Translator State

class TranslatorState: ObservableObject {
    
    // MARK: Static Properties
    
    /// Shared UserDefaults store for consistent settings across app instances
    static let preferencesStore = UserDefaults(suiteName: "com.screenlingo.shared")!
    static let clearCacheNotification = Notification.Name("clearTranslationCache")
    static let deleteCacheFileNotification = Notification.Name("deleteCacheFile")
    static let saveCacheNotification = Notification.Name("saveTranslationCache")
    
    // MARK: Managers
    
    let excludedAppsManager = ExcludedAppsManager()
    let ignorePatternManager = IgnorePatternManager()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Forward manager changes to trigger TranslatorState updates
        excludedAppsManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        ignorePatternManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: Dynamic Language Lists (fetched from servers)
    
    // Cached LTEngine languages fetched from the server
    @Published var ltEngineLanguages: [(code: String, name: String)] = []
    @Published var isLoadingLTEngineLanguages: Bool = false
    @Published var ltEngineLanguagesError: String? = nil
    private var lastLTEngineFetchAttempt: Date? = nil
    
    // Cached Google Translate languages fetched from custom API
    @Published var googleLanguages: [(code: String, name: String)] = []
    @Published var isLoadingGoogleLanguages: Bool = false
    @Published var googleLanguagesError: String? = nil
    private var lastGoogleFetchAttempt: Date? = nil
    
    // MARK: Language Settings
    
    @AppStorage("sourceLanguage", store: TranslatorState.preferencesStore) var sourceLanguage: String = "fr" {
        didSet { log.info("Source language changed: \(oldValue) -> \(sourceLanguage)", category: .settings) }
    }
    @AppStorage("targetLanguage", store: TranslatorState.preferencesStore) var targetLanguage: String = "en" {
        didSet { log.info("Target language changed: \(oldValue) -> \(targetLanguage)", category: .settings) }
    }
    
    // MARK: Appearance Settings
    
    @AppStorage("overlayOpacity", store: TranslatorState.preferencesStore) var overlayOpacity: Double = 0.95 {
        didSet { log.info("Overlay opacity: \(String(format: "%.0f", overlayOpacity * 100))%", category: .settings) }
    }
    @AppStorage("fontSize", store: TranslatorState.preferencesStore) var fontSize: Double = 20 {
        didSet { log.info("Font size: \(Int(fontSize))pt", category: .settings) }
    }
    @AppStorage("interactionMode", store: TranslatorState.preferencesStore) var interactionModeRaw: Int = 0 {  // 0=click, 1=hover
        didSet { 
            let mode = InteractionMode(rawValue: interactionModeRaw)?.name ?? "Unknown"
            log.info("Interaction mode: \(mode)", category: .settings) 
        }
    }
    @AppStorage("alwaysOnTop", store: TranslatorState.preferencesStore) var alwaysOnTop: Bool = true {  // Keep overlay above all windows
        didSet { log.info("Always on top: \(alwaysOnTop ? "enabled" : "disabled")", category: .settings) }
    }
    
    // Overlay display mode: 0 = box (white background), 1 = outline (text with stroke)
    @AppStorage("overlayDisplayMode", store: TranslatorState.preferencesStore) var overlayDisplayMode: Int = 0 {
        didSet { log.info("Overlay display mode: \(overlayDisplayMode == 0 ? "box" : "outline")", category: .settings) }
    }
    
    // Outline settings
    @AppStorage("outlineWidth", store: TranslatorState.preferencesStore) var outlineWidth: Double = 2.0 {
        didSet { log.info("Outline width: \(outlineWidth)px", category: .settings) }
    }
    @AppStorage("outlineColor", store: TranslatorState.preferencesStore) var outlineColorHex: String = "#000000" {
        didSet { log.info("Outline color: \(outlineColorHex)", category: .settings) }
    }
    @AppStorage("textColor", store: TranslatorState.preferencesStore) var textColorHex: String = "#FFFFFF" {
        didSet { log.info("Text color: \(textColorHex)", category: .settings) }
    }
    
    // Box mode settings
    @AppStorage("boxPaddingH", store: TranslatorState.preferencesStore) var boxPaddingH: Double = 12 {
        didSet { log.info("Box horizontal padding: \(boxPaddingH)px", category: .settings) }
    }
    @AppStorage("boxPaddingV", store: TranslatorState.preferencesStore) var boxPaddingV: Double = 8 {
        didSet { log.info("Box vertical padding: \(boxPaddingV)px", category: .settings) }
    }
    @AppStorage("boxCornerRadius", store: TranslatorState.preferencesStore) var boxCornerRadius: Double = 5 {
        didSet { log.info("Box corner radius: \(boxCornerRadius)px", category: .settings) }
    }
    @AppStorage("boxBackgroundColorHex", store: TranslatorState.preferencesStore) var boxBackgroundColorHex: String = "#FFFFFF" {
        didSet { log.info("Box background color: \(boxBackgroundColorHex)", category: .settings) }
    }
    @AppStorage("boxTextColorHex", store: TranslatorState.preferencesStore) var boxTextColorHex: String = "#000000" {
        didSet { log.info("Box text color: \(boxTextColorHex)", category: .settings) }
    }
    @AppStorage("boxBorderWidth", store: TranslatorState.preferencesStore) var boxBorderWidth: Double = 0 {
        didSet { log.info("Box border width: \(boxBorderWidth)px", category: .settings) }
    }
    @AppStorage("boxBorderColorHex", store: TranslatorState.preferencesStore) var boxBorderColorHex: String = "#000000" {
        didSet { log.info("Box border color: \(boxBorderColorHex)", category: .settings) }
    }
    @AppStorage("boxShadowEnabled", store: TranslatorState.preferencesStore) var boxShadowEnabled: Bool = true {
        didSet { log.info("Box shadow: \(boxShadowEnabled ? "enabled" : "disabled")", category: .settings) }
    }
    @AppStorage("boxCoverOriginal", store: TranslatorState.preferencesStore) var boxCoverOriginal: Bool = true {
        didSet { log.info("Box cover original text: \(boxCoverOriginal ? "enabled" : "disabled")", category: .settings) }
    }
    
    // MARK: Keyboard Shortcuts
    
    @AppStorage("hotkeyKeyCode", store: TranslatorState.preferencesStore) var hotkeyKeyCode: Int = 17 {  // 'T' key
        didSet { log.info("Hotkey changed: \(hotkeyDisplayString)", category: .settings) }
    }
    @AppStorage("hotkeyModifiers", store: TranslatorState.preferencesStore) var hotkeyModifiers: Int = 0x101000 {  // Cmd+Ctrl
        didSet { log.info("Hotkey changed: \(hotkeyDisplayString)", category: .settings) }
    }
    
    var hotkeyDisplayString: String {
        var parts: [String] = []
        let mods = UInt(hotkeyModifiers)
        if mods & UInt(NSEvent.ModifierFlags.command.rawValue) != 0 { parts.append("⌘") }
        if mods & UInt(NSEvent.ModifierFlags.control.rawValue) != 0 { parts.append("⌃") }
        if mods & UInt(NSEvent.ModifierFlags.option.rawValue) != 0 { parts.append("⌥") }
        if mods & UInt(NSEvent.ModifierFlags.shift.rawValue) != 0 { parts.append("⇧") }
        
        // Convert key code to character
        let keyChar: String
        switch hotkeyKeyCode {
        case 0: keyChar = "A"
        case 1: keyChar = "S"
        case 2: keyChar = "D"
        case 3: keyChar = "F"
        case 4: keyChar = "H"
        case 5: keyChar = "G"
        case 6: keyChar = "Z"
        case 7: keyChar = "X"
        case 8: keyChar = "C"
        case 9: keyChar = "V"
        case 11: keyChar = "B"
        case 12: keyChar = "Q"
        case 13: keyChar = "W"
        case 14: keyChar = "E"
        case 15: keyChar = "R"
        case 16: keyChar = "Y"
        case 17: keyChar = "T"
        case 31: keyChar = "O"
        case 32: keyChar = "U"
        case 34: keyChar = "I"
        case 35: keyChar = "P"
        case 37: keyChar = "L"
        case 38: keyChar = "J"
        case 40: keyChar = "K"
        case 45: keyChar = "N"
        case 46: keyChar = "M"
        case 49: keyChar = "Space"
        default: keyChar = "\(hotkeyKeyCode)"
        }
        parts.append(keyChar)
        return parts.joined()
    }
    
    var interactionMode: InteractionMode {
        get { InteractionMode(rawValue: interactionModeRaw) ?? .click }
        set { interactionModeRaw = newValue.rawValue }
    }
    
    var hideOnHover: Bool {
        interactionMode == .hover
    }
    
    // MARK: Logging Settings
    
    @AppStorage("logFilePath", store: TranslatorState.preferencesStore) var logFilePath: String = "/tmp/overlay_translator.log"
    @AppStorage("logLevel", store: TranslatorState.preferencesStore) var logLevelRaw: Int = 1 {  // 0=debug, 1=info, 2=warning, 3=error
        didSet { 
            let level = LogLevel(rawValue: logLevelRaw)?.label ?? "Unknown"
            log.info("Log level: \(level)", category: .settings) 
        }
    }
    @AppStorage("enableFileLogging", store: TranslatorState.preferencesStore) var enableFileLogging: Bool = true {
        didSet { log.info("File logging: \(enableFileLogging ? "enabled" : "disabled")", category: .settings) }
    }
    
    var logLevel: LogLevel {
        get { LogLevel(rawValue: logLevelRaw) ?? .info }
        set { logLevelRaw = newValue.rawValue }
    }
    
    // MARK: Translation Service Settings
    
    @AppStorage("translationService", store: TranslatorState.preferencesStore) var translationServiceRaw: Int = 0 {  // 0=apple, 1=ltEngine, 2=google
        didSet { 
            let serviceName = TranslationServiceType(rawValue: translationServiceRaw)?.name ?? "Unknown"
            log.info("Translation service changed: \(serviceName)", category: .settings) 
        }
    }
    @AppStorage("customApiUrl", store: TranslatorState.preferencesStore) var customApiUrl: String = ""
    @AppStorage("googleApiKey", store: TranslatorState.preferencesStore) var googleApiKey: String = ""  // Optional API key for Google Translate
    
    // LibreTranslate/LTEngine settings
    @AppStorage("libreTranslateUrl", store: TranslatorState.preferencesStore) var libreTranslateUrl: String = "http://localhost:5000/translate" {
        didSet { log.info("LibreTranslate URL changed: \(libreTranslateUrl)", category: .settings) }
    }
    @AppStorage("libreTranslateApiKey", store: TranslatorState.preferencesStore) var libreTranslateApiKey: String = ""  // Optional API key
    
    // LLM settings
    @AppStorage("llmApiUrl", store: TranslatorState.preferencesStore) var llmApiUrl: String = "https://api.openai.com/v1/chat/completions" {
        didSet { log.info("LLM API URL changed: \(llmApiUrl)", category: .settings) }
    }
    @AppStorage("llmModel", store: TranslatorState.preferencesStore) var llmModel: String = "gpt-4.1-mini" {
        didSet { log.info("LLM model changed: \(llmModel)", category: .settings) }
    }
    @AppStorage("llmSystemPrompt", store: TranslatorState.preferencesStore) var llmSystemPrompt: String = "" {
        didSet { log.info("LLM system prompt changed", category: .settings) }
    }
    @AppStorage("llmAutoAppendLanguages", store: TranslatorState.preferencesStore) var llmAutoAppendLanguages: Bool = true {
        didSet { log.info("LLM auto-append languages: \(llmAutoAppendLanguages ? "enabled" : "disabled")", category: .settings) }
    }
    
    // LLM Confidence settings
    @AppStorage("llmConfidenceEnabled", store: TranslatorState.preferencesStore) var llmConfidenceEnabled: Bool = false {
        didSet { log.info("LLM confidence mode: \(llmConfidenceEnabled ? "enabled" : "disabled")", category: .settings) }
    }
    @AppStorage("llmConfidenceThreshold", store: TranslatorState.preferencesStore) var llmConfidenceThreshold: Int = 70 {
        didSet { log.info("LLM confidence threshold: \(llmConfidenceThreshold)%", category: .settings) }
    }
    @AppStorage("llmMaxRetries", store: TranslatorState.preferencesStore) var llmMaxRetries: Int = 3 {
        didSet { log.info("LLM max retries: \(llmMaxRetries)", category: .settings) }
    }
    
    // Scroll detection settings
    @AppStorage("scrollDetectionEnabled", store: TranslatorState.preferencesStore) var scrollDetectionEnabled: Bool = true {
        didSet { log.info("Scroll detection: \(scrollDetectionEnabled ? "enabled" : "disabled")", category: .settings) }
    }
    @AppStorage("scrollCooldown", store: TranslatorState.preferencesStore) var scrollCooldown: Double = 0.4 {
        didSet { log.info("Scroll cooldown: \(Int(scrollCooldown * 1000))ms", category: .settings) }
    }
    
    /// Default system prompt for LLM translation (used when llmSystemPrompt is empty)
    static let defaultLLMSystemPrompt = "You are a professional translator. Translate the following text from {source} to {target}. Only respond with the translation, nothing else. Do not include explanations, notes, or quotation marks around the translation."
    
    /// Language context suffix appended when auto-append is enabled and placeholders are missing
    static let languageContextSuffix = " Translate from {source} to {target}."
    
    /// Get effective system prompt (custom or default)
    var effectiveLLMSystemPrompt: String {
        llmSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
            ? TranslatorState.defaultLLMSystemPrompt 
            : llmSystemPrompt
    }
    
    /// Check if custom prompt is missing language placeholders
    var llmSystemPromptMissingPlaceholders: Bool {
        let prompt = llmSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return false }  // Default prompt has placeholders
        return !prompt.contains("{source}") || !prompt.contains("{target}")
    }
    
    // API Keys for different LLM providers
    @AppStorage("openaiApiKey", store: TranslatorState.preferencesStore) var openaiApiKey: String = ""
    @AppStorage("anthropicApiKey", store: TranslatorState.preferencesStore) var anthropicApiKey: String = ""
    @AppStorage("geminiApiKey", store: TranslatorState.preferencesStore) var geminiApiKey: String = ""
    @AppStorage("ollamaApiKey", store: TranslatorState.preferencesStore) var ollamaApiKey: String = ""  // Usually not needed
    @AppStorage("otherLlmApiKey", store: TranslatorState.preferencesStore) var otherLlmApiKey: String = ""
    
    var translationService: TranslationServiceType {
        get { TranslationServiceType(rawValue: translationServiceRaw) ?? .apple }
        set { translationServiceRaw = newValue.rawValue }
    }
    
    // Legacy compatibility properties for TranslationService
    var useAppleTranslation: Bool { translationService == .apple }
    var useLibreTranslate: Bool { translationService == .ltEngine }
    var useLLM: Bool { translationService == .llm }
    
    // MARK: LLM Provider Detection
    
    var detectedLLMProvider: LLMProvider {
        let url = llmApiUrl.lowercased()
        if url.contains("anthropic.com") || url.contains("claude") {
            return .anthropic
        } else if url.contains("openai.com") || url.contains("gpt") {
            return .openai
        } else if url.contains("generativelanguage.googleapis.com") || url.contains("gemini") {
            return .gemini
        } else if url.contains("localhost:11434") || url.contains("ollama") {
            return .ollama
        } else {
            return .other
        }
    }
    
    var currentLlmApiKey: String {
        get {
            switch detectedLLMProvider {
            case .openai: return openaiApiKey
            case .anthropic: return anthropicApiKey
            case .gemini: return geminiApiKey
            case .ollama: return ollamaApiKey
            case .other: return otherLlmApiKey
            }
        }
        set {
            switch detectedLLMProvider {
            case .openai: openaiApiKey = newValue
            case .anthropic: anthropicApiKey = newValue
            case .gemini: geminiApiKey = newValue
            case .ollama: ollamaApiKey = newValue
            case .other: otherLlmApiKey = newValue
            }
        }
    }
    
    // MARK: Advanced Settings
    
    @AppStorage("forceSerbianLatin", store: TranslatorState.preferencesStore) var forceSerbianLatin: Bool = true {  // Convert Cyrillic to Latin for Serbian
        didSet { log.info("Force Serbian Latin: \(forceSerbianLatin ? "enabled" : "disabled")", category: .settings) }
    }
    
    // MARK: Performance Settings
    
    @AppStorage("captureInterval", store: TranslatorState.preferencesStore) var captureInterval: Double = 0.05 {  // 50ms default - how often to capture screen
        didSet { log.info("Capture interval: \(Int(captureInterval * 1000))ms", category: .settings) }
    }
    @AppStorage("stabilityThreshold", store: TranslatorState.preferencesStore) var stabilityThreshold: Double = 15 {  // px - movement below this is ignored to prevent jitter
        didSet { log.info("Stability threshold: \(Int(stabilityThreshold))px", category: .settings) }
    }
    @AppStorage("maxCacheSize", store: TranslatorState.preferencesStore) var maxCacheSize: Int = 500 {  // max translations to cache
        didSet { log.info("Max cache size: \(maxCacheSize) entries", category: .settings) }
    }
    @AppStorage("cacheFilePath", store: TranslatorState.preferencesStore) var cacheFilePath: String = "" {  // empty = use default
        didSet { log.info("Cache file path: \(cacheFilePath.isEmpty ? "default" : cacheFilePath)", category: .settings) }
    }
    @AppStorage("enableCachePersistence", store: TranslatorState.preferencesStore) var enableCachePersistence: Bool = true {
        didSet { log.info("Cache persistence: \(enableCachePersistence ? "enabled" : "disabled")", category: .settings) }
    }  // save/load cache on app start/stop
    
    var effectiveCacheFilePath: String {
        if cacheFilePath.isEmpty {
            // Default path: ~/Library/Application Support/ScreenLingo/cache.json
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appDir = appSupport.appendingPathComponent("ScreenLingo")
            return appDir.appendingPathComponent("translation_cache.json").path
        }
        return cacheFilePath
    }
    
    // MARK: API & Network Settings
    
    @AppStorage("rateLimitBackoff", store: TranslatorState.preferencesStore) var rateLimitBackoff: Double = 3.0 {
        didSet { log.info("Rate limit backoff: \(rateLimitBackoff)s", category: .settings) }
    }  // seconds to wait after rate limit error
    @AppStorage("apiTimeout", store: TranslatorState.preferencesStore) var apiTimeout: Double = 30.0 {  // API request timeout in seconds
        didSet { log.info("API timeout: \(apiTimeout)s", category: .settings) }
    }
    @AppStorage("languageFetchCooldown", store: TranslatorState.preferencesStore) var languageFetchCooldown: Double = 30.0 {  // seconds before retrying language fetch
        didSet { log.info("Language fetch cooldown: \(languageFetchCooldown)s", category: .settings) }
    }
    @AppStorage("maxConcurrentTranslations", store: TranslatorState.preferencesStore) var maxConcurrentTranslations: Int = 3 {  // max parallel API calls
        didSet { log.info("Max concurrent translations: \(maxConcurrentTranslations)", category: .settings) }
    }
    @AppStorage("translationDelay", store: TranslatorState.preferencesStore) var translationDelay: Double = 0.1 {  // seconds between translation requests
        didSet { log.info("Translation delay: \(Int(translationDelay * 1000))ms", category: .settings) }
    }
    @AppStorage("requestThrottleEnabled", store: TranslatorState.preferencesStore) var requestThrottleEnabled: Bool = true {
        didSet { log.info("Request throttle: \(requestThrottleEnabled ? "enabled" : "disabled")", category: .settings) }
    }
    @AppStorage("minRequestInterval", store: TranslatorState.preferencesStore) var minRequestInterval: Double = 0.2 {  // minimum seconds between API requests (200ms default)
        didSet { log.info("Min request interval: \(Int(minRequestInterval * 1000))ms", category: .settings) }
    }
    
    // MARK: OCR Settings
    
    @AppStorage("ocrAccurate", store: TranslatorState.preferencesStore) var ocrAccurate: Bool = true {  // true=accurate (slower), false=fast
        didSet { log.info("OCR mode: \(ocrAccurate ? "accurate" : "fast")", category: .settings) }
    }
    
    // Multi-monitor support
    @AppStorage("multiMonitorEnabled", store: TranslatorState.preferencesStore) var multiMonitorEnabled: Bool = false {
        didSet { log.info("Multi-monitor support: \(multiMonitorEnabled ? "enabled" : "disabled")", category: .settings) }
    }
    @AppStorage("minTextLength", store: TranslatorState.preferencesStore) var minTextLength: Int = 3 {  // minimum characters to translate
        didSet { log.info("Min text length: \(minTextLength) chars", category: .settings) }
    }
    @AppStorage("minLetterCount", store: TranslatorState.preferencesStore) var minLetterCount: Int = 2 {  // minimum letters required in text
        didSet { log.info("Min letter count: \(minLetterCount)", category: .settings) }
    }
    
    // MARK: Text Grouping Settings
    
    @AppStorage("textGrouping", store: TranslatorState.preferencesStore) var textGrouping: Double = 1.0 {  // 0.5=strict, 1.0=normal, 2.0=aggressive
        didSet { log.info("Text grouping: \(String(format: "%.1f", textGrouping))", category: .settings) }
    }
    @AppStorage("maxBubbleWidth", store: TranslatorState.preferencesStore) var maxBubbleWidth: Double = 0.30 {  // maximum bubble width (0-1, percentage of screen)
        didSet { log.info("Max bubble width: \(String(format: "%.0f", maxBubbleWidth * 100))%", category: .settings) }
    }
    @AppStorage("maxBubbleHeight", store: TranslatorState.preferencesStore) var maxBubbleHeight: Double = 0.35 {  // maximum bubble height (0-1, percentage of screen)
        didSet { log.info("Max bubble height: \(String(format: "%.0f", maxBubbleHeight * 100))%", category: .settings) }
    }
    @AppStorage("horizontalGapThreshold", store: TranslatorState.preferencesStore) var horizontalGapThreshold: Double = 0.03 {  // horizontal gap to separate bubbles (0-1)
        didSet { log.info("Horizontal gap threshold: \(String(format: "%.0f", horizontalGapThreshold * 100))%", category: .settings) }
    }
    @AppStorage("verticalGapMultiplier", store: TranslatorState.preferencesStore) var verticalGapMultiplier: Double = 2.5 {  // vertical gap multiplier for grouping
        didSet { log.info("Vertical gap multiplier: \(String(format: "%.1f", verticalGapMultiplier))", category: .settings) }
    }
    @AppStorage("centerAlignmentThreshold", store: TranslatorState.preferencesStore) var centerAlignmentThreshold: Double = 0.05 {  // center alignment tolerance (0-1)
        didSet { log.info("Center alignment threshold: \(String(format: "%.0f", centerAlignmentThreshold * 100))%", category: .settings) }
    }
    
    // MARK: Computed Properties for LTEngine
    
    var ltEngineBaseUrl: String {
        var url = libreTranslateUrl.trimmingCharacters(in: .whitespaces)
        // Remove /translate suffix to get base URL
        if url.hasSuffix("/translate") {
            url = String(url.dropLast("/translate".count))
        }
        if url.hasSuffix("/") {
            url = String(url.dropLast())
        }
        return url
    }
    
    private var canRetryLTEngineFetch: Bool {
        guard let lastAttempt = lastLTEngineFetchAttempt else { return true }
        return Date().timeIntervalSince(lastAttempt) >= languageFetchCooldown
    }
    
    // MARK: LTEngine Language Fetching
    
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
    
    // MARK: Google Translate Custom API
    
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
        return Date().timeIntervalSince(lastAttempt) >= languageFetchCooldown
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
                request.timeoutInterval = apiTimeout
                
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
                
                // Try Google Cloud Translation API v3 format
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
                
                // Try Google Cloud v2 format
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
                
                // Try simple array format
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
    
    // MARK: Language Utilities
    
    func languageName(for code: String) -> String {
        if code == "auto" { return "Auto Detect" }
        // Check fetched languages first based on active service
        if translationService == .ltEngine, let lang = ltEngineLanguages.first(where: { $0.code == code }) {
            return lang.name
        }
        if translationService == .google && hasCustomGoogleApi, let lang = googleLanguages.first(where: { $0.code == code }) {
            return lang.name
        }
        return StaticLanguageData.languageName(for: code)
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
            return StaticLanguageData.supportedLanguages
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
            return StaticLanguageData.supportedLanguages
        case .apple:
            return StaticLanguageData.supportedLanguages.filter { translationService.isLanguageSupported($0.code) }
        case .llm:
            // LLMs can translate to/from any language
            return StaticLanguageData.supportedLanguages
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
    
    // MARK: Manager Delegate Methods
    
    func isAppExcluded(_ bundleIdentifier: String?) -> Bool {
        excludedAppsManager.isAppExcluded(bundleIdentifier)
    }
    
    func shouldIgnoreText(_ text: String) -> Bool {
        ignorePatternManager.shouldIgnoreText(text)
    }
    
    func addIgnoredPattern(_ pattern: String) {
        ignorePatternManager.addIgnoredPattern(pattern)
    }
}

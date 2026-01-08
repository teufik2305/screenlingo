import Foundation
import os.log

// MARK: - Log Level

enum LogLevel: Int, Comparable, CaseIterable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    
    var label: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARN"
        case .error: return "ERROR"
        }
    }
    
    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Log Category

enum LogCategory: String {
    case engine = "Engine"
    case ocr = "OCR"
    case translation = "Translation"
    case api = "API"
    case cache = "Cache"
    case ui = "UI"
    case app = "App"
}

// MARK: - Translation Statistics

class TranslationStats {
    private let queue = DispatchQueue(label: "stats.queue")
    
    private var _sessionStart: Date = Date()
    private var _totalTranslations: Int = 0
    private var _cacheHits: Int = 0
    private var _apiCalls: Int = 0
    private var _appleTranslationCalls: Int = 0
    private var _errors: Int = 0
    private var _totalCharacters: Int = 0
    private var _totalApiTime: TimeInterval = 0
    
    var sessionStart: Date { queue.sync { _sessionStart } }
    var totalTranslations: Int { queue.sync { _totalTranslations } }
    var cacheHits: Int { queue.sync { _cacheHits } }
    var apiCalls: Int { queue.sync { _apiCalls } }
    var appleTranslationCalls: Int { queue.sync { _appleTranslationCalls } }
    var errors: Int { queue.sync { _errors } }
    var totalCharacters: Int { queue.sync { _totalCharacters } }
    var averageApiTime: TimeInterval { 
        queue.sync { 
            let calls = _apiCalls + _appleTranslationCalls
            return calls > 0 ? _totalApiTime / Double(calls) : 0 
        }
    }
    var cacheHitRate: Double {
        queue.sync { 
            let total = _cacheHits + _apiCalls + _appleTranslationCalls
            return total > 0 ? Double(_cacheHits) / Double(total) * 100 : 0
        }
    }
    
    func recordTranslation(cached: Bool, characters: Int, usedAppleTranslation: Bool = false) {
        queue.sync {
            _totalTranslations += 1
            _totalCharacters += characters
            if cached {
                _cacheHits += 1
            } else if usedAppleTranslation {
                _appleTranslationCalls += 1
            } else {
                _apiCalls += 1
            }
        }
    }
    
    func recordApiTime(_ time: TimeInterval) {
        queue.sync { _totalApiTime += time }
    }
    
    func recordError() {
        queue.sync { _errors += 1 }
    }
    
    func reset() {
        queue.sync {
            _sessionStart = Date()
            _totalTranslations = 0
            _cacheHits = 0
            _apiCalls = 0
            _appleTranslationCalls = 0
            _errors = 0
            _totalCharacters = 0
            _totalApiTime = 0
        }
    }
    
    func summary() -> String {
        let duration = Date().timeIntervalSince(sessionStart)
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        
        return """
        =======================================
        SESSION STATISTICS
        =======================================
        Duration:           \(minutes)m \(seconds)s
        Translations:       \(totalTranslations)
        Cache Hits:         \(cacheHits) (\(String(format: "%.1f", cacheHitRate))%)
        API Calls:          \(apiCalls)
        Apple Translation:  \(appleTranslationCalls)
        Avg Response Time:  \(String(format: "%.0f", averageApiTime * 1000))ms
        Characters:         \(totalCharacters)
        Errors:             \(errors)
        =======================================
        """
    }
}

// MARK: - App Logger

class AppLogger {
    static let shared = AppLogger()
    
    let stats = TranslationStats()
    
    private let fileQueue = DispatchQueue(label: "logger.file")
    private let osLog = OSLog(subsystem: "com.overlay.translator", category: "general")
    
    private var logFilePath: String = "/tmp/overlay_translator.log"
    private var minLevel: LogLevel = .info
    private var enableFileLogging: Bool = true
    private var enableConsoleLogging: Bool = true
    private var maxLogSize: Int = 5 * 1024 * 1024 // 5MB
    
    private var sessionId: String = ""
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    
    private let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    private init() {
        // Don't start session here - wait for engine to start
        sessionId = String(UUID().uuidString.prefix(8))
    }
    
    // MARK: - Configuration
    
    func configure(logFilePath: String, minLevel: LogLevel = .info, enableFileLogging: Bool = true) {
        fileQueue.sync {
            self.logFilePath = logFilePath
            self.minLevel = minLevel
            self.enableFileLogging = enableFileLogging
        }
    }
    
    func setMinLevel(_ level: LogLevel) {
        fileQueue.sync { self.minLevel = level }
    }
    
    // MARK: - Session Management
    
    func startNewSession() {
        sessionId = String(UUID().uuidString.prefix(8))
        stats.reset()
        
        let header = """
        
        ================================================================
        OVERLAY TRANSLATOR - SESSION \(sessionId)
        Started: \(fullDateFormatter.string(from: Date()))
        ================================================================
        
        """
        writeToFile(header)
    }
    
    func endSession() {
        let footer = stats.summary()
        writeToFile(footer)
    }
    
    // MARK: - Logging Methods
    
    func debug(_ message: String, category: LogCategory = .app) {
        log(message, level: .debug, category: category)
    }
    
    func info(_ message: String, category: LogCategory = .app) {
        log(message, level: .info, category: category)
    }
    
    func warning(_ message: String, category: LogCategory = .app) {
        log(message, level: .warning, category: category)
    }
    
    func error(_ message: String, category: LogCategory = .app) {
        log(message, level: .error, category: category)
        stats.recordError()
    }
    
    // MARK: - Specialized Logging
    
    func engineStarted() {
        // Start a new session when engine starts
        startNewSession()
        info("Translation engine started", category: .engine)
    }
    
    func engineStopped() {
        info("Translation engine stopped", category: .engine)
        endSession()
    }
    
    func windowCaptured(app: String, size: CGSize) {
        debug("Captured [\(app)] \(Int(size.width))x\(Int(size.height))", category: .engine)
    }
    
    func windowChanged(from oldApp: String?, to newApp: String) {
        info("Window changed -> \(newApp)", category: .engine)
    }
    
    func appExcluded(_ bundleId: String) {
        debug("Skipping excluded app: \(bundleId)", category: .engine)
    }
    
    func ocrCompleted(regions: Int, duration: TimeInterval) {
        debug("OCR: \(regions) regions in \(String(format: "%.0f", duration * 1000))ms", category: .ocr)
    }
    
    func textIgnored(_ text: String, reason: String) {
        debug("Ignored [\(reason)]: '\(text.prefix(30))...'", category: .ocr)
    }
    
    func textAccepted(_ text: String) {
        debug("Text: '\(text.prefix(50))...'", category: .ocr)
    }
    
    func translationStarted(_ text: String) {
        debug("Translating: '\(text.prefix(40))...'", category: .translation)
    }
    
    func translationCompleted(_ original: String, _ translated: String, cached: Bool, usedAppleTranslation: Bool, duration: TimeInterval) {
        let source: String
        if cached {
            source = "CACHE"
        } else if usedAppleTranslation {
            source = "APPLE"
        } else {
            source = "API"
        }
        let timeStr = cached ? "" : " [\(String(format: "%.0f", duration * 1000))ms]"
        debug("[\(source)] '\(original.prefix(25))...' -> '\(translated.prefix(25))...'\(timeStr)", category: .translation)
        stats.recordTranslation(cached: cached, characters: original.count, usedAppleTranslation: usedAppleTranslation)
        if !cached {
            stats.recordApiTime(duration)
        }
    }
    
    func translationFailed(_ text: String, error: Error) {
        self.error("Translation failed: \(error.localizedDescription) - '\(text.prefix(30))...'", category: .translation)
    }
    
    func apiRequest(url: String) {
        debug("API Request: \(url.prefix(80))...", category: .api)
    }
    
    func apiResponse(status: Int, duration: TimeInterval) {
        debug("API Response: \(status) in \(String(format: "%.0f", duration * 1000))ms", category: .api)
    }
    
    func cacheHit(_ text: String) {
        debug("Cache hit: '\(text.prefix(30))...'", category: .cache)
    }
    
    func cacheMiss(_ text: String) {
        debug("Cache miss: '\(text.prefix(30))...'", category: .cache)
    }
    
    func blocksCreated(_ count: Int) {
        info("Created \(count) overlay blocks", category: .ui)
    }
    
    func appleTranslationFallback() {
        warning("Apple Translation unavailable (requires macOS 26+), using API fallback", category: .translation)
    }
    
    // MARK: - Core Logging
    
    private func log(_ message: String, level: LogLevel, category: LogCategory) {
        guard level >= minLevel else { return }
        
        let timestamp = dateFormatter.string(from: Date())
        let formattedMessage = "[\(timestamp)] [\(level.label)] [\(category.rawValue)] \(message)"
        
        // Console logging via os.log
        if enableConsoleLogging {
            let osLogType: OSLogType
            switch level {
            case .debug: osLogType = .debug
            case .info: osLogType = .info
            case .warning: osLogType = .default
            case .error: osLogType = .error
            }
            os_log("%{public}@", log: osLog, type: osLogType, formattedMessage)
        }
        
        // File logging
        if enableFileLogging {
            writeToFile(formattedMessage + "\n")
        }
    }
    
    private func writeToFile(_ text: String) {
        fileQueue.async { [weak self] in
            guard let self = self else { return }
            
            let url = URL(fileURLWithPath: self.logFilePath)
            
            // Check and rotate if needed
            self.rotateLogIfNeeded()
            
            if let data = text.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: self.logFilePath) {
                    if let handle = try? FileHandle(forWritingTo: url) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        try? handle.close()
                    }
                } else {
                    try? data.write(to: url)
                }
            }
        }
    }
    
    private func rotateLogIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: logFilePath),
              let size = attrs[.size] as? Int,
              size > maxLogSize else { return }
        
        // Rotate: rename current to .old, start fresh
        let oldPath = logFilePath + ".old"
        try? FileManager.default.removeItem(atPath: oldPath)
        try? FileManager.default.moveItem(atPath: logFilePath, toPath: oldPath)
        
        let rotateMessage = "Log rotated (previous log saved as .old)\n"
        if let data = rotateMessage.data(using: .utf8) {
            try? data.write(to: URL(fileURLWithPath: logFilePath))
        }
    }
    
    // MARK: - Utilities
    
    func clearLog() {
        fileQueue.async { [weak self] in
            guard let self = self else { return }
            try? FileManager.default.removeItem(atPath: self.logFilePath)
            // Just clear the file, don't start a new session
        }
    }
    
    func getLogContents() -> String {
        fileQueue.sync {
            (try? String(contentsOfFile: logFilePath, encoding: .utf8)) ?? "No log file found"
        }
    }
}

// MARK: - Global Convenience Functions

let log = AppLogger.shared

func logDebug(_ message: String, category: LogCategory = .app) {
    log.debug(message, category: category)
}

func logInfo(_ message: String, category: LogCategory = .app) {
    log.info(message, category: category)
}

func logWarning(_ message: String, category: LogCategory = .app) {
    log.warning(message, category: category)
}

func logError(_ message: String, category: LogCategory = .app) {
    log.error(message, category: category)
}

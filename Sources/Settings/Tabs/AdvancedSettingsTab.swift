import SwiftUI

struct AdvancedSettingsTab: View {
    @ObservedObject var state: TranslatorState
    @State private var showingStats = false
    @State private var isRecordingHotkey = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Display (multi-monitor support)
                settingsSection("Display") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $state.multiMonitorEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Multi-Monitor Support")
                                Text(state.multiMonitorEnabled 
                                     ? "Overlay follows windows across all monitors" 
                                     : "Overlay only shows on primary monitor")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        
                        if state.multiMonitorEnabled {
                            HStack(spacing: 8) {
                                Image(systemName: "display.2")
                                    .foregroundStyle(.secondary)
                                Text("Connected displays: \(NSScreen.screens.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.leading, 20)
                        }
                    }
                }
                
                // Performance (first section)
                settingsSection("Performance") {
                    VStack(alignment: .leading, spacing: 12) {
                        // OCR Settings
                        Toggle(isOn: $state.ocrAccurate) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Accurate OCR")
                                Text(state.ocrAccurate ? "Better recognition, slightly slower" : "Faster, may miss some text")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        
                        Divider()
                        
                        // Capture Interval
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Capture Interval")
                                Spacer()
                                Text("\(Int(state.captureInterval * 1000))ms")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $state.captureInterval, in: 0.03...0.5, step: 0.01)
                            Text("Screen capture frequency. Lower = more responsive but uses more CPU.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Divider()
                        
                        // Stability Threshold
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Stability Threshold")
                                Spacer()
                                Text("\(Int(state.stabilityThreshold))px")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $state.stabilityThreshold, in: 0...50, step: 1)
                            Text("Ignore small position changes to prevent jitter.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Divider()
                        
                        // Text Grouping
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Text Grouping")
                                Spacer()
                                Text(groupingLabel(state.textGrouping))
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $state.textGrouping, in: 0.5...2.0, step: 0.25)
                            Text("Group nearby text lines. Lower = separate bubbles (manga/comics), Higher = merge lines (subtitles).")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Divider()
                        
                        // Min Text Length
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Min Text Length")
                                Spacer()
                                Text("\(state.minTextLength) chars")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: Binding(
                                get: { Double(state.minTextLength) },
                                set: { state.minTextLength = Int($0) }
                            ), in: 1...10, step: 1)
                            Text("Skip text shorter than this to reduce noise.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Divider()
                        
                        // Min Letter Count
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Min Letter Count")
                                Spacer()
                                Text("\(state.minLetterCount) letters")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: Binding(
                                get: { Double(state.minLetterCount) },
                                set: { state.minLetterCount = Int($0) }
                            ), in: 1...5, step: 1)
                            Text("Minimum letters required (filters symbols/numbers).")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Divider()
                        
                        // Cache
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Cache Size")
                                Spacer()
                                Text("\(state.maxCacheSize)")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: Binding(
                                get: { Double(state.maxCacheSize) },
                                set: { state.maxCacheSize = Int($0) }
                            ), in: 100...2000, step: 100)
                            Text("Number of translations to remember. Higher = less API calls.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                NotificationCenter.default.post(name: TranslatorState.clearCacheNotification, object: nil)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                    Text("Clear Cache")
                                }
                            }
                            
                            Button(action: {
                                NotificationCenter.default.post(name: TranslatorState.deleteCacheFileNotification, object: nil)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash.slash")
                                    Text("Delete File")
                                }
                            }
                            .buttonStyle(.bordered)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Clear = memory only")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text("Delete = remove file from disk")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        
                        Divider()
                        
                        // Cache Persistence
                        Toggle(isOn: $state.enableCachePersistence) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Save Cache to Disk")
                                Text("Persist translations between app restarts")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        
                        if state.enableCachePersistence {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Cache File Location")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                
                                HStack(spacing: 8) {
                                    TextField("Default location", text: $state.cacheFilePath)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(.caption, design: .monospaced))
                                    
                                    Button("Choose...") {
                                        let panel = NSOpenPanel()
                                        panel.canChooseFiles = false
                                        panel.canChooseDirectories = true
                                        panel.canCreateDirectories = true
                                        panel.prompt = "Select"
                                        panel.message = "Choose folder for cache file"
                                        
                                        if panel.runModal() == .OK, let url = panel.url {
                                            state.cacheFilePath = url.appendingPathComponent("translation_cache.json").path
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Button("Reset") {
                                        state.cacheFilePath = ""
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(state.cacheFilePath.isEmpty)
                                }
                                
                                Text(state.cacheFilePath.isEmpty ? "Default: ~/Library/Application Support/ScreenLingo/translation_cache.json" : state.effectiveCacheFilePath)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(2)
                                
                                HStack {
                                    Button("Save Now") {
                                        NotificationCenter.default.post(name: TranslatorState.saveCacheNotification, object: nil)
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Spacer()
                                    
                                    Text("Manually save current cache to disk")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.leading, 20)
                        }
                    }
                }
                
                // Network & API
                settingsSection("Network & API") {
                    VStack(alignment: .leading, spacing: 12) {
                        // API Timeout
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("API Timeout")
                                Spacer()
                                Text("\(Int(state.apiTimeout))s")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $state.apiTimeout, in: 5...60, step: 5)
                            Text("Max wait time for API response. Increase for slow connections.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Divider()
                        
                        // Rate Limit Backoff
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Rate Limit Backoff")
                                Spacer()
                                Text("\(String(format: "%.1f", state.rateLimitBackoff))s")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $state.rateLimitBackoff, in: 1...10, step: 0.5)
                            Text("Pause duration when API rate limit is hit (prevents spam).")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Divider()
                        
                        // Max Concurrent Translations
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Max Concurrent Translations")
                                Spacer()
                                Text("\(state.maxConcurrentTranslations)")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: Binding(
                                get: { Double(state.maxConcurrentTranslations) },
                                set: { state.maxConcurrentTranslations = Int($0) }
                            ), in: 1...10, step: 1)
                            Text("Maximum parallel API requests. Lower = less rate limits, slower.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Divider()
                        
                        // Translation Delay
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Translation Delay")
                                Spacer()
                                Text("\(Int(state.translationDelay * 1000))ms")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $state.translationDelay, in: 0...1.0, step: 0.05)
                            Text("Delay between translation requests. Higher = less rate limits.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        Divider()
                        
                        // Language Fetch Cooldown
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Language Fetch Cooldown")
                                Spacer()
                                Text("\(Int(state.languageFetchCooldown))s")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $state.languageFetchCooldown, in: 10...120, step: 10)
                            Text("Wait time before retrying to fetch available languages from API.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                
                // Text Grouping (Advanced)
                settingsSection("Text Grouping (Advanced)") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Fine-tune how text regions are grouped into translation bubbles.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Divider()
                        
                        // Max Bubble Width
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Max Bubble Width")
                                Spacer()
                                Text("\(Int(state.maxBubbleWidth * 100))%")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $state.maxBubbleWidth, in: 0.1...0.5, step: 0.05)
                            Text("Maximum width of a single bubble (% of screen).")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Divider()
                        
                        // Max Bubble Height
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Max Bubble Height")
                                Spacer()
                                Text("\(Int(state.maxBubbleHeight * 100))%")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $state.maxBubbleHeight, in: 0.1...0.6, step: 0.05)
                            Text("Maximum height of a single bubble (% of screen).")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Divider()
                        
                        // Horizontal Gap
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Horizontal Gap Threshold")
                                Spacer()
                                Text("\(String(format: "%.2f", state.horizontalGapThreshold))")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $state.horizontalGapThreshold, in: 0.01...0.1, step: 0.01)
                            Text("Side-by-side text spacing. Lower = split more, Higher = merge more.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Divider()
                        
                        // Vertical Gap Multiplier
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Vertical Gap Multiplier")
                                Spacer()
                                Text("\(String(format: "%.1f", state.verticalGapMultiplier))x")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $state.verticalGapMultiplier, in: 1.0...5.0, step: 0.5)
                            Text("Vertical line spacing. Lower = separate lines, Higher = group lines.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Divider()
                        
                        // Center Alignment
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Center Alignment Threshold")
                                Spacer()
                                Text("\(Int(state.centerAlignmentThreshold * 100))%")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $state.centerAlignmentThreshold, in: 0.01...0.15, step: 0.01)
                            Text("How aligned text must be to group vertically. Lower = stricter.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                
                // Keyboard Shortcuts
                settingsSection("Keyboard Shortcuts") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Toggle Translation")
                            Spacer()
                            
                            if isRecordingHotkey {
                                HStack(spacing: 6) {
                                    Text("Press keys...")
                                        .foregroundStyle(.secondary)
                                    
                                    Button("Cancel") {
                                        isRecordingHotkey = false
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.red)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.2))
                                .cornerRadius(6)
                            } else {
                                Button(action: {
                                    isRecordingHotkey = true
                                }) {
                                    Text(state.hotkeyDisplayString)
                                        .font(.system(.body, design: .monospaced))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color(nsColor: .windowBackgroundColor))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        if isRecordingHotkey {
                            Text("Press a key combination with ⌘, ⌃, ⌥, or ⇧")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("Requires app restart to take effect")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .background(
                        HotkeyRecorderView(
                            isRecording: $isRecordingHotkey,
                            keyCode: $state.hotkeyKeyCode,
                            modifiers: $state.hotkeyModifiers
                        )
                        .frame(width: 0, height: 0)
                    )
                }
                
                // Logging (at the bottom)
                settingsSection("Logging") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $state.enableFileLogging) {
                            Text("Enable file logging")
                        }
                        
                        if state.enableFileLogging {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Log Level")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Picker("Log Level", selection: $state.logLevelRaw) {
                                    Text("Debug").tag(0)
                                    Text("Info").tag(1)
                                    Text("Warning").tag(2)
                                    Text("Error").tag(3)
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                                
                                Text(logLevelDescription(state.logLevelRaw))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Log File Path")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                HStack {
                                    TextField("Log path", text: $state.logFilePath)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(.body, design: .monospaced))
                                    
                                    Button("Open") {
                                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: state.logFilePath)
                                    }
                                }
                            }
                            
                            Divider()
                            
                            HStack {
                                Button("View Statistics") {
                                    showingStats = true
                                }
                                
                                Spacer()
                                
                                Button("Clear Log") {
                                    log.clearLog()
                                }
                                .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingStats) {
            StatsView()
        }
    }
    
    @ViewBuilder
    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            
            content()
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
        }
    }
    
    private func groupingLabel(_ value: Double) -> String {
        if value <= 0.5 { return "Minimal" }
        if value <= 0.75 { return "Light" }
        if value <= 1.25 { return "Normal" }
        if value <= 1.75 { return "Strong" }
        return "Maximum"
    }
    
    private func logLevelDescription(_ level: Int) -> String {
        switch level {
        case 0: return "Verbose logging - includes all details"
        case 1: return "Normal logging - operations and statistics"
        case 2: return "Warnings and errors only"
        case 3: return "Errors only - minimal logging"
        default: return ""
        }
    }
}

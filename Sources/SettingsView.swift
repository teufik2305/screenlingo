import SwiftUI
import Translation

struct SettingsView: View {
    @ObservedObject var state: TranslatorState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            TabView {
                // General Tab
                GeneralSettingsTab(state: state)
                    .tabItem {
                        Label("General", systemImage: "gearshape")
                    }
                
                // Appearance Tab
                AppearanceSettingsTab(state: state)
                    .tabItem {
                        Label("Appearance", systemImage: "paintbrush")
                    }
                
                // Filters Tab
                FiltersSettingsTab(state: state)
                    .tabItem {
                        Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                    }
                
                // Advanced Tab
                AdvancedSettingsTab(state: state)
                    .tabItem {
                        Label("Advanced", systemImage: "wrench.and.screwdriver")
                    }
            }
            .padding(.top, 8)
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.return)
            }
            .padding()
        }
        .frame(width: 520, height: 480)
    }
}

// MARK: - General Settings Tab

struct GeneralSettingsTab: View {
    @ObservedObject var state: TranslatorState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Translation Service
                settingsSection("Translation Service") {
                    VStack(alignment: .leading, spacing: 12) {
                        // Service selection cards
                        HStack(spacing: 10) {
                            ForEach(TranslationServiceType.allCases, id: \.rawValue) { service in
                                TranslationServiceCard(
                                    service: service,
                                    isSelected: state.translationService == service,
                                    isAvailable: service != .apple || TranslationService.isAppleTranslationAvailable
                                ) {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        state.translationService = service
                                    }
                                }
                            }
                        }
                        
                        // Description of selected service
                        VStack(alignment: .leading, spacing: 6) {
                            Text(state.translationService.detailedDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Divider()
                            
                            HStack(alignment: .top, spacing: 4) {
                                Text("Languages:")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                Text(state.translationService.supportedLanguagesNote)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .cornerRadius(8)
                        
                        // Service-specific settings
                        switch state.translationService {
                        case .ltEngine:
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Server URL")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                TextField("http://localhost:5000/translate", text: $state.libreTranslateUrl)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                
                                Text("API Key (optional)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                SecureField("Leave empty if not required", text: $state.libreTranslateApiKey)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            
                        case .apple:
                            AppleTranslationSettingsWrapper(state: state)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            
                        case .google:
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Custom API URL (optional)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                TextField("Default: translate.googleapis.com", text: $state.customApiUrl)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                
                                if state.customApiUrl.isEmpty {
                                    Text("Using default: \(TranslatorState.defaultApiUrl)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                
                // Languages
                settingsSection("Languages") {
                    HStack(spacing: 12) {
                        Picker("From", selection: $state.sourceLanguage) {
                            ForEach(state.availableSourceLanguages, id: \.code) { lang in
                                Text(lang.name).tag(lang.code)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        Button(action: { state.swapLanguages() }) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.caption)
                                .foregroundStyle(state.sourceLanguage == "auto" ? .tertiary : .secondary)
                        }
                        .buttonStyle(.plain)
                        .disabled(state.sourceLanguage == "auto")
                        
                        Picker("To", selection: $state.targetLanguage) {
                            ForEach(state.availableLanguages, id: \.code) { lang in
                                Text(lang.name).tag(lang.code)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                
                // Interaction Mode
                settingsSection("Interaction Mode") {
                    VStack(alignment: .leading, spacing: 12) {
                        // Mode selection cards
                        HStack(spacing: 10) {
                            ForEach(InteractionMode.allCases, id: \.rawValue) { mode in
                                InteractionModeCard(
                                    mode: mode,
                                    isSelected: state.interactionMode == mode
                                ) {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        state.interactionMode = mode
                                    }
                                }
                            }
                        }
                        
                        // Description
                        Text(state.interactionMode.detailedDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .windowBackgroundColor))
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
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
    
}

// MARK: - Appearance Settings Tab

struct AppearanceSettingsTab: View {
    @ObservedObject var state: TranslatorState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                settingsSection("Overlay Style") {
                    VStack(alignment: .leading, spacing: 12) {
                        // Font Size
                        HStack {
                            Text("Font Size")
                                .frame(width: 100, alignment: .leading)
                            Slider(value: $state.fontSize, in: 12...24, step: 1)
                            Text("\(Int(state.fontSize))pt")
                                .frame(width: 40)
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        // Opacity
                        HStack {
                            Text("Opacity")
                                .frame(width: 100, alignment: .leading)
                            Slider(value: $state.overlayOpacity, in: 0.7...1.0, step: 0.05)
                            Text("\(Int(state.overlayOpacity * 100))%")
                                .frame(width: 40)
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        Divider()
                        
                        // Single unified preview
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Preview")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            OverlayPreview(fontSize: state.fontSize, opacity: state.overlayOpacity)
                        }
                    }
                }
            }
            .padding()
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
}

// MARK: - Filters Settings Tab

struct FiltersSettingsTab: View {
    @ObservedObject var state: TranslatorState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Excluded Apps
                settingsSection("Excluded Apps") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Translation is disabled for these apps:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        ExcludedAppsEditor(state: state)
                    }
                }
                
                // Ignore Patterns
                settingsSection("Ignore Patterns") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Text containing these patterns will be ignored:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        IgnoreListEditor(state: state)
                    }
                }
            }
            .padding()
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
}

// MARK: - Advanced Settings Tab

struct AdvancedSettingsTab: View {
    @ObservedObject var state: TranslatorState
    @State private var showingStats = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Logging
                settingsSection("Logging") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $state.enableFileLogging) {
                            Text("Enable file logging")
                        }
                        
                        if state.enableFileLogging {
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
                
                // Performance
                settingsSection("Performance") {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Capture Interval")
                                Spacer()
                                Text("\(Int(state.captureInterval * 1000))ms")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $state.captureInterval, in: 0.03...0.5, step: 0.01)
                            Text("How often to capture screen. Lower = smoother but uses more CPU.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Stability Threshold")
                                Spacer()
                                Text("\(Int(state.stabilityThreshold))px")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $state.stabilityThreshold, in: 0...50, step: 1)
                            Text("Ignore position changes smaller than this. Prevents jitter.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Divider()
                        
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
                            Text("Skip text shorter than this. Reduces noise from short labels.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Divider()
                        
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
                            Text("Max translations to cache. Higher = more memory but faster.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Divider()
                        
                        Toggle(isOn: $state.ocrAccurate) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Accurate OCR")
                                Text(state.ocrAccurate ? "Better text recognition, slightly slower" : "Faster recognition, may miss some text")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Text Grouping")
                                Spacer()
                                Text(groupingLabel(state.textGrouping))
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $state.textGrouping, in: 0.5...2.0, step: 0.25)
                            Text("How aggressively to group text lines. Higher = better for manga/comics.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Divider()
                        
                        HStack {
                            Button(action: {
                                NotificationCenter.default.post(name: TranslatorState.clearCacheNotification, object: nil)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                    Text("Clear Translation Cache")
                                }
                            }
                            
                            Spacer()
                            
                            Text("Clears all cached translations")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                
                // Keyboard Shortcuts
                settingsSection("Keyboard Shortcuts") {
                    VStack(alignment: .leading, spacing: 8) {
                        shortcutRow("Toggle Translation", shortcut: "⌘⌃T")
                    }
                }
                
                // Tips
                settingsSection("Tips") {
                    VStack(alignment: .leading, spacing: 8) {
                        tipRow("Click overlay for options (copy, hide, ignore)")
                        tipRow("Hidden overlays: click any overlay → Show All")
                        tipRow("Add apps to Excluded Apps to skip translation")
                        tipRow("Use Ignore Patterns to filter unwanted text")
                    }
                }
                
                // About
                settingsSection("About") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Overlay Translator")
                                .fontWeight(.medium)
                            Spacer()
                            Text("v1.0")
                                .foregroundStyle(.secondary)
                        }
                        Text("Real-time screen translation for macOS")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
    
    @ViewBuilder
    private func shortcutRow(_ action: String, shortcut: String) -> some View {
        HStack {
            Text(action)
            Spacer()
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(4)
        }
    }
    
    @ViewBuilder
    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
                .font(.caption)
            Text(text)
                .font(.callout)
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

// MARK: - Statistics View

struct StatsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Session Statistics")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()
            
            Divider()
            
            // Stats content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    StatRow(label: "Session Duration", value: sessionDuration)
                    StatRow(label: "Total Translations", value: "\(log.stats.totalTranslations)")
                    
                    Divider()
                    
                    StatRow(label: "Cache Hits", value: "\(log.stats.cacheHits)")
                    StatRow(label: "API Calls", value: "\(log.stats.apiCalls)")
                    StatRow(label: "Cache Hit Rate", value: String(format: "%.1f%%", log.stats.cacheHitRate))
                    
                    Divider()
                    
                    StatRow(label: "Avg API Time", value: String(format: "%.0fms", log.stats.averageApiTime * 1000))
                    StatRow(label: "Characters Translated", value: "\(log.stats.totalCharacters)")
                    StatRow(label: "Errors", value: "\(log.stats.errors)")
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            HStack {
                Button("Reset Statistics") {
                    log.stats.reset()
                }
                .foregroundStyle(.red)
                
                Spacer()
                
                Button("Copy to Clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(log.stats.summary(), forType: .string)
                }
            }
            .padding()
        }
        .frame(width: 350, height: 400)
    }
    
    var sessionDuration: String {
        let duration = Date().timeIntervalSince(log.stats.sessionStart)
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return "\(minutes)m \(seconds)s"
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .font(.system(.body, design: .monospaced))
        }
    }
}

// MARK: - Reusable Components

struct ExcludedAppsEditor: View {
    @ObservedObject var state: TranslatorState
    @State private var newBundleId = ""
    
    var body: some View {
        VStack(spacing: 8) {
            // Add new app
            HStack {
                TextField("Bundle ID (e.g. com.apple.Safari)", text: $newBundleId)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { addApp() }
                
                Button("Add") { addApp() }
                    .disabled(newBundleId.isEmpty)
            }
            
            // Common apps quick-add
            HStack(spacing: 8) {
                Text("Quick add:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                QuickAddButton(label: "Cursor", bundleId: "com.todesktop.230313mzl4w4u92", state: state)
                QuickAddButton(label: "VS Code", bundleId: "com.microsoft.VSCode", state: state)
                QuickAddButton(label: "Xcode", bundleId: "com.apple.dt.Xcode", state: state)
                QuickAddButton(label: "Terminal", bundleId: "com.apple.Terminal", state: state)
            }
            
            // App list
            if state.excludedApps.isEmpty {
                Text("No excluded apps")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .padding(.vertical, 4)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(state.excludedApps, id: \.self) { bundleId in
                        AppTag(bundleId: bundleId) {
                            state.removeExcludedApp(bundleId)
                        }
                    }
                }
            }
        }
    }
    
    private func addApp() {
        let trimmed = newBundleId.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            state.addExcludedApp(trimmed)
            newBundleId = ""
        }
    }
}

struct QuickAddButton: View {
    let label: String
    let bundleId: String
    @ObservedObject var state: TranslatorState
    
    var isAdded: Bool {
        state.excludedApps.contains(bundleId)
    }
    
    var body: some View {
        Button(action: {
            if isAdded {
                state.removeExcludedApp(bundleId)
            } else {
                state.addExcludedApp(bundleId)
            }
        }) {
            Text(label)
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .tint(isAdded ? .green : .gray)
    }
}

struct AppTag: View {
    let bundleId: String
    let onRemove: () -> Void
    
    var displayName: String {
        switch bundleId {
        case "com.todesktop.230313mzl4w4u92": return "Cursor"
        case "com.microsoft.VSCode": return "VS Code"
        case "com.apple.dt.Xcode": return "Xcode"
        case "com.apple.Terminal": return "Terminal"
        default: return bundleId.components(separatedBy: ".").last ?? bundleId
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(displayName)
                .font(.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.purple.opacity(0.1))
        .foregroundStyle(.purple)
        .cornerRadius(12)
        .help(bundleId)
    }
}

struct IgnoreListEditor: View {
    @ObservedObject var state: TranslatorState
    @State private var newPattern = ""
    
    var body: some View {
        VStack(spacing: 8) {
            // Add new pattern
            HStack {
                TextField("Add pattern...", text: $newPattern)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addPattern() }
                
                Button("Add") { addPattern() }
                    .disabled(newPattern.isEmpty)
            }
            
            // Pattern list
            if state.ignoredPatterns.isEmpty {
                Text("No patterns")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .padding(.vertical, 4)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(state.ignoredPatterns, id: \.self) { pattern in
                        PatternTag(pattern: pattern) {
                            state.removeIgnoredPattern(pattern)
                        }
                    }
                }
            }
        }
    }
    
    private func addPattern() {
        let trimmed = newPattern.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            state.addIgnoredPattern(trimmed)
            newPattern = ""
        }
    }
}

struct PatternTag: View {
    let pattern: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(pattern)
                .font(.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .foregroundStyle(.blue)
        .cornerRadius(12)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0
        
        let maxX = proposal.width ?? .infinity
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxX && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxWidth = max(maxWidth, currentX)
        }
        
        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}

// MARK: - Translation Service Card

struct TranslationServiceCard: View {
    let service: TranslationServiceType
    let isSelected: Bool
    let isAvailable: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: service.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? service.color : .secondary)
                
                Text(service.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                
                Text(service.shortDescription)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? service.color.opacity(0.12) : Color(nsColor: .windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? service.color : Color.clear, lineWidth: 2)
            )
            .opacity(isAvailable ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
    }
}

// MARK: - Interaction Mode Card

struct InteractionModeCard: View {
    let mode: InteractionMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: mode.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? mode.color : .secondary)
                
                Text(mode.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                
                Text(mode.shortDescription)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? mode.color.opacity(0.12) : Color(nsColor: .windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? mode.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Overlay Preview

struct OverlayPreview: View {
    let fontSize: Double
    let opacity: Double
    
    var body: some View {
        ZStack {
            // Checkerboard pattern to show transparency
            GeometryReader { geo in
                let cellSize: CGFloat = 10
                let cols = Int(ceil(geo.size.width / cellSize))
                let rows = Int(ceil(geo.size.height / cellSize))
                
                Canvas { context, size in
                    for row in 0..<rows {
                        for col in 0..<cols {
                            let isLight = (row + col) % 2 == 0
                            let rect = CGRect(
                                x: CGFloat(col) * cellSize,
                                y: CGFloat(row) * cellSize,
                                width: cellSize,
                                height: cellSize
                            )
                            context.fill(
                                Path(rect),
                                with: .color(isLight ? Color.gray.opacity(0.2) : Color.gray.opacity(0.4))
                            )
                        }
                    }
                }
            }
            .cornerRadius(6)
            
            // Overlay preview
            Text("Preview text")
                .font(.system(size: fontSize))
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(opacity))
                .foregroundColor(.white)
                .cornerRadius(6)
        }
        .frame(height: 44)
    }
}

// MARK: - Apple Translation Settings

@available(macOS 26.0, *)
struct AppleTranslationSettings: View {
    @ObservedObject var state: TranslatorState
    @State private var isDownloading = false
    @State private var statusMessage: String = ""
    @State private var configuration: TranslationSession.Configuration?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button(action: downloadLanguagePack) {
                    HStack(spacing: 6) {
                        if isDownloading {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "arrow.down.circle")
                        }
                        Text(isDownloading ? "Downloading..." : "Download Language Packs")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(isDownloading)
                
                // Show check button when download is in progress in background
                if statusMessage.contains("↓") {
                    Button("Check") {
                        checkStatus()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(
                            statusMessage.contains("✓") ? .green : 
                            statusMessage.contains("✗") ? .red : 
                            statusMessage.contains("↓") ? .blue : .secondary
                        )
                }
            }
            
            Text("\(state.languageName(for: state.sourceLanguage)) → \(state.languageName(for: state.targetLanguage))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .onAppear { setupConfiguration() }
        .onChange(of: state.sourceLanguage) { _, _ in setupConfiguration() }
        .onChange(of: state.targetLanguage) { _, _ in setupConfiguration() }
        .translationTask(configuration) { session in
            // Perform a test translation to trigger download if needed
            guard isDownloading else { return }
            do {
                _ = try await session.translate("test")
                await MainActor.run {
                    statusMessage = "✓ Ready"
                    isDownloading = false
                }
            } catch {
                await MainActor.run {
                    // Check if it was cancelled (user clicked Done) - download continues in background
                    let errorDesc = error.localizedDescription.lowercased()
                    if errorDesc.contains("cancel") {
                        statusMessage = "↓ Downloading in background..."
                    } else {
                        statusMessage = "✗ \(error.localizedDescription)"
                    }
                    isDownloading = false
                }
            }
        }
    }
    
    private func setupConfiguration() {
        let source = Locale.Language(identifier: state.sourceLanguage)
        let target = Locale.Language(identifier: state.targetLanguage)
        configuration = TranslationSession.Configuration(source: source, target: target)
        statusMessage = ""
    }
    
    private func downloadLanguagePack() {
        isDownloading = true
        statusMessage = ""
        
        Task {
            let source = Locale.Language(identifier: state.sourceLanguage)
            let target = Locale.Language(identifier: state.targetLanguage)
            
            let availability = LanguageAvailability()
            let status = await availability.status(from: source, to: target)
            
            await MainActor.run {
                switch status {
                case .installed:
                    statusMessage = "✓ Ready"
                    isDownloading = false
                case .supported:
                    // Trigger download by invalidating - translationTask will handle it
                    statusMessage = "Starting download..."
                    configuration?.invalidate()
                case .unsupported:
                    statusMessage = "✗ Not supported"
                    isDownloading = false
                @unknown default:
                    statusMessage = "✗ Unknown"
                    isDownloading = false
                }
            }
        }
    }
    
    private func checkStatus() {
        Task {
            let source = Locale.Language(identifier: state.sourceLanguage)
            let target = Locale.Language(identifier: state.targetLanguage)
            
            let availability = LanguageAvailability()
            let status = await availability.status(from: source, to: target)
            
            await MainActor.run {
                switch status {
                case .installed:
                    statusMessage = "✓ Ready"
                case .supported:
                    statusMessage = "↓ Still downloading..."
                case .unsupported:
                    statusMessage = "✗ Not supported"
                @unknown default:
                    statusMessage = "?"
                }
            }
        }
    }
}

struct AppleTranslationSettingsWrapper: View {
    @ObservedObject var state: TranslatorState
    
    var body: some View {
        if #available(macOS 26.0, *) {
            AppleTranslationSettings(state: state)
        } else {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Requires macOS 15+ • Will fallback to Google API")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}

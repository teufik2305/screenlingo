import SwiftUI

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
                        Toggle(isOn: $state.useAppleTranslation) {
                            Text("Use Apple Translation")
                        }
                        .disabled(!TranslationService.isAppleTranslationAvailable)
                        
                        // Visual explanation
                        HStack(spacing: 12) {
                            Image(systemName: state.useAppleTranslation ? "apple.logo" : "network")
                                .font(.title2)
                                .foregroundStyle(state.useAppleTranslation ? .blue : .orange)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(state.useAppleTranslation ? "Apple Translation" : "API Translation")
                                    .fontWeight(.medium)
                                
                                if state.useAppleTranslation {
                                    if TranslationService.isAppleTranslationAvailable {
                                        Text("On-device translation, private & fast")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("Requires macOS 26+ • Using API as fallback")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                } else {
                                    Text("Uses external API for translation")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(10)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .cornerRadius(8)
                        
                        // API URL settings
                        Divider()
                            .padding(.vertical, 4)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API URL")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            TextField("Custom API URL (leave empty for default)", text: $state.customApiUrl)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                            
                            HStack(spacing: 8) {
                                Text("Default:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(TranslatorState.defaultApiUrl)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            
                            if !state.customApiUrl.isEmpty {
                                Button("Reset to Default") {
                                    state.customApiUrl = ""
                                }
                                .font(.caption)
                            }
                        }
                    }
                }
                
                // Interaction Mode
                settingsSection("Interaction Mode") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $state.hideOnHover) {
                            Text("Auto-hide on hover")
                        }
                        
                        HStack(spacing: 12) {
                            Image(systemName: state.hideOnHover ? "eye.slash" : "hand.tap")
                                .font(.title2)
                                .foregroundStyle(state.hideOnHover ? .orange : .blue)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(state.hideOnHover ? "Hover Mode" : "Click Mode")
                                    .fontWeight(.medium)
                                Text(state.hideOnHover 
                                     ? "Move mouse over overlay → it disappears" 
                                     : "Click overlay → menu appears (copy, hide, ignore)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
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
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Font Size")
                                    .frame(width: 100, alignment: .leading)
                                Slider(value: $state.fontSize, in: 12...24, step: 1)
                                Text("\(Int(state.fontSize))pt")
                                    .frame(width: 40)
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            // Preview
                            Text("Preview: Translated text")
                                .font(.system(size: state.fontSize))
                                .padding(8)
                                .background(Color.black.opacity(0.85))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Opacity")
                                    .frame(width: 100, alignment: .leading)
                                Slider(value: $state.overlayOpacity, in: 0.7...1.0, step: 0.05)
                                Text("\(Int(state.overlayOpacity * 100))%")
                                    .frame(width: 40)
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            // Preview
                            Text("Preview: Overlay opacity")
                                .font(.system(size: 14))
                                .padding(8)
                                .background(Color.black.opacity(state.overlayOpacity))
                                .foregroundColor(.white)
                                .cornerRadius(6)
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

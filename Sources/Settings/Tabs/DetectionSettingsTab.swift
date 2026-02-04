import SwiftUI

struct DetectionSettingsTab: View {
    @ObservedObject var state: TranslatorState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: Detection Engine Selection
                settingsSection("Detection Engine") {
                    VStack(alignment: .leading, spacing: 16) {
                        // Mode selection cards
                        HStack(spacing: 12) {
                            DetectionModeCard(
                                title: "Apple Vision",
                                subtitle: "Fast on-device OCR",
                                icon: "text.viewfinder",
                                color: .blue,
                                isSelected: !state.adeEnabled
                            ) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    state.adeEnabled = false
                                }
                            }
                            
                            DetectionModeCard(
                                title: "AI Vision",
                                subtitle: "LLM-powered extraction (ADE)",
                                icon: "brain.head.profile",
                                color: .purple,
                                isSelected: state.adeEnabled
                            ) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    state.adeEnabled = true
                                }
                            }
                        }
                        
                        // Description of selected mode
                        VStack(alignment: .leading, spacing: 8) {
                            Text(detectionModeDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            if state.adeEnabled {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "sparkles")
                                            .foregroundStyle(.purple)
                                            .font(.caption)
                                        Text("Better for manga, comics, and complex layouts")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .foregroundStyle(.blue)
                                            .font(.caption)
                                        Text("Falls back to OCR if AI Vision fails")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(Color.purple.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .cornerRadius(8)
                    }
                }
                
                // MARK: Engine-Specific Settings
                if state.adeEnabled {
                    ADESettingsSection(state: state)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    OCRSettingsSection(state: state)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // MARK: Shared Performance Settings
                settingsSection("Performance & Grouping") {
                    VStack(alignment: .leading, spacing: 16) {
                        // Accurate OCR (only affects OCR, not ADE)
                        Toggle(isOn: $state.ocrAccurate) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text("Accurate OCR")
                                    if state.adeEnabled {
                                        Text("(fallback)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Text(state.ocrAccurate 
                                     ? "Better recognition, slightly slower" 
                                     : "Faster, may miss some text")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .disabled(state.adeEnabled)
                        .opacity(state.adeEnabled ? 0.6 : 1)
                        
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
                        
                        // Scroll Detection
                        Toggle(isOn: $state.scrollDetectionEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Scroll Detection")
                                Text(state.scrollDetectionEnabled 
                                     ? "Pauses translation while scrolling" 
                                     : "Translates during scrolling (more API calls)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        
                        if state.scrollDetectionEnabled {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Scroll Cooldown")
                                    Spacer()
                                    Text("\(Int(state.scrollCooldown * 1000))ms")
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                Slider(value: $state.scrollCooldown, in: 0.2...1.0, step: 0.1)
                                Text("Wait this long after scrolling stops before translating.")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.leading, 20)
                        }
                    }
                }
                
                // MARK: Advanced Grouping (collapsible)
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 16) {
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
                    .padding(.top, 12)
                } label: {
                    Text("Advanced Grouping Options")
                        .font(.subheadline)
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
    
    private var detectionModeDescription: String {
        if state.adeEnabled {
            return "AI Vision uses Large Language Models to intelligently extract and structure text from images. It excels at complex layouts like manga and comics, understanding reading order and text types."
        } else {
            return "Apple Vision provides fast, on-device optical character recognition using Apple's native OCR engine. Best for standard text layouts and when speed is prioritized over complex layout understanding."
        }
    }
    
    private func groupingLabel(_ value: Double) -> String {
        if value <= 0.5 { return "Minimal" }
        if value <= 0.75 { return "Light" }
        if value <= 1.25 { return "Normal" }
        if value <= 1.75 { return "Strong" }
        return "Maximum"
    }
}

// MARK: - Detection Mode Card

struct DetectionModeCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    private var isADECard: Bool {
        title == "AI Vision"
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundStyle(isSelected ? color : .secondary)
                    
                    // Subtle ADE badge for AI Vision card
                    if isADECard && isSelected {
                        Text("ADE")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(color.opacity(0.15))
                            .clipShape(Capsule())
                            .offset(x: 12, y: -8)
                    }
                }
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(.subheadline, weight: .medium))
                    
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? color.opacity(0.1) : Color(nsColor: .windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? color : Color(nsColor: .separatorColor), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - OCR Settings Section

struct OCRSettingsSection: View {
    @ObservedObject var state: TranslatorState
    
    var body: some View {
        EmptyView()
        // OCR uses mostly shared settings
        // Future: Add OCR-specific settings here (language hints, etc.)
    }
}

// MARK: - ADE Settings Section

struct ADESettingsSection: View {
    @ObservedObject var state: TranslatorState
    @State private var isTestingConnection = false
    @State private var connectionTestResult: ConnectionTestResult?
    
    enum ConnectionTestResult {
        case success(String)
        case failure(String)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Provider Selection Header
            HStack(spacing: 12) {
                Image(systemName: state.adeDetectedProvider.icon)
                    .font(.title2)
                    .foregroundStyle(providerColor(state.adeDetectedProvider))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Provider")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(state.adeDetectedProvider.displayName)
                        .font(.headline)
                }
                
                Spacer()
                
                // Test Connection Button
                Button(action: testConnection) {
                    HStack(spacing: 6) {
                        if isTestingConnection {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: "bolt.horizontal.circle")
                        }
                        Text(isTestingConnection ? "Testing..." : "Test")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isTestingConnection || state.adeApiUrl.isEmpty)
                
                // Connection status indicator
                if let result = connectionTestResult {
                    switch result {
                    case .success:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .failure:
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            
            // Connection test result
            if let result = connectionTestResult {
                switch result {
                case .success(let message):
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(message)
                            .font(.caption)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                case .failure(let error):
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            
            // API Configuration
            settingsSubsection("API Configuration") {
                VStack(alignment: .leading, spacing: 16) {
                    // API URL
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API URL")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextField("https://api.example.com/v1/chat/completions", text: $state.adeApiUrl)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        
                        // Quick provider presets
                        HStack(spacing: 8) {
                            Text("Quick Setup:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Button("Local (Ollama)") {
                                state.adeApiUrl = "http://localhost:11434/v1/chat/completions"
                                state.adeModel = "qwen3-vl:8b"
                                connectionTestResult = nil
                            }
                            .font(.caption2)
                            .buttonStyle(.bordered)
                            
                            Button("Gemini") {
                                state.adeApiUrl = "https://generativelanguage.googleapis.com/v1beta"
                                state.adeModel = "gemini-2.5-flash"
                                connectionTestResult = nil
                            }
                            .font(.caption2)
                            .buttonStyle(.bordered)
                            .tint(.blue)
                            
                            Button("Claude") {
                                state.adeApiUrl = "https://api.anthropic.com/v1/messages"
                                state.adeModel = "claude-3-haiku-20240307"
                                connectionTestResult = nil
                            }
                            .font(.caption2)
                            .buttonStyle(.bordered)
                            .tint(.orange)
                            
                            Button("OpenAI") {
                                state.adeApiUrl = "https://api.openai.com/v1/chat/completions"
                                state.adeModel = "gpt-4o-mini"
                                connectionTestResult = nil
                            }
                            .font(.caption2)
                            .buttonStyle(.bordered)
                            .tint(.green)
                        }
                    }
                    
                    Divider()
                    
                    // API Key
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        SecureField("Enter API key (if required)", text: $state.adeApiKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        
                        Text(apiKeyHint)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    
                    Divider()
                    
                    // Model
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Model")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        
                        TextField("Model name", text: $state.adeModel)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        
                        // Model presets
                        modelPresetsView
                    }
                    
                    Divider()
                    
                    // Timeout
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Timeout")
                            Spacer()
                            Text("\(Int(state.adeTimeout))s")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $state.adeTimeout, in: 10...120, step: 5)
                        Text("Max time for ADE extraction. Increase for large images.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            
            // Processing Options
            settingsSubsection("Processing Options") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $state.adeMergeFragments) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Merge Fragments")
                            Text("Combine broken text lines into coherent sentences")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    Toggle(isOn: $state.adeCorrectOCRErrors) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Correct OCR Errors")
                            Text("Fix common OCR mistakes (0 vs O, rn vs m)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    Toggle(isOn: $state.adeClassifyTextType) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Classify Text Type")
                            Text("Distinguish speech, narration, sound effects, etc.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    Toggle(isOn: $state.adePreserveReadingOrder) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Preserve Reading Order")
                            Text("Maintain correct manga/comic reading sequence")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    Divider()
                    
                    Toggle(isOn: $state.adeEnableCaching) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable Caching")
                            Text("Remember extraction results to avoid duplicate processing")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func settingsSubsection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            content()
                .padding()
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(8)
        }
    }
    
    private var apiKeyHint: String {
        switch state.adeDetectedProvider {
        case .local:
            return "Not required for local servers (Ollama, etc.)"
        case .gemini:
            return "Required: Google AI Studio API key (AIza...)"
        case .anthropic:
            return "Required: Anthropic API key (sk-ant...)"
        case .openAI:
            return "Required: OpenAI API key (sk-...)"
        case .other:
            return "API key if required by your provider"
        }
    }
    
    private var modelPresetsView: some View {
        FlowLayout(spacing: 8) {
            Text("Suggestions:")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ForEach(modelPresets, id: \.self) { model in
                Button(model) {
                    state.adeModel = model
                }
                .font(.caption2)
                .buttonStyle(.bordered)
                .tint(providerTint)
            }
        }
    }
    
    private var modelPresets: [String] {
        switch state.adeDetectedProvider {
        case .local, .other:
            return ["qwen3-vl:8b", "qwen2-vl:7b", "llava:7b", "minicpm-v:8b"]
        case .gemini:
            return ["gemini-2.5-flash", "gemini-2.5-pro", "gemini-2.0-flash-lite"]
        case .anthropic:
            return ["claude-3-haiku-20240307", "claude-3-sonnet-20240229", "claude-3-opus-20240229"]
        case .openAI:
            return ["gpt-4o-mini", "gpt-4o", "gpt-4-turbo"]
        }
    }
    
    private var providerTint: Color {
        switch state.adeDetectedProvider {
        case .local: return .gray
        case .gemini: return .blue
        case .anthropic: return .orange
        case .openAI: return .green
        case .other: return .purple
        }
    }
    
    private func providerColor(_ provider: ADEDetectedProvider) -> Color {
        switch provider {
        case .local: return .gray
        case .gemini: return .blue
        case .anthropic: return .orange
        case .openAI: return .green
        case .other: return .purple
        }
    }
    
    private func testConnection() {
        isTestingConnection = true
        connectionTestResult = nil
        
        Task {
            // Simple validation - check if URL is reachable
            // In a real implementation, this would make a lightweight API call
            do {
                guard let url = URL(string: state.adeApiUrl) else {
                    await MainActor.run {
                        connectionTestResult = .failure("Invalid URL format")
                        isTestingConnection = false
                    }
                    return
                }
                
                // Check if it's localhost and might be Ollama
                let isLocalhost = url.host?.contains("localhost") == true || 
                                  url.host?.contains("127.0.0.1") == true
                
                if isLocalhost {
                    // Try to connect to Ollama tags endpoint as a simple check
                    var testUrl = url
                    if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                        var newComponents = components
                        newComponents.path = "/api/tags"
                        newComponents.query = nil
                        if let newUrl = newComponents.url {
                            testUrl = newUrl
                        }
                    }
                    
                    var request = URLRequest(url: testUrl)
                    request.timeoutInterval = 5
                    
                    let (_, response) = try await URLSession.shared.data(for: request)
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode == 200 {
                            await MainActor.run {
                                connectionTestResult = .success("Connected to Ollama successfully")
                                isTestingConnection = false
                            }
                        } else {
                            await MainActor.run {
                                connectionTestResult = .failure("Server returned HTTP \(httpResponse.statusCode)")
                                isTestingConnection = false
                            }
                        }
                    }
                } else {
                    // For cloud providers, just validate URL format for now
                    // A full implementation would make an actual API call
                    await MainActor.run {
                        connectionTestResult = .success("URL format looks valid")
                        isTestingConnection = false
                    }
                }
            } catch {
                await MainActor.run {
                    if (error as? URLError)?.code == .cannotConnectToHost {
                        connectionTestResult = .failure("Cannot connect to server. Is it running?")
                    } else {
                        connectionTestResult = .failure(error.localizedDescription)
                    }
                    isTestingConnection = false
                }
            }
        }
    }
}

import SwiftUI

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
                                // Compatibility note
                                HStack(spacing: 6) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundStyle(.blue)
                                        .font(.caption)
                                    Text("Works with LibreTranslate & LTEngine servers")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                
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
                            if #available(macOS 26.0, *) {
                                AppleTranslationSettingsWrapper(state: state)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            } else {
                                Text("Apple Translation requires macOS 26.0+")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                        case .google:
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Custom API URL (optional)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                TextField("Default: translate.googleapis.com", text: $state.customApiUrl)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                    .onChange(of: state.customApiUrl) { _, newValue in
                                        // Clear cached languages when URL changes
                                        state.googleLanguages = []
                                        state.googleLanguagesError = nil
                                        // Fetch languages if custom URL is set
                                        if !newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                                            state.fetchGoogleLanguages(force: true)
                                        }
                                    }
                                
                                if state.customApiUrl.isEmpty {
                                    Text("Using default: \(TranslationService.defaultApiUrl)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                
                                Text("API Key (optional)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                SecureField("Leave empty if not required", text: $state.googleApiKey)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            
                        case .llm:
                            VStack(alignment: .leading, spacing: 8) {
                                // Provider detection indicator
                                HStack(spacing: 6) {
                                    Image(systemName: providerIcon(state.detectedLLMProvider))
                                        .foregroundStyle(providerColor(state.detectedLLMProvider))
                                        .font(.caption)
                                    Text("Detected: \(state.detectedLLMProvider.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(providerColor(state.detectedLLMProvider).opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                
                                Text("API URL")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                TextField("https://api.openai.com/v1/chat/completions", text: $state.llmApiUrl)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                
                                // Quick URL buttons
                                HStack(spacing: 8) {
                                    Text("Presets:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Button("OpenAI") {
                                        state.llmApiUrl = "https://api.openai.com/v1/chat/completions"
                                        state.llmModel = "gpt-4.1-mini"
                                    }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                    .tint(.green)
                                    
                                    Button("Claude") {
                                        state.llmApiUrl = "https://api.anthropic.com/v1/messages"
                                        state.llmModel = "claude-haiku-4-5"
                                    }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                    .tint(.orange)
                                    
                                    Button("Gemini") {
                                        state.llmApiUrl = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
                                        state.llmModel = "gemini-2.5-flash"
                                    }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                    .tint(.blue)
                                    
                                    Button("Ollama") {
                                        state.llmApiUrl = "http://localhost:11434/v1/chat/completions"
                                        state.llmModel = "llama3.3"
                                    }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                    .tint(.gray)
                                }
                                
                                Text("\(state.detectedLLMProvider.rawValue) API Key")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                SecureField(apiKeyPlaceholder(for: state.detectedLLMProvider), text: Binding(
                                    get: { state.currentLlmApiKey },
                                    set: { state.currentLlmApiKey = $0 }
                                ))
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                
                                Text("Model")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                TextField(state.detectedLLMProvider.defaultModel, text: $state.llmModel)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                
                                // Model suggestions based on provider
                                HStack(spacing: 8) {
                                    Text("Popular:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    ForEach(modelSuggestions(for: state.detectedLLMProvider), id: \.self) { model in
                                        Button(model) {
                                            state.llmModel = model
                                        }
                                        .font(.caption2)
                                        .buttonStyle(.bordered)
                                        .tint(.gray)
                                    }
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                
                // Languages
                settingsSection("Languages") {
                    VStack(alignment: .leading, spacing: 8) {
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
                        
                        // LTEngine connection error indicator
                        if state.translationService == .ltEngine {
                            if state.isLoadingLTEngineLanguages {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                    Text("Loading languages from server...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else if let error = state.ltEngineLanguagesError {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button("Retry") {
                                        state.retryLTEngineLanguageFetch()
                                    }
                                    .font(.caption)
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.blue)
                                }
                            } else if !state.ltEngineLanguages.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                    Text("\(state.ltEngineLanguages.count) languages from server")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        // Google Translate custom API indicator
                        if state.translationService == .google && state.hasCustomGoogleApi {
                            if state.isLoadingGoogleLanguages {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                    Text("Loading languages from server...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else if let error = state.googleLanguagesError {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button("Retry") {
                                        state.retryGoogleLanguageFetch()
                                    }
                                    .font(.caption)
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.blue)
                                }
                            } else if !state.googleLanguages.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                    Text("\(state.googleLanguages.count) languages from server")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        // Serbian script option - show when target is Serbian
                        if state.targetLanguage.hasPrefix("sr") {
                            Divider()
                                .padding(.vertical, 4)
                            
                            Toggle(isOn: $state.forceSerbianLatin) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Force Latin script")
                                        .font(.callout)
                                    Text("Convert Cyrillic → Latin after translation")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .toggleStyle(.switch)
                        }
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
    
    private func providerIcon(_ provider: LLMProvider) -> String {
        switch provider {
        case .openai: return "sparkles"
        case .anthropic: return "brain.head.profile"
        case .gemini: return "diamond"
        case .ollama: return "desktopcomputer"
        case .other: return "server.rack"
        }
    }
    
    private func providerColor(_ provider: LLMProvider) -> Color {
        switch provider {
        case .openai: return .green
        case .anthropic: return .orange
        case .gemini: return .blue
        case .ollama: return .gray
        case .other: return .purple
        }
    }
    
    private func modelSuggestions(for provider: LLMProvider) -> [String] {
        switch provider {
        case .openai:
            // Latest: GPT-5.2 (Dec 2025), GPT-5 (Aug 2025), GPT-4.1 (Apr 2025)
            return ["gpt-4.1-mini", "gpt-4.1-nano", "gpt-5", "gpt-5.2"]
        case .anthropic:
            // Latest: Opus 4.5 (Nov 2025), Sonnet 4.5 (Sep 2025), Haiku 4.5 (Oct 2025)
            return ["claude-haiku-4-5", "claude-sonnet-4-5", "claude-opus-4-5"]
        case .gemini:
            // Latest: Gemini 2.5 Pro/Flash (Jun 2025), Flash-Lite (Jul 2025)
            return ["gemini-2.5-flash-lite", "gemini-2.5-flash", "gemini-2.5-pro"]
        case .ollama:
            return ["llama3.3", "qwen3", "gemma3"]
        case .other:
            return ["gpt-4.1-mini", "gpt-5"]
        }
    }
    
    private func apiKeyPlaceholder(for provider: LLMProvider) -> String {
        switch provider {
        case .openai: return "sk-... (required)"
        case .anthropic: return "sk-ant-... (required)"
        case .gemini: return "AIza... (required)"
        case .ollama: return "Usually not needed for local"
        case .other: return "API key if required"
        }
    }
    
}

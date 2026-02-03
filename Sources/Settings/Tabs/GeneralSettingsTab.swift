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
                                    .onChange(of: state.libreTranslateUrl) { _, _ in
                                        state.validateLibreTranslateUrl()
                                    }
                                
                                // URL validation feedback
                                URLValidationView(validation: state.libreTranslateUrlValidation)
                                
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
                                        // Validate URL
                                        state.validateCustomApiUrl()
                                        // Clear cached languages when URL changes
                                        state.googleLanguages = []
                                        state.googleLanguagesError = nil
                                        // Fetch languages if custom URL is set and valid
                                        if !newValue.trimmingCharacters(in: .whitespaces).isEmpty && state.isCustomApiUrlValid {
                                            state.fetchGoogleLanguages(force: true)
                                        }
                                    }
                                
                                // URL validation feedback
                                URLValidationView(validation: state.customApiUrlValidation)
                                
                                if state.customApiUrl.isEmpty {
                                    Text("Using default: \(TranslationService.defaultApiUrl)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                
                                // V3 API - requires OAuth2 access token
                                if state.isGoogleCloudV3Api {
                                    HStack(spacing: 6) {
                                        Image(systemName: "info.circle.fill")
                                            .foregroundStyle(.blue)
                                            .font(.caption)
                                        Text("V3 API requires OAuth2 Access Token from: gcloud auth print-access-token")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    
                                    Text("Access Token")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    SecureField("Paste token from: gcloud auth print-access-token", text: $state.googleAccessToken)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(.body, design: .monospaced))
                                    
                                    Text("Tokens expire after ~1 hour. Regenerate with: gcloud auth print-access-token")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                
                                // V2 API or default - uses API key
                                if state.isGoogleCloudV2Api || !state.isGoogleCloudV3Api {
                                    Text(state.isGoogleCloudV2Api ? "API Key (required)" : "API Key (optional)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    SecureField(state.isGoogleCloudV2Api ? "Your Google Cloud API key (AIza...)" : "Leave empty for free API", text: $state.googleApiKey)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(.body, design: .monospaced))
                                }
                                
                                // Quick preset buttons for Google APIs
                                HStack(spacing: 8) {
                                    Text("Presets:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Button("Free") {
                                        state.customApiUrl = ""
                                    }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                    .tint(.green)
                                    
                                    Button("V2 (API key)") {
                                        state.customApiUrl = "https://translation.googleapis.com/language/translate/v2"
                                    }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                    .tint(.blue)
                                    
                                    Button("V3 (OAuth)") {
                                        // Set a template URL - user must replace with their project ID
                                        state.customApiUrl = "https://translate.googleapis.com/v3/projects/your-project-id:translateText"
                                    }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                    .tint(.orange)
                                    .help("Replace 'your-project-id' with your Google Cloud project ID")
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            
                        case .llm:
                            VStack(alignment: .leading, spacing: 8) {
                                // Compatibility note (only for local/other providers)
                                if state.detectedLLMProvider == .local || state.detectedLLMProvider == .other {
                                    HStack(spacing: 6) {
                                        Image(systemName: "info.circle.fill")
                                            .foregroundStyle(.blue)
                                            .font(.caption)
                                        Text("Requires OpenAI-compatible API (Ollama, vLLM, LM Studio, etc.)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                
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
                                    .onChange(of: state.llmApiUrl) { _, _ in
                                        state.validateLLMApiUrl()
                                    }
                                
                                // URL validation feedback
                                URLValidationView(validation: state.llmApiUrlValidation)
                                
                                // Quick URL buttons
                                HStack(spacing: 8) {
                                    Text("Providers:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Menu {
                                        Button("Chat Completions") {
                                            state.llmApiUrl = "https://api.openai.com/v1/chat/completions"
                                            state.llmModel = "gpt-4.1-mini"
                                        }
                                        Button("Responses API") {
                                            state.llmApiUrl = "https://api.openai.com/v1/responses"
                                            state.llmModel = "gpt-4.1-mini"
                                        }
                                    } label: {
                                        Text("OpenAI")
                                    }
                                    .font(.caption)
                                    .menuStyle(.borderlessButton)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(6)
                                    
                                    Button("Claude") {
                                        state.llmApiUrl = "https://api.anthropic.com/v1/messages"
                                        state.llmModel = "claude-haiku-4-5"
                                    }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                    .tint(.orange)
                                    
                                    Button("Gemini") {
                                        state.llmApiUrl = "https://generativelanguage.googleapis.com/v1beta"
                                        state.llmModel = "gemini-2.5-flash"
                                    }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                    .tint(.blue)
                                    
                                    Button("Local") {
                                        state.llmApiUrl = "http://localhost:11434/v1/chat/completions"
                                        state.llmModel = "llama4"
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
                                
                                Divider()
                                    .padding(.vertical, 4)
                                
                                // System prompt
                                HStack {
                                    Text("System Prompt")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    if !state.llmSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Button("Reset to Default") {
                                            state.llmSystemPrompt = ""
                                        }
                                        .font(.caption2)
                                        .buttonStyle(.plain)
                                        .foregroundStyle(.blue)
                                    }
                                }
                                
                                TextEditor(text: $state.llmSystemPrompt)
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(minHeight: 80, maxHeight: 120)
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                                    .background(Color(nsColor: .textBackgroundColor))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                                    )
                                
                                Text("Placeholders: {source}, {target} for languages. {confidence} for confidence mode JSON structure. Leave empty for default.")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                
                                // Warning if placeholders are missing
                                if state.llmSystemPromptMissingPlaceholders {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.orange)
                                            .font(.caption)
                                        Text("Missing {source} or {target} placeholder")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(Color.orange.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    
                                    // Auto-append toggle
                                    Toggle(isOn: $state.llmAutoAppendLanguages) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Auto-append language context")
                                                .font(.caption)
                                            Text("Automatically add \"\(TranslatorState.languageContextSuffix.trimmingCharacters(in: .whitespaces))\" to the prompt")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .toggleStyle(.switch)
                                    .controlSize(.small)
                                }
                                
                                Divider()
                                    .padding(.vertical, 4)
                                
                                // Confidence mode
                                Toggle(isOn: $state.llmConfidenceEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Confidence Mode")
                                            .font(.caption)
                                        Text("LLM rates translation quality. Retries if below threshold.")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                
                                if state.llmConfidenceEnabled {
                                    VStack(alignment: .leading, spacing: 8) {
                                        // Confidence threshold
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text("Confidence Threshold")
                                                    .font(.caption)
                                                Spacer()
                                                Text("\(state.llmConfidenceThreshold)%")
                                                    .font(.system(.caption, design: .monospaced))
                                                    .foregroundStyle(.secondary)
                                            }
                                            Slider(value: Binding(
                                                get: { Double(state.llmConfidenceThreshold) },
                                                set: { state.llmConfidenceThreshold = Int($0) }
                                            ), in: 30...95, step: 5)
                                            Text("Accept translation if confidence ≥ threshold")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                        
                                        // Max retries
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text("Max Retries")
                                                    .font(.caption)
                                                Spacer()
                                                Text("\(state.llmMaxRetries)")
                                                    .font(.system(.caption, design: .monospaced))
                                                    .foregroundStyle(.secondary)
                                            }
                                            Slider(value: Binding(
                                                get: { Double(state.llmMaxRetries) },
                                                set: { state.llmMaxRetries = Int($0) }
                                            ), in: 1...5, step: 1)
                                            Text("Retry up to N times if below threshold, keep best result")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                        
                                        // Info about cost
                                        HStack(spacing: 6) {
                                            Image(systemName: "info.circle.fill")
                                                .foregroundStyle(.blue)
                                                .font(.caption)
                                            Text("Increases API calls by up to \(state.llmMaxRetries)x. Filters garbage translations.")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        
                                        // Note about JSON structure for custom prompt
                                        if !state.llmSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            let hasConfidencePlaceholder = state.llmSystemPrompt.contains("{confidence}")
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack(spacing: 6) {
                                                    Image(systemName: hasConfidencePlaceholder ? "checkmark.circle.fill" : "doc.append.fill")
                                                        .foregroundStyle(hasConfidencePlaceholder ? .green : .purple)
                                                        .font(.caption)
                                                    Text(hasConfidencePlaceholder 
                                                         ? "{confidence} will be replaced with JSON structure:" 
                                                         : "JSON structure will be appended (use {confidence} to place it):")
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                }
                                                Text("""
                                                    {"translation": "...", "confidence": 85}
                                                    """)
                                                    .font(.system(.caption2, design: .monospaced))
                                                    .foregroundStyle(.tertiary)
                                                    .padding(6)
                                                    .background(Color(nsColor: .textBackgroundColor))
                                                    .cornerRadius(4)
                                            }
                                            .padding(.vertical, 4)
                                            .padding(.horizontal, 8)
                                            .background((hasConfidencePlaceholder ? Color.green : Color.purple).opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                        }
                                    }
                                    .padding(.leading, 20)
                                }
                                
                                // Show effective prompt when empty
                                if state.llmSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Default prompt:")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                        Text(TranslatorState.defaultLLMSystemPrompt)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                            .italic()
                                    }
                                    .padding(8)
                                    .background(Color(nsColor: .windowBackgroundColor))
                                    .cornerRadius(6)
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
        case .local: return "desktopcomputer"
        case .other: return "server.rack"
        }
    }
    
    private func providerColor(_ provider: LLMProvider) -> Color {
        switch provider {
        case .openai: return .green
        case .anthropic: return .orange
        case .gemini: return .blue
        case .local: return .gray
        case .other: return .purple
        }
    }
    
    private func modelSuggestions(for provider: LLMProvider) -> [String] {
        switch provider {
        case .openai:
            // Latest: GPT-5 (Aug 2025), GPT-4.1 (Apr 2025), o3/o4 reasoning models
            return ["gpt-4.1-mini", "gpt-5-mini", "gpt-5", "o3-mini", "o4-mini"]
        case .anthropic:
            // Latest: Opus 4.5 (Nov 2025), Sonnet 4.5 (Sep 2025), Haiku 4.5 (Oct 2025)
            return ["claude-haiku-4-5", "claude-sonnet-4-5", "claude-opus-4-5"]
        case .gemini:
            // Latest: Gemini 3 (Dec 2025), Gemini 2.5 (Jun 2025)
            return ["gemini-2.5-flash-lite", "gemini-2.5-flash", "gemini-3-flash", "gemini-3-pro"]
        case .local:
            // Popular local models (works with Ollama, LM Studio, vLLM, etc.)
            return ["llama4", "qwen3", "deepseek-r1", "mistral", "gemma3", "phi4"]
        case .other:
            // Generic suggestions for self-hosted OpenAI-compatible servers
            return ["llama4", "qwen3", "deepseek-r1", "mistral", "gemma3", "phi4", "custom-model"]
        }
    }
    
    private func apiKeyPlaceholder(for provider: LLMProvider) -> String {
        switch provider {
        case .openai: return "sk-... (required)"
        case .anthropic: return "sk-ant-... (required)"
        case .gemini: return "AIza... (required)"
        case .local: return "Usually not needed for local"
        case .other: return "API key if required"
        }
    }
    
}

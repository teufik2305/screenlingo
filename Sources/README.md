# Sources

## Structure

```
Sources/
├── Engine/                 # Core translation engine
│   ├── RealTimeTranslationEngine.swift  # Main orchestrator
│   ├── TranslationCache.swift           # LRU cache with persistence
│   ├── OCRProcessor.swift               # Text recognition & grouping
│   ├── WindowCaptureService.swift       # Screen capture
│   ├── ScrollMonitor.swift              # Scroll event detection
│   └── ADE/                             # Agentic Document Extraction
│       ├── ADEAgent.swift               # Main ADE orchestrator
│       ├── ADEModels.swift              # Data models & provider detection
│       └── Providers/                   # Gemini, Anthropic, OpenAI, Local
│           ├── ADEGeminiProvider.swift
│           ├── ADEAnthropicProvider.swift
│           ├── ADECustomProvider.swift
│           └── ADELocalProvider.swift
│
├── Translation/            # Translation providers
│   ├── TranslationService.swift         # Provider router, confidence retry logic
│   ├── TranslationProvider.swift        # Provider protocol
│   ├── TranslationResult.swift          # Result with confidence score
│   └── Providers/                       # OpenAI, Anthropic, Gemini, Google, Apple, LibreTranslate, Local (OpenAI-compatible)
│
├── State/                  # Application state
│   ├── TranslatorState.swift            # Main state (ObservableObject)
│   ├── Managers/                        # ExcludedApps, IgnorePatterns
│   └── Models/                          # Enums, data types
│
├── Settings/               # Settings UI
│   ├── SettingsView.swift               # Tab container
│   ├── Tabs/                            # General, Appearance, Filters, Advanced, About
│   └── Components/                      # Reusable UI elements
│
├── OverlayTranslatorApp.swift           # App entry point
├── RealTimeOverlayView.swift            # Overlay rendering
├── MenuBarView.swift                    # Menu bar UI
└── Logger.swift                         # Logging system
```

## Agentic Document Extraction (ADE)

ADE uses vision-capable LLMs to intelligently extract text from images, providing better accuracy than traditional OCR for complex layouts like manga/comics.

### How it works
1. Captures screen image
2. Sends to vision model (Gemini, Claude, GPT-4V, or local models like Qwen3-VL)
3. Receives structured text blocks with bounding boxes and reading order
4. Falls back to OCR if ADE fails

### ADE Providers
- **Gemini** - `https://generativelanguage.googleapis.com/v1beta`
- **Anthropic** - `https://api.anthropic.com/v1/messages`
- **OpenAI** - `https://api.openai.com/v1/chat/completions`
- **Local** - `http://localhost:11434/v1/chat/completions` (Ollama, vLLM, etc.)

Provider is auto-detected from the URL pattern.

### Adding ADE Providers

1. Create `Engine/ADE/Providers/YourADEProvider.swift`
2. Implement `ADEProviderInterface`:
   ```swift
   actor YourProvider: ADEProviderInterface {
       func extract(request: ADERequest) async throws -> ADEResponse
       func checkAvailability() async throws -> Bool
   }
   ```
3. Add routing in `ADEAgent.createADEProvider()`

### New Translation Provider

1. Create `Translation/Providers/YourProvider.swift`
2. Implement `TranslationProvider` protocol:
   ```swift
   actor YourProvider: TranslationProvider {
       func translate(text: String, from: String, to: String, timeout: TimeInterval) async throws -> String
   }
   ```
3. Add routing in `TranslationService.translate()`

### New Setting

1. Add `@AppStorage` property to `TranslatorState.swift`
2. Add UI control in appropriate `Settings/Tabs/*.swift`
3. Add `didSet` logging if needed

### Overlay Display Modes

Two rendering modes in `RealTimeOverlayView.swift`:
- **Box mode** (`drawBoxText`) - Rounded boxes with customizable background, padding, colors, border
- **Outline mode** (`drawOutlinedText`) - Text with stroke outline (subtitle-style)

Settings in `TranslatorState`: `overlayDisplayMode`, `boxPaddingH/V`, `boxCornerRadius`, `boxBackgroundColorHex`, etc.

### Confidence Mode (Beta)

LLM providers can return confidence scores (0-100) with translations. When enabled:
1. LLM returns JSON: `{"translation": "...", "confidence": 85}`
2. If confidence < threshold, retry up to N times
3. Keep best result across all attempts

**Custom prompts** work in confidence mode with these placeholders:
- `{source}` / `{target}` - Language names (auto-appended if missing)
- `{confidence}` - JSON structure placement (appended at end if not specified)

Settings: `llmConfidenceEnabled`, `llmConfidenceThreshold`, `llmMaxRetries`

Implemented in `TranslationService.translateWithConfidenceRetry()` and provider `translateWithConfidence()` methods.

### New Manager

1. Create `State/Managers/YourManager.swift` as `ObservableObject`
2. Add instance to `TranslatorState`
3. Forward `objectWillChange` in `TranslatorState.init()`

## Logging

Categories: `Engine`, `OCR`, `Translation`, `API`, `Cache`, `UI`, `App`, `Settings`, `State`

```swift
log.info("Message", category: .engine)
log.debug("Message", category: .api)
```

## Build

```bash
swift build           # Debug
./build-app.sh        # Release app bundle
```

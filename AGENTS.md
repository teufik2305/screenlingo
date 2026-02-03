# ScreenLingo - Agent Documentation

This file provides guidance for AI coding agents working on the ScreenLingo codebase.

## Project Overview

**ScreenLingo** is a real-time screen translation overlay application for macOS. It captures the screen of the frontmost window, detects text using OCR (Apple Vision framework), and displays translated text directly over the original content.

### Key Features

- Real-time OCR text detection using Apple Vision framework
- Multiple translation backends: Apple Translation, LibreTranslate, Google Translate, LLM (OpenAI/Claude/Gemini/Ollama)
- Multi-monitor support - overlay follows windows across displays
- Two display modes: Box (customizable background) or Outline (subtitle-style stroke)
- Confidence Mode (Beta) - LLM rates translation quality and retries low-confidence results
- Scroll Detection - pauses translation while scrolling, clears stale overlays
- Smart caching with optional persistence
- Configurable text grouping for manga/comics/subtitles
- Global hotkey toggle (Cmd+Ctrl+T by default)
- Click or hover interaction modes

### System Requirements

- macOS 14.0+ (Sonoma)
- Screen Recording permission
- Accessibility permission (for global hotkey)

## Technology Stack

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI with AppKit integration
- **Build System**: Swift Package Manager (SPM)
- **OCR**: Vision.framework
- **Translation**: Translation.framework (macOS 15+), custom providers
- **Minimum Platform**: macOS 14.0

## Project Structure

```
Sources/
├── OverlayTranslatorApp.swift      # App entry point, menu bar extra, global hotkey
├── MenuBarView.swift               # Menu bar dropdown UI
├── RealTimeOverlayView.swift       # Overlay window rendering (Box/Outline modes)
├── Logger.swift                    # Structured logging system
├── Engine/
│   ├── RealTimeTranslationEngine.swift  # Main orchestration engine
│   ├── OCRProcessor.swift               # Text detection and grouping
│   ├── WindowCaptureService.swift       # Screen capture and window detection
│   ├── TranslationCache.swift           # LRU cache with persistence
│   └── ScrollMonitor.swift              # Scroll detection
├── Translation/
│   ├── TranslationService.swift         # Provider routing
│   ├── TranslationProvider.swift        # Protocol definition
│   ├── TranslationError.swift           # Error types
│   ├── TranslationResult.swift          # Result wrapper
│   ├── Providers/                       # Individual provider implementations
│   │   ├── AnthropicProvider.swift
│   │   ├── AppleTranslationProvider.swift
│   │   ├── GeminiProvider.swift
│   │   ├── GoogleTranslateProvider.swift
│   │   ├── LibreTranslateProvider.swift
│   │   └── OpenAIProvider.swift
│   └── Utilities/
│       ├── LanguageNameMapper.swift
│       └── SerbianTransliterator.swift
├── State/
│   ├── TranslatorState.swift            # Central state management (@AppStorage)
│   ├── Models/                          # Data models
│   │   ├── InteractionMode.swift
│   │   ├── LLMProvider.swift
│   │   ├── LTEngineLanguage.swift
│   │   └── TranslationServiceType.swift
│   ├── Managers/                        # Complex state managers
│   │   ├── ExcludedAppsManager.swift
│   │   └── IgnorePatternManager.swift
│   └── Utilities/
│       ├── StaticLanguageData.swift
│       └── URLValidator.swift
└── Settings/
    ├── SettingsView.swift                # Main settings window
    ├── Components/                       # Reusable UI components
    ├── Tabs/                             # Settings tab views
    └── Layouts/                          # Custom layout helpers

Tests/
├── CacheTests/
│   └── TranslationCacheTests.swift
├── EngineTests/
│   └── WindowCaptureServiceTests.swift
├── ManagerTests/
│   ├── ExcludedAppsManagerTests.swift
│   └── IgnorePatternManagerTests.swift
└── StateTests/
    └── TranslatorStateTests.swift

Configuration Files:
├── Package.swift                    # SPM manifest
├── Info.plist                       # App bundle configuration
├── OverlayTranslator.entitlements   # Sandbox entitlements
└── build-app.sh                     # App bundle creation script
```

## Build Commands

```bash
# Build debug version
swift build

# Run directly
swift build && .build/debug/OverlayTranslator

# Run tests
swift test

# Run specific test class
swift test --filter TranslationCacheTests

# Run tests in parallel
swift test --parallel

# Clean build cache
swift package clean

# Build release app bundle
./build-app.sh

# Build and open app
./build-app.sh --open
```

## Architecture Overview

### Core Data Flow

1. **RealTimeTranslationEngine** orchestrates the translation pipeline
2. **WindowCaptureService** captures screenshots of frontmost window (~50ms intervals)
3. **OCRProcessor** uses Vision.framework to detect text regions and groups them
4. **TranslationCache** (LRU with persistence) checks for cached translations
5. **TranslationService** routes uncached text to appropriate provider
6. **RealTimeOverlayView** renders translated text over original content

### State Management

**TranslatorState** is the central `ObservableObject` that:
- Stores all user preferences using `@AppStorage` with shared UserDefaults suite (`com.screenlingo.shared`)
- Manages sub-managers: `ExcludedAppsManager` and `IgnorePatternManager`
- Forwards manager `objectWillChange` events to trigger UI updates

### Translation Provider Priority

1. **LLM** (OpenAI, Anthropic, Gemini, Ollama) - Auto-detected from API URL
2. **LibreTranslate/LTEngine** - Self-hosted translation
3. **Apple Translation** - Native macOS 15+ translation
4. **Google Translate** - Fallback for older macOS

Each provider implements `TranslationProvider` protocol:
```swift
func translate(text: String, from: String, to: String, timeout: TimeInterval) async throws -> String
```

### Key Design Patterns

- **Actor-based providers**: Translation providers are actors for thread safety
- **Task groups**: Concurrent translation with configurable limits
- **Debounce/throttle**: Content change detection and API request throttling
- **Version tracking**: Content versioning to discard stale translations
- **Multi-monitor**: Screen tracking with overlay repositioning

## Testing Guidelines

### Test Isolation (CRITICAL)

Tests MUST use isolated UserDefaults to avoid modifying user preferences:

```swift
var testStore: UserDefaults!

override func setUp() {
    super.setUp()
    testStore = UserDefaults(suiteName: "com.screenlingo.tests.mytest")!
    testStore.removePersistentDomain(forName: "com.screenlingo.tests.mytest")
    manager = MyManager(store: testStore)
}

override func tearDown() {
    testStore.removePersistentDomain(forName: "com.screenlingo.tests.mytest")
    testStore = nil
    super.tearDown()
}
```

### Test Naming Convention

Format: `test[Method]_When[Condition]_Then[Expected]`

Example:
```swift
func testAddExcludedApp_WhenAddingValidBundleId_ThenAppIsExcluded()
```

### Test Structure

Follow Given-When-Then pattern:
```swift
func testSetAndGet() {
    // Given
    let text = "Hello"
    let translation = "Bonjour"
    
    // When
    cache.set(text, translation: translation)
    
    // Then
    XCTAssertEqual(cache.get(text), translation)
}
```

## Code Style Guidelines

### General Conventions

- Use Swift's native types (`String`, `Int`, `Double`) over Foundation types
- Prefer `let` over `var`, `struct` over `class` where possible
- Use explicit `self.` only when required (closures, initializers)
- Mark classes `final` unless inheritance is intended

### Logging

Use the centralized logger with appropriate categories:
```swift
log.info("Message", category: .engine)
log.debug("Debug info", category: .ocr)
log.error("Error: \(error)", category: .translation)
```

Available categories: `.engine`, `.ocr`, `.translation`, `.api`, `.cache`, `.ui`, `.app`, `.settings`, `.state`

### Settings Implementation

New settings should use `@AppStorage` with the shared store:

```swift
@AppStorage("mySetting", store: TranslatorState.preferencesStore) 
var mySetting: Bool = true {
    didSet { 
        log.info("My setting: \(mySetting ? "enabled" : "disabled")", category: .settings) 
    }
}
```

### URL Validation (CRITICAL)

Always validate user-provided API URLs:
```swift
// In settings UI
state.validateCustomApiUrl()
state.validateLibreTranslateUrl()
state.validateLLMApiUrl()

// Before API requests
let (sanitizedUrl, validation) = URLValidator.validateAndSanitize(url)
if !validation.isUsable {
    log.error("Invalid URL", category: .translation)
    url = defaultUrl
}
```

## Security Considerations

### Permissions

The app requires two macOS permissions:
1. **Screen Recording** - For capturing window content
2. **Accessibility** - For global keyboard shortcuts

### Entitlements

The app is NOT sandboxed (`com.apple.security.app-sandbox: false`) to allow:
- Screen capture
- Window detection
- Global hotkey monitoring

Network client entitlement is enabled for translation APIs.

### Sensitive Data Handling

- API keys are stored in UserDefaults (not Keychain - by design for user convenience)
- Cache files are stored in user's Application Support directory
- No sensitive data is logged (URLs are logged, keys are not)

### URL Security

The `URLValidator` blocks:
- Documentation placeholders (`PROJECT_ID`, `YOUR_API_KEY`, etc.)
- Template markers (`${...}`, `{{...}}`, `<...>`, `[...]`)
- Placeholder keywords (`PLACEHOLDER`, `EXAMPLE`, `TODO`)

This prevents users from accidentally using example URLs from documentation.

## Adding New Features

### New Translation Provider

1. Create `Sources/Translation/Providers/YourProvider.swift`
2. Implement `TranslationProvider` protocol as an `actor`
3. Add routing logic in `TranslationService.translate()`
4. Add enum case to `TranslationServiceType`

### New Manager

1. Create `Sources/State/Managers/YourManager.swift` as `ObservableObject`
2. Accept `UserDefaults` parameter for testability
3. Add instance property to `TranslatorState`
4. Forward `objectWillChange` in `TranslatorState.init()`

### New Setting

1. Add `@AppStorage` property to `TranslatorState.swift`
2. Add UI control in relevant `Sources/Settings/Tabs/*.swift`
3. Add `didSet` observer for logging if important
4. Forward through manager if applicable

## Critical Behaviors

1. **Rate Limiting**: Engine respects `rateLimitBackoff` after errors
2. **Excluded Apps**: Overlay clears immediately when switching to excluded apps
3. **Window Changes**: Hash comparison detects content changes; switching windows forces re-translation
4. **Concurrency**: Translation requests limited by `maxConcurrentTranslations`
5. **Text Filtering**: URLs, pipe characters, fragments, and ignore patterns are filtered
6. **Hash Debouncing**: Requires 3 consecutive changes before clearing (reduces overlay flicker)

## Key File References

- `Sources/Engine/RealTimeTranslationEngine.swift:12` - Main orchestrator
- `Sources/State/TranslatorState.swift:7` - Central state and settings
- `Sources/Translation/TranslationService.swift:5` - Provider routing
- `Sources/RealTimeOverlayView.swift` - Overlay rendering
- `Sources/Engine/OCRProcessor.swift` - Text detection algorithms
- `Sources/Engine/TranslationCache.swift` - LRU cache implementation
- `Sources/Engine/WindowCaptureService.swift` - Screen capture
- `Sources/State/Utilities/URLValidator.swift` - URL validation

## License

MIT License

# ScreenLingo Development Rules

Rules for AI assistants working on ScreenLingo (OverlayTranslator) - a real-time macOS screen translation overlay.

## Project Context

- **Language**: Swift 5.9, SwiftUI
- **Platform**: macOS 14.0+ (Sonoma), Apple Translation requires macOS 15+
- **Build System**: Swift Package Manager (no CocoaPods/Carthage)
- **Architecture**: Actor-based concurrency for translation providers

## Build Commands

```bash
swift build                              # Debug build
swift build && .build/debug/OverlayTranslator  # Build and run
swift test                               # Run all tests
swift test --filter <TestClass>          # Run specific test
./build-app.sh                           # Build release app bundle
./build-app.sh --open                    # Build and open app
swift package clean                      # Clean build cache
```

## Key Entry Points

Start here when navigating the codebase:

1. `Sources/Engine/RealTimeTranslationEngine.swift` - Main orchestrator
2. `Sources/State/TranslatorState.swift` - Central state management
3. `Sources/Translation/TranslationService.swift` - Provider routing
4. `Sources/RealTimeOverlayView.swift` - Overlay rendering
5. `Sources/Engine/OCRProcessor.swift` - Text detection

## Code Patterns

### Settings (use @AppStorage with logging)

```swift
@AppStorage("mySetting", store: TranslatorState.preferencesStore) var mySetting: Bool = true {
    didSet { log.info("My setting: \(mySetting ? "enabled" : "disabled")", category: .settings) }
}
```

### Translation Provider (implement as actor)

```swift
actor MyProvider: TranslationProvider {
    let apiUrl: String
    let apiKey: String?
    nonisolated let providerName: String = "MyProvider"
    
    func translate(text: String, from: String, to: String, timeout: TimeInterval) async throws -> String {
        // Build request, make API call, parse response
    }
}
```

### Manager Integration (forward objectWillChange)

```swift
// In TranslatorState.init()
myManager.objectWillChange
    .sink { [weak self] _ in self?.objectWillChange.send() }
    .store(in: &cancellables)
```

### Logging (use categories)

```swift
log.debug("Message", category: .engine)
log.info("Message", category: .translation)
log.warning("Message", category: .api)
log.error("Message", category: .cache)
// Categories: .engine, .ocr, .translation, .api, .cache, .ui, .app, .settings, .state
```

## URL Validation (CRITICAL)

**Always validate user-provided API URLs to prevent app crashes and infinite loops.**

### In Settings UI

```swift
TextField("API URL", text: $state.customApiUrl)
    .onChange(of: state.customApiUrl) { _, _ in
        state.validateCustomApiUrl()
    }
URLValidationView(validation: state.customApiUrlValidation)
```

### In TranslationService

```swift
let (sanitizedUrl, validation) = URLValidator.validateAndSanitize(url)
if !validation.isUsable {
    log.error("Invalid URL: \(validation.message ?? "Unknown"). Using default.", category: .translation)
    url = defaultUrl
}
```

### Validation Methods

- `state.validateCustomApiUrl()` - Google API URLs
- `state.validateLibreTranslateUrl()` - LibreTranslate/LTEngine URLs
- `state.validateLLMApiUrl()` - LLM provider URLs

### Blocked Patterns

URLs containing these are rejected:
- `PROJECT_ID`, `GEN_LANG_PROJECT_ID`, `YOUR_PROJECT_ID`
- `YOUR_API_KEY`, `API_KEY_HERE`, `sk-your-api-key`
- `${...}`, `{{...}}`, `<...>`, `[...]` template markers
- `PLACEHOLDER`, `EXAMPLE`, `TODO`

## Test Guidelines

**CRITICAL**: Use isolated UserDefaults in tests!

```swift
var testStore: UserDefaults!

override func setUp() {
    super.setUp()
    testStore = UserDefaults(suiteName: "com.screenlingo.tests.mytest")!
    testStore.removePersistentDomain(forName: "com.screenlingo.tests.mytest")
}

override func tearDown() {
    testStore.removePersistentDomain(forName: "com.screenlingo.tests.mytest")
    testStore = nil
    super.tearDown()
}
```

Test naming: `test[Method]_When[Condition]_Then[Expected]`

## Adding Features

### New Translation Provider

1. Create `Sources/Translation/Providers/YourProvider.swift` as actor
2. Implement `TranslationProvider` protocol
3. Add routing in `TranslationService.translate()`
4. Add enum case to `TranslationServiceType`

### New Setting

1. Add `@AppStorage` property in `TranslatorState.swift`
2. Add UI in `Sources/Settings/Tabs/*.swift`
3. Add `didSet` logging observer

### New Manager

1. Create `Sources/State/Managers/YourManager.swift` as ObservableObject
2. Add property to TranslatorState
3. Forward `objectWillChange` in init

## Critical Behaviors

1. **Rate Limiting**: Respect `rateLimitBackoff` after rate limit errors
2. **Excluded Apps**: Clear overlay when switching to excluded apps
3. **Concurrency**: Limit requests via `maxConcurrentTranslations`
4. **URL Validation**: Never use invalid URLs - fall back to defaults
5. **Text Filtering**: Filter URLs, pipes, fragments, ignore patterns

## File Organization

```
Sources/
├── Engine/           # Core translation pipeline
├── State/
│   ├── Managers/     # ObservableObject managers
│   ├── Models/       # Data models and enums
│   └── Utilities/    # Helpers (URLValidator, etc.)
├── Translation/
│   ├── Providers/    # Translation provider actors
│   └── Utilities/    # Translation helpers
└── Settings/
    ├── Tabs/         # Settings tab views
    └── Components/   # Reusable UI components
```

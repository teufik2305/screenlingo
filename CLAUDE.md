# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ScreenLingo** is a real-time screen translation overlay for macOS that uses OCR to detect text in any window and displays translations directly over the original content. Built with Swift 5.9 and SwiftUI, requiring macOS 14.0+.

## Build & Development Commands

```bash
# Build (debug)
swift build

# Run directly
swift build && .build/debug/OverlayTranslator

# Test (all)
swift test

# Test (specific class)
swift test --filter TranslationCacheTests

# Test (parallel)
swift test --parallel

# Build release app bundle
./build-app.sh

# Build and open app
./build-app.sh --open

# Clean build cache
swift package clean
```

## Architecture Overview

### Core System Flow

The application follows this data flow:

1. **RealTimeTranslationEngine** (Sources/Engine/RealTimeTranslationEngine.swift:12) orchestrates the entire translation pipeline
2. **WindowCaptureService** captures screenshots of the frontmost window at configurable intervals (default 50ms)
3. **OCRProcessor** uses Vision.framework to detect text regions and groups them intelligently based on proximity
4. **TranslationCache** (LRU cache with optional persistence) checks if text was previously translated
5. **TranslationService** routes uncached text to the appropriate provider (Apple/Google/LibreTranslate/LLM)
6. **RealTimeOverlayView** renders translated text over original content using two modes: Box (customizable background) or Outline (subtitle-style stroke)

### Multi-Monitor Support

The engine tracks which screen the captured window is on and passes this information to the overlay view. The overlay window automatically positions itself on the correct display and follows windows across monitors when `multiMonitorEnabled` is true.

### State Management

**TranslatorState** (Sources/State/TranslatorState.swift:7) is the central `ObservableObject` that:
- Stores all user preferences using `@AppStorage` with shared UserDefaults suite ("com.screenlingo.shared")
- Manages two sub-managers: `ExcludedAppsManager` and `IgnorePatternManager`
- Forwards manager `objectWillChange` events to trigger UI updates
- Provides computed properties for service-specific settings (e.g., `useAppleTranslation`, `useLLM`)

All settings are automatically persisted and trigger logging via `didSet` observers.

### Translation Provider System

**TranslationService** (Sources/Translation/TranslationService.swift:5) is an `actor` that routes translation requests based on priority:

1. **LLM** (OpenAI, Anthropic, Gemini, Ollama) - Provider auto-detected from API URL
2. **LibreTranslate/LTEngine** - Self-hosted translation
3. **Apple Translation** - Native macOS 15+ translation (NO API)
4. **Google Translate** - Fallback for older macOS or custom API

Each provider implements `TranslationProvider` protocol with a single async method:
```swift
func translate(text: String, from: String, to: String, timeout: TimeInterval) async throws -> String
```

LLM provider selection in TranslationService.createLLMProvider() automatically chooses AnthropicProvider or OpenAIProvider based on URL patterns.

### Overlay Rendering Modes

**RealTimeOverlayView** (Sources/RealTimeOverlayView.swift) supports two display modes:

- **Box mode** (`overlayDisplayMode = 0`): Draws rounded rectangles with customizable background color, padding, border, shadow, and corner radius. Can cover original text if `boxCoverOriginal = true`.
- **Outline mode** (`overlayDisplayMode = 1`): Renders text with stroke outline (subtitle-style) using configurable outline width and colors.

Settings controlled via TranslatorState: `overlayDisplayMode`, `boxPaddingH/V`, `boxCornerRadius`, `boxBackgroundColorHex`, `boxTextColorHex`, `boxBorderWidth`, `outlineWidth`, `outlineColorHex`, `textColorHex`.

### Caching Strategy

**TranslationCache** (Sources/Engine/TranslationCache.swift) implements:
- LRU eviction (configurable max size via `maxCacheSize`)
- Text normalization (whitespace, case-insensitive keys)
- Optional persistence to JSON file (`enableCachePersistence`)
- Thread-safe operations

The engine uses a two-phase approach:
1. **Fast path**: Cached translations update overlay immediately
2. **Slow path**: Uncached text is translated with concurrency limiting (`maxConcurrentTranslations`)

### OCR Text Grouping

**OCRProcessor** (Sources/Engine/OCRProcessor.swift) groups detected text regions using configurable heuristics:

- `textGrouping`: Controls grouping aggressiveness (0.5=strict, 1.0=normal, 2.0=aggressive)
- `horizontalGapThreshold`: Maximum horizontal gap to group text (percentage of screen width)
- `verticalGapMultiplier`: Multiplier for vertical spacing tolerance
- `centerAlignmentThreshold`: Tolerance for center-aligned text grouping
- `maxBubbleWidth/Height`: Limits for grouped text regions

This is critical for manga/comics/subtitle translation where text should be grouped into logical bubbles.

### Logging System

**Logger.swift** provides structured logging with categories:
- Categories: `.engine`, `.ocr`, `.translation`, `.api`, `.cache`, `.ui`, `.app`, `.settings`, `.state`
- Configurable via TranslatorState: `logLevel`, `logFilePath`, `enableFileLogging`
- Use: `log.info("Message", category: .engine)`

## Adding Features

### New Translation Provider

1. Create `Sources/Translation/Providers/YourProvider.swift`
2. Implement `TranslationProvider` protocol:
   ```swift
   actor YourProvider: TranslationProvider {
       func translate(text: String, from: String, to: String, timeout: TimeInterval) async throws -> String {
           // Implementation
       }
   }
   ```
3. Add routing logic in `TranslationService.translate()` (Sources/Translation/TranslationService.swift:22)
4. Add enum case to `TranslationServiceType` (Sources/State/Models/TranslationServiceType.swift)

### New Setting

1. Add `@AppStorage` property to `TranslatorState.swift` with appropriate default
2. Add UI control in relevant `Sources/Settings/Tabs/*.swift` file
3. Add `didSet` observer for logging if the setting is important
4. If the setting affects a manager, forward `objectWillChange` in TranslatorState.init()

### New Manager (for complex state)

1. Create `Sources/State/Managers/YourManager.swift` as `ObservableObject`
2. Add instance property to `TranslatorState`
3. Forward `objectWillChange` in `TranslatorState.init()`:
   ```swift
   yourManager.objectWillChange
       .sink { [weak self] _ in
           self?.objectWillChange.send()
       }
       .store(in: &cancellables)
   ```

## Test Guidelines

**CRITICAL**: Tests MUST use isolated UserDefaults to avoid modifying user preferences.

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

Test naming: `test[Method]_When[Condition]_Then[Expected]`

Structure: Given-When-Then pattern

## Key Files Reference

- **RealTimeTranslationEngine.swift:12** - Main orchestrator (start here)
- **TranslatorState.swift:7** - Central state and settings
- **TranslationService.swift:5** - Provider routing and translation logic
- **RealTimeOverlayView.swift** - Overlay rendering (box vs outline modes)
- **OCRProcessor.swift** - Text detection and grouping algorithms
- **TranslationCache.swift** - LRU cache with persistence
- **WindowCaptureService.swift** - Screen capture and window detection

## Common Patterns

### Settings with Logging
```swift
@AppStorage("mySetting", store: TranslatorState.preferencesStore) var mySetting: Bool = true {
    didSet { log.info("My setting: \(mySetting ? "enabled" : "disabled")", category: .settings) }
}
```

### Manager Integration
```swift
// In manager init
init(store: UserDefaults = TranslatorState.preferencesStore) {
    self.store = store
    // Load from store
}
```

### Translation Provider
```swift
actor MyProvider: TranslationProvider {
    let apiUrl: String
    let apiKey: String?

    func translate(text: String, from: String, to: String, timeout: TimeInterval) async throws -> String {
        // Build request
        // Make API call with timeout
        // Parse response
        // Return translated text
    }
}
```

## Platform-Specific Notes

- **macOS 14.0+** required (Sonoma)
- **macOS 15.0+** for native Apple Translation (falls back to Google Translate on older versions)
- Requires **Screen Recording** and **Accessibility** permissions
- Uses **Vision.framework** for OCR (always available on macOS 14+)
- **Swift Package Manager** only (no CocoaPods/Carthage)

## Critical Behaviors

1. **Rate Limiting**: Engine respects `rateLimitBackoff` after receiving rate limit errors and skips translations during backoff period
2. **Excluded Apps**: Overlay clears immediately when switching to excluded apps (checked via bundle identifier)
3. **Window Changes**: Hash comparison detects content changes; switching windows forces re-translation
4. **Concurrency**: Translation requests are limited by `maxConcurrentTranslations` to prevent overwhelming APIs
5. **Text Filtering**: Engine filters out URLs, pipe characters, fragments (partial words), and user-defined ignore patterns

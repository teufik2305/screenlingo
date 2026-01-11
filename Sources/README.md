# Sources

## Structure

```
Sources/
├── Engine/                 # Core translation engine
│   ├── RealTimeTranslationEngine.swift  # Main orchestrator
│   ├── TranslationCache.swift           # LRU cache with persistence
│   ├── OCRProcessor.swift               # Text recognition & grouping
│   └── WindowCaptureService.swift       # Screen capture
│
├── Translation/            # Translation providers
│   ├── TranslationService.swift         # Provider router
│   ├── TranslationProvider.swift        # Provider protocol
│   └── Providers/                       # OpenAI, Anthropic, Google, Apple, LibreTranslate
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

## Adding Features

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

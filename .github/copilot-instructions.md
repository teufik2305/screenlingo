# Copilot instructions for OverlayTranslator (ScreenLingo)

This file gives focused, actionable guidance for AI coding agents working in this repository.

Quick context
- Purpose: real-time macOS screen translation overlay using OCR + multiple translation backends.
- Languages/tech: Swift 5.9, SwiftUI, Vision.framework, SPM (no CocoaPods/Carthage).
- Key entry points: `Sources/Engine/RealTimeTranslationEngine.swift`, `Sources/State/TranslatorState.swift`, `Sources/Translation/TranslationService.swift`, `Sources/RealTimeOverlayView.swift`.

Build / test / run (use these exact commands)
- Build debug: `swift build`
- Run locally: `swift build && .build/debug/OverlayTranslator`
- Run tests: `swift test` (or `swift test --filter TranslationCacheTests`)
- Build app bundle: `./build-app.sh` (use `--open` to open the bundle)

Important runtime requirements
- macOS 14.0+ required; Apple Translation needs macOS 15+.
- During development grant System Settings: Screen Recording and Accessibility.

Architecture highlights (how components interact)
- Orchestration: `RealTimeTranslationEngine` captures windows (via `WindowCaptureService`), sends regions to `OCRProcessor`, checks `TranslationCache`, then routes to `TranslationService` for providers.
- State: `TranslatorState` is the central `ObservableObject` (stores `@AppStorage` keys, exposes managers in `Sources/State/Managers`).
- Rendering: `RealTimeOverlayView` draws overlays in two modes (Box / Outline) based on settings in `TranslatorState`.
- Concurrency: `TranslationService` is an `actor` which routes to async provider actors and uses `maxConcurrentTranslations` and backoff on rate limits.

Project-specific conventions and patterns
- Settings: prefer `@AppStorage` properties inside `TranslatorState` with `didSet` logging (see `TranslatorState.swift`).
- Providers: implement `TranslationProvider` as an `actor` with `translate(text:from:to:timeout:) async throws -> String` (see `Translation/Providers/` for examples).
- Manager integration: create `ObservableObject` managers under `Sources/State/Managers` and forward their `objectWillChange` into `TranslatorState` (use Combine sink and store cancellables).
- Caching: `TranslationCache` is LRU, normalizes keys (whitespace/case); prefer using it before calling external providers.
- Logging: use `log.info/debug/error(..., category: .engine/.ocr/.translation/.cache/.ui/.settings)` consistently (see `Logger.swift`).
- URL validation: **ALWAYS** validate user-provided API URLs using `URLValidator` before use (see below).

URL validation (critical for stability)
- Use `URLValidator` from `Sources/State/Utilities/URLValidator.swift` for all API URL validation.
- Blocked patterns: `PROJECT_ID`, `YOUR_API_KEY`, `${...}`, `{{...}}`, `PLACEHOLDER`, etc.
- In settings UI: call `state.validateCustomApiUrl()` / `validateLibreTranslateUrl()` / `validateLLMApiUrl()` on `onChange`.
- In TranslationService: use `URLValidator.validateAndSanitize(url)` before API calls; fall back to defaults if invalid.
- Show validation feedback with `URLValidationView` component in settings forms.

How to add common items (copy/paste snippets)
- New translation provider:
  1. Add `Sources/Translation/Providers/YourProvider.swift` implementing `TranslationProvider` as an `actor`.
  2. Update routing in `Sources/Translation/TranslationService.swift` to include the provider and its enum case in `TranslationServiceType`.
- New setting:
  1. Add an `@AppStorage` var in `TranslatorState.swift` with default and `didSet` logging.
  2. Add UI in `Sources/Settings/Tabs/*` and ensure state propagates via `TranslatorState`.

Tests and test conventions
- Always use isolated `UserDefaults` suites in tests to avoid touching developer/user preferences (see `Tests/README.md`).
- Test naming: `test[Method]_When[Condition]_Then[Expected]` and Given-When-Then structure.

What to check when editing behavior
- If changing translation flow, update `RealTimeTranslationEngine` and `TranslationService` together — both orchestrate retries, caching, and confidence-mode logic.
- If overlay appearance changes, update `RealTimeOverlayView` and the corresponding `TranslatorState` settings.
- If adding/modifying URL input fields, add `URLValidator` validation and `URLValidationView` feedback.

Files to open first when triaging a change
- `Sources/Engine/RealTimeTranslationEngine.swift`
- `Sources/State/TranslatorState.swift`
- `Sources/Translation/TranslationService.swift`
- `Sources/Engine/OCRProcessor.swift`
- `Sources/RealTimeOverlayView.swift`

When to ask the repo owner
- Clarify supported LLM endpoints and which are considered "LLM" vs "translate" endpoints if adding provider routing changes.
- Confirm acceptable persistence path for `TranslationCache` when enabling `enableCachePersistence` in CI or test runs.

If anything here is unclear or you need more examples (e.g., a provider skeleton or tests), tell me which area and I'll expand with concrete code. 

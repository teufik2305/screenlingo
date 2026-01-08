# ScreenLingo

A macOS menu bar app that provides **real-time translation overlays** for any text on your screen. Perfect for reading manga, foreign documents, or any content in another language.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Real-time Translation** - Continuously monitors the active window and translates text as you scroll
- **Apple Translation** - On-device translation using Apple's framework (macOS 26+), with API fallback
- **Overlay Display** - Translations appear directly over the original text
- **OCR Recognition** - Uses Apple's Vision framework for accurate text detection
- **25+ Languages** - Supports major world languages
- **Smart Caching** - Avoids re-translating text you've already seen
- **Excluded Apps** - Skip translation for IDEs (Cursor, VS Code, Xcode) and other apps
- **Ignore Patterns** - Filter out UI elements, headers, or any unwanted text
- **Click Interactions** - Copy translations, hide overlays, or add to ignore list
- **Global Hotkey** - Toggle translation with `Cmd+Ctrl+T`

## How It Works

1. Start translation from the menu bar or press `Cmd+Ctrl+T`
2. The app captures the frontmost window using ScreenCaptureKit
3. OCR detects text, groups nearby text blocks
4. Translations overlay directly on detected text
5. Click any overlay for options (copy, hide, ignore)

## Quick Start

### Build & Run

```bash
# Clone the repository
git clone https://github.com/teufik2305/screenlingo.git
cd screenlingo

# Build and run
swift build
.build/debug/OverlayTranslator
```

### Create App Bundle

```bash
# Build a proper .app bundle with icon
./build-app.sh

# The app will be created as ScreenLingo.app
open ScreenLingo.app
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+Ctrl+T` | Toggle translation on/off |
| `Cmd+Q` | Quit application |

## Settings

Access from menu bar → **Settings...**

### General Tab
- **Translation Service** - Toggle Apple Translation (on-device) or API
- **Custom API URL** - Use your own translation endpoint
- **Interaction Mode** - Click mode (context menu) or Hover mode (auto-hide)

### Appearance Tab
- **Font Size** - 12-24pt with live preview
- **Opacity** - 70-100% overlay transparency

### Filters Tab
- **Excluded Apps** - Apps where translation is disabled (IDEs by default)
- **Ignore Patterns** - Text patterns to skip (e.g., "Chapter", page numbers)

### Advanced Tab
- **Logging** - Enable/disable file logging, set log level
- **Statistics** - View session stats (translations, cache hits, timing)

## Supported Languages

English, French, German, Spanish, Italian, Portuguese, Russian, Japanese, Korean, Chinese, Arabic, Dutch, Polish, Turkish, Ukrainian, Vietnamese, Thai, Czech, Danish, Finnish, Greek, Hebrew, Hindi, Hungarian, Indonesian, Norwegian, Romanian, Swedish

## Requirements

- **macOS 14.0** (Sonoma) or later
- **macOS 26.0** for Apple Translation (falls back to API on older versions)
- **Screen Recording** permission
- **Accessibility** permission (for global hotkey)

## Permissions

On first run, grant these permissions in **System Settings → Privacy & Security**:

1. **Screen Recording** - Required for window capture
2. **Accessibility** - Required for global keyboard shortcut

## Project Structure

```
Sources/
├── OverlayTranslatorApp.swift      # App entry point, menu bar setup
├── MenuBarView.swift               # Menu bar dropdown UI
├── SettingsView.swift              # Tabbed settings window
├── TranslatorState.swift           # App state & settings storage
├── RealTimeTranslationEngine.swift # ScreenCaptureKit, OCR & translation
├── RealTimeOverlayView.swift       # Overlay rendering
├── TranslationService.swift        # Apple Translation + API fallback
└── Logger.swift                    # Logging system with levels & stats
```

## Technical Details

- **UI Framework**: SwiftUI + AppKit hybrid
- **Screen Capture**: ScreenCaptureKit (modern API)
- **OCR**: Apple Vision framework
- **Translation**: Apple Translation (macOS 26+) or Google Translate API
- **Architecture**: Menu bar app with floating overlay window

## License

MIT License - feel free to use and modify!

## Contributing

Contributions welcome! Please feel free to submit issues and pull requests.

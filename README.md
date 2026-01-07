# 🌐 ScreenLingo

A macOS menu bar app that provides **real-time translation overlays** for any text on your screen. Perfect for reading manga, foreign documents, or any content in another language.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/License-MIT-green)

## ✨ Features

- **Real-time Translation** - Continuously monitors the active window and translates text as you scroll
- **Overlay Display** - Translations appear directly over the original text
- **OCR Recognition** - Uses Apple's Vision framework for accurate text detection
- **25+ Languages** - Supports major world languages
- **Smart Caching** - Avoids re-translating text you've already seen
- **Ignore List** - Filter out UI elements, headers, or any unwanted text
- **Click Interactions** - Copy translations, hide overlays, or add to ignore list
- **Global Hotkey** - Toggle translation with `⌘⌃T` (Cmd+Control+T)

## 📸 How It Works

1. Start translation from the menu bar or press `⌘⌃T`
2. The app captures the frontmost window continuously
3. OCR detects text, groups nearby text blocks
4. Translations overlay directly on detected text
5. Click any overlay for options (copy, hide, ignore)

## 🚀 Quick Start

### Build & Run

```bash
# Clone the repository
git clone https://github.com/yourusername/screenlingo.git
cd screenlingo

# Build and run
swift build
.build/debug/OverlayTranslator
```

### Create App Bundle

```bash
# Build a proper .app bundle with icon
./build-app.sh

# Or manually:
swift build -c release
```

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘⌃T` | Toggle translation on/off |
| `⌘Q` | Quit application |

## 🔧 Settings

Access from menu bar → **Settings...**

- **Interaction Mode**
  - *Click Mode*: Click overlay → context menu (copy, hide, ignore)
  - *Hover Mode*: Mouse over → overlay disappears temporarily
- **Font Size**: 12-24pt
- **Opacity**: 80-100%
- **Ignore List**: Add patterns to skip (e.g., "Chapter", page numbers)
- **Log File**: Debug output location

## 🌐 Supported Languages

English, French, German, Spanish, Italian, Portuguese, Russian, Japanese, Korean, Chinese, Arabic, Dutch, Polish, Turkish, Ukrainian, Vietnamese, Thai, Czech, Danish, Finnish, Greek, Hebrew, Hindi, Hungarian, Indonesian, Norwegian, Romanian, Swedish

## 📋 Requirements

- **macOS 14.0** (Sonoma) or later
- **Screen Recording** permission
- **Accessibility** permission (for global hotkey)

## 🔐 Permissions

On first run, grant these permissions in **System Settings → Privacy & Security**:

1. **Screen Recording** - Required for window capture
2. **Accessibility** - Required for global keyboard shortcut

## 🏗️ Project Structure

```
Sources/
├── OverlayTranslatorApp.swift    # App entry point, menu bar setup
├── MenuBarView.swift             # Menu bar dropdown UI
├── SettingsView.swift            # Settings window
├── TranslatorState.swift         # App state & settings storage
├── RealTimeTranslationEngine.swift # OCR & translation logic
├── RealTimeOverlayView.swift     # Overlay rendering
└── TranslationService.swift      # Google Translate API
```

## 🛠️ Technical Details

- **UI Framework**: SwiftUI + AppKit hybrid
- **OCR**: Apple Vision framework
- **Translation**: Google Translate (unofficial API)
- **Architecture**: Menu bar app with floating overlay window

## 📄 License

MIT License - feel free to use and modify!

## 🤝 Contributing

Contributions welcome! Please feel free to submit issues and pull requests.

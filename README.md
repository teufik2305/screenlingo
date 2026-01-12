# ScreenLingo

Real-time screen translation overlay for macOS. Translates text in any window using OCR and displays translations directly over the original content.

## Features

- Real-time OCR text detection (Apple Vision)
- Multiple translation backends: Apple Translation, LibreTranslate, Google Translate, LLM (OpenAI/Claude/Gemini/Local)
- **Multi-monitor support** - overlay follows windows across displays
- **Two display modes**: Box (customizable background) or Outline (subtitle-style stroke)
- **Confidence Mode (Beta)** - LLM rates translation quality, retries low-confidence results
- **Scroll Detection** - pauses translation while scrolling, clears stale overlays
- Customizable appearance: colors, padding, opacity, corner radius, borders
- Smart caching with persistence
- Configurable text grouping for manga/comics/subtitles
- Global hotkey toggle (Cmd+Ctrl+T)
- Click or hover interaction modes

## Requirements

- macOS 14.0+ (Sonoma)
- Screen Recording permission
- Accessibility permission (for hotkey)

## Quick Start

```bash
# Build and run
swift build && .build/debug/OverlayTranslator

# Or create app bundle
./build-app.sh && open ScreenLingo.app
```

Or run directly:
```bash
swift build && .build/debug/OverlayTranslator
```

## Setup

1. **Grant Permissions** (System Settings > Privacy & Security):
   - Screen Recording
   - Accessibility

2. **Configure Translation Service** (Settings > General):
   | Service | Setup |
   |---------|-------|
   | Apple | None (macOS 15+, download language packs) |
   | Google | Works out of box |
   | LibreTranslate | Set server URL |
   | LLM | Set API URL and key (OpenAI-compatible: Ollama, vLLM, LM Studio) |

3. **Select Languages** and start translating

## Tech Stack

- **Swift 5.9** / SwiftUI
- **Vision.framework** - OCR
- **Translation.framework** - Apple Translation (macOS 15+)
- **Swift Package Manager** - Build system

## Project Structure

```
Sources/          # Application code (see Sources/README.md)
Tests/            # Unit tests (see Tests/README.md)
build-app.sh      # Creates ScreenLingo.app bundle
Package.swift     # SPM manifest
```

## Development

```bash
# Build
swift build

# Test
swift test

# Build release app
./build-app.sh
```

## License

MIT

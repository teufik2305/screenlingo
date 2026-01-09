# ScreenLingo

A macOS menu bar app that provides **real-time translation overlays** for any text on your screen. Perfect for games, manga, foreign documents, or any content in another language.

## Features

- **Real-time Translation** - Continuously translates text in the active window
- **Multiple Translation Services**
  - **Apple Translation** - On-device, private (macOS 15+)
  - **LibreTranslate/LTEngine** - Self-hosted or remote server
  - **Google Translate** - Works out of the box
  - **LLM Translation** - OpenAI GPT, Anthropic Claude, Google Gemini, or local models via Ollama
- **OCR Recognition** - Uses Apple Vision for accurate text detection
- **Overlay Display** - Translations appear directly over original text
- **Smart Caching** - Avoids re-translating seen text
- **Click Interactions** - Copy, hide, or ignore overlays
- **Global Hotkey** - Toggle with `Cmd+Ctrl+T`

## Quick Start

```bash
# Build and run
swift build && .build/debug/OverlayTranslator

# Or create app bundle
./build-app.sh && open ScreenLingo.app
```

## Requirements

- **macOS 14.0+** (Sonoma)
- **Screen Recording** permission
- **Accessibility** permission (for global hotkey)

## Permissions

On first run, grant permissions in **System Settings → Privacy & Security**:
1. **Screen Recording** - For window capture
2. **Accessibility** - For global keyboard shortcut

## Settings

Access from menu bar → **Settings...**

- **Translation Service** - Choose Apple, LibreTranslate, Google, or LLM
- **Languages** - Source/target language with auto-detect support
- **Appearance** - Font size (12-24pt), overlay opacity
- **Filters** - Excluded apps, ignore patterns
- **Advanced** - Logging, performance tuning

## Translation Services

| Service | Pros | Requirements |
|---------|------|--------------|
| **Apple** | Private, on-device, fast | macOS 15+, language packs |
| **LibreTranslate** | Open source, self-hostable | Server URL |
| **Google** | Reliable, 100+ languages | None (works out of box) |
| **LLM** | High quality, context-aware | API key |

### LLM Translation

Supports multiple AI providers with preset configurations:

- **OpenAI** - GPT-4.1, GPT-5, GPT-5.2
- **Anthropic** - Claude Haiku/Sonnet/Opus 4.5
- **Google Gemini** - Gemini 2.5 Flash/Pro
- **Ollama** - Local models (Llama, Qwen, Gemma)

Each provider stores its API key independently—switch freely without losing keys.

## Supported Languages

20+ languages including English, French, German, Spanish, Japanese, Korean, Chinese (Simplified/Traditional), Russian, Arabic, and more. LLM translation supports any language the model understands.

## Notes

- **Full-screen games**: Use windowed/borderless mode for overlays to appear
- **Serbian**: Option to force Latin script (converts Cyrillic automatically)
- **LLM errors**: Clear messages for invalid API keys, billing issues, rate limits

## License

MIT License

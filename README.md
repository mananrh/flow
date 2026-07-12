# Flow

A premium macOS dictation app with AI-powered transcription, context-aware cleanup, and transcript history.

## Overview

Flow gives you fast AI transcription, context-aware cleanup, and voice-driven text editing — all from a sleek menu bar app.

## Quick Start

1. Build & run with `make run`
2. Get a free Groq API key from [groq.com](https://groq.com/)
3. Hold `Fn` to talk, or tap `Command-Fn` to toggle dictation

## Features

- **Context-aware cleanup:** Flow reads nearby app context so names, terms, and phrases are spelled correctly when you dictate
- **Custom shortcuts:** Customize both hold-to-talk and toggle dictation shortcuts
- **Custom vocabulary:** Add names, jargon, and project-specific words that Flow should preserve
- **OpenAI-compatible providers:** Use Groq by default, or configure a custom model and API URL
- **Edit Mode:** Highlight existing text and transform it with spoken instructions
- **Transcript History:** *(Coming soon)* Review, search, and replay past dictations

## Building

```bash
# Dev build (current architecture)
make

# Run immediately after building
make run

# Production build (universal binary)
make APP_NAME=Flow BUNDLE_ID=com.mananrathod.flow ARCH=universal

# Clean build artifacts
make clean
```

## License

Licensed under the GNU Affero General Public License v3.0 (AGPL-3.0).

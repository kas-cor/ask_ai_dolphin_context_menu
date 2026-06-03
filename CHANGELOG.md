# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — 2026-06-03

### 🚀 Initial release

Ask AI Dolphin Context Menu — AI assistant for KDE Dolphin file manager.

- KDE Dolphin context menu integration via service menu
- PyQt5 dialog with configurable preset queries and custom input
- Streaming AI response through `glow` Markdown formatter in Konsole
- Adaptive dark/light theme (auto-detected from system palette)
- `ask` / `askr` shell functions for terminal usage

### 🌐 Localization

- English and Russian UI (auto-detected from `$LANG`)
- Locale files: `locales/en_EN` and `locales/ru_RU` (44 keys each)
- Locale validation in CI (UTF-8, format, cross-file key parity)
- Russian documentation (`README_ru.md`)

### ⚙️ Configuration

- `ASK_AI_MODEL` — model selection (default: `opencode/deepseek-v4-flash-free`)
- `ASK_AI_LOCALE` — language override (`ru_RU` / `en_EN`)
- `ASK_AI_THEME` — theme override (`dark` / `light`, with `d`/`l` shortcuts)
- `GLOW_DISABLED` — disable Markdown formatting
- `~/.ask_ai` auto-created on install with conditional sourcing in `.bashrc`/`.zshrc`
- `~/.config/ask-ai-dolphin.cfg` for preset queries (last 8 shown)

### 🧪 CI & Testing

- Shell syntax check (4 scripts)
- Python syntax check (dialog + CI scripts)
- Locale file validation
- Qt `setFamilies()` compatibility test (Qt ≥ 5.13 / fallback for < 5.13)
- `ASK_AI_THEME` style selection test (6 tests)
- Release Please workflow for automated versioning

### 📦 Installation

- One-liner: `curl ... install.sh | bash`
- Local: `git clone && ./install.sh`
- Works via curl pipe mode (no cloning needed)
- Uninstall: `curl ... uninstall.sh | bash`
- Dependency checks in install script

### 🏗️ Infrastructure

- License: MIT
- AGENTS.md for AI coding assistants
- GitHub badges (CI, License, Release, Platform)
- CONTRIBUTING.md with conventional commits guide

# Quick AI Chat Plugin for DankMaterialShell

A slide-out AI chat panel for DankMaterialShell, powered by any OpenAI-compatible API (DeepSeek, OpenAI, etc.).

This project was inspired by [this repo](https://github.com/devnullvoid/dms-ai-assistant), but made from scratch, also mainly by AI agent (Claude Sonnet 4.6)

## Features

- Pros
    - Streaming responses via SSE (which devnullvoid's plugin doesn't work correctly)
    - Cleaner UX (Focus on textbox immediately, Esc to back from setting / interrupt generation / close panel)
    - Basic Markdown rendering
- Cons
    - now only supports OpenAI-compatible APIs

## Installation & Setup

Get the plugin:

```bash
mkdir -p ~/.config/DankMaterialShell/plugins
cd ~/.config/DankMaterialShell/plugins
git clone https://github.com/MrZ626/dms-quick-ai-chat.git quickAiChat
```

Restart dms:

```bash
`dms restart`
```

Add a keybind in `~/.config/niri/dms/binds.kdl`

```
Mod+Shift+F23 repeat=false hotkey-overlay-title="Quick AI Chat" { spawn "dms" "ipc" "call" "plugins" "toggle" "quickAiChat"; }
```

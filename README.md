# Quick AI Chat Plugin for DankMaterialShell

基于DMS的快速AI聊天插件

受devnullvoid的[这个仓库](https://github.com/devnullvoid/dms-ai-assistant)启发

由Claude Sonnet 4.6从头编写

## 功能

- 优点
    - 支持流式传输（devnullvoid 的插件无法正确工作）
    - 支持Markdown
    - 交互更高效简洁
- 缺点
    - 目前仅支持 OpenAI 兼容的 API

## 安装

下载：

```bash
mkdir -p ~/.config/DankMaterialShell/plugins
cd ~/.config/DankMaterialShell/plugins
git clone https://github.com/MrZ626/dms-quick-ai-chat.git quickAiChat
```

重启 DMS：

```bash
`dms restart`
```

在 `~/.config/niri/dms/binds.kdl` 中添加快捷键绑定：

```
Mod+Shift+F23 repeat=false hotkey-overlay-title="Quick AI Chat" { spawn "dms" "ipc" "call" "plugins" "toggle" "quickAiChat"; }
```

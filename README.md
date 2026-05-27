# Deepseek Chat for DankMaterialShell

基于DMS的Deepseek聊天插件

受devnullvoid的[这个仓库](https://github.com/devnullvoid/dms-ai-assistant)启发

由Claude Sonnet 4.6从头编写

## 功能

- 支持流式传输（devnullvoid 的插件无法正确工作）
- 支持Markdown
- 交互更高效简洁

## 安装

下载：

```bash
mkdir -p ~/.config/DankMaterialShell/plugins
cd ~/.config/DankMaterialShell/plugins
git clone https://github.com/MrZ626/dms-deepseek-chat.git DeepseekChat
```

重启 DMS：

```bash
`dms restart`
```

在 `~/.config/niri/dms/binds.kdl` 中添加快捷键绑定：

```
Mod+Shift+F23 repeat=false hotkey-overlay-title="Deepseek Chat" { spawn "dms" "ipc" "call" "plugins" "toggle" "DeepseekChat"; }
```

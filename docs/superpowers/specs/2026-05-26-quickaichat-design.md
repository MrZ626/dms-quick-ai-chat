# QuickAiChat 插件设计文档

日期：2026-05-26

## 概述

一个可以通过 niri 快捷键快速唤出的 AI 聊天面板，作为 DankMaterialShell 的 daemon 插件运行。

目标：代码简单易读，便于学习 DMS 插件开发，后续逐步扩展功能。

## 技术栈

- **框架**：Quickshell + QML
- **插件类型**：daemon + slideout 能力
- **UI 组件**：DMS 内置 DankSlideout、Theme 系统

## 文件结构

```
quickAiChat/
├── plugin.json        # 插件清单，type: daemon
├── QuickAiChat.qml    # 入口：ChatService 单例 + Variants(DankSlideout)
├── ChatService.qml    # 逻辑：ListModel + 消息管理（后续加 API）
└── ChatPanel.qml      # UI：顶栏 + ListView + 输入区 + 设置覆盖层
```

## 各文件职责

### plugin.json
- id: `quickAiChat`
- type: `daemon`
- capabilities: `["slideout"]`
- permissions: `["settings_read", "settings_write"]`

### QuickAiChat.qml（daemon 入口）
- 持有 ChatService 单例（所有屏幕共享同一份消息状态）
- 用 `Variants` 为每个屏幕创建一个 `DankSlideout`
- 暴露 `toggle()` 函数供 IPC / 快捷键调用
- 把 chatService 注入进每个 ChatPanel

### ChatService.qml（状态与逻辑）
- `messagesModel: ListModel` — 消息列表，每项 `{ role, content }`
- `isLoading: bool` — 等待 API 响应时为 true（暂时不用，预留）
- `sendMessage(text)` — 追加 user 消息（后续扩展为调用 API）
- `clearHistory()` — 清空消息列表
- 设置项（后续阶段）：`apiKey`, `model`, `systemPrompt`

### ChatPanel.qml（纯 UI）
- `required property var chatService` — 唯一外部依赖
- `signal hideRequested` — 通知 slideout 收起
- 布局：顶栏（标题 + 清空按钮）+ 消息区（ListView）+ 输入区（TextArea + 发送按钮）
- 快捷键：Enter 发送，Shift+Enter 换行，Escape 触发 hideRequested

## 消息对象结构

```js
{ role: "user" | "assistant", content: string }
```

## 数据流

```
用户输入 → ChatPanel.sendCurrentMessage()
         → ChatService.sendMessage(text)
         → messagesModel.append({ role:"user", content:text })
         → ListView 自动刷新（绑定 messagesModel）
```

## 开发阶段

| 阶段 | 目标 |
|------|------|
| 1（当前） | 能拉出空白面板；只有用户能发消息，消息显示在列表中 |
| 2 | 接入 OpenAI API，实现真实 AI 回复（非流式） |
| 3 | 设置界面：配置 API Key、model、system prompt |
| 4 | 流式输出；修复 ref 中 SSE 解析问题 |
| 5 | DankBar 图标按钮入口 |

## 流式输出升级路径（预留）

现在的非流式设计与流式兼容：
- 非流式：`Process.onExited` → 解析完整 JSON → `setProperty`
- 流式：`StdioCollector.onTextChanged` → 逐行解析 SSE → 追加到同一条消息

升级时只改 ChatService.qml，ChatPanel.qml 无需修改。

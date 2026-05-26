// ChatService.qml
// 消息状态管理 + DeepSeek API 调用（流式 SSE，SplitParser 逐行推送）

import QtQuick
import Quickshell.Io
import qs.Services

Item {
    id: root

    property string pluginId: ""

    // ── 设置项 ────────────────────────────────────────────────────
    property string baseUrl:     ""
    property string model:       ""
    property string apiKey:      ""
    property real   temperature: 0
    property int    maxTokens:   0

    // ── 对外暴露的状态 ────────────────────────────────────────────
    property ListModel messagesModel: ListModel {}
    property bool      isLoading:     false

    // ── 设置持久化 ────────────────────────────────────────────────

    Component.onCompleted: loadSettings()

    function loadSettings() {
        baseUrl     = String(PluginService.loadPluginData(pluginId, "baseUrl",     "https://api.deepseek.com")).trim()
        model       = String(PluginService.loadPluginData(pluginId, "model",       "deepseek-v4-flash")).trim()
        apiKey      = String(PluginService.loadPluginData(pluginId, "apiKey",      "")).trim()
        temperature = Number(PluginService.loadPluginData(pluginId, "temperature", 1.0))
        maxTokens   = parseInt(PluginService.loadPluginData(pluginId, "maxTokens", 4096))
    }

    function saveSettings() {
        PluginService.savePluginData(pluginId, "baseUrl",     baseUrl)
        PluginService.savePluginData(pluginId, "model",       model)
        PluginService.savePluginData(pluginId, "apiKey",      apiKey)
        PluginService.savePluginData(pluginId, "temperature", temperature)
        PluginService.savePluginData(pluginId, "maxTokens",   maxTokens)
    }

    // 外部（如 PluginService 管理界面）修改设置时重新加载
    Connections {
        target: PluginService
        function onPluginDataChanged(pId) {
            if (pId === root.pluginId) root.loadSettings()
        }
    }

    // ── 公开函数 ──────────────────────────────────────────────────

    function sendMessage(text) {
        if (!text || text.trim().length === 0) return
        if (isLoading) return

        messagesModel.append({ role: "user",      content: text.trim(), status: "ok"      })
        messagesModel.append({ role: "assistant", content: "",          status: "loading" })
        _assistantIndex = messagesModel.count - 1

        isLoading = true
        _runRequest()
    }

    function clearHistory() {
        if (isLoading) return
        messagesModel.clear()
    }

    // ── 内部状态 ──────────────────────────────────────────────────
    property int    _assistantIndex: -1
    property string _errorBuffer:    ""   // 收集非 SSE 行（API 错误 JSON）

    // ── 内部实现 ──────────────────────────────────────────────────

    function _buildMessages() {
        const msgs = []
        for (let i = 0; i < messagesModel.count; i++) {
            const m = messagesModel.get(i)
            if (m.status !== "ok") continue
            if (m.role !== "user" && m.role !== "assistant") continue
            msgs.push({ role: m.role, content: m.content })
        }
        return msgs
    }

    function _runRequest() {
        _errorBuffer = ""

        const payload = JSON.stringify({
            model:       model,
            messages:    _buildMessages(),
            temperature: temperature,
            max_tokens:  maxTokens,
            stream:      true
        })

        chatProcess.command = [
            "curl", "-s", "-S", "-N",
            "-H", "Content-Type: application/json",
            "-H", "Authorization: Bearer " + apiKey,
            "-d", payload,
            baseUrl.replace(/\/$/, "") + "/chat/completions"
        ]

        chatProcess.running = true
    }

    // 处理单行 SSE（SplitParser 每收到一行就调用一次）
    function _processLine(line) {
        if (!line) return

        if (line === "data: [DONE]" || line === "data:[DONE]") {
            _finalizeStream()
            return
        }

        if (line.startsWith("data:")) {
            const jsonStr = line.substring(5).trim()
            try {
                const chunk = JSON.parse(jsonStr)
                const delta = chunk.choices?.[0]?.delta?.content
                if (typeof delta === "string" && delta.length > 0) {
                    _appendDelta(delta)
                    _errorBuffer = ""   // 收到有效内容，清空错误缓冲
                }
                if (chunk.choices?.[0]?.finish_reason === "stop")
                    _finalizeStream()
            } catch (e) {
                // 忽略格式错误的 chunk
            }
        } else {
            // 非 SSE 行（如 API 错误 JSON）先累积，等 streamFinished 再处理
            _errorBuffer += line
        }
    }

    function _appendDelta(delta) {
        if (_assistantIndex < 0) return
        const cur = messagesModel.get(_assistantIndex).content || ""
        messagesModel.setProperty(_assistantIndex, "content", cur + delta)
    }

    function _finalizeStream() {
        if (_assistantIndex >= 0)
            messagesModel.setProperty(_assistantIndex, "status", "ok")
        isLoading       = false
        _assistantIndex = -1
        _errorBuffer    = ""
    }

    function _setError(msg) {
        const idx = _assistantIndex >= 0 ? _assistantIndex : _findLoadingIndex()
        if (idx >= 0) {
            messagesModel.setProperty(idx, "content", msg)
            messagesModel.setProperty(idx, "status",  "error")
        }
        isLoading       = false
        _assistantIndex = -1
        _errorBuffer    = ""
    }

    function _findLoadingIndex() {
        for (let i = messagesModel.count - 1; i >= 0; i--) {
            if (messagesModel.get(i).status === "loading") return i
        }
        return -1
    }

    // ── curl 进程 ─────────────────────────────────────────────────
    Process {
        id: chatProcess
        running: false

        stdout: SplitParser {
            // 按换行符切割，每条完整的 SSE 行触发一次 onRead
            splitMarker: "\n"

            onRead: line => root._processLine(line.trim())
        }

        onExited: exitCode => {
            if (!root.isLoading) return

            if (exitCode !== 0) {
                root._setError("请求失败（curl exit " + exitCode + "）")
                return
            }

            // curl 正常退出但没收到 [DONE]（兜底）
            const idx        = root._assistantIndex
            const hasContent = idx >= 0 && (root.messagesModel.get(idx).content || "").length > 0

            if (hasContent) {
                root._finalizeStream()
                return
            }

            // 没有流式内容——尝试把错误缓冲当 JSON 解析
            const errText = root._errorBuffer.trim()
            if (errText) {
                try {
                    const data = JSON.parse(errText)
                    if (data.error) {
                        root._setError(data.error.message || JSON.stringify(data.error, null, 2))
                        return
                    }
                    // JSON 合法但结构不认识，直接显示
                    root._setError(JSON.stringify(data, null, 2))
                } catch (e) {
                    // 不是 JSON，直接显示原文
                    root._setError(errText)
                }
                return
            }
            root._setError("收到空响应")
        }
    }
}

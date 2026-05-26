// ChatService.qml
// 消息状态管理 + DeepSeek API 调用（非流式）

import QtQuick
import Quickshell.Io

Item {
    id: root

    // DMS 注入的插件 ID（暂未使用，预留给 PluginService 持久化）
    property string pluginId: ""

    // ── 设置项 ────────────────────────────────────────────────────
    property string baseUrl:     "https://api.deepseek.com"
    property string model:       "deepseek-v4-flash"
    property string apiKey:      ""
    property real   temperature: 1.0
    property int    maxTokens:   4096

    // ── 对外暴露的状态 ────────────────────────────────────────────

    // 消息列表，每项结构：{ role, content, status }
    // role: "user" | "assistant"
    // content: string
    // status: "ok" | "loading" | "error"
    property ListModel messagesModel: ListModel {}

    // 等待 API 响应时为 true
    property bool isLoading: false

    // ── 公开函数 ──────────────────────────────────────────────────

    function sendMessage(text) {
        if (!text || text.trim().length === 0) return
        if (isLoading) return

        // 追加用户消息
        messagesModel.append({ role: "user", content: text.trim(), status: "ok" })
        // 追加 loading 占位（assistant 回复）
        messagesModel.append({ role: "assistant", content: "", status: "loading" })

        isLoading = true
        _runRequest()
    }

    function clearHistory() {
        if (isLoading) return
        messagesModel.clear()
    }

    // ── 内部实现 ──────────────────────────────────────────────────

    // 构建发给 API 的消息数组（只取 status=ok 的消息，排除 loading 占位）
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

    // 启动 curl 请求
    function _runRequest() {
        const payload = JSON.stringify({
            model:       model,
            messages:    _buildMessages(),
            temperature: temperature,
            max_tokens:  maxTokens,
            stream:      false
        })

        const url = baseUrl.replace(/\/$/, "") + "/chat/completions"

        chatProcess.command = [
            "curl", "-s", "-S",
            "-H", "Content-Type: application/json",
            "-H", "Authorization: Bearer " + apiKey,
            "-d", payload,
            url
        ]

        chatProcess.running = true
    }

    // 找到最后一条 loading 消息的下标
    function _findLoadingIndex() {
        for (let i = messagesModel.count - 1; i >= 0; i--) {
            if (messagesModel.get(i).status === "loading") return i
        }
        return -1
    }

    function _setAssistantReply(text) {
        const idx = _findLoadingIndex()
        if (idx >= 0) {
            messagesModel.setProperty(idx, "content", text)
            messagesModel.setProperty(idx, "status", "ok")
        }
        isLoading = false
    }

    function _setError(msg) {
        const idx = _findLoadingIndex()
        if (idx >= 0) {
            messagesModel.setProperty(idx, "content", msg)
            messagesModel.setProperty(idx, "status", "error")
        }
        isLoading = false
    }

    // ── curl 进程 ─────────────────────────────────────────────────
    Process {
        id: chatProcess
        running: false

        stdout: StdioCollector {
            id: outputCollector

            // onStreamFinished 在所有 stdout 数据到齐后触发
            // text 是本次运行的完整输出，每次 Process 重新启动都会重置
            onStreamFinished: {
                if (!root.isLoading) return  // 已被 onExited 的非零退出码处理过

                if (!text || text.trim().length === 0) {
                    root._setError("收到空响应")
                    return
                }

                try {
                    const data = JSON.parse(text)
                    const content = data.choices?.[0]?.message?.content
                    if (typeof content === "string" && content.length > 0) {
                        root._setAssistantReply(content)
                    } else if (data.error) {
                        root._setError("API 错误：" + (data.error.message || JSON.stringify(data.error)))
                    } else {
                        root._setError("解析失败：" + text.slice(0, 300))
                    }
                } catch (e) {
                    root._setError("JSON 解析失败：" + text.slice(0, 300))
                }
            }
        }

        // onExited 只处理 curl 本身失败（网络不通、命令错误等）
        onExited: exitCode => {
            if (exitCode !== 0 && root.isLoading) {
                root._setError("请求失败（curl exit " + exitCode + "）")
            }
        }
    }
}

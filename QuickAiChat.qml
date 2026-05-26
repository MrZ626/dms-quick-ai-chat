// QuickAiChat.qml
// daemon 入口：持有 ChatService 单例，为每个屏幕创建一个 DankSlideout
//
// DMS 会自动注入 pluginService 和 pluginId。
// toggle() 函数供 niri 快捷键通过 IPC 调用：
//   dms ipc call plugins toggle quickAiChat

import QtQuick
import Quickshell
import qs.Widgets
import "."

Item {
    id: root

    // DMS 自动注入
    property var pluginService: null
    property string pluginId: "quickAiChat"

    // 供 IPC 调用：dms ipc call plugins toggle quickAiChat
    function toggle() {
        if (variants.instances.length > 0)
            variants.instances[0].toggle()
    }

    // ChatService 单例：所有屏幕共享同一份消息状态
    ChatService {
        id: chatService
        pluginId: root.pluginId
    }

    // Variants 为每个屏幕创建一个 slideout 实例
    Variants {
        id: variants
        model: Quickshell.screens

        delegate: DankSlideout {
            id: slideout
            required property var modelData  // Quickshell 注入的屏幕对象

            title: "Quick Chat"
            slideoutWidth: 480
            expandable: true
            expandedWidthValue: 960

            content: ChatPanel {
                chatService: chatService
                onHideRequested: slideout.hide()
            }
        }
    }
}

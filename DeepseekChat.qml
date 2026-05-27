// DeepseekChat.qml
// daemon 入口：持有 ChatService 单例，为每个屏幕创建一个 DankSlideout
//
// toggle() 函数供 niri 快捷键通过 IPC 调用：
//   dms ipc call plugins toggle deepseekChat

import QtQuick
import Quickshell
import qs.Widgets
import "."

Item {
    id: root

    // DMS 自动注入（备用，目前未使用）
    property var pluginService: null

    // 供 IPC 调用：dms ipc call plugins toggle deepseekChat
    function toggle() {
        if (variants.instances.length > 0)
            variants.instances[0].toggle()
    }

    // ChatService 单例：所有屏幕共享同一份消息状态
    // 注意：ID 用 chatLogic 而非 chatService，避免与 ChatPanel 的 required property
    // 同名导致 content: ChatPanel { chatService: chatService } 右侧解析到自身属性（undefined）
    ChatService {
        id: chatLogic
    }

    // Variants 为每个屏幕创建一个 slideout 实例
    Variants {
        id: variants
        model: Quickshell.screens

        delegate: DankSlideout {
            id: slideout
            required property var modelData  // Quickshell 注入的屏幕对象

            title: "Deepseek"
            slideoutWidth: 480
            expandable: true
            expandedWidthValue: 960

            content: ChatPanel {
                chatService: chatLogic
                onHideRequested: slideout.hide()
            }
        }
    }
}

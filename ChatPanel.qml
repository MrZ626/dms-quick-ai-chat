// ChatPanel.qml
// 聊天面板 UI：消息列表 + 输入区
// 只依赖 chatService，不包含任何业务逻辑。

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Widgets

Item {
    id: root

    implicitWidth: 480
    implicitHeight: 640

    // 唯一外部依赖，由 QuickAiChat.qml 注入
    required property var chatService

    // 通知 slideout 收起（绑定到 Escape 键）
    signal hideRequested

    // 控制设置面板显隐
    property bool showSettings: false

    // 便捷函数：读取输入框内容并发送
    function triggerSendMessage() {
        if (composer.text.trim().length === 0)
            return
        chatService.sendMessage(composer.text)
        composer.text = ""
    }

    // ── 整体布局 ──────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        // 右上角工具栏：设置、 清空
        Row {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Theme.spacingXS
            spacing: 0
            z: 1

            DankActionButton {
                iconName: "delete_sweep"
                tooltipText: "清空对话"
                buttonSize: 32
                iconSize: 24
                onClicked: chatService.clearHistory()
            }

            DankActionButton {
                iconName: "settings"
                tooltipText: "设置"
                buttonSize: 32
                iconSize: 24
                onClicked: root.showSettings = true
            }
        }

        // ── 消息列表 ──────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.cornerRadius
            color: Theme.surfaceContainer
            border.color: Theme.outlineMedium
            border.width: 1
            clip: true

            // 没有消息时的提示文字
            StyledText {
                anchors.centerIn: parent
                text: "发送消息开始对话"
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeMedium
                visible: chatService.messagesModel.count === 0
            }

            ListView {
                id: messageList
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                model: chatService.messagesModel
                spacing: Theme.spacingS
                clip: true

                // 新消息到来时自动滚动到底部
                onCountChanged: Qt.callLater(() => positionViewAtEnd())

                delegate: Item {
                    id: msgDelegate

                    // ListView 注入的数据
                    required property string role
                    required property string content

                    width: messageList.width
                    // 高度由气泡决定，气泡高度由文字 implicitHeight 决定（无循环依赖）
                    height: bubble.height + Theme.spacingXS

                    // 气泡：user 右对齐，assistant 左对齐
                    Rectangle {
                        id: bubble

                        anchors.right: msgDelegate.role === "user" ? parent.right : undefined
                        anchors.left:  msgDelegate.role === "user" ? undefined   : parent.left

                        // 用隐藏的单行 Text 测量自然宽度，避免 wrapMode 导致 implicitWidth 不可靠
                        readonly property real hPad: Theme.spacingM * 2
                        readonly property real maxWidth: parent.width * 0.8
                        width: Math.min(bubbleSizer.implicitWidth + hPad, maxWidth)
                        height: bubbleText.implicitHeight + Theme.spacingS * 2

                        radius: Theme.cornerRadius
                        color: msgDelegate.role === "user" ? "#1a2a4a" : "#202020"
                        border.color: msgDelegate.role === "user" ? "#80b1e5" : "#2a5c90"
                        border.width: 1

                        // 隐藏的单行测量器，只用于确定气泡宽度
                        // 用 StyledText 保证字体 metrics 与可见文字一致
                        StyledText {
                            id: bubbleSizer
                            text: msgDelegate.content
                            font.pixelSize: Theme.fontSizeMedium
                            visible: false
                            // 无 wrapMode，implicitWidth = 文字的真实单行宽度
                        }

                        StyledText {
                            id: bubbleText
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                leftMargin: Theme.spacingM
                                rightMargin: Theme.spacingM
                                topMargin: Theme.spacingS
                            }
                            text: msgDelegate.content
                            wrapMode: Text.WordWrap
                            elide: Text.ElideNone
                            color: "#e8eaf0"
                            font.pixelSize: Theme.fontSizeMedium
                        }
                    }
                }
            }
        }

        // ── 输入区 ────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 100
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh
            border.color: composerFlick.activeFocus || composer.activeFocus
                ? Theme.primary : Theme.outlineMedium
            border.width: composerFlick.activeFocus || composer.activeFocus ? 2 : 1

            Behavior on border.color {
                ColorAnimation { duration: 150 }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: 0

                // 用 Flickable + TextEdit 替代 ScrollView + TextArea
                // TextEdit 是低层组件，Keys 机制可正确拦截 Enter
                Flickable {
                    id: composerFlick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: composer.width
                    contentHeight: composer.implicitHeight
                    clip: true

                    // 让 Flickable 自身可获取焦点（用于边框高亮）
                    activeFocusOnTab: true

                    ScrollBar.vertical: ScrollBar {
                        policy: composerFlick.contentHeight > composerFlick.height
                            ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    }

                    TextEdit {
                        id: composer
                        width: composerFlick.width
                        wrapMode: TextEdit.Wrap
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        // 光标颜色
                        cursorDelegate: Rectangle {
                            width: 2
                            color: Theme.primary
                        }

                        // 占位提示（TextEdit 没有内置 placeholderText）
                        StyledText {
                            anchors.fill: parent
                            text: "输入消息…"
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeMedium
                            visible: composer.text.length === 0 && !composer.activeFocus
                        }

                        // Enter 发送，Shift+Enter 换行，Escape 关闭面板
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                root.hideRequested()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (event.modifiers & Qt.ShiftModifier) {
                                    // 换行
                                    event.accepted = false
                                } else {
                                    // 发送
                                    root.triggerSendMessage()
                                    event.accepted = true
                                }
                            }
                        }

                        // 内容增长时自动滚动到底部
                        onImplicitHeightChanged: {
                            if (implicitHeight > composerFlick.height)
                                composerFlick.contentY = implicitHeight - composerFlick.height
                        }
                    }
                }

                // 底部工具栏
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingXS

                    Item { Layout.fillWidth: true }

                    DankActionButton {
                        iconName: "send"
                        tooltipText: "发送"
                        buttonSize: 32
                        iconSize: 16
                        onClicked: root.triggerSendMessage()
                    }
                }
            }
        }
    }

    // ── 设置覆盖层 ────────────────────────────────────────────────
    // active 时才实例化，避免常驻内存
    Loader {
        anchors.fill: parent
        active: root.showSettings
        sourceComponent: Component {
            ChatSettings {
                anchors.fill: parent
                onCloseRequested: root.showSettings = false
            }
        }
    }
}

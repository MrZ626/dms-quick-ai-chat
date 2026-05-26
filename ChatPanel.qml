// ChatPanel.qml
// 聊天面板 UI：顶栏 + 消息列表 + 输入区
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

    // 通知 slideout 收起（绑定到 Escape 键 和 关闭按钮）
    signal hideRequested

    // 便捷函数：读取输入框内容并发送
    function sendCurrentMessage() {
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
                    height: bubble.height

                    // 气泡：user 右对齐，assistant 左对齐
                    Rectangle {
                        id: bubble

                        // user 消息靠右，assistant 消息靠左
                        anchors.right: msgDelegate.role === "user" ? parent.right : undefined
                        anchors.left:  msgDelegate.role === "user" ? undefined : parent.left

                        // 气泡最宽占 80%
                        width: Math.min(bubbleText.implicitWidth + Theme.spacingM * 2,
                                        parent.width * 0.8)
                        height: bubbleText.height + Theme.spacingS * 2

                        radius: Theme.cornerRadius
                        color: msgDelegate.role === "user"
                            ? Theme.primary
                            : Theme.surfaceContainerHigh

                        StyledText {
                            id: bubbleText
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: Theme.spacingM
                                topMargin: Theme.spacingS
                            }
                            text: msgDelegate.content
                            wrapMode: Text.WordWrap
                            color: msgDelegate.role === "user"
                                ? Theme.onPrimary
                                : Theme.surfaceText
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
            border.color: composer.activeFocus ? Theme.primary : Theme.outlineMedium
            border.width: composer.activeFocus ? 2 : 1

            // 边框颜色过渡动画
            Behavior on border.color {
                ColorAnimation { duration: 150 }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: 0

                // 多行文本输入框
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    TextArea {
                        id: composer
                        wrapMode: TextArea.Wrap
                        background: null
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        padding: 0

                        // 占位提示
                        placeholderText: "输入消息…"
                        placeholderTextColor: Theme.surfaceVariantText

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                root.hideRequested()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (event.modifiers & Qt.ShiftModifier) {
                                    // Shift+Enter：插入换行（默认行为）
                                    event.accepted = false
                                } else {
                                    // Enter：发送
                                    root.sendCurrentMessage()
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }

                // 底部工具栏：发送按钮
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingXS

                    Item { Layout.fillWidth: true }

                    DankActionButton {
                        iconName: "delete_sweep"
                        tooltipText: "清空对话"
                        buttonSize: 32
                        iconSize: 16
                        onClicked: chatService.clearHistory()
                    }

                    DankActionButton {
                        iconName: "send"
                        tooltipText: "发送"
                        buttonSize: 32
                        iconSize: 16
                        onClicked: root.sendCurrentMessage()
                    }
                }
            }
        }
    }
}

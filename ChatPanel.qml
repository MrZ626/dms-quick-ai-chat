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

    // 唯一外部依赖，由 DeepseekChat.qml 注入
    required property var chatService

    // 通知 slideout 收起（绑定到 Esc 键）
    signal hideRequested
    // 通知 slideout 切换展开状态（绑定到 Ctrl+Tab）
    signal toggleExpandRequested

    // 控制设置面板显隐
    property bool showSettings: false

    // Esc 统一入口：
    //   生成中 → 打断生成
    //   设置页打开 → 关闭设置页
    //   否则 → 收起面板
    function handleEscape() {
        if (chatService.isLoading) {
            chatService.abortRequest()
        } else if (showSettings) {
            if (settingsLoader.item)
                settingsLoader.item.triggerClose()
        } else {
            hideRequested()
        }
    }

    // 兜底：焦点不在输入框时（如设置页关闭后）也能响应 Esc
    Keys.onEscapePressed: event => {
        handleEscape()
        event.accepted = true
    }
    focus: true

    Component.onCompleted: composer.forceActiveFocus()

    // 便捷函数：读取输入框内容并发送
    function triggerSendMessage() {
        if (composer.text.trim().length === 0 || chatService.isLoading)
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

            // 欢迎文字
            Text {
                anchors.centerIn: parent
                textFormat: Text.MarkdownText
                text: chatService.proMode ? "使用  **󰇈  专家模式**  开始对话" : "使用  **󱐋  快速模式**  开始对话"
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeLarge
                visible: chatService.messagesModel.count === 0
            }

            ListView {
                id: messageList
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                model: chatService.messagesModel
                spacing: Theme.spacingS
                clip: true

                // 自动滚动标记：新消息时 true，用户手动拖动后 false
                property bool _autoScroll: true

                onCountChanged: {
                    _autoScroll = true
                    positionViewAtEnd()
                }

                onContentHeightChanged: {
                    if (_autoScroll)
                        Qt.callLater(() => positionViewAtEnd())
                }

                // 用户主动拖动/滚轮 → 切换手动模式
                onMovementStarted: _autoScroll = false

                delegate: Item {
                    id: msgDelegate

                    // ListView 注入的数据
                    required property string role
                    required property string content
                    required property string status

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
                        readonly property bool isLoading: msgDelegate.status === "loading" && msgDelegate.content.length === 0
                        readonly property bool isError:   msgDelegate.status === "error"
                        // assistant 消息渲染完成后用 maxWidth（Markdown 标题/代码块宽度不可预测）
                        readonly property bool useMaxWidth: msgDelegate.role === "assistant"
                                                         && msgDelegate.status === "ok"

                        // loading 时固定宽度，assistant ok 时用 maxWidth，其余动态量宽
                        width: isLoading
                            ? 72
                            : (useMaxWidth
                               ? maxWidth
                               : Math.min(bubbleSizer.contentWidth + hPad, maxWidth))
                        height: (isLoading ? 28 : bubbleText.implicitHeight)
                            + Theme.spacingS * 2

                        radius: Theme.cornerRadius
                        color: msgDelegate.role === "user"
                            ? "#1a2a4a"
                            : (isError ? "#2a1a1a" : "#202020")
                        border.color: msgDelegate.role === "user"
                            ? "#80b1e5"
                            : (isError ? "#a52e2e" : "#356496")
                        border.width: 1

                        // 隐藏的单行测量器：用 TextEdit 保证 metrics 与 bubbleText 完全一致
                        TextEdit {
                            id: bubbleSizer
                            text: msgDelegate.content
                            font.pixelSize: Theme.fontSizeMedium
                            wrapMode: TextEdit.NoWrap
                            width: 10000        // 不限宽，contentWidth 即单行真实宽度
                            visible: false
                            enabled: false
                        }

                        // 气泡文字
                        // 流式生成中用 PlainText，完成后切换为 MarkdownText
                        TextEdit {
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
                            textFormat: (msgDelegate.role === "assistant" && msgDelegate.status === "ok")
                                        ? TextEdit.MarkdownText
                                        : TextEdit.PlainText
                            wrapMode: Text.Wrap
                            readOnly: true
                            selectByMouse: true
                            color: bubble.isError ? "#e8a0a0" : "#e8eaf0"
                            font.pixelSize: Theme.fontSizeMedium
                            selectionColor: Theme.primary
                            selectedTextColor: Theme.onPrimary
                            visible: !bubble.isLoading
                        }

                        // loading 动画（三个跳动的点）
                        Row {
                            id: loadingDots
                            anchors.centerIn: parent
                            spacing: 6
                            visible: bubble.isLoading

                            Repeater {
                                model: 3
                                delegate: Rectangle {
                                    required property int index
                                    width: 8; height: 8; radius: 4
                                    color: "#80b0e0"

                                    SequentialAnimation on y {
                                        loops: Animation.Infinite
                                        running: bubble.isLoading
                                        PauseAnimation { duration: index * 160 }
                                        NumberAnimation { to: -7; duration: 260; easing.type: Easing.InOutSine }
                                        NumberAnimation { to:  0; duration: 260; easing.type: Easing.InOutSine }
                                        PauseAnimation { duration: (2 - index) * 160 }
                                    }
                                }
                            }
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
                        height: Math.max(implicitHeight, composerFlick.height)
                        wrapMode: TextEdit.Wrap
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        cursorDelegate: Rectangle {
                            width: 2
                            color: Theme.primary
                        }

                        // 占位提示
                        StyledText {
                            anchors {
                                left: parent.left
                                top: parent.top
                            }
                            text: "输入消息内容…"
                            color: Qt.rgba(Theme.surfaceVariantText.r, Theme.surfaceVariantText.g, Theme.surfaceVariantText.b, 0.62)
                            font.pixelSize: Theme.fontSizeMedium
                            visible: composer.text.length === 0
                        }
                        StyledText {
                            anchors {
                                left: parent.left
                                bottom: parent.bottom
                            }
                            text: "Esc中断/关闭，Tab展开\nCtrl+N清空，Ctrl+M切模型"
                            color: Qt.rgba(Theme.surfaceVariantText.r, Theme.surfaceVariantText.g, Theme.surfaceVariantText.b, 0.62)
                            font.pixelSize: Theme.fontSizeMedium
                            visible: composer.text.length === 0
                        }

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                root.handleEscape()
                                event.accepted = true
                            } else if (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier)) {
                                chatService.clearHistory()
                                event.accepted = true
                            } else if (event.key === Qt.Key_M && (event.modifiers & Qt.ControlModifier)) {
                                chatService.proMode = !chatService.proMode
                                event.accepted = true
                            } else if (event.key === Qt.Key_Tab) {
                                root.toggleExpandRequested()
                                event.accepted = true
                            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                                root.triggerSendMessage()
                                event.accepted = true
                            }
                        }

                        // 内容增长时自动滚动到底部
                        onImplicitHeightChanged: {
                            if (implicitHeight > composerFlick.height)
                                composerFlick.contentY = implicitHeight - composerFlick.height
                        }
                    }
                }
            }

            // 专家模式开关
            Rectangle {
                id: proModeBtn
                anchors { right: sendBtn.left; bottom: parent.bottom; margins: Theme.spacingS }
                width: 28; height: 28; radius: 14
                color:        chatService.proMode ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : "transparent"
                border.color: chatService.proMode ? Theme.primary : Theme.outlineMedium

                Text {
                    anchors.centerIn: parent
                    text: "󰇈"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 17
                    color: chatService.proMode ? Theme.primary : Theme.surfaceVariantText
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: chatService.proMode = !chatService.proMode
                }
            }

            // 发送 / 停止按钮：浮在输入框右下角，不参与 layout
            Rectangle {
                id: sendBtn
                anchors { right: parent.right; bottom: parent.bottom; margins: Theme.spacingS }
                width: 28; height: 28; radius: 14
                color: Theme.primary

                Text {
                    anchors.centerIn: parent
                    text: chatService.isLoading ? "󰓛" : "󰁝"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 20
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: chatService.isLoading ? chatService.abortRequest() : root.triggerSendMessage()
                }
            }
        }
    }

    // ── 设置覆盖层 ────────────────────────────────────────────────
    // active 时才实例化，避免常驻内存
    Loader {
        id: settingsLoader
        anchors.fill: parent
        active: root.showSettings
        sourceComponent: Component {
            ChatSettings {
                anchors.fill: parent
                chatService: root.chatService
                // 返回时只需关闭面板，数据已在 triggerClose() 内写回
                onCloseRequested: {
                    root.showSettings = false
                    composer.forceActiveFocus()
                }
            }
        }
    }
}

// ChatSettings.qml
// 设置覆盖层：覆盖在 ChatPanel 上方，点击返回按钮回到聊天界面

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Common
import qs.Widgets

Item {
    id: root

    signal closeRequested

    // ── 设置项（由 ChatPanel 从 chatService 注入）─────────────────
    property string baseUrl:     ""
    property string model:       ""
    property string apiKey:      ""
    property real   temperature: 0
    property int    maxTokens:   0

    // ── 可编辑文本行 ──────────────────────────────────────────────
    component EditRow: ColumnLayout {
        property string label: ""
        property string value: ""
        property bool obscure: false

        // 外部通过 fieldInput.text 读取用户编辑后的值
        property alias currentText: fieldInput.text

        Layout.fillWidth: true
        spacing: 2

        StyledText {
            text: label
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        Rectangle {
            Layout.fillWidth: true
            height: fieldInput.implicitHeight + Theme.spacingS * 2
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh
            border.color: fieldInput.activeFocus ? Theme.primary : Theme.outlineMedium
            border.width: fieldInput.activeFocus ? 2 : 1

            Behavior on border.color { ColorAnimation { duration: 150 } }

            TextInput {
                id: fieldInput
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: Theme.spacingM
                    rightMargin: Theme.spacingM
                }
                text: value
                echoMode: obscure ? TextInput.Password : TextInput.Normal
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                selectionColor: Theme.primary
                selectedTextColor: Theme.onPrimary
                clip: true

                HoverHandler { cursorShape: Qt.IBeamCursor }
            }
        }
    }

    // ── 滑条行 ────────────────────────────────────────────────────
    component SliderRow: ColumnLayout {
        property string label: ""
        property real value: 0
        property real from: 0
        property real to: 1
        property real stepSize: 0.1

        // 外部通过 slider.value 读取用户拖动后的值
        property alias currentValue: slider.value

        Layout.fillWidth: true
        spacing: 2

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                text: label
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                Layout.fillWidth: true
            }

            StyledText {
                text: slider.value.toFixed(1)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
            }
        }

        Slider {
            id: slider
            Layout.fillWidth: true
            from: parent.from
            to: parent.to
            stepSize: parent.stepSize
            value: parent.value

            HoverHandler { cursorShape: Qt.PointingHandCursor }

            background: Rectangle {
                x: slider.leftPadding
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: slider.availableWidth
                height: 4
                radius: 2
                color: Theme.outlineMedium

                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height
                    radius: parent.radius
                    color: Theme.primary
                }
            }

            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: 18
                height: 18
                radius: 9
                color: slider.pressed ? Theme.primaryContainer : Theme.primary
                border.color: Theme.outlineMedium
                border.width: 1
            }
        }
    }

    // 拦截所有鼠标事件，防止穿透到下层 ChatPanel
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
    }

    // 背景
    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        radius: Theme.cornerRadius
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingM

        // ── 顶栏 ──────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS

            DankActionButton {
                iconName: "arrow_back"
                tooltipText: "保存并返回"
                onClicked: {
                    // 返回时一次性写回所有设置项
                    root.baseUrl     = fieldBaseUrl.currentText
                    root.model       = fieldModel.currentText
                    root.apiKey      = fieldApiKey.currentText
                    root.maxTokens   = parseInt(fieldMaxTokens.currentText) || root.maxTokens
                    root.temperature = sliderTemp.currentValue
                    root.closeRequested()
                }
            }

            StyledText {
                text: "设置"
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                color: Theme.surfaceText
                Layout.fillWidth: true
            }
        }

        // ── 设置项 ────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS

            EditRow {
                id: fieldBaseUrl
                label: "服务商URL"
                value: root.baseUrl
            }

            EditRow {
                id: fieldModel
                label: "模型ID"
                value: root.model
            }

            EditRow {
                id: fieldApiKey
                label: "API Key"
                value: root.apiKey
                obscure: true
            }

            EditRow {
                id: fieldMaxTokens
                label: "最大Token数"
                value: root.maxTokens.toString()
            }

            SliderRow {
                id: sliderTemp
                label: "温度（越高越随机）"
                value: root.temperature
                from: 0
                to: 2
                stepSize: 0.1
            }
        }

        Item { Layout.fillHeight: true }
    }
}

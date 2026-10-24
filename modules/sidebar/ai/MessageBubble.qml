pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: delegateItem

    required property string text
    required property bool isUser
    required property bool isFinished
    required property string thoughtText
    required property string toolCallsJson

    width: parent ? parent.width : 400
    visible: (!delegateItem.isFinished && AiEngine.isThinking)
        ? false
        : (delegateItem.text !== "" || delegateItem.thoughtText !== "")
    height: visible ? bubbleRect.height : 0

    scale: 0.0
    opacity: 0.0

    Component.onCompleted: {
        popInAnim.start();
    }

    ParallelAnimation {
        id: popInAnim
        NumberAnimation { target: delegateItem; property: "scale"; from: 0.8; to: 1.0; duration: 300; easing.type: Easing.OutBack }
        NumberAnimation { target: delegateItem; property: "opacity"; from: 0.0; to: 1.0; duration: 200; easing.type: Easing.OutQuad }
    }

    SequentialAnimation {
        id: popDoneAnim
        NumberAnimation { target: delegateItem; property: "scale"; from: 1.0; to: 1.02; duration: 100; easing.type: Easing.OutQuad }
        NumberAnimation { target: delegateItem; property: "scale"; from: 1.02; to: 1.0; duration: 150; easing.type: Easing.OutSine }
    }

    onIsFinishedChanged: {
        if (isFinished) popDoneAnim.start();
    }

    StyledRect {
        id: bubbleRect
        readonly property real maxBubbleWidth: delegateItem.width * 0.85
        anchors.right: delegateItem.isUser ? parent.right : undefined
        anchors.rightMargin: delegateItem.isUser ? Tokens.padding.large : 0
        anchors.left: delegateItem.isUser ? undefined : parent.left
        anchors.leftMargin: delegateItem.isUser ? 0 : Tokens.padding.large

        width: Math.min(maxBubbleWidth, bubbleLayout.implicitWidth + Tokens.padding.medium * 2 + 8)
        height: bubbleLayout.implicitHeight + Tokens.padding.medium * 2
        radius: Tokens.rounding.large
        color: delegateItem.isUser ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainer

        // Asymmetric Material 3 message corners
        topLeftRadius: Tokens.rounding.large
        topRightRadius: Tokens.rounding.large
        bottomLeftRadius: delegateItem.isUser ? Tokens.rounding.large : 4
        bottomRightRadius: delegateItem.isUser ? 4 : Tokens.rounding.large

        Column {
            id: bubbleLayout
            anchors.top: parent.top
            anchors.topMargin: Tokens.padding.medium
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Tokens.spacing.small

            property string delegateThought: delegateItem.thoughtText
            property bool isExpanded: false

            // Collapsible Thought Process Header
            Item {
                visible: bubbleLayout.delegateThought !== ""
                implicitWidth: thoughtRow.implicitWidth
                implicitHeight: thoughtRow.implicitHeight
                height: visible ? implicitHeight : 0

                Row {
                    id: thoughtRow
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: qsTr("Thought Process")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                    }

                    MaterialIcon {
                        id: thoughtArrow
                        text: "expand_more"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.small
                        rotation: bubbleLayout.isExpanded ? 180 : 0
                        Behavior on rotation { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bubbleLayout.isExpanded = !bubbleLayout.isExpanded
                }
            }

            // Collapsible Thought Process Content
            Item {
                id: thoughtContentWrapper
                width: thoughtContent.width
                height: bubbleLayout.isExpanded ? thoughtContent.implicitHeight : 0
                clip: true

                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

                TextEdit {
                    id: thoughtContent
                    width: Math.min(implicitWidth, bubbleRect.maxBubbleWidth - Tokens.padding.medium * 2)
                    textFormat: Text.MarkdownText

                    property string fullThought: bubbleLayout.delegateThought
                    property bool cursorVisible: true

                    Timer {
                        running: !delegateItem.isFinished
                        repeat: true
                        interval: 400
                        onTriggered: thoughtContent.cursorVisible = !thoughtContent.cursorVisible
                    }

                    text: delegateItem.isFinished ? fullThought : fullThought + (cursorVisible ? "▌" : "")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    wrapMode: Text.Wrap
                    readOnly: true
                    selectByMouse: true
                    selectionColor: Colours.palette.m3primary
                    selectedTextColor: Colours.palette.m3onPrimary
                    opacity: bubbleLayout.isExpanded ? 1.0 : 0.0

                    Behavior on opacity {
                        SequentialAnimation {
                            PauseAnimation { duration: bubbleLayout.isExpanded ? 100 : 0 }
                            NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                        }
                    }
                }
            }

            // Main Streaming / Markdown Message Text
            TextEdit {
                id: messageText
                textFormat: Text.MarkdownText
                width: Math.min(implicitWidth, bubbleRect.maxBubbleWidth - Tokens.padding.medium * 2)

                property string fullText: delegateItem.text !== undefined ? delegateItem.text : ""
                property bool cursorVisible: true

                Timer {
                    running: !delegateItem.isFinished
                    repeat: true
                    interval: 400
                    onTriggered: messageText.cursorVisible = !messageText.cursorVisible
                }

                text: delegateItem.isFinished ? fullText : fullText + (cursorVisible ? "▌" : "")
                color: delegateItem.isUser ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                font: Tokens.font.body.small
                wrapMode: Text.Wrap
                readOnly: true
                selectByMouse: true
                selectionColor: Colours.palette.m3primary
                selectedTextColor: Colours.palette.m3onPrimary
                onLinkActivated: link => Qt.openUrlExternally(link)

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.IBeamCursor
                    propagateComposedEvents: true
                    onPressed: mouse => mouse.accepted = false
                }
            }
        }
    }
}

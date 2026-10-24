pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

Item {
    id: root

    signal suggestionSelected(string promptText)

    Connections {
        target: AiEngine
        function onScrollToBottomRequested() {
            listView.positionViewAtEnd();
        }
    }

    VerticalFadeListView {
        id: listView
        anchors.fill: parent
        spacing: Tokens.spacing.medium
        model: AiEngine.chatHistory
        boundsBehavior: Flickable.StopAtBounds

        // Empty State (Logo + Personalized Greeting + Pill Starters)
        LilithMascot {
            anchors.centerIn: parent
            opacity: AiEngine.chatHistory.count === 0 && !AiEngine.isTyping && !AiEngine.isThinking ? 1.0 : 0.0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
            onSuggestionSelected: promptText => root.suggestionSelected(promptText)
        }

        ScrollBar.vertical: StyledScrollBar {
            flickable: listView
        }

        // Authentic Caelestia M3 Expressive Thinking Footer Bubble
        footer: Item {
            width: listView.width
            height: AiEngine.isThinking ? bubbleBg.height + Tokens.spacing.medium : 0
            visible: opacity > 0
            opacity: AiEngine.isThinking ? 1 : 0

            Behavior on height { Anim { type: Anim.DefaultSpatial } }
            Behavior on opacity { Anim { type: Anim.DefaultSpatial } }

            StyledRect {
                id: bubbleBg
                x: Tokens.padding.large
                y: Tokens.spacing.medium / 2
                width: Math.min(listView.width * 0.85, footerCol.implicitWidth + Tokens.padding.medium * 2 + 8)
                height: footerCol.implicitHeight + Tokens.padding.medium * 2
                radius: Tokens.rounding.large
                color: Colours.tPalette.m3surfaceContainer

                // Asymmetric corners matching assistant bubbles
                topLeftRadius: Tokens.rounding.large
                topRightRadius: Tokens.rounding.large
                bottomLeftRadius: 4
                bottomRightRadius: Tokens.rounding.large

                Column {
                    id: footerCol
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    spacing: Tokens.spacing.small

                    Row {
                        spacing: Tokens.spacing.small

                        LoadingIndicator {
                            width: 20
                            height: 20
                            color: Colours.palette.m3primary
                        }

                        // M3 Expressive Animated Action Text Wrapper
                        Item {
                            width: mainText.implicitWidth
                            height: mainText.implicitHeight
                            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                            StyledText {
                                id: mainText
                                text: displayedText
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.body.small

                                property string displayedText: AiEngine.currentActionText
                                property string nextText: ""

                                transform: Translate { id: textTrans; y: 0 }
                                opacity: 1.0

                                Connections {
                                    target: AiEngine
                                    function onCurrentActionTextChanged() {
                                        if (AiEngine.currentActionText !== mainText.displayedText) {
                                            mainText.nextText = AiEngine.currentActionText;
                                            switchAnim.restart();
                                        }
                                    }
                                }

                                SequentialAnimation {
                                    id: switchAnim
                                    ParallelAnimation {
                                        NumberAnimation { target: textTrans; property: "y"; to: -8; duration: 150; easing.type: Easing.InCubic }
                                        NumberAnimation { target: mainText; property: "opacity"; to: 0.0; duration: 150; easing.type: Easing.InCubic }
                                    }
                                    PropertyAction { target: mainText; property: "displayedText"; value: mainText.nextText }
                                    PropertyAction { target: textTrans; property: "y"; value: 8 }
                                    ParallelAnimation {
                                        NumberAnimation { target: textTrans; property: "y"; to: 0; duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
                                        NumberAnimation { target: mainText; property: "opacity"; to: 1.0; duration: 250; easing.type: Easing.OutQuad }
                                    }
                                }

                                SequentialAnimation {
                                    running: AiEngine.isThinking && !switchAnim.running
                                    loops: Animation.Infinite
                                    NumberAnimation { target: mainText; property: "opacity"; from: 1.0; to: 0.4; duration: 800; easing.type: Easing.InOutSine }
                                    NumberAnimation { target: mainText; property: "opacity"; from: 0.4; to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                                }
                            }
                        }

                        Item {
                            visible: AiEngine.currentThoughtText !== ""
                            width: Tokens.spacing.medium
                            height: 1
                        }

                        Item {
                            visible: AiEngine.currentThoughtText !== ""
                            width: thoughtRowFooter.implicitWidth
                            height: thoughtRowFooter.implicitHeight

                            Row {
                                id: thoughtRowFooter
                                spacing: Tokens.spacing.small

                                MaterialIcon {
                                    text: "expand_more"
                                    color: Colours.palette.m3onSurfaceVariant
                                    fontStyle: Tokens.font.icon.small
                                    rotation: AiEngine.isThoughtExpanded ? 180 : 0
                                    Behavior on rotation { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -10
                                cursorShape: Qt.PointingHandCursor
                                onClicked: AiEngine.isThoughtExpanded = !AiEngine.isThoughtExpanded
                            }
                        }
                    }

                    Item {
                        id: footerThoughtContentWrapper
                        width: footerThoughtContent.width
                        height: AiEngine.isThoughtExpanded ? footerThoughtContent.implicitHeight : 0
                        clip: true

                        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

                        TextEdit {
                            id: footerThoughtContent
                            width: Math.min(implicitWidth, listView.width * 0.85 - Tokens.padding.medium * 2)
                            textFormat: Text.MarkdownText
                            text: AiEngine.currentThoughtText
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.body.small
                            wrapMode: Text.Wrap
                            readOnly: true
                            selectByMouse: true
                            selectionColor: Colours.palette.m3primary
                            selectedTextColor: Colours.palette.m3onPrimary
                            opacity: AiEngine.isThoughtExpanded ? 1.0 : 0.0

                            Behavior on opacity {
                                SequentialAnimation {
                                    PauseAnimation { duration: AiEngine.isThoughtExpanded ? 100 : 0 }
                                    NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                                }
                            }
                        }
                    }
                }
            }
        }

        delegate: MessageBubble {
            width: listView.width
        }
    }
}

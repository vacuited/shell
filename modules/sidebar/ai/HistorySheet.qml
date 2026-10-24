pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    GridView {
        id: historyGrid
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: newChatButton.top
        anchors.bottomMargin: Tokens.spacing.medium
        clip: true

        cellWidth: width / 2
        cellHeight: 90
        model: AiEngine.historySessionsModel

        delegate: Item {
            id: gridDelegate
            required property var model
            readonly property string chatId: model && model.id ? String(model.id) : ""
            readonly property string chatTitle: model && model.title ? String(model.title) : ""
            readonly property string chatPreview: model && model.preview ? String(model.preview) : ""
            readonly property string chatUpdated: model && model.updated ? String(model.updated) : ""
            readonly property string chatIcon: model && model.providerIcon ? String(model.providerIcon) : "chat"

            width: historyGrid.cellWidth
            height: historyGrid.cellHeight

            StyledRect {
                anchors.fill: parent
                anchors.margins: Tokens.spacing.small
                radius: Tokens.rounding.medium
                color: Colours.tPalette.m3surfaceContainerHigh

                StateLayer {
                    radius: Tokens.rounding.medium
                    onClicked: AiEngine.loadChat(gridDelegate.chatId)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small
                    spacing: Tokens.spacing.medium

                    StyledRect {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 16
                        color: Colours.tPalette.m3surfaceContainerHighest

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: gridDelegate.chatIcon
                            color: Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.small
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: gridDelegate.chatTitle ? gridDelegate.chatTitle : qsTr("New Chat")
                            color: Colours.palette.m3onSurface
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: gridDelegate.chatPreview !== ""
                            text: gridDelegate.chatPreview
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: gridDelegate.chatUpdated !== ""
                            text: gridDelegate.chatUpdated
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    Item {
                        Layout.alignment: Qt.AlignTop | Qt.AlignRight
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24

                        StyledRect {
                            anchors.fill: parent
                            radius: 12
                            color: Colours.palette.m3onSurfaceVariant
                            opacity: deleteMouseArea.containsMouse ? 0.12 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "close"
                            fontStyle: Tokens.font.icon.small
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        MouseArea {
                            id: deleteMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AiEngine.deleteChat(gridDelegate.chatId)
                        }
                    }
                }
            }
        }
    }

    // "Clear All" Pill Button
    StyledRect {
        id: clearAllButton
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: clearAllLayout.implicitWidth + Tokens.padding.large * 2
        height: 32
        radius: 16
        color: Colours.palette.m3errorContainer

        StateLayer {
            radius: 16
            onClicked: AiEngine.clearAllHistory()
        }

        RowLayout {
            id: clearAllLayout
            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "delete"
                color: Colours.palette.m3onErrorContainer
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                text: qsTr("Clear All")
                color: Colours.palette.m3onErrorContainer
                font: Tokens.font.body.small
            }
        }
    }

    // "New Chat" Pill Button
    StyledRect {
        id: newChatButton
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: newChatLayout.implicitWidth + Tokens.padding.large * 2
        height: 32
        radius: 16
        color: Colours.palette.m3primaryContainer

        StateLayer {
            radius: 16
            onClicked: AiEngine.createNewChat()
        }

        RowLayout {
            id: newChatLayout
            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "add"
                color: Colours.palette.m3onPrimaryContainer
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                text: qsTr("New Chat")
                color: Colours.palette.m3onPrimaryContainer
                font: Tokens.font.body.small
            }
        }
    }
}

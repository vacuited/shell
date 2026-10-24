pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

ColumnLayout {
    id: root

    property string toolCallsJson: "[]"

    readonly property var toolCalls: {
        if (!toolCallsJson || toolCallsJson === "[]") return [];
        try {
            var parsed = JSON.parse(toolCallsJson);
            return Array.isArray(parsed) ? parsed : [];
        } catch (e) {
            return [];
        }
    }

    visible: toolCalls.length > 0
    spacing: Tokens.spacing.extraSmall

    function iconForTool(name) {
        if (!name) return "build";
        if (name.indexOf("web_search") !== -1) return "travel_explore";
        if (name.indexOf("read_webpage") !== -1) return "article";
        if (name.indexOf("screenshot") !== -1) return "screenshot_monitor";
        if (name.indexOf("clipboard") !== -1) return "content_paste";
        if (name.indexOf("spotify") !== -1 || name.indexOf("media") !== -1) return "music_note";
        if (name.indexOf("weather") !== -1) return "partly_cloudy_day";
        if (name.indexOf("reminder") !== -1 || name.indexOf("notify") !== -1) return "notifications_active";
        if (name.indexOf("memory") !== -1 || name.indexOf("memories") !== -1) return "bookmark";
        if (name.indexOf("system") !== -1 || name.indexOf("caelestia") !== -1) return "terminal";
        return "handyman";
    }

    function formatToolName(name) {
        if (!name) return qsTr("Tool");
        return name.replace(/_/g, " ").replace(/\b\w/g, c => c.toUpperCase());
    }

    Repeater {
        model: root.toolCalls

        delegate: StyledRect {
            id: toolCard

            required property var modelData
            property bool detailsOpen: false

            readonly property bool isRunning: modelData.status === "running"
            readonly property string argsText: modelData.args || ""
            readonly property string resultText: modelData.result || ""

            Layout.fillWidth: true
            implicitHeight: cardCol.implicitHeight + Tokens.padding.small * 2
            radius: Tokens.rounding.medium
            color: Colours.tPalette.m3surfaceContainer
            border.width: 1
            border.color: isRunning
                ? Qt.rgba(Colours.palette.m3tertiary.r, Colours.palette.m3tertiary.g, Colours.palette.m3tertiary.b, 0.5)
                : Colours.tPalette.m3outlineVariant

            ColumnLayout {
                id: cardCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.small
                spacing: toolCard.detailsOpen ? Tokens.spacing.extraSmall : 0

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 24

                    StateLayer {
                        anchors.fill: parent
                        radius: Tokens.rounding.small
                        color: Colours.palette.m3onSurface
                        onClicked: toolCard.detailsOpen = !toolCard.detailsOpen
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.extraSmall
                        anchors.rightMargin: Tokens.padding.extraSmall
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: root.iconForTool(toolCard.modelData.name)
                            fontStyle: Tokens.font.icon.small
                            color: toolCard.isRunning ? Colours.palette.m3tertiary : Colours.palette.m3primary
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.formatToolName(toolCard.modelData.name)
                            font: Tokens.font.label.medium
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        // Status Pill
                        StyledRect {
                            implicitWidth: statusRow.implicitWidth + Tokens.padding.small * 2
                            implicitHeight: 20
                            radius: Tokens.rounding.full
                            color: toolCard.isRunning
                                ? Colours.tPalette.m3tertiaryContainer
                                : Colours.tPalette.m3secondaryContainer

                            Row {
                                id: statusRow
                                anchors.centerIn: parent
                                spacing: 4

                                MaterialIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: toolCard.isRunning ? "progress_activity" : "check_circle"
                                    fontStyle: Tokens.font.icon.small
                                    color: toolCard.isRunning
                                        ? Colours.palette.m3onTertiaryContainer
                                        : Colours.palette.m3onSecondaryContainer

                                    RotationAnimator on rotation {
                                        from: 0
                                        to: 360
                                        duration: 1100
                                        loops: Animation.Infinite
                                        running: toolCard.isRunning
                                    }
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: toolCard.isRunning ? qsTr("Running") : qsTr("Done")
                                    font: Tokens.font.label.small
                                    color: toolCard.isRunning
                                        ? Colours.palette.m3onTertiaryContainer
                                        : Colours.palette.m3onSecondaryContainer
                                }
                            }
                        }

                        MaterialIcon {
                            text: toolCard.detailsOpen ? "expand_less" : "expand_more"
                            fontStyle: Tokens.font.icon.small
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }
                }

                // Expandable Parameters & Output Preview
                StyledRect {
                    Layout.fillWidth: true
                    visible: toolCard.detailsOpen
                    implicitHeight: visible ? detailsCol.implicitHeight + Tokens.padding.small * 2 : 0
                    radius: Tokens.rounding.small
                    color: Colours.tPalette.m3surfaceContainerLowest

                    ColumnLayout {
                        id: detailsCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Tokens.padding.small
                        spacing: 4

                        StyledText {
                            Layout.fillWidth: true
                            visible: toolCard.argsText.length > 0 && toolCard.argsText !== "{}"
                            text: qsTr("Args: %1").arg(toolCard.argsText)
                            font: Tokens.font.body.small
                            color: Colours.palette.m3onSurfaceVariant
                            wrapMode: Text.WrapAnywhere
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: toolCard.resultText.length > 0
                            text: toolCard.resultText
                            font: Tokens.font.body.small
                            color: Colours.palette.m3onSurface
                            wrapMode: Text.Wrap
                            maximumLineCount: 8
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}

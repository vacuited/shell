pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Blobs
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.services
import "../../../components/controls"

Item {
    id: root

    property bool open
    readonly property real padding: Tokens.padding.medium
    readonly property int expandedWidth: 312
    readonly property bool hasTrack: Boolean(Players.active) || Lyrics.hasLyrics || Lyrics.trackTitle !== ""

    function backendDisplayName(b: int): string {
        switch (b) {
        case LyricsBackend.Local:
            return qsTr("Local");
        case LyricsBackend.Boidu:
            return "Boidu";
        case LyricsBackend.LyricsPlus:
            return "LyricsPlus";
        case LyricsBackend.NetEase:
            return "NetEase";
        case LyricsBackend.LRCLIB:
            return "LRCLIB";
        default:
            return qsTr("Automatic");
        }
    }

    onHasTrackChanged: {
        if (!hasTrack)
            open = false;
    }

    implicitWidth: btn.implicitWidth * 0.9
    implicitHeight: btn.implicitHeight * 0.9

    BlobGroup {
        id: blobGroup

        color: Colours.palette.m3surfaceContainerHighest
        smoothing: root.Tokens.rounding.medium
        cornerFill: false

        Behavior on color {
            CAnim {}
        }
    }

    BlobRect {
        id: btnRect

        anchors.fill: parent
        anchors.margins: !btn.pressed && btn.containsMouse ? -Tokens.padding.extraSmall : 0
        group: blobGroup
        radius: Tokens.rounding.medium

        Behavior on anchors.margins {
            Anim {}
        }
    }

    BlobRect {
        id: rect

        anchors.right: parent.right
        anchors.top: parent.top

        implicitWidth: parent.width
        implicitHeight: parent.height

        group: blobGroup
        radius: Tokens.rounding.medium
        deformScale: 0.00001

        states: State {
            name: "open"
            when: root.open

            PropertyChanges {
                rect.anchors.rightMargin: root.width - root.Tokens.spacing.small
                rect.anchors.topMargin: -root.Tokens.padding.medium
                rect.implicitWidth: root.hasTrack
                    ? Math.min(340, Math.max(280, root.expandedWidth))
                    : Math.min(340, Math.max(250, placeholder.implicitWidth + root.padding * 2))
                rect.implicitHeight: (root.hasTrack ? layout.implicitHeight : placeholder.implicitHeight) + root.padding * 2
                content.opacity: 1
            }
        }

        transitions: Transition {
            Anim {
                properties: "rightMargin,implicitWidth"
            }
            Anim {
                properties: "topMargin,implicitHeight"
                easing: root.Tokens.anim.expressiveFastSpatial
            }
            Anim {
                property: "opacity"
                type: Anim.DefaultEffects
            }
        }

        Behavior on implicitWidth {
            Anim {}
        }

        Behavior on implicitHeight {
            Anim {}
        }

        Item {
            id: content

            anchors.fill: parent
            clip: true
            opacity: 0
            state: root.hasTrack ? "hasTrack" : ""

            states: State {
                name: "hasTrack"

                PropertyChanges {
                    layout.opacity: 1
                    placeholder.opacity: 0
                }
            }

            transitions: [
                Transition {
                    from: "hasTrack"

                    SequentialAnimation {
                        Anim {
                            target: layout
                            property: "opacity"
                            type: Anim.FastEffects
                        }
                        Anim {
                            target: placeholder
                            property: "opacity"
                            type: Anim.DefaultEffects
                        }
                    }
                },
                Transition {
                    to: "hasTrack"

                    SequentialAnimation {
                        Anim {
                            target: placeholder
                            property: "opacity"
                            type: Anim.FastEffects
                        }
                        Anim {
                            target: layout
                            property: "opacity"
                            type: Anim.DefaultEffects
                        }
                    }
                }
            ]

            ColumnLayout {
                id: layout

                anchors.centerIn: parent
                width: root.expandedWidth - root.padding * 2
                spacing: Tokens.spacing.extraSmall
                opacity: 0

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Lyrics source")
                        font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                        animate: true
                    }

                    IconButton {
                        icon: "refresh"
                        type: IconButton.Text
                        font: Tokens.font.icon.small
                        disabled: !root.hasTrack
                        onClicked: Lyrics.refresh()
                    }
                }

                // Automatic row
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: Math.max(34, autoTextCol.implicitHeight + Tokens.padding.extraSmall * 2)
                    radius: Tokens.rounding.medium
                    color: !Lyrics.manualSource ? Colours.palette.m3secondaryContainer : "transparent"
                    border.width: !Lyrics.manualSource ? 1 : 0
                    border.color: Colours.palette.m3secondary

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.small
                        anchors.rightMargin: Tokens.padding.small
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: "auto_awesome"
                            fontStyle: Tokens.font.icon.small
                            color: !Lyrics.manualSource ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                        }

                        ColumnLayout {
                            id: autoTextCol

                            Layout.fillWidth: true
                            spacing: -2

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Automatic")
                                font: Tokens.font.label.builders.small.weight(!Lyrics.manualSource ? Font.Bold : Font.Medium).build()
                                color: !Lyrics.manualSource ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: !Lyrics.manualSource
                                text: Lyrics.hasLyrics
                                    ? qsTr("Showing %1").arg(root.backendDisplayName(Lyrics.backend))
                                    : (Lyrics.loading ? qsTr("Waiting...") : qsTr("No lyrics found"))
                                font: Tokens.font.label.builders.small.scale(0.85).build()
                                color: !Lyrics.manualSource ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                                opacity: 0.85
                                elide: Text.ElideRight
                            }
                        }

                        MaterialIcon {
                            visible: !Lyrics.manualSource
                            text: "check"
                            fontStyle: Tokens.font.icon.small
                            color: Colours.palette.m3onSecondaryContainer
                        }
                    }

                    StateLayer {
                        onClicked: Lyrics.selectProvider(LyricsBackend.Auto)
                    }
                }

                // Provider source list
                Repeater {
                    model: Lyrics.providerStates

                    delegate: StyledRect {
                        id: provRow

                        required property var modelData
                        readonly property bool isSelected: Lyrics.manualSource && Lyrics.backend === modelData.backend
                        readonly property bool isCurrentActive: Boolean(modelData.active)
                        readonly property bool isDotActive: isCurrentActive || isSelected
                        readonly property bool isReady: modelData.status === "ready"
                        readonly property bool isLoading: modelData.status === "loading"
                        readonly property string sublabelText: String(modelData.sublabel ?? "")

                        Layout.fillWidth: true
                        implicitHeight: Math.max(sublabelText !== "" ? 32 : 26, provTextCol.implicitHeight + Tokens.padding.extraSmall * 2)
                        radius: Tokens.rounding.small
                        color: isSelected ? Colours.palette.m3primaryContainer : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.padding.small
                            anchors.rightMargin: Tokens.padding.small
                            spacing: Tokens.spacing.small

                            Rectangle {
                                width: 12
                                height: 12
                                radius: 6
                                color: "transparent"
                                border.width: 1.5
                                border.color: provRow.isDotActive ? Colours.palette.m3primary : Colours.palette.m3outline

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 6
                                    height: 6
                                    radius: 3
                                    visible: provRow.isDotActive
                                    color: Colours.palette.m3primary
                                }
                            }

                            ColumnLayout {
                                id: provTextCol

                                Layout.fillWidth: true
                                spacing: -2

                                StyledText {
                                    Layout.fillWidth: true
                                    text: String(provRow.modelData.label ?? "")
                                    font: Tokens.font.label.builders.small.weight(provRow.isDotActive ? Font.Bold : Font.Medium).build()
                                    color: provRow.isSelected
                                        ? Colours.palette.m3onPrimaryContainer
                                        : (provRow.isReady || provRow.isLoading ? Colours.palette.m3onSurface : Colours.palette.m3outline)
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    visible: provRow.sublabelText !== ""
                                    text: provRow.sublabelText
                                    font: Tokens.font.label.builders.small.scale(0.82).build()
                                    color: provRow.isSelected
                                        ? Colours.palette.m3onPrimaryContainer
                                        : Colours.palette.m3onSurfaceVariant
                                    opacity: provRow.isReady || provRow.isLoading ? 0.85 : 0.65
                                    elide: Text.ElideRight
                                }
                            }

                            MaterialIcon {
                                visible: Boolean(provRow.modelData.hasTranslation || provRow.modelData.hasRomanization)
                                text: "translate"
                                fontStyle: Tokens.font.icon.small
                                color: provRow.isSelected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                            }

                            StyledRect {
                                visible: provRow.isReady || provRow.isLoading || provRow.modelData.status === "not_found" || provRow.modelData.status === "error"
                                implicitWidth: Math.round(badgeTxt.implicitWidth + 10)
                                implicitHeight: 18
                                radius: 9
                                color: {
                                    if (!provRow.isReady)
                                        return "transparent";
                                    return provRow.modelData.syncType === "word"
                                        ? Colours.palette.m3primaryContainer
                                        : Colours.palette.m3secondaryContainer;
                                }
                                border.width: provRow.isSelected && provRow.isReady ? 1 : 0
                                border.color: Colours.palette.m3primary

                                StyledText {
                                    id: badgeTxt

                                    anchors.centerIn: parent
                                    text: {
                                        if (provRow.isLoading)
                                            return qsTr("Loading…");
                                        if (provRow.modelData.status === "error")
                                            return qsTr("Error");
                                        if (!provRow.isReady)
                                            return qsTr("Not found");
                                        return provRow.modelData.syncType === "word"
                                            ? qsTr("WORD BY WORD")
                                            : qsTr("SYNCED");
                                    }
                                    font: Tokens.font.label.builders.small.scale(0.78).weight(provRow.isReady ? Font.Bold : Font.Normal).build()
                                    color: {
                                        if (!provRow.isReady)
                                            return provRow.isSelected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3outline;
                                        return provRow.modelData.syncType === "word"
                                            ? Colours.palette.m3onPrimaryContainer
                                            : Colours.palette.m3onSecondaryContainer;
                                    }
                                }
                            }
                        }

                        StateLayer {
                            onClicked: Lyrics.selectProvider(provRow.modelData.backend)
                        }
                    }
                }

                // Offset row
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Tokens.spacing.extraSmall / 2
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Offset: %1 ms").arg(Math.round(Lyrics.offset * 1000))
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                        animate: true
                    }

                    IconButton {
                        icon: "restart_alt"
                        type: IconButton.Text
                        font: Tokens.font.icon.small
                        visible: Math.abs(Lyrics.offset) > 0.001
                        onClicked: Lyrics.offset = 0
                    }

                    IconButton {
                        icon: "remove"
                        type: IconButton.Tonal
                        padding: Tokens.padding.extraSmall
                        font: Tokens.font.icon.small
                        onClicked: Lyrics.offset = Math.round((Lyrics.offset - 0.1) * 100) / 100
                    }

                    IconButton {
                        icon: "add"
                        type: IconButton.Tonal
                        padding: Tokens.padding.extraSmall
                        font: Tokens.font.icon.small
                        onClicked: Lyrics.offset = Math.round((Lyrics.offset + 0.1) * 100) / 100
                    }
                }
            }

            Item {
                id: placeholder

                anchors.centerIn: parent
                implicitWidth: placeholderText.implicitWidth
                implicitHeight: placeholderText.implicitHeight

                StyledText {
                    id: placeholderText

                    text: Lyrics.loading ? Tr.tr("Loading...") : Tr.tr("No track playing")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.medium
                    animate: true
                }
            }
        }
    }

    MouseArea {
        id: btn

        anchors.centerIn: parent
        implicitWidth: implicitHeight
        implicitHeight: icon.implicitHeight + Tokens.padding.extraSmall * 2
        cursorShape: root.hasTrack ? Qt.PointingHandCursor : Qt.ArrowCursor
        hoverEnabled: root.hasTrack
        enabled: root.hasTrack || root.open
        onClicked: root.open = !root.open

        MaterialIcon {
            id: icon

            anchors.centerIn: parent
            text: "more_vert"
            fontStyle: Tokens.font.icon.medium
        }
    }
}

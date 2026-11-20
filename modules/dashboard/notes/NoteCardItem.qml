pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

StyledRect {
    id: root

    required property var note
    required property string viewMode // "grid" | "list"
    signal clicked()

    property bool copied: false

    function copyNote(): void {
        const body = (root.note && root.note.body) ? root.note.body : "";
        if (!body || body.trim().length === 0)
            return;
        Quickshell.clipboardText = body;
        root.copied = true;
        copyResetTimer.restart();
        const title = (root.note && root.note.title && root.note.title.trim().length > 0) ? root.note.title : qsTr("Note");
        Toaster.toast(qsTr("Copied to clipboard"), title, "content_copy");
    }

    HoverHandler {
        id: cardHover
    }

    Timer {
        id: copyResetTimer
        interval: 1200
        repeat: false
        onTriggered: root.copied = false
    }

    readonly property bool hasCustomColor: !!(note && note.color && note.color !== "none")

    readonly property color accentColor: {
        if (!note || !note.color || note.color === "none") return Colours.palette.m3primary;
        switch (note.color) {
            case "secondary": return Colours.palette.m3secondary;
            case "tertiary": return Colours.palette.m3tertiary;
            case "pink": return Colours.palette.m3error;
            case "surface": return Colours.palette.m3outline;
            default: return Colours.palette.m3primary;
        }
    }

    readonly property bool isHovered: cardHover.hovered || stateLayer.containsMouse || copyLayer.containsMouse

    readonly property color baseColor: isHovered
        ? Colours.tPalette.m3surfaceContainerHighest
        : Colours.tPalette.m3surfaceContainerHigh

    radius: Tokens.rounding.medium
    color: root.hasCustomColor
           ? Qt.tint(baseColor, Qt.alpha(root.accentColor, 0.22))
           : baseColor
    border.width: 1
    border.color: isHovered
                  ? (root.hasCustomColor ? root.accentColor : Colours.palette.m3primary)
                  : (root.hasCustomColor
                     ? Qt.alpha(root.accentColor, 0.45)
                     : Qt.alpha(Colours.palette.m3outlineVariant, 0.45))
    implicitHeight: viewMode === "list" ? 70 : 118
    height: implicitHeight
    clip: true

    Behavior on color {
        CAnim {}
    }

    Behavior on border.color {
        CAnim {}
    }

    readonly property string cleanSnippet: {
        if (!root.note || !root.note.body) return "";
        return root.note.body
            .replace(/^#+\s+/gm, "")
            .replace(/^[\*\-\+]\s*/gm, "• ")
            .replace(/^\d+\.\s+/gm, "")
            .replace(/\*\*([^*]+)\*\*/g, "$1")
            .replace(/\*([^*]+)\*/g, "$1")
            .replace(/~~([^~]+)~~/g, "$1")
            .replace(/`([^`]+)`/g, "$1")
            .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
            .trim();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            Layout.rightMargin: copyBtn.showBtn ? (copyBtn.width + Tokens.spacing.extraSmall) : 0
            spacing: Tokens.spacing.small

            Behavior on Layout.rightMargin {
                Anim { type: Anim.DefaultSpatial }
            }

            StyledText {
                Layout.fillWidth: true
                text: (root.note && root.note.title && root.note.title.trim().length > 0) ? root.note.title : qsTr("Untitled")
                font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                color: (root.note && root.note.title && root.note.title.trim().length > 0) ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            MaterialIcon {
                visible: !!(root.note && root.note.pinned)
                text: "push_pin"
                fontStyle: Tokens.font.icon.small
                color: root.hasCustomColor ? root.accentColor : Colours.palette.m3primary
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.fillHeight: root.viewMode === "grid"
            text: root.cleanSnippet
            font: Tokens.font.body.small
            color: Colours.palette.m3onSurfaceVariant
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            maximumLineCount: root.viewMode === "list" ? 1 : 3
            opacity: 0.85
        }
    }

    StateLayer {
        id: stateLayer
        anchors.fill: parent
        radius: root.radius
        color: root.hasCustomColor ? root.accentColor : Colours.palette.m3primary
        z: 10
        onClicked: root.clicked()
    }

    StyledRect {
        id: copyBtn

        readonly property bool hasContent: !!(root.note && root.note.body && root.note.body.trim().length > 0)
        readonly property bool showBtn: hasContent && (cardHover.hovered || stateLayer.containsMouse || copyLayer.containsMouse || root.copied)

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Tokens.padding.small
        width: 26
        height: 26
        radius: Tokens.rounding.full
        z: 20
        visible: opacity > 0.01
        opacity: showBtn ? 1 : 0
        scale: showBtn ? 1 : 0.85
        color: root.copied ? Colours.palette.m3primaryContainer : Colours.tPalette.m3surfaceContainerHighest
        border.width: 1
        border.color: root.copied ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outlineVariant, 0.5)

        Behavior on opacity {
            Anim { type: Anim.FastEffects }
        }

        Behavior on scale {
            Anim { type: Anim.DefaultSpatial }
        }

        Behavior on color {
            CAnim {}
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: root.copied ? "check" : "content_copy"
            fontStyle: Tokens.font.icon.small
            color: root.copied ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
        }

        StateLayer {
            id: copyLayer
            anchors.fill: parent
            radius: copyBtn.radius
            color: root.copied ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
            onClicked: root.copyNote()
        }
    }
}

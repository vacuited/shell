pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    property string osdKind: "volume"
    property var monitor: null
    property bool compact: false

    signal interacted

    readonly property bool isMuted: {
        if (osdKind === "volume")
            return Audio.muted;
        if (osdKind === "mic")
            return Audio.sourceMuted;
        return false;
    }

    readonly property real metricValue: {
        if (osdKind === "volume")
            return Math.max(0, Math.min(1, Audio.volume));
        if (osdKind === "mic")
            return Math.max(0, Math.min(1, Audio.sourceVolume));
        return Math.max(0, Math.min(1, monitor?.brightness ?? 0));
    }

    readonly property string iconName: {
        if (osdKind === "volume")
            return Icons.getVolumeIcon(Audio.volume, Audio.muted);
        if (osdKind === "mic")
            return Icons.getMicVolumeIcon(Audio.sourceVolume, Audio.sourceMuted);
        return HyprSunset.active ? "nightlight" : "light_mode";
    }

    readonly property color accentColor: {
        if (isMuted)
            return Colours.palette.m3error;
        if (osdKind === "brightness" && HyprSunset.active)
            return Colours.palette.m3tertiary;
        return Colours.palette.m3primary;
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    function togglePrimary(): void {
        if (osdKind === "volume") {
            if (Audio.sink?.ready && Audio.sink?.audio)
                Audio.sink.audio.muted = !Audio.sink.audio.muted;
        } else if (osdKind === "mic") {
            if (Audio.source?.ready && Audio.source?.audio)
                Audio.source.audio.muted = !Audio.source.audio.muted;
        } else {
            HyprSunset.toggle(5000);
        }
        interacted();
    }

    // Absorb blank pointer presses inside OSD so drags on slider never fall through
    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton
        preventStealing: true
    }

    TextMetrics {
        id: pctMetrics

        font: pctText.font
        text: "100%"
    }

    TextMetrics {
        id: muteMetrics

        font: pctText.font
        text: qsTr("Mute")
    }

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        StyledRect {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: root.compact ? 22 : 24
            implicitHeight: root.compact ? 22 : 24
            radius: Tokens.rounding.full
            color: Qt.alpha(root.accentColor, 0.16)

            StateLayer {
                radius: parent.radius
                color: root.accentColor
                onClicked: root.togglePrimary()
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: root.iconName
                color: root.accentColor
                fontStyle: Tokens.font.icon.size(root.compact ? 14 : 16).build()
                fill: !root.isMuted && (root.osdKind !== "brightness" || HyprSunset.active) ? 1 : 0
            }
        }

        StyledSlider {
            id: slider

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: root.compact ? 124 : 156
            Layout.preferredHeight: root.compact ? 22 : 24
            wavy: false
            interactionOnMove: true
            value: root.isMuted ? 0 : root.metricValue
            onInteraction: v => {
                const clamped = Math.max(0, Math.min(1, v));
                if (root.osdKind === "volume")
                    Audio.setVolume(clamped);
                else if (root.osdKind === "mic")
                    Audio.setSourceVolume(clamped);
                else
                    root.monitor?.setBrightness(clamped);
                root.interacted();
            }
        }

        StyledText {
            id: pctText

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Math.max(pctMetrics.width, muteMetrics.width)
            horizontalAlignment: Text.AlignRight
            text: root.isMuted ? qsTr("Mute") : Strings.percent(root.metricValue)
            color: root.isMuted ? Colours.palette.m3error : Colours.palette.m3onSurface
            font: Tokens.font.mono.small
        }
    }
}

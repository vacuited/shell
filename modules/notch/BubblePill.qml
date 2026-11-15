pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.widgets
import qs.services
import qs.utils

Item {
    id: root

    property bool initialized: false
    Component.onCompleted: Qt.callLater(() => root.initialized = true)

    property string activity: ""
    property bool compact: false
    property bool allowLive: true
    property bool hovered: false

    readonly property bool live: allowLive && !GameMode.enabled
    readonly property int hPad: compact ? Tokens.padding.small : Tokens.padding.small + 2
    readonly property int vPad: compact ? 6 : Tokens.padding.small
    readonly property int bottomPad: compact ? 6 : Tokens.padding.small
    readonly property int iconSize: compact ? 20 : 22

    readonly property real activeContentWidth: {
        if (activity === "recording")
            return recRow.implicitWidth;
        if (activity === "focus")
            return focusRow.implicitWidth;
        if (activity === "music")
            return musicRow.implicitWidth;
        return 0;
    }

    readonly property real targetWidth: Math.max(iconSize + hPad * 2, activeContentWidth + hPad * 2)
    property real animatedWidth: targetWidth
    Behavior on animatedWidth {
        enabled: root.initialized && root.activity.length > 0
        Anim { type: Anim.DefaultSpatial }
    }

    implicitWidth: animatedWidth
    implicitHeight: iconSize + vPad + bottomPad
    clip: true

    function formatElapsed(totalSeconds: real): string {
        const secs = Math.max(0, Math.floor(totalSeconds));
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        const s = secs % 60;
        const pad = n => (n < 10 ? "0" + n : "" + n);
        return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`;
    }

    // Subtle M3 hover wash
    Rectangle {
        anchors.fill: parent
        radius: Tokens.rounding.large
        color: Colours.palette.m3onSurface
        opacity: root.hovered ? 0.08 : 0

        Behavior on opacity {
            Anim { type: Anim.DefaultEffects }
        }
    }

    Item {
        id: contentHost

        anchors.centerIn: parent
        width: parent.width - root.hPad * 2
        height: root.iconSize

        // Recording bubble
        RowLayout {
            id: recRow

            anchors.centerIn: parent
            spacing: Tokens.spacing.small
            visible: opacity > 0.01
            opacity: root.activity === "recording" ? 1 : 0
            scale: root.activity === "recording" ? 1 : 0.88

            Behavior on opacity {
                enabled: root.initialized
                Anim { type: Anim.DefaultEffects }
            }
            Behavior on scale {
                enabled: root.initialized
                Anim { type: Anim.DefaultSpatial }
            }

            Item {
                Layout.preferredWidth: 12
                Layout.preferredHeight: 12
                Layout.alignment: Qt.AlignVCenter

                StyledRect {
                    id: recDot

                    anchors.centerIn: parent
                    width: 8
                    height: 8
                    radius: Tokens.rounding.full
                    color: Recorder.paused ? Colours.palette.m3tertiary : Colours.palette.m3error

                    SequentialAnimation on opacity {
                        running: root.activity === "recording" && Recorder.running && !Recorder.paused && root.live
                        loops: Animation.Infinite
                        onRunningChanged: {
                            if (!running)
                                recDot.opacity = 1;
                        }
                        NumberAnimation {
                            from: 1
                            to: 0.3
                            duration: 750
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            from: 0.3
                            to: 1
                            duration: 750
                            easing.type: Easing.InOutSine
                        }
                    }
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: Recorder.paused ? qsTr("Paused") : root.formatElapsed(Recorder.elapsed)
                color: Recorder.paused ? Colours.palette.m3tertiary : Colours.palette.m3error
                font: Tokens.font.mono.small
            }
        }

        // Focus bubble
        RowLayout {
            id: focusRow

            readonly property color phaseColor: FocusTimer.phase === "focus"
                ? Colours.palette.m3primary
                : (FocusTimer.phase === "shortBreak" ? Colours.palette.m3tertiary : Colours.palette.m3secondary)

            anchors.centerIn: parent
            spacing: Tokens.spacing.small
            visible: opacity > 0.01
            opacity: root.activity === "focus" ? 1 : 0
            scale: root.activity === "focus" ? 1 : 0.88

            Behavior on opacity {
                enabled: root.initialized
                Anim { type: Anim.DefaultEffects }
            }
            Behavior on scale {
                enabled: root.initialized
                Anim { type: Anim.DefaultSpatial }
            }

            Item {
                Layout.preferredWidth: root.iconSize
                Layout.preferredHeight: root.iconSize
                Layout.alignment: Qt.AlignVCenter

                CircularProgress {
                    anchors.fill: parent
                    implicitSize: root.iconSize
                    strokeWidth: 3
                    value: FocusTimer.isStopwatch ? 1 : FocusTimer.progress
                    fgColour: FocusTimer.running ? focusRow.phaseColor : Colours.palette.m3outline
                    bgColour: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: FocusTimer.phaseIcon
                    fontStyle: Tokens.font.icon.size(11).build()
                    fill: FocusTimer.running ? 1 : 0
                    color: FocusTimer.running ? focusRow.phaseColor : Colours.palette.m3onSurfaceVariant
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: FocusTimer.display
                color: FocusTimer.running ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                font: Tokens.font.mono.small
            }
        }

        // Music bubble
        RowLayout {
            id: musicRow

            readonly property bool isPlaying: Players.recentPlayer?.isPlaying ?? false

            anchors.centerIn: parent
            spacing: Tokens.spacing.small
            visible: opacity > 0.01
            opacity: root.activity === "music" ? 1 : 0
            scale: root.activity === "music" ? 1 : 0.88

            Behavior on opacity {
                enabled: root.initialized
                Anim { type: Anim.DefaultEffects }
            }
            Behavior on scale {
                enabled: root.initialized
                Anim { type: Anim.DefaultSpatial }
            }

            CoverArt {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: root.iconSize
                Layout.preferredHeight: root.iconSize
                source: Players.getArtUrl(Players.recentPlayer)
                spinning: root.live && musicRow.isPlaying
            }

            Row {
                Layout.alignment: Qt.AlignVCenter
                spacing: 2
                visible: musicRow.isPlaying

                Repeater {
                    model: 3

                    Rectangle {
                        required property int index

                        readonly property var vals: Audio.cava?.values ?? []
                        readonly property real val: vals.length > index * 2 ? vals[index * 2] : 0
                        readonly property real barH: root.live ? Math.max(4, Math.min(14, 4 + val * 10)) : (index === 1 ? 10 : 6)

                        anchors.verticalCenter: parent.verticalCenter
                        width: 2.5
                        height: barH
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primary

                        Behavior on height {
                            enabled: root.live
                            Anim { type: Anim.DefaultSpatial }
                        }
                    }
                }
            }
        }
    }
}

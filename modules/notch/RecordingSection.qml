pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

Item {
    id: root

    property bool compact: false
    property bool allowLive: true

    readonly property bool live: allowLive && !GameMode.enabled
    readonly property color statusColor: Recorder.paused ? Colours.palette.m3tertiary : Colours.palette.m3error

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    function formatElapsed(totalSeconds: real): string {
        const secs = Math.max(0, Math.floor(totalSeconds));
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        const s = secs % 60;
        const pad = n => (n < 10 ? "0" + n : "" + n);
        return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`;
    }

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        Item {
            Layout.preferredWidth: 12
            Layout.preferredHeight: 12
            Layout.alignment: Qt.AlignVCenter

            StyledRect {
                id: pulseDot

                anchors.centerIn: parent
                width: 8
                height: 8
                radius: Tokens.rounding.full
                color: root.statusColor

                SequentialAnimation on opacity {
                    running: Recorder.running && !Recorder.paused && root.live
                    loops: Animation.Infinite
                    onRunningChanged: {
                        if (!running)
                            pulseDot.opacity = 1;
                    }
                    NumberAnimation {
                        from: 1
                        to: 0.25
                        duration: 750
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        from: 0.25
                        to: 1
                        duration: 750
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }

        StyledRect {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: badgeText.implicitWidth + Tokens.padding.small * 2
            implicitHeight: root.compact ? 18 : 20
            radius: Tokens.rounding.full
            color: Qt.alpha(root.statusColor, 0.18)

            StyledText {
                id: badgeText

                anchors.centerIn: parent
                text: Recorder.paused ? Tr.tr("PAUSED") : Tr.tr("REC")
                color: root.statusColor
                font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: root.formatElapsed(Recorder.elapsed)
            color: Colours.palette.m3onSurface
            font: Tokens.font.mono.small
        }
    }
}

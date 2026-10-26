pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

RowLayout {
    id: root

    spacing: Tokens.spacing.large

    CircularProgress {
        implicitSize: 96
        strokeWidth: 7
        value: FocusTimer.progress
        fgColour: FocusTimer.phase === "focus" ? Colours.palette.m3primary : Colours.palette.m3tertiary
        bgColour: Colours.palette.m3surfaceContainerHighest

        Behavior on clampedVal {
            Anim {}
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 0

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: FocusTimer.display
                color: Colours.palette.m3onSurface
                font: Tokens.font.clock.size(Tokens.font.title.medium.pointSize).weight(Font.Bold).build()
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                visible: FocusTimer.completedSessions > 0
                text: `#${FocusTimer.completedSessions + (FocusTimer.phase === "focus" ? 1 : 0)}`
                color: Colours.palette.m3primary
                font: Tokens.font.label.small
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.maximumWidth: Number.POSITIVE_INFINITY
        spacing: Tokens.spacing.small

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: FocusTimer.phaseLabel
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.small

            IconButton {
                icon: FocusTimer.running ? "pause" : "play_arrow"
                type: IconButton.Filled
                onClicked: FocusTimer.toggle()
            }

            IconButton {
                icon: "skip_next"
                type: IconButton.Tonal
                onClicked: FocusTimer.skipPhase()
            }

            IconButton {
                icon: "restart_alt"
                type: IconButton.Tonal
                onClicked: FocusTimer.reset()
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.small

            IconButton {
                icon: "remove"
                type: IconButton.Text
                disabled: FocusTimer.running
                onClicked: FocusTimer.adjust(-5)
            }

            StyledText {
                text: Math.round(FocusTimer.durationSecs / 60) + " min"
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
            }

            IconButton {
                icon: "add"
                type: IconButton.Text
                disabled: FocusTimer.running
                onClicked: FocusTimer.adjust(5)
            }
        }
    }
}

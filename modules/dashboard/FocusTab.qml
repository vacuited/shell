pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    implicitWidth: 840
    implicitHeight: 480

    RowLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.medium

        // Left Card: Pomodoro Focus Station
        StyledRect {
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.preferredWidth: 480
            radius: Tokens.rounding.extraLarge
            color: Colours.tPalette.m3surfaceContainer

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                // Card Header
                RowLayout {
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "timer"
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        text: Tr.tr("Focus Station").toUpperCase()
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.builders.small.letterSpacing(1.5).weight(Font.DemiBold).build()
                    }
                }

                // Phase Selector Sliding Pill Track
                StyledRect {
                    id: phasePillTrack
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: Tokens.rounding.full
                    color: Colours.tPalette.m3surfaceContainerHigh

                    readonly property int activeIndex: FocusTimer.phase === "focus" ? 0 : (FocusTimer.phase === "shortBreak" ? 1 : 2)
                    readonly property color activeColor: FocusTimer.phase === "focus" ? Colours.palette.m3primary : Colours.palette.m3tertiary

                    // Sliding Indicator Pill
                    StyledRect {
                        x: 3 + phasePillTrack.activeIndex * ((phasePillTrack.width - 6) / 3)
                        y: 3
                        width: (phasePillTrack.width - 6) / 3
                        height: phasePillTrack.height - 6
                        radius: Tokens.rounding.full
                        color: phasePillTrack.activeColor

                        Behavior on x {
                            Anim { type: Anim.EmphasizedLarge }
                        }
                        Behavior on color {
                            ColorAnimation { duration: 200 }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        Repeater {
                            model: [
                                { label: Tr.tr("Focus"), phase: "focus" },
                                { label: Tr.tr("Short Break"), phase: "shortBreak" },
                                { label: Tr.tr("Long Break"), phase: "longBreak" }
                            ]

                            Item {
                                required property var modelData
                                required property int index

                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                readonly property bool isSelected: phasePillTrack.activeIndex === index

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: FocusTimer.setPhase(modelData.phase)
                                }

                                StyledText {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                    font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()

                                    Behavior on color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }
                            }
                        }
                    }
                }

                // Timer Dial
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    CircularProgress {
                        id: progressDial
                        anchors.centerIn: parent
                        implicitSize: 148
                        strokeWidth: 8
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
                                font: Tokens.font.clock.size(36).weight(Font.Bold).build()
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: FocusTimer.phaseLabel
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                            }
                        }
                    }
                }

                // Control Buttons
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Tokens.spacing.medium

                    IconButton {
                        icon: "remove"
                        type: IconButton.Tonal
                        disabled: FocusTimer.running
                        onClicked: FocusTimer.adjust(-5)
                    }

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

                    IconButton {
                        icon: "add"
                        type: IconButton.Tonal
                        disabled: FocusTimer.running
                        onClicked: FocusTimer.adjust(5)
                    }
                }

                // Auto-advance Checkbox/Row
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: Tr.tr("Auto-advance cycles")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.medium
                    }

                    StyledSwitch {
                        checked: FocusTimer.autoAdvance
                        onToggled: FocusTimer.autoAdvance = checked
                    }
                }
            }
        }

        // Right Card: Today's Focus Overview
        StyledRect {
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.preferredWidth: 360
            radius: Tokens.rounding.extraLarge
            color: Colours.tPalette.m3surfaceContainer

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                // Card Header
                RowLayout {
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "insights"
                        color: Colours.palette.m3tertiary
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        text: Tr.tr("Today's Overview").toUpperCase()
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.builders.small.letterSpacing(1.5).weight(Font.DemiBold).build()
                    }
                }

                // Stat Box 1: Sessions
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 84
                    radius: Tokens.rounding.large
                    color: Colours.tPalette.m3surfaceContainerHigh

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        spacing: Tokens.spacing.medium

                        MaterialIcon {
                            text: "task_alt"
                            color: Colours.palette.m3primary
                            fontStyle: Tokens.font.icon.builders.large.scale(1.2).build()
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                text: `${FocusTimer.completedSessions}`
                                color: Colours.palette.m3onSurface
                                font: Tokens.font.headline.builders.medium.weight(Font.Bold).build()
                            }

                            StyledText {
                                text: Tr.tr("Completed sessions")
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                            }
                        }

                        // Cycle dots (4 dots in current cycle)
                        RowLayout {
                            spacing: 6

                            Repeater {
                                model: FocusTimer.cyclesBeforeLongBreak

                                StyledRect {
                                    required property int index
                                    implicitWidth: 10
                                    implicitHeight: 10
                                    radius: Tokens.rounding.full
                                    color: (FocusTimer.completedSessions % FocusTimer.cyclesBeforeLongBreak) > index
                                           ? Colours.palette.m3primary
                                           : Colours.palette.m3surfaceContainerHighest
                                }
                            }
                        }
                    }
                }

                // Stat Box 2: Total Time
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 84
                    radius: Tokens.rounding.large
                    color: Colours.tPalette.m3surfaceContainerHigh

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        spacing: Tokens.spacing.medium

                        MaterialIcon {
                            text: "schedule"
                            color: Colours.palette.m3tertiary
                            fontStyle: Tokens.font.icon.builders.large.scale(1.2).build()
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                text: {
                                    const h = Math.floor(FocusTimer.totalFocusedSecsToday / 3600);
                                    const m = Math.floor((FocusTimer.totalFocusedSecsToday % 3600) / 60);
                                    return `${h}h ${m}m`;
                                }
                                color: Colours.palette.m3onSurface
                                font: Tokens.font.headline.builders.medium.weight(Font.Bold).build()
                            }

                            StyledText {
                                text: Tr.tr("Focused time today")
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                            }
                        }
                    }
                }

                // Target Progress Card
                StyledRect {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Tokens.rounding.large
                    color: Colours.tPalette.m3surfaceContainerHigh

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        spacing: Tokens.spacing.small

                        RowLayout {
                            StyledText {
                                text: Tr.tr("Daily Target (8 sessions)")
                                color: Colours.palette.m3onSurface
                                font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
                            }

                            Item { Layout.fillWidth: true }

                            StyledText {
                                text: `${Math.round(Math.min(1, FocusTimer.completedSessions / 8) * 100)}%`
                                color: Colours.palette.m3primary
                                font: Tokens.font.label.builders.medium.weight(Font.Bold).build()
                            }
                        }

                        StyledRect {
                            Layout.fillWidth: true
                            implicitHeight: 8
                            radius: Tokens.rounding.full
                            color: Colours.palette.m3surfaceContainerHighest

                            StyledRect {
                                width: parent.width * Math.max(0, Math.min(1, FocusTimer.completedSessions / 8))
                                height: parent.height
                                radius: Tokens.rounding.full
                                color: Colours.palette.m3primary

                                Behavior on width {
                                    Anim {}
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        RowLayout {
                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                text: "lightbulb"
                                color: Colours.palette.m3outline
                                fontStyle: Tokens.font.icon.small
                            }

                            StyledText {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                text: FocusTimer.phase === "focus"
                                      ? Tr.tr("Stay in the flow. Block notifications and focus on one task.")
                                      : Tr.tr("Step back, stretch, and give your eyes a rest.")
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                            }
                        }
                    }
                }
            }
        }
    }
}

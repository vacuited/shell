pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.widgets
import qs.services

Item {
    id: root

    property bool cavaWarm: false
    property bool showMedia: true
    property bool showClock: false
    property bool showFocus: false
    property bool showMediaControls: true
    property bool showFocusControls: true
    property bool allowLive: true
    property bool compact: false
    property bool expanded: false

    readonly property bool hasFocusControls: showFocus && showFocusControls
    readonly property bool hasMediaControls: showMedia && showMediaControls
    readonly property bool hasControls: hasFocusControls || hasMediaControls

    readonly property bool live: allowLive && !GameMode.enabled
    readonly property string trackTitle: Players.recentPlayer?.trackTitle ?? ""
    readonly property string trackArtist: Players.recentPlayer?.trackArtist ?? ""

    property real clockProg: showClock ? 1 : 0
    property real focusProg: showFocus ? 1 : 0
    property real clockFocusDivProg: showClock && (showFocus || showMedia) ? 1 : 0
    property real focusMediaDivProg: showFocus && showMedia ? 1 : 0
    property real expandProg: expanded && hasControls ? 1 : 0

    Behavior on clockProg { Anim { type: Anim.DefaultEffects } }
    Behavior on focusProg { Anim { type: Anim.DefaultEffects } }
    Behavior on clockFocusDivProg { Anim { type: Anim.DefaultEffects } }
    Behavior on focusMediaDivProg { Anim { type: Anim.DefaultEffects } }
    Behavior on expandProg { Anim { type: Anim.DefaultSpatial } }

    readonly property int coverSize: compact ? Tokens.padding.large + 4 : Tokens.padding.extraLarge
    readonly property int barCount: Math.max(3, Math.round(root.coverSize / 5))
    property var spectrum: Array(barCount).fill(0.2)
    property real placeholderPhase: 0

    function sampleSpectrum(values: var, count: int): var {
        const bars = [];
        if (!values || values.length === 0)
            return bars;
        const step = values.length / count;
        for (let i = 0; i < count; i++) {
            const start = Math.floor(i * step);
            const end = Math.max(start + 1, Math.floor((i + 1) * step));
            let peak = 0;
            for (let j = start; j < end && j < values.length; j++)
                peak = Math.max(peak, values[j]);
            bars.push(peak);
        }
        return bars;
    }

    function placeholderSpectrum(count: int): var {
        const bars = [];
        for (let i = 0; i < count; i++) {
            const envelope = 0.55 + 0.45 * (1 - Math.abs((i + 0.5) / count * 2 - 1));
            const wave = 0.5 + 0.32 * Math.sin(root.placeholderPhase * (1 + i * 0.19) + i * 1.7) + 0.18 * Math.sin(root.placeholderPhase * (2.2 + i * 0.11) + i * 0.7);
            bars.push(0.25 + 0.4 * envelope * wave);
        }
        return bars;
    }

    implicitWidth: mainCol.implicitWidth + (compact ? Tokens.padding.medium : Tokens.padding.large) * 2
    implicitHeight: mainCol.implicitHeight + (compact ? Tokens.padding.small : Tokens.padding.medium) * 2

    ColumnLayout {
        id: mainCol

        anchors.centerIn: parent
        spacing: Tokens.spacing.small * root.expandProg

        RowLayout {
            id: layout

            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.medium

            // 1. Optional Clock Section
            Item {
                visible: root.clockProg > 0.01
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: clockColumn.implicitWidth * root.clockProg
                implicitHeight: clockColumn.implicitHeight
                opacity: root.clockProg
                clip: true

                ColumnLayout {
                    id: clockColumn

                    anchors.centerIn: parent
                    spacing: 0

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Tokens.spacing.extraSmall

                        StyledText {
                            text: `${Time.hourStr}:${Time.minuteStr}`
                            color: Colours.palette.m3primary
                            font: root.compact ? Tokens.font.label.builders.large.weight(Font.DemiBold).build() : Tokens.font.title.builders.small.weight(Font.DemiBold).build()
                        }

                        StyledText {
                            visible: Config.services.clockFormat === ClockFormat.TwelveHour
                            text: Time.amPmStr.toLowerCase()
                            color: Colours.palette.m3primary
                            font: Tokens.font.label.small
                        }
                    }

                    StyledText {
                        visible: !root.compact
                        Layout.alignment: Qt.AlignHCenter
                        text: Time.format("ddd d MMM")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                    }
                }
            }

            StyledRect {
                visible: root.clockFocusDivProg > 0.01
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: root.clockFocusDivProg
                Layout.preferredHeight: root.coverSize
                opacity: root.clockFocusDivProg
                color: Colours.palette.m3outlineVariant
            }

            // 2. Pomodoro Focus Timer Section
            Item {
                visible: root.focusProg > 0.01
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: focusRow.implicitWidth * root.focusProg
                implicitHeight: focusRow.implicitHeight
                opacity: root.focusProg
                clip: true

                RowLayout {
                    id: focusRow

                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    CircularProgress {
                        Layout.alignment: Qt.AlignVCenter
                        implicitSize: root.coverSize
                        strokeWidth: root.compact ? 3 : 3.5
                        value: FocusTimer.progress
                        fgColour: FocusTimer.phase === "focus" ? Colours.palette.m3primary : Colours.palette.m3tertiary
                        bgColour: Colours.palette.m3surfaceContainerHighest

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: FocusTimer.running ? FocusTimer.phaseIcon : "pause"
                            color: FocusTimer.phase === "focus" ? Colours.palette.m3primary : Colours.palette.m3tertiary
                            fontStyle: Tokens.font.icon.small
                        }
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0

                        StyledText {
                            text: FocusTimer.display
                            color: FocusTimer.phase === "focus" ? Colours.palette.m3primary : Colours.palette.m3tertiary
                            font: root.compact ? Tokens.font.mono.builders.small.weight(Font.Bold).build() : Tokens.font.mono.builders.medium.weight(Font.Bold).build()
                        }

                        StyledText {
                            visible: !root.compact
                            text: FocusTimer.phaseLabel
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                        }
                    }
                }
            }

            StyledRect {
                visible: root.focusMediaDivProg > 0.01
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: root.focusMediaDivProg
                Layout.preferredHeight: root.coverSize
                opacity: root.focusMediaDivProg
                color: Colours.palette.m3outlineVariant
            }

            // 3. Media Section
            CoverArt {
                visible: root.showMedia
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: root.coverSize
                Layout.preferredHeight: root.coverSize
                source: Players.getArtUrl(Players.recentPlayer)
                spinning: root.live && (Players.recentPlayer?.isPlaying ?? false)
            }

            StyledText {
                id: primaryText

                visible: root.showMedia
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: root.compact ? Math.min(Config.notch.maxTitleWidth, 200) : Config.notch.maxTitleWidth
                text: Config.notch.showArtist && Config.notch.artistFirst ? root.trackArtist : root.trackTitle
                color: Colours.palette.m3onSurface
                font: root.compact ? Tokens.font.label.large : Tokens.font.title.small
                elide: Text.ElideRight
            }

            StyledText {
                visible: root.showMedia && Config.notch.showArtist && root.trackArtist !== "" && root.trackTitle !== ""
                Layout.alignment: Qt.AlignVCenter
                text: "-"
                color: Colours.palette.m3outlineVariant
                font: primaryText.font
            }

            StyledText {
                visible: root.showMedia && Config.notch.showArtist && root.trackArtist !== "" && root.trackTitle !== ""
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: root.compact ? Math.min(Config.notch.maxTitleWidth, 200) : Config.notch.maxTitleWidth
                text: Config.notch.artistFirst ? root.trackTitle : root.trackArtist
                color: Colours.palette.m3onSurface
                font: primaryText.font
                elide: Text.ElideRight
            }

            Item {
                id: visualiserWrapper

                visible: root.showMedia
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: root.coverSize
                Layout.preferredHeight: root.coverSize

                ServiceRef {
                    service: !root.live || !root.showMedia ? null : Audio.cava
                }

                VisualiserBars {
                    id: bars

                    anchors.fill: parent
                    mirrored: true
                    singleRow: true
                    values: root.spectrum
                    primaryColor: Colours.palette.m3primary
                    secondaryColor: Colours.palette.m3inversePrimary
                    rounding: Tokens.rounding.small
                    spacing: Tokens.spacing.extraSmall / 4
                    animationDuration: Tokens.anim.durations.normal
                }

                Timer {
                    property real last: Date.now()

                    interval: 33
                    repeat: true
                    triggeredOnStart: true
                    running: root.showMedia && root.live && (Players.recentPlayer?.isPlaying ?? false)
                    onRunningChanged: last = Date.now()
                    onTriggered: {
                        const now = Date.now();
                        const dt = Math.min(0.25, (now - last) / 1000);
                        last = now;

                        if (!root.cavaWarm)
                            root.placeholderPhase += dt * 4;
                        root.spectrum = root.cavaWarm ? root.sampleSpectrum(Audio.cava.values, root.barCount) : root.placeholderSpectrum(root.barCount);
                        if (!bars.settled)
                            bars.advance(dt);
                    }
                }
            }
        }

        // 4. Inline Click-to-Expand Drawer Controls
        Item {
            visible: root.expandProg > 0.01
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: controlsRow.implicitWidth
            implicitHeight: controlsRow.implicitHeight * root.expandProg
            opacity: root.expandProg
            clip: true

            MouseArea {
                anchors.fill: parent
            }

            RowLayout {
                id: controlsRow

                anchors.centerIn: parent
                spacing: Tokens.spacing.medium

                // Pomodoro Quick Controls (only shown when Pomodoro is active and focus controls enabled)
                RowLayout {
                    visible: root.hasFocusControls
                    spacing: Tokens.spacing.extraSmall

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

                StyledRect {
                    visible: root.hasFocusControls && root.hasMediaControls
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 24
                    color: Colours.palette.m3outlineVariant
                }

                // Media Quick Controls (when media is shown and media controls enabled)
                RowLayout {
                    visible: root.hasMediaControls
                    spacing: Tokens.spacing.extraSmall

                    IconButton {
                        icon: "skip_previous"
                        type: IconButton.Text
                        disabled: !(Players.recentPlayer?.canGoPrevious ?? false)
                        onClicked: Players.recentPlayer?.previous()
                    }

                    IconButton {
                        icon: (Players.recentPlayer?.isPlaying ?? false) ? "pause" : "play_arrow"
                        type: IconButton.Tonal
                        onClicked: Players.recentPlayer?.togglePlaying()
                    }

                    IconButton {
                        icon: "skip_next"
                        type: IconButton.Text
                        disabled: !(Players.recentPlayer?.canGoNext ?? false)
                        onClicked: Players.recentPlayer?.next()
                    }
                }
            }
        }
    }
}

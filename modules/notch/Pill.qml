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

    property bool initialized: false
    Component.onCompleted: Qt.callLater(() => root.initialized = true)

    property bool panelActive: true
    property bool cavaWarm: false
    property bool showMedia: true
    property bool showClock: false
    property bool showFocus: false
    property bool showMediaControls: true
    property bool showFocusControls: true
    property bool allowLive: true
    property bool compact: false
    property bool expanded: false

    property bool focusRevealed: showFocus && panelActive
    onShowFocusChanged: {
        if (!showFocus)
            focusRevealed = false;
        else if (panelActive)
            focusRevealed = true;
    }
    onPanelActiveChanged: {
        if (panelActive && showFocus)
            focusRevealed = true;
    }

    readonly property bool hasFocusControls: focusRevealed && showFocusControls
    readonly property bool hasMediaControls: showMedia && showMediaControls
    readonly property bool hasControls: hasFocusControls || hasMediaControls

    readonly property bool live: allowLive && !GameMode.enabled
    readonly property string trackTitle: Players.recentPlayer?.trackTitle ?? ""
    readonly property string trackArtist: Players.recentPlayer?.trackArtist ?? ""

    property real clockProg: showClock ? 1 : 0
    property real focusProg: focusRevealed ? 1 : 0
    property real mediaProg: showMedia ? 1 : 0
    property real clockFocusDivProg: showClock && (focusRevealed || showMedia) ? 1 : 0
    property real focusMediaDivProg: focusRevealed && showMedia ? 1 : 0
    property real expandProg: expanded && hasControls ? 1 : 0

    Behavior on clockProg {
        enabled: root.initialized
        Anim { type: Anim.DefaultSpatial }
    }
    Behavior on focusProg {
        enabled: root.initialized
        Anim { type: Anim.DefaultSpatial }
    }
    Behavior on mediaProg {
        enabled: root.initialized
        Anim { type: Anim.DefaultSpatial }
    }
    Behavior on clockFocusDivProg {
        enabled: root.initialized
        Anim { type: Anim.DefaultEffects }
    }
    Behavior on focusMediaDivProg {
        enabled: root.initialized
        Anim { type: Anim.DefaultEffects }
    }
    Behavior on expandProg {
        enabled: root.initialized
        Anim {
            id: expandAnim
            type: Anim.DefaultSpatial
        }
    }

    readonly property int coverSize: compact ? Tokens.padding.large + 4 : Tokens.padding.extraLarge
    readonly property int barCount: Math.max(3, Math.round(root.coverSize / 5))
    property var spectrum: Array(barCount).fill(0.12)
    property real placeholderPhase: 0

    function sampleSpectrum(values: var, count: int): var {
        const bars = [];
        if (!values || values.length === 0)
            return Array(count).fill(0.12);
        const step = values.length / count;
        for (let i = 0; i < count; i++) {
            const start = Math.floor(i * step);
            const end = Math.max(start + 1, Math.floor((i + 1) * step));
            let peak = 0;
            for (let j = start; j < end && j < values.length; j++)
                peak = Math.max(peak, values[j]);
            bars.push(Math.max(0.12, Math.min(1.0, 0.12 + peak * 1.35)));
        }
        return bars;
    }

    function placeholderSpectrum(count: int): var {
        const bars = [];
        for (let i = 0; i < count; i++) {
            const envelope = 0.55 + 0.45 * (1 - Math.abs((i + 0.5) / count * 2 - 1));
            const wave = 0.5 + 0.32 * Math.sin(root.placeholderPhase * (1 + i * 0.19) + i * 1.7) + 0.18 * Math.sin(root.placeholderPhase * (2.2 + i * 0.11) + i * 0.7);
            bars.push(Math.max(0.12, Math.min(1.0, 0.18 + 0.55 * envelope * wave)));
        }
        return bars;
    }

    readonly property int hPad: compact ? Tokens.padding.medium : Tokens.padding.large
    readonly property int vPad: compact ? 6 : Tokens.padding.small
    readonly property int bottomPad: compact ? 6 : Tokens.padding.small
    readonly property int drawerGap: compact ? Tokens.spacing.small : Tokens.spacing.medium

    property real animatedMediaWidth: mediaRow.implicitWidth
    Behavior on animatedMediaWidth {
        enabled: root.initialized && root.showMedia
        Anim { type: Anim.DefaultSpatial }
    }

    readonly property real baseWidth: layout.implicitWidth + hPad * 2
    readonly property real expandedWidth: Math.max(baseWidth + Tokens.padding.medium, controlsRow.implicitWidth + hPad * 2)
    readonly property real collapsedHeight: layout.implicitHeight + vPad + bottomPad
    readonly property real drawerAddHeight: controlsRow.implicitHeight + drawerGap + 2

    implicitWidth: Math.max(baseWidth * 0.88, baseWidth + (expandedWidth - baseWidth) * expandProg)
    implicitHeight: Math.max(collapsedHeight * 0.86, collapsedHeight + drawerAddHeight * expandProg)
    clip: true

    Item {
        id: mainContainer

        anchors.fill: parent

        RowLayout {
            id: layout

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: root.vPad
            spacing: Tokens.spacing.small + 2

            // 1. Optional Clock Section
            Item {
                visible: root.clockProg > 0.005
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: clockColumn.implicitWidth * Math.max(0, root.clockProg)
                implicitHeight: clockColumn.implicitHeight
                opacity: Math.max(0, Math.min(1, root.clockProg))
                scale: 0.85 + 0.15 * root.clockProg
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
                            visible: GlobalConfig.services.clockFormat === ClockFormat.TwelveHour
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
                Layout.preferredWidth: Math.max(1, Math.round(2 * root.clockFocusDivProg))
                Layout.preferredHeight: Math.round(root.coverSize * 0.65)
                radius: Tokens.rounding.full
                opacity: root.clockFocusDivProg * 0.7
                color: Colours.palette.m3outlineVariant
            }

            // 2. Pomodoro Focus Timer Section (Caelestia M3 Style)
            Item {
                visible: root.focusProg > 0.005
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: focusRow.implicitWidth * Math.max(0, root.focusProg)
                implicitHeight: focusRow.implicitHeight
                opacity: Math.max(0, Math.min(1, root.focusProg))
                scale: 0.85 + 0.15 * root.focusProg
                clip: true

                RowLayout {
                    id: focusRow

                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    CircularProgress {
                        Layout.alignment: Qt.AlignVCenter
                        implicitSize: root.coverSize + 2
                        strokeWidth: 3
                        value: FocusTimer.progress
                        fgColour: FocusTimer.phase === "focus" ? Colours.palette.m3primary : Colours.palette.m3tertiary

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: FocusTimer.running ? FocusTimer.phaseIcon : "pause"
                            color: FocusTimer.phase === "focus" ? Colours.palette.m3primary : Colours.palette.m3tertiary
                            fontStyle: Tokens.font.icon.size(root.compact ? 11 : 13).build()
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        text: FocusTimer.display
                        color: FocusTimer.running
                            ? (FocusTimer.phase === "focus" ? Colours.palette.m3primary : Colours.palette.m3tertiary)
                            : Colours.palette.m3onSurface
                        font: root.compact
                            ? Tokens.font.label.builders.large.weight(Font.DemiBold).build()
                            : Tokens.font.title.builders.small.weight(Font.DemiBold).build()

                        Behavior on color {
                            enabled: root.initialized
                            CAnim {}
                        }
                    }

                    StyledRect {
                        visible: FocusTimer.phase === "focus" && FocusTimer.subject !== ""
                        Layout.alignment: Qt.AlignVCenter
                        implicitHeight: root.compact ? 18 : 22
                        implicitWidth: Math.min(subjectLabel.implicitWidth + Tokens.padding.small * 2, 110)
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3secondaryContainer

                        StyledText {
                            id: subjectLabel

                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, 110 - Tokens.padding.small * 2)
                            text: FocusTimer.subject
                            color: Colours.palette.m3onSecondaryContainer
                            font: Tokens.font.label.builders.small.weight(Font.Medium).build()
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }

            StyledRect {
                visible: root.focusMediaDivProg > 0.01
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Math.max(1, Math.round(2 * root.focusMediaDivProg))
                Layout.preferredHeight: Math.round(root.coverSize * 0.65)
                radius: Tokens.rounding.full
                opacity: root.focusMediaDivProg * 0.7
                color: Colours.palette.m3outlineVariant
            }

            // 3. Media Section
            Item {
                visible: root.mediaProg > 0.005
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: root.animatedMediaWidth * Math.max(0, root.mediaProg)
                implicitHeight: mediaRow.implicitHeight
                opacity: Math.max(0, Math.min(1, root.mediaProg))
                scale: 0.85 + 0.15 * root.mediaProg
                clip: true

                RowLayout {
                    id: mediaRow

                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    CoverArt {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: root.coverSize
                        Layout.preferredHeight: root.coverSize
                        source: Players.getArtUrl(Players.recentPlayer)
                        spinning: root.live && (Players.recentPlayer?.isPlaying ?? false)
                    }

                    StyledText {
                        id: primaryText

                        Layout.alignment: Qt.AlignVCenter
                        Layout.maximumWidth: root.compact ? Math.min(Config.notch.maxTitleWidth, 200) : Config.notch.maxTitleWidth
                        text: Config.notch.showArtist && Config.notch.artistFirst ? root.trackArtist : root.trackTitle
                        color: Colours.palette.m3onSurface
                        font: root.compact ? Tokens.font.label.large : Tokens.font.title.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        visible: Config.notch.showArtist && root.trackArtist !== "" && root.trackTitle !== ""
                        Layout.alignment: Qt.AlignVCenter
                        text: "-"
                        color: Colours.palette.m3outlineVariant
                        font: primaryText.font
                    }

                    StyledText {
                        visible: Config.notch.showArtist && root.trackArtist !== "" && root.trackTitle !== ""
                        Layout.alignment: Qt.AlignVCenter
                        Layout.maximumWidth: root.compact ? Math.min(Config.notch.maxTitleWidth, 200) : Config.notch.maxTitleWidth
                        text: Config.notch.artistFirst ? root.trackTitle : root.trackArtist
                        color: Colours.palette.m3onSurface
                        font: primaryText.font
                        elide: Text.ElideRight
                    }

                    Item {
                        id: visualiserWrapper

                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: root.coverSize
                        Layout.preferredHeight: root.coverSize
                        implicitWidth: root.coverSize
                        implicitHeight: root.coverSize

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
                            secondaryColor: Colours.palette.m3primary
                            rounding: Tokens.rounding.full
                            spacing: Math.max(1.5, Math.round(Tokens.spacing.extraSmall / 2))
                            animationDuration: Tokens.anim.durations.expressiveDefaultEffects
                        }

                        Timer {
                            property real last: Date.now()

                            interval: 33
                            repeat: true
                            triggeredOnStart: true
                            running: root.showMedia && (root.live && (Players.recentPlayer?.isPlaying ?? false) || !bars.settled)
                            onRunningChanged: last = Date.now()
                            onTriggered: {
                                const now = Date.now();
                                const dt = Math.min(0.25, (now - last) / 1000);
                                last = now;

                                const isPlaying = root.live && (Players.recentPlayer?.isPlaying ?? false);
                                if (isPlaying) {
                                    const cavaVals = Audio.cava?.values;
                                    let hasCava = false;
                                    if (cavaVals && cavaVals.length > 0) {
                                        for (let i = 0; i < cavaVals.length; i++) {
                                            if (cavaVals[i] > 0.02) {
                                                hasCava = true;
                                                break;
                                            }
                                        }
                                    }

                                    if (hasCava) {
                                        root.spectrum = root.sampleSpectrum(cavaVals, root.barCount);
                                    } else {
                                        root.placeholderPhase += dt * 4;
                                        root.spectrum = root.placeholderSpectrum(root.barCount);
                                    }
                                } else {
                                    root.spectrum = Array(root.barCount).fill(0.12);
                                }

                                bars.advance(dt);
                            }
                        }
                    }
                }
            }
        }

        // 4. Expanded Controls Drawer (Caelestia Shape-Morphing ButtonRow + Elastic Kick)
        Item {
            id: drawerWrapper

            visible: root.expanded || root.expandProg > 0.005 || expandAnim.running
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: layout.bottom
            anchors.topMargin: root.drawerGap * root.expandProg
            width: controlsRow.implicitWidth
            height: controlsRow.implicitHeight
            opacity: Math.max(0, Math.min(1, (root.expandProg - 0.12) / 0.72))
            scale: Math.max(0.75, 0.82 + 0.18 * root.expandProg)

            transform: Translate {
                y: (1 - root.expandProg) * -10
            }

            MouseArea {
                anchors.fill: parent
            }

            RowLayout {
                id: controlsRow

                anchors.centerIn: parent
                spacing: Tokens.spacing.medium

                // Pomodoro Quick Controls (Caelestia ButtonRow with shapeMorph + isRound)
                ButtonRow {
                    id: focusControlsRow

                    visible: root.hasFocusControls
                    spacing: Tokens.spacing.extraSmall
                    Layout.preferredWidth: implicitWidth + (root.hasMediaControls ? 16 : 24)
                    Layout.preferredHeight: implicitHeight

                    IconButton {
                        fillWidth: true
                        icon: FocusTimer.running ? "pause" : "play_arrow"
                        type: IconButton.Filled
                        isRound: true
                        shapeMorph: true
                        checked: FocusTimer.running
                        onClicked: FocusTimer.toggle()
                    }

                    IconButton {
                        icon: "more_time"
                        type: IconButton.Tonal
                        isRound: true
                        shapeMorph: true
                        disabled: !FocusTimer.sessionActive || FocusTimer.isStopwatch
                        onClicked: FocusTimer.extend()
                    }

                    IconButton {
                        icon: FocusTimer.phase === "focus" ? "coffee" : "skip_next"
                        type: IconButton.Tonal
                        isRound: true
                        shapeMorph: true
                        onClicked: FocusTimer.skipPhase()
                    }

                    IconButton {
                        icon: "restart_alt"
                        type: IconButton.Tonal
                        isRound: true
                        shapeMorph: true
                        onClicked: FocusTimer.reset()
                    }
                }

                StyledRect {
                    visible: root.hasFocusControls && root.hasMediaControls
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 2
                    Layout.preferredHeight: 20
                    radius: Tokens.rounding.full
                    opacity: 0.7
                    color: Colours.palette.m3outlineVariant
                }

                // Media Quick Controls (1:1 Caelestia Media.qml ButtonRow style)
                ButtonRow {
                    id: mediaControlsRow

                    visible: root.hasMediaControls
                    spacing: Tokens.spacing.extraSmall
                    Layout.preferredWidth: implicitWidth + (root.hasFocusControls ? 16 : 24)
                    Layout.preferredHeight: implicitHeight

                    IconButton {
                        icon: "skip_previous"
                        type: IconButton.Tonal
                        isRound: true
                        shapeMorph: true
                        disabled: !(Players.recentPlayer?.canGoPrevious ?? false)
                        onClicked: Players.recentPlayer?.previous()
                    }

                    IconButton {
                        fillWidth: true
                        icon: (Players.recentPlayer?.isPlaying ?? false) ? "pause" : "play_arrow"
                        type: IconButton.Filled
                        isRound: true
                        shapeMorph: true
                        checked: Players.recentPlayer?.isPlaying ?? false
                        onClicked: Players.recentPlayer?.togglePlaying()
                    }

                    IconButton {
                        icon: "skip_next"
                        type: IconButton.Tonal
                        isRound: true
                        shapeMorph: true
                        disabled: !(Players.recentPlayer?.canGoNext ?? false)
                        onClicked: Players.recentPlayer?.next()
                    }
                }
            }
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.UPower
import Caelestia
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.widgets
import qs.services
import qs.utils

Item {
    id: root

    property bool initialized: false
    Component.onCompleted: Qt.callLater(() => root.initialized = true)

    property bool panelActive: true
    property string activeActivity: ""
    property bool allowStandingCoexist: true
    property bool cavaWarm: false
    property bool showMedia: true
    property bool showClock: false
    property bool showFocus: false
    property bool showRecording: false
    property bool showMediaControls: true
    property bool showFocusControls: true
    property bool allowLive: true
    property bool compact: false
    property bool expanded: false
    property bool hovered: false

    // Transient payloads
    property string osdKind: "volume"
    property var brightnessMonitor: null
    property NotifData activeNotif
    property var activeToast: null
    property bool chargingActive: false
    property bool chargingIsNewer: false

    signal osdInteracted
    signal dismissNotif
    signal dismissToast
    signal escapePressed

    readonly property bool isTransient: activeActivity === "osd" || activeActivity === "notification" || activeActivity === "toast"
    readonly property bool isRecording: activeActivity === "recording"

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

    onActiveNotifChanged: {
        replyInput.text = "";
        replyInput.focus = false;
    }

    // Determine visible pill sections cleanly (vanilla coexist vs Dynamic Island single priority)
    readonly property bool showOsdSlot: activeActivity === "osd"
    readonly property bool showNotifSlot: activeActivity === "notification" && activeNotif !== null
    readonly property bool showToastSlot: activeActivity === "toast" && ((chargingActive && chargingIsNewer) || activeToast !== null || chargingActive)
    readonly property bool showRecSlot: activeActivity === "recording" && showRecording && Recorder.running
    readonly property bool showFocusSlot: activeActivity === "focus" || (allowStandingCoexist && !isTransient && !isRecording && focusRevealed)
    readonly property bool showMusicSlot: activeActivity === "music" || (allowStandingCoexist && !isTransient && !isRecording && showMedia)
    readonly property bool showClockSlot: activeActivity === "clock" || (allowStandingCoexist && !isTransient && !isRecording && showClock && (showFocusSlot || showMusicSlot))

    readonly property bool hasFocusControls: showFocusSlot && showFocusControls
    readonly property bool hasMediaControls: showMusicSlot && showMediaControls
    readonly property bool hasRecControls: showRecSlot
    readonly property bool hasNotifControls: showNotifSlot && activeNotif !== null
    readonly property bool hasToastControls: showToastSlot && ((chargingActive && chargingIsNewer) || activeToast !== null)

    readonly property bool replyPinned: showNotifSlot && (replyInput.activeFocus || replyInput.text.length > 0)

    readonly property bool hasControls: {
        if (showOsdSlot)
            return false;
        if (hasNotifControls)
            return Config.notch.expandMode !== "none" || (activeNotif?.forceExpand ?? false) || (activeNotif?.urgency === NotificationUrgency.Critical) || replyPinned;
        if (hasToastControls)
            return Config.notch.expandMode !== "none";
        if (hasRecControls)
            return Config.notch.expandMode !== "none";
        return Config.notch.expandMode !== "none" && (hasFocusControls || hasMediaControls);
    }

    readonly property bool live: allowLive && !GameMode.enabled
    readonly property string trackTitle: Players.recentPlayer?.trackTitle ?? ""
    readonly property string trackArtist: Players.recentPlayer?.trackArtist ?? ""
    readonly property bool hasUnknownLength: (Players.recentPlayer?.length ?? 0) > 2147483647

    readonly property bool expandMusicActive: showMusicSlot && hasMediaControls && !showNotifSlot && !showToastSlot && !showRecSlot

    property real osdProg: showOsdSlot ? 1 : 0
    property real notifProg: showNotifSlot ? 1 : 0
    property real toastProg: showToastSlot ? 1 : 0
    property real recProg: showRecSlot ? 1 : 0
    property real clockProg: showClockSlot ? 1 : 0
    property real focusProg: showFocusSlot ? 1 : 0
    property real mediaProg: showMusicSlot ? 1 : 0
    property real clockFocusDivProg: showClockSlot && (showFocusSlot || showMusicSlot) ? 1 : 0
    property real focusMediaDivProg: showFocusSlot && showMusicSlot ? 1 : 0
    property real expandProg: expanded && hasControls ? 1 : 0

    Behavior on osdProg { enabled: root.initialized; Anim { type: Anim.DefaultSpatial } }
    Behavior on notifProg { enabled: root.initialized; Anim { type: Anim.DefaultSpatial } }
    Behavior on toastProg { enabled: root.initialized; Anim { type: Anim.DefaultSpatial } }
    Behavior on recProg { enabled: root.initialized; Anim { type: Anim.DefaultSpatial } }
    Behavior on clockProg { enabled: root.initialized; Anim { type: Anim.DefaultSpatial } }
    Behavior on focusProg { enabled: root.initialized; Anim { type: Anim.DefaultSpatial } }
    Behavior on mediaProg { enabled: root.initialized; Anim { type: Anim.DefaultSpatial } }
    Behavior on clockFocusDivProg { enabled: root.initialized; Anim { type: Anim.DefaultEffects } }
    Behavior on focusMediaDivProg { enabled: root.initialized; Anim { type: Anim.DefaultEffects } }
    Behavior on expandProg {
        enabled: root.initialized
        Anim {
            id: expandAnim
            type: Anim.DefaultSpatial
        }
    }

    readonly property int baseCoverSize: compact ? Tokens.padding.large + 4 : Tokens.padding.extraLarge
    readonly property int coverSize: Math.round(baseCoverSize + (expandMusicActive ? (compact ? 8 : 10) * expandProg : 0))
    readonly property int barCount: Math.max(3, Math.round(baseCoverSize / 5))
    property var spectrum: Array(barCount).fill(0.12)
    property real placeholderPhase: 0

    function formatMediaTime(length: int): string {
        if (length < 0)
            return "0:00";
        const mins = Math.floor(length / 60);
        const secs = length % 60;
        const hrs = Math.floor(mins / 60);
        const pad = n => (n < 10 ? "0" + n : "" + n);
        if (hrs > 0)
            return `${hrs}:${pad(mins % 60)}:${pad(secs)}`;
        return `${mins}:${pad(secs)}`;
    }

    function submitInlineReply(): void {
        if (!activeNotif || !activeNotif.hasInlineReply)
            return;
        const msg = replyInput.text.trim();
        if (msg.length === 0)
            return;
        activeNotif.sendReply(msg);
        replyInput.text = "";
        replyInput.focus = false;
        activeNotif.popup = false;
    }

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
        enabled: root.initialized && root.showMusicSlot
        Anim { type: Anim.DefaultSpatial }
    }

    readonly property real baseWidth: layout.implicitWidth + hPad * 2
    readonly property real expandedWidth: Math.max(baseWidth + Tokens.padding.medium, drawerStack.implicitWidth + hPad * 2)
    readonly property real collapsedHeight: layout.implicitHeight + vPad + bottomPad
    readonly property real drawerAddHeight: drawerStack.implicitHeight + drawerGap + 4

    implicitWidth: Math.max(baseWidth * 0.88, baseWidth + (expandedWidth - baseWidth) * expandProg)
    implicitHeight: Math.max(collapsedHeight * 0.86, collapsedHeight + drawerAddHeight * expandProg)
    clip: true

    // Poll player position smoothly while Music expanded drawer is visible
    Timer {
        running: root.expanded && root.hasMediaControls && (Players.recentPlayer?.isPlaying ?? false) && !mediaSeekSlider.dragging
        interval: GlobalConfig.dashboard.mediaUpdateInterval
        triggeredOnStart: true
        repeat: true
        onTriggered: Players.recentPlayer?.positionChanged()
    }

    Timer {
        id: copyTimer

        interval: 1500
    }

    Item {
        id: mainContainer

        anchors.fill: parent

        RowLayout {
            id: layout

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: root.vPad
            spacing: Tokens.spacing.small + 2

            // OSD Section
            Item {
                visible: root.osdProg > 0.005
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: osdSection.implicitWidth * Math.max(0, root.osdProg)
                implicitHeight: osdSection.implicitHeight
                opacity: Math.max(0, Math.min(1, root.osdProg))
                scale: 0.85 + 0.15 * root.osdProg
                clip: true

                OsdSection {
                    id: osdSection

                    anchors.centerIn: parent
                    osdKind: root.osdKind
                    monitor: root.brightnessMonitor
                    compact: root.compact
                    onInteracted: root.osdInteracted()
                }
            }

            // Notification Section
            Item {
                visible: root.notifProg > 0.005
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: notifSection.implicitWidth * Math.max(0, root.notifProg)
                implicitHeight: notifSection.implicitHeight
                opacity: Math.max(0, Math.min(1, root.notifProg))
                scale: 0.85 + 0.15 * root.notifProg
                clip: true

                NotificationSection {
                    id: notifSection

                    anchors.centerIn: parent
                    notif: root.activeNotif
                    holdActive: root.showNotifSlot && (root.expanded || root.hovered || root.replyPinned)
                    compact: root.compact
                    maxWidth: root.compact ? Math.min(Config.notch.maxTitleWidth, 210) : Config.notch.maxTitleWidth
                }
            }

            // Toast / Charging Section
            Item {
                visible: root.toastProg > 0.005
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: toastSection.implicitWidth * Math.max(0, root.toastProg)
                implicitHeight: toastSection.implicitHeight
                opacity: Math.max(0, Math.min(1, root.toastProg))
                scale: 0.85 + 0.15 * root.toastProg
                clip: true

                ToastSection {
                    id: toastSection

                    anchors.centerIn: parent
                    chargingMode: root.chargingActive && (root.chargingIsNewer || root.activeToast === null)
                    toast: root.activeToast
                    compact: root.compact
                    maxWidth: root.compact ? Math.min(Config.notch.maxTitleWidth, 210) : Config.notch.maxTitleWidth
                }
            }

            // Recording Section
            Item {
                visible: root.recProg > 0.005
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: recSection.implicitWidth * Math.max(0, root.recProg)
                implicitHeight: recSection.implicitHeight
                opacity: Math.max(0, Math.min(1, root.recProg))
                scale: 0.85 + 0.15 * root.recProg
                clip: true

                RecordingSection {
                    id: recSection

                    anchors.centerIn: parent
                    compact: root.compact
                    allowLive: root.allowLive
                }
            }

            // Clock Section
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
                Layout.preferredHeight: Math.round(root.baseCoverSize * 0.65)
                radius: Tokens.rounding.full
                opacity: root.clockFocusDivProg * 0.7
                color: Colours.palette.m3outlineVariant
            }

            // Focus Section
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
                        implicitSize: root.baseCoverSize + 2
                        strokeWidth: 3
                        value: FocusTimer.isStopwatch ? 1 : FocusTimer.progress
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
                Layout.preferredHeight: Math.round(root.baseCoverSize * 0.65)
                radius: Tokens.rounding.full
                opacity: root.focusMediaDivProg * 0.7
                color: Colours.palette.m3outlineVariant
            }

            // Media Section
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

                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0

                        RowLayout {
                            spacing: Tokens.spacing.small

                            StyledText {
                                id: primaryText

                                Layout.alignment: Qt.AlignVCenter
                                Layout.maximumWidth: root.compact ? Math.min(Config.notch.maxTitleWidth, 200) : Config.notch.maxTitleWidth
                                text: Config.notch.showArtist && Config.notch.artistFirst && !(root.expanded && root.expandMusicActive)
                                    ? root.trackArtist
                                    : root.trackTitle
                                color: Colours.palette.m3onSurface
                                font: root.compact ? Tokens.font.label.large : Tokens.font.title.small
                                elide: Text.ElideRight
                            }

                            StyledText {
                                visible: Config.notch.showArtist && root.trackArtist !== "" && root.trackTitle !== "" && !(root.expanded && root.expandMusicActive)
                                Layout.alignment: Qt.AlignVCenter
                                text: "-"
                                color: Colours.palette.m3outlineVariant
                                font: primaryText.font
                            }

                            StyledText {
                                visible: Config.notch.showArtist && root.trackArtist !== "" && root.trackTitle !== "" && !(root.expanded && root.expandMusicActive)
                                Layout.alignment: Qt.AlignVCenter
                                Layout.maximumWidth: root.compact ? Math.min(Config.notch.maxTitleWidth, 200) : Config.notch.maxTitleWidth
                                text: Config.notch.artistFirst ? root.trackTitle : root.trackArtist
                                color: Colours.palette.m3onSurface
                                font: primaryText.font
                                elide: Text.ElideRight
                            }
                        }

                        StyledText {
                            visible: root.expanded && root.expandMusicActive && root.trackArtist !== ""
                            Layout.maximumWidth: Config.notch.maxTitleWidth
                            text: root.trackArtist
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.medium
                            elide: Text.ElideRight
                        }
                    }

                    Item {
                        id: visualiserWrapper

                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: root.baseCoverSize
                        Layout.preferredHeight: root.baseCoverSize
                        implicitWidth: root.baseCoverSize
                        implicitHeight: root.baseCoverSize

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
                            running: (root.showMedia || root.showMusicSlot) && (root.live && (Players.recentPlayer?.isPlaying ?? false) || !bars.settled)
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

        // Expanded Drawer Container
        Item {
            id: drawerWrapper

            visible: root.expanded || root.expandProg > 0.005 || expandAnim.running
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: layout.bottom
            anchors.topMargin: root.drawerGap * root.expandProg
            width: drawerStack.implicitWidth
            height: drawerStack.implicitHeight
            opacity: Math.max(0, Math.min(1, (root.expandProg - 0.12) / 0.72))
            scale: Math.max(0.75, 0.82 + 0.18 * root.expandProg)

            transform: Translate {
                y: (1 - root.expandProg) * -10
            }

            MouseArea {
                anchors.fill: parent
                preventStealing: true
            }

            RowLayout {
                id: drawerStack

                anchors.centerIn: parent
                spacing: Tokens.spacing.medium

                // 1. Focus Expanded Card
                ColumnLayout {
                    id: focusDrawerCol

                    readonly property int displayCycle: {
                        const maxC = Math.max(1, FocusTimer.cyclesBeforeLongBreak);
                        if (FocusTimer.phase === "focus")
                            return Math.min(FocusTimer.cycleCount + 1, maxC);
                        return Math.max(1, Math.min(FocusTimer.cycleCount, maxC));
                    }

                    visible: !root.showNotifSlot && !root.showToastSlot && !root.showRecSlot && root.hasFocusControls
                    spacing: Tokens.spacing.small

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        StyledText {
                            Layout.fillWidth: true
                            text: FocusTimer.phaseLabel
                            color: FocusTimer.phase === "focus" ? Colours.palette.m3primary : Colours.palette.m3tertiary
                            font: Tokens.font.label.builders.large.weight(Font.DemiBold).build()
                        }

                        StyledRect {
                            implicitWidth: cycleText.implicitWidth + Tokens.padding.small * 2
                            implicitHeight: 20
                            radius: Tokens.rounding.full
                            color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 1)

                            StyledText {
                                id: cycleText

                                anchors.centerIn: parent
                                text: FocusTimer.isStopwatch
                                    ? Tr.tr("Stopwatch")
                                    : Tr.tr("Cycle %1/%2").arg(focusDrawerCol.displayCycle).arg(FocusTimer.cyclesBeforeLongBreak)
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                            }
                        }
                    }

                    ButtonRow {
                        id: focusControlsRow

                        spacing: Tokens.spacing.extraSmall
                        Layout.preferredWidth: Math.max(implicitWidth + (root.hasMediaControls ? 16 : 24), 200)
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
                }

                StyledRect {
                    visible: !root.showNotifSlot && !root.showToastSlot && !root.showRecSlot && root.hasFocusControls && root.hasMediaControls
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 2
                    Layout.preferredHeight: 44
                    radius: Tokens.rounding.full
                    opacity: 0.7
                    color: Colours.palette.m3outlineVariant
                }

                // 2. Music Expanded Card (Seek + 5-Button Controls)
                ColumnLayout {
                    id: mediaDrawerCol

                    visible: !root.showNotifSlot && !root.showToastSlot && !root.showRecSlot && root.hasMediaControls
                    spacing: Tokens.spacing.small

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: Math.max(250, mediaControlsRow.implicitWidth + 24)
                        spacing: Tokens.spacing.small

                        TextMetrics {
                            id: mediaTimeMetrics

                            text: Players.recentPlayer
                                ? root.formatMediaTime(Math.max(Players.recentPlayer.position, root.hasUnknownLength ? 0 : Players.recentPlayer.length)).replace(/[1-9]/g, "0")
                                : "00:00"
                            font: Tokens.font.mono.small
                        }

                        StyledText {
                            id: posLabel

                            Layout.preferredWidth: mediaTimeMetrics.width
                            horizontalAlignment: Text.AlignHCenter
                            text: mediaSeekSlider.dragging
                                ? root.formatMediaTime(Math.round(mediaSeekSlider.pos * (Players.recentPlayer?.length ?? 0)))
                                : root.formatMediaTime(Players.recentPlayer?.position ?? -1)
                            color: Colours.palette.m3onSurfaceVariant
                            font: mediaTimeMetrics.font
                        }

                        StyledSlider {
                            id: mediaSeekSlider

                            Layout.fillWidth: true
                            implicitHeight: 22
                            value: Players.recentPlayer && !root.hasUnknownLength && Players.recentPlayer.length > 0
                                ? Math.max(0, Math.min(1, Players.recentPlayer.position / Players.recentPlayer.length))
                                : 0
                            enabled: (Players.recentPlayer?.canSeek ?? false) && !root.hasUnknownLength
                            wavy: true
                            animateWave: root.live && (Players.recentPlayer?.isPlaying ?? false)
                            waveFrequency: 5
                            waveDuration: 2000
                            interactionOnMove: false
                            onInteraction: v => {
                                const p = Players.recentPlayer;
                                if (p?.canSeek && p?.positionSupported && p.length > 0)
                                    p.position = v * p.length;
                            }
                        }

                        StyledText {
                            Layout.preferredWidth: mediaTimeMetrics.width
                            horizontalAlignment: Text.AlignHCenter
                            text: root.hasUnknownLength ? "--:--" : root.formatMediaTime(Players.recentPlayer?.length ?? -1)
                            color: Colours.palette.m3onSurfaceVariant
                            font: mediaTimeMetrics.font
                        }
                    }

                    ButtonRow {
                        id: mediaControlsRow

                        spacing: Tokens.spacing.extraSmall
                        Layout.preferredWidth: Math.max(implicitWidth + (root.hasFocusControls ? 16 : 24), 250)
                        Layout.preferredHeight: implicitHeight

                        IconButton {
                            icon: "shuffle"
                            type: IconButton.Tonal
                            isRound: true
                            shapeMorph: true
                            checked: Players.recentPlayer?.shuffle ?? false
                            disabled: !(Players.recentPlayer?.shuffleSupported ?? false)
                            onClicked: {
                                const p = Players.recentPlayer;
                                if (p)
                                    p.shuffle = !p.shuffle;
                            }
                        }

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

                        IconButton {
                            icon: Players.recentPlayer?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                            type: IconButton.Tonal
                            isRound: true
                            shapeMorph: true
                            checked: Players.recentPlayer?.loopState === MprisLoopState.Track || Players.recentPlayer?.loopState === MprisLoopState.Playlist
                            disabled: !(Players.recentPlayer?.loopSupported ?? false)
                            onClicked: {
                                const p = Players.recentPlayer;
                                if (!p)
                                    return;
                                if (p.loopState === MprisLoopState.None)
                                    p.loopState = MprisLoopState.Track;
                                else if (p.loopState === MprisLoopState.Track)
                                    p.loopState = MprisLoopState.Playlist;
                                else
                                    p.loopState = MprisLoopState.None;
                            }
                        }
                    }
                }

                // 3. Recording Expanded Card
                ButtonRow {
                    id: recordingControlsRow

                    visible: root.hasRecControls
                    spacing: Tokens.spacing.extraSmall
                    Layout.preferredWidth: Math.max(implicitWidth + 24, 170)
                    Layout.preferredHeight: implicitHeight

                    IconButton {
                        fillWidth: true
                        icon: Recorder.paused ? "play_arrow" : "pause"
                        type: IconButton.Filled
                        isRound: true
                        shapeMorph: true
                        checked: !Recorder.paused
                        onClicked: Recorder.togglePause()
                    }

                    IconButton {
                        icon: "stop"
                        type: IconButton.Tonal
                        isRound: true
                        shapeMorph: true
                        inactiveOnColour: Colours.palette.m3error
                        onClicked: Recorder.stop()
                    }
                }

                // 4. Notification Expanded Card
                ColumnLayout {
                    id: notifDrawerCol

                    visible: root.hasNotifControls && root.activeNotif !== null
                    spacing: Tokens.spacing.small

                    RowLayout {
                        visible: ((root.activeNotif?.appName ?? "").length > 0) || ((root.activeNotif?.timeStr ?? "").length > 0)
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.extraSmall

                        StyledText {
                            visible: (root.activeNotif?.appName ?? "").length > 0
                            text: root.activeNotif?.appName ?? ""
                            color: Colours.palette.m3primary
                            font: Tokens.font.label.medium
                        }

                        StyledText {
                            visible: (root.activeNotif?.appName ?? "").length > 0 && (root.activeNotif?.timeStr ?? "").length > 0
                            text: "•"
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.medium
                        }

                        StyledText {
                            visible: (root.activeNotif?.timeStr ?? "").length > 0
                            text: root.activeNotif?.timeStr ?? ""
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.medium
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }

                    StyledText {
                        visible: (root.activeNotif?.body ?? "").length > 0
                        Layout.maximumWidth: 340
                        text: root.activeNotif?.body ?? ""
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        textFormat: Text.MarkdownText
                        wrapMode: Text.Wrap
                        onLinkActivated: link => Qt.openUrlExternally(link)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        Flow {
                            Layout.fillWidth: true
                            Layout.maximumWidth: 270
                            spacing: Tokens.spacing.small
                            visible: (root.activeNotif?.actions?.length ?? 0) > 0

                            Repeater {
                                model: root.activeNotif?.actions ?? []

                                delegate: TextButton {
                                    required property var modelData

                                    text: modelData.text
                                    type: TextButton.Tonal
                                    isRound: true
                                    verticalPadding: Tokens.padding.extraSmall
                                    horizontalPadding: Tokens.padding.medium
                                    onClicked: {
                                        modelData.invoke();
                                        if (!root.activeNotif?.resident)
                                            root.dismissNotif();
                                    }
                                }
                            }
                        }

                        Item {
                            visible: (root.activeNotif?.actions?.length ?? 0) === 0
                            Layout.fillWidth: true
                        }

                        IconButton {
                            visible: (root.activeNotif?.body ?? "").length > 0
                            icon: copyTimer.running ? "inventory" : "content_copy"
                            type: IconButton.Tonal
                            isRound: true
                            onClicked: {
                                Quickshell.clipboardText = root.activeNotif?.body ?? "";
                                copyTimer.restart();
                            }
                        }

                        IconButton {
                            icon: "close"
                            type: IconButton.Tonal
                            isRound: true
                            inactiveOnColour: Colours.palette.m3error
                            onClicked: root.dismissNotif()
                        }
                    }

                    // Inline Reply Box
                    RowLayout {
                        visible: Config.notch.notifReplies && (root.activeNotif?.hasInlineReply ?? false)
                        Layout.fillWidth: true
                        Layout.preferredWidth: 320
                        spacing: Tokens.spacing.small

                        StyledTextField {
                            id: replyInput

                            Layout.fillWidth: true
                            type: StyledTextField.Filled
                            verticalPadding: Tokens.padding.extraSmall
                            horizontalPadding: Tokens.padding.medium
                            placeholderText: root.activeNotif?.inlineReplyPlaceholder || Tr.tr("Reply...")
                            Keys.onReturnPressed: root.submitInlineReply()
                            Keys.onEnterPressed: root.submitInlineReply()
                            Keys.onEscapePressed: {
                                replyInput.focus = false;
                                root.escapePressed();
                            }
                        }

                        IconButton {
                            icon: "send"
                            type: IconButton.Filled
                            isRound: true
                            shapeMorph: true
                            disabled: replyInput.text.trim().length === 0
                            onClicked: root.submitInlineReply()
                        }
                    }
                }

                // 5. Toast / Charging Expanded Card
                ColumnLayout {
                    id: toastDrawerCol

                    visible: !root.showNotifSlot && root.hasToastControls
                    spacing: Tokens.spacing.small

                    StyledText {
                        visible: root.activeToast !== null && !(root.chargingActive && root.chargingIsNewer) && (root.activeToast?.message ?? "").length > 0
                        Layout.maximumWidth: 320
                        text: root.activeToast?.message ?? ""
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        wrapMode: Text.Wrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.medium

                        StyledText {
                            visible: root.chargingActive && (root.chargingIsNewer || root.activeToast === null) && UPower.displayDevice.ready
                            text: {
                                const rateW = Math.abs(UPower.displayDevice.changeRate ?? 0);
                                return rateW > 0.1 ? `${rateW.toFixed(1)} W` : (UPower.onBattery ? Tr.tr("Discharging") : Tr.tr("Power connected"));
                            }
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.medium
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        TextButton {
                            text: Tr.tr("Dismiss")
                            type: TextButton.Tonal
                            isRound: true
                            verticalPadding: Tokens.padding.extraSmall
                            horizontalPadding: Tokens.padding.medium
                            onClicked: root.dismissToast()
                        }
                    }
                }
            }
        }
    }
}

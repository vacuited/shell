pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import M3Shapes
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import "notes"
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    property int rightView: 0 // 0 = Focus Overview Bento, 1 = Digital Wellbeing
    property bool initialized: false

    readonly property list<color> subjectColors: [
        Colours.palette.m3primary,
        Colours.palette.m3tertiary,
        Colours.palette.m3secondary,
        Colours.palette.m3inversePrimary,
        Colours.palette.m3outline
    ]

    readonly property list<string> dayInitials: [
        Tr.tr("M"),
        Tr.tr("T"),
        Tr.tr("W"),
        Tr.tr("T"),
        Tr.tr("F"),
        Tr.tr("S"),
        Tr.tr("S")
    ]

    // ==========================================
    // Screen Time State & Helpers
    // ==========================================
    readonly property int stTopN: 5
    readonly property int stMaxDayOffset: 6
    property int stDayOffset: 0
    property bool stBarsReady: true
    property bool stAllowAppear: false
    property int stAnimGen: 0
    property int stDayTotalSeconds: 0
    property int stMaxSeconds: 1

    function dateForOffset(offset: int): date {
        const d = new Date();
        d.setHours(12, 0, 0, 0);
        d.setDate(d.getDate() - offset);
        return d;
    }

    function dayKeyForOffset(offset: int): string {
        const d = dateForOffset(offset);
        const y = d.getFullYear();
        const m = String(d.getMonth() + 1).padStart(2, "0");
        const day = String(d.getDate()).padStart(2, "0");
        return `${y}-${m}-${day}`;
    }

    readonly property string stSelectedDay: dayKeyForOffset(stDayOffset)
    readonly property string stDayTitle: stDayOffset === 0 ? Tr.tr("Today") : Qt.formatDate(dateForOffset(stDayOffset), "dddd, MMMM d")
    readonly property bool stIsEmpty: stAppsModel.count === 0 || stDayTotalSeconds <= 0

    ListModel {
        id: stAppsModel
    }

    function prettyTotal(seconds: int): string {
        if (seconds < 60)
            return `${seconds}s`;
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        if (h > 0 && m > 0)
            return `${h}h ${m}m`;
        if (h > 0)
            return `${h}h`;
        return `${m}m`;
    }

    function hourLabel(seconds: int): string {
        const h = Math.floor(seconds / 3600);
        return h > 0 ? `${String(h).padStart(2, "0")}h` : "";
    }

    function minuteLabel(seconds: int): string {
        const m = Math.floor((seconds % 3600) / 60);
        const s = seconds % 60;
        if (seconds < 60)
            return `${s}s`;
        return `${String(m).padStart(2, "0")}m`;
    }

    function intensityFor(rank: int, count: int, ratio: real): real {
        const byRank = 1 - rank / Math.max(count - 1, 1);
        return Math.max(0.2, 0.25 * ratio + 0.75 * byRank);
    }

    function mixColor(a: color, b: color, t: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    function fetchDayApps(offset: int): var {
        const day = dayKeyForOffset(offset);
        return ScreenTime.usageForDay(day, root.stTopN);
    }

    function totalsFrom(list: var): void {
        let total = 0;
        for (let i = 0; i < list.length; i++)
            total += list[i].seconds;
        stDayTotalSeconds = total;
        stMaxSeconds = list.length > 0 ? list[0].seconds : 1;
    }

    function sameAppSet(list: var): bool {
        if (list.length !== stAppsModel.count)
            return false;
        for (let i = 0; i < list.length; i++) {
            if (stAppsModel.get(i).appClass !== list[i].appClass)
                return false;
        }
        return true;
    }

    function replaceModel(list: var, animate: bool): void {
        stAllowAppear = animate;
        stAppsModel.clear();
        for (let i = 0; i < list.length; i++)
            stAppsModel.append(list[i]);
        totalsFrom(list);

        if (animate) {
            stBarsReady = false;
            stAnimGen++;
            Qt.callLater(() => {
                stBarsReady = true;
            });
        } else {
            stBarsReady = true;
        }
    }

    function syncSeconds(list: var): void {
        for (let i = 0; i < list.length; i++)
            stAppsModel.setProperty(i, "seconds", list[i].seconds);
        totalsFrom(list);
        stBarsReady = true;
    }

    function loadApps(animate: bool): void {
        const list = fetchDayApps(stDayOffset);
        if (animate) {
            replaceModel(list, true);
            return;
        }
        if (sameAppSet(list))
            syncSeconds(list);
        else
            replaceModel(list, false);
    }

    function switchStDay(nextOffset: int): void {
        const clamped = Math.max(0, Math.min(nextOffset, stMaxDayOffset));
        if (clamped === stDayOffset)
            return;
        stDayOffset = clamped;
        replaceModel(fetchDayApps(clamped), true);
        stQuietRefresh.restart();
    }

    onRightViewChanged: {
        if (rightView === 1) {
            root.loadApps(true);
        }
    }

    Timer {
        id: stQuietRefresh
        interval: 3000
        repeat: true
        running: root.rightView === 1
        onTriggered: root.loadApps(false)
    }

    Connections {
        target: ScreenTime
        function onRevisionChanged(): void {
            if (root.rightView === 1)
                root.loadApps(false);
        }
    }

    implicitWidth: 840
    implicitHeight: 480

    Component.onCompleted: {
        root.loadApps(true);
        Qt.callLater(() => {
            root.initialized = true;
        });
    }

    RowLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.medium

        // ==========================================
        // 1. LEFT CARD: Focus Station (286px Caelestia Media-style Pillar)
        // ==========================================
        StyledRect {
            Layout.preferredWidth: 286
            Layout.minimumWidth: 286
            Layout.maximumWidth: 286
            Layout.fillHeight: true
            radius: Tokens.rounding.extraLarge
            color: Colours.tPalette.m3surfaceContainer

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.small

                // 1. Header Row with MaterialShape Badge (like Dashboard User.qml)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    MaterialShape {
                        implicitSize: 28
                        shape: FocusTimer.running ? MaterialShape.Sunny : MaterialShape.Gem
                        color: FocusTimer.phase === "focus" ? Colours.palette.m3primaryContainer : Colours.palette.m3tertiaryContainer

                        animationEasing: Tokens.anim.expressiveDefaultSpatial
                        animationDuration: Tokens.anim.durations.expressiveDefaultSpatial * Tokens.anim.durations.scale

                        Behavior on color {
                            enabled: root.initialized
                            CAnim {}
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: FocusTimer.mode === "stopwatch" ? "waves" : "timer"
                            color: FocusTimer.phase === "focus" ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onTertiaryContainer
                            fontStyle: Tokens.font.icon.small
                        }
                    }

                    StyledText {
                        text: Tr.tr("Focus")
                        font: Tokens.font.title.medium
                        color: Colours.palette.m3onSurface
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    // Strict Shield Quick Toggle Button
                    StyledRect {
                        id: shieldToggleBtn

                        implicitWidth: 32
                        implicitHeight: 32
                        radius: Tokens.rounding.full
                        color: ScreenTime.strictShield ? Colours.palette.m3tertiaryContainer : Colours.tPalette.m3surfaceContainerHigh

                        Behavior on color {
                            enabled: root.initialized
                            CAnim {}
                        }

                        StateLayer {
                            radius: Tokens.rounding.full
                            color: ScreenTime.strictShield ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurface
                            onClicked: ScreenTime.setStrictShield(!ScreenTime.strictShield)
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: ScreenTime.strictShield ? "gpp_good" : "shield"
                            fontStyle: Tokens.font.icon.small
                            color: ScreenTime.strictShield ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurfaceVariant

                            Behavior on color {
                                enabled: root.initialized
                                CAnim {}
                            }
                        }
                    }

                    // Mode Toggle Button (Timer <-> Flow Stopwatch)
                    StyledRect {
                        id: modeToggleBtn

                        readonly property bool inFlow: FocusTimer.mode === "stopwatch"

                        implicitWidth: 32
                        implicitHeight: 32
                        radius: Tokens.rounding.full
                        color: inFlow ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerHigh
                        opacity: FocusTimer.canSwitchMode ? 1.0 : 0.4

                        Behavior on color {
                            enabled: root.initialized
                            CAnim {}
                        }

                        StateLayer {
                            radius: Tokens.rounding.full
                            color: modeToggleBtn.inFlow ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                            disabled: !FocusTimer.canSwitchMode
                            onClicked: FocusTimer.setMode(modeToggleBtn.inFlow ? "timer" : "stopwatch")
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "timer"
                            fontStyle: Tokens.font.icon.small
                            color: Colours.palette.m3onSurfaceVariant
                            opacity: modeToggleBtn.inFlow ? 0 : 1
                            scale: modeToggleBtn.inFlow ? 0.65 : 1
                            rotation: modeToggleBtn.inFlow ? -45 : 0

                            Behavior on opacity {
                                enabled: root.initialized
                                Anim {
                                    type: Anim.DefaultEffects
                                }
                            }

                            Behavior on scale {
                                enabled: root.initialized
                                Anim {
                                    type: Anim.DefaultSpatial
                                }
                            }

                            Behavior on rotation {
                                enabled: root.initialized
                                Anim {
                                    type: Anim.DefaultSpatial
                                }
                            }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "waves"
                            fontStyle: Tokens.font.icon.small
                            color: Colours.palette.m3onSecondaryContainer
                            opacity: modeToggleBtn.inFlow ? 1 : 0
                            scale: modeToggleBtn.inFlow ? 1 : 0.65
                            rotation: modeToggleBtn.inFlow ? 0 : 45

                            Behavior on opacity {
                                enabled: root.initialized
                                Anim {
                                    type: Anim.DefaultEffects
                                }
                            }

                            Behavior on scale {
                                enabled: root.initialized
                                Anim {
                                    type: Anim.DefaultSpatial
                                }
                            }

                            Behavior on rotation {
                                enabled: root.initialized
                                Anim {
                                    type: Anim.DefaultSpatial
                                }
                            }
                        }
                    }
                }

                // 2. Notification-Panel Style Expanding Phase Pill [ 📖 Study | ☕ | 🛋️ ]
                StyledRect {
                    id: phasePillTrack

                    readonly property var phases: [
                        { label: Tr.tr("Study"), phase: "focus", icon: "menu_book" },
                        { label: Tr.tr("Short Break"), phase: "shortBreak", icon: "coffee" },
                        { label: Tr.tr("Long Break"), phase: "longBreak", icon: "weekend" }
                    ]
                    readonly property int activeIndex: {
                        if (FocusTimer.phase === "shortBreak") return 1;
                        if (FocusTimer.phase === "longBreak") return 2;
                        return 0;
                    }
                    readonly property color activeColor: FocusTimer.phase === "focus"
                        ? Colours.palette.m3primary
                        : Colours.palette.m3tertiary
                    readonly property color activeOnColor: FocusTimer.phase === "focus"
                        ? Colours.palette.m3onPrimary
                        : Colours.palette.m3onTertiary

                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 2
                    implicitWidth: phasePillRow.width
                    implicitHeight: 34
                    radius: Tokens.rounding.full
                    color: Colours.tPalette.m3surfaceContainerHigh

                    StyledRect {
                        id: activePhaseIndicator

                        readonly property Item activeTabItem: phaseRepeater.count > phasePillTrack.activeIndex
                            ? phaseRepeater.itemAt(phasePillTrack.activeIndex)
                            : null

                        height: parent.height
                        radius: Tokens.rounding.full
                        color: phasePillTrack.activeColor
                        x: phasePillTrack.activeIndex * 40
                        width: activeTabItem ? activeTabItem.targetWidth : 40

                        Behavior on x {
                            enabled: root.initialized
                            Anim {
                                type: Anim.EmphasizedLarge
                            }
                        }

                        Behavior on width {
                            enabled: root.initialized
                            Anim {
                                type: Anim.EmphasizedLarge
                            }
                        }

                        Behavior on color {
                            enabled: root.initialized
                            CAnim {}
                        }
                    }

                    Row {
                        id: phasePillRow

                        height: parent.height
                        spacing: 0

                        Repeater {
                            id: phaseRepeater
                            model: phasePillTrack.phases

                            delegate: Item {
                                id: phaseBtn

                                required property var modelData
                                required property int index

                                readonly property bool active: FocusTimer.phase === modelData.phase
                                readonly property real targetWidth: active
                                    ? Math.ceil(phaseIcon.implicitWidth + Tokens.spacing.small + phaseLabelText.implicitWidth + Tokens.padding.medium * 2)
                                    : 40

                                height: phasePillRow.height
                                width: targetWidth
                                clip: true

                                Behavior on width {
                                    enabled: root.initialized
                                    Anim {
                                        type: Anim.EmphasizedLarge
                                    }
                                }

                                StateLayer {
                                    id: phaseState

                                    radius: Tokens.rounding.full
                                    color: phaseBtn.active ? phasePillTrack.activeOnColor : Colours.palette.m3onSurface
                                    onClicked: FocusTimer.setPhase(phaseBtn.modelData.phase)
                                }

                                Row {
                                    id: phaseContent

                                    anchors.centerIn: parent
                                    spacing: phaseBtn.active ? Tokens.spacing.small : 0

                                    Behavior on spacing {
                                        enabled: root.initialized
                                        Anim {
                                            type: Anim.DefaultSpatial
                                        }
                                    }

                                    MaterialIcon {
                                        id: phaseIcon

                                        anchors.verticalCenter: parent.verticalCenter
                                        text: phaseBtn.modelData.icon
                                        color: phaseBtn.active
                                            ? phasePillTrack.activeOnColor
                                            : (phaseState.containsMouse ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant)
                                        fontStyle: Tokens.font.icon.small
                                        fill: phaseBtn.active ? 1 : 0

                                        Behavior on color {
                                            enabled: root.initialized
                                            CAnim {}
                                        }

                                        Behavior on fill {
                                            enabled: root.initialized
                                            Anim {
                                                type: Anim.DefaultEffects
                                            }
                                        }
                                    }

                                    Item {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: phaseBtn.active ? phaseLabelText.implicitWidth : 0
                                        height: phaseLabelText.implicitHeight
                                        clip: true

                                        Behavior on width {
                                            enabled: root.initialized
                                            Anim {
                                                type: Anim.EmphasizedLarge
                                            }
                                        }

                                        StyledText {
                                            id: phaseLabelText

                                            anchors.verticalCenter: parent.verticalCenter
                                            text: phaseBtn.modelData.label
                                            color: phasePillTrack.activeOnColor
                                            font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
                                            opacity: phaseBtn.active ? 1 : 0

                                            Behavior on opacity {
                                                enabled: root.initialized
                                                Anim {
                                                    type: Anim.FastEffects
                                                }
                                            }

                                            Behavior on color {
                                                enabled: root.initialized
                                                CAnim {}
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 3. Caelestia Wavy Circular Dial + Cycle Dots (like Dashboard Media.qml)
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.small

                        CircularProgress {
                            id: progressDial

                            Layout.alignment: Qt.AlignHCenter
                            implicitSize: 138
                            strokeWidth: 7
                            value: FocusTimer.progress
                            fgColour: FocusTimer.phase === "focus" ? Colours.palette.m3primary : Colours.palette.m3tertiary
                            // Uses default Caelestia bgColour (Colours.palette.m3secondaryContainer) like MemoryCard & Media!
                            wavy: FocusTimer.running
                            waveFrequency: 8
                            waveDuration: 2200
                            wavePaused: !FocusTimer.running

                            Behavior on clampedVal {
                                enabled: root.initialized
                                Anim {}
                            }

                            Behavior on fgColour {
                                enabled: root.initialized
                                CAnim {}
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 0

                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: FocusTimer.display
                                    color: FocusTimer.phase === "focus" ? Colours.palette.m3primary : Colours.palette.m3tertiary
                                    font: Tokens.font.clock.size(28).weight(Font.Bold).build()

                                    Behavior on color {
                                        enabled: root.initialized
                                        CAnim {}
                                    }
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: FocusTimer.phaseLabel
                                    color: Colours.palette.m3onSurfaceVariant
                                    font: Tokens.font.body.small
                                }
                            }
                        }

                        // Clean Cycle Dots Row Below Dial
                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 6
                            visible: FocusTimer.cyclesBeforeLongBreak > 0

                            Repeater {
                                model: FocusTimer.cyclesBeforeLongBreak

                                StyledRect {
                                    required property int index

                                    width: (FocusTimer.cycleCount > index) ? 16 : 6
                                    height: 6
                                    radius: Tokens.rounding.full
                                    color: (FocusTimer.cycleCount > index) ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer

                                    Behavior on width {
                                        enabled: root.initialized
                                        Anim {}
                                    }

                                    Behavior on color {
                                        enabled: root.initialized
                                        CAnim {}
                                    }
                                }
                            }
                        }
                    }
                }

                // 4. Subject Chips Row (Centered)
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 26
                    visible: GlobalConfig.focus.subjects.length > 0

                    Flickable {
                        id: subjectFlickable

                        anchors.fill: parent
                        contentWidth: Math.max(width, subjectRow.implicitWidth)
                        flickableDirection: Flickable.HorizontalFlick
                        clip: true

                        RowLayout {
                            id: subjectRow

                            x: Math.max(0, (subjectFlickable.width - implicitWidth) / 2)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Tokens.spacing.extraSmall

                            Repeater {
                                model: GlobalConfig.focus.subjects

                                StyledRect {
                                    id: subjChip

                                    required property string modelData
                                    readonly property bool isSelected: FocusTimer.subject === modelData

                                    radius: Tokens.rounding.full
                                    color: isSelected ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHigh
                                    implicitWidth: subjText.implicitWidth + Tokens.padding.small * 2
                                    implicitHeight: 24

                                    Behavior on color {
                                        enabled: root.initialized
                                        CAnim {}
                                    }

                                    StateLayer {
                                        radius: Tokens.rounding.full
                                        color: subjChip.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                        onClicked: FocusTimer.setSubject(subjChip.modelData)
                                    }

                                    StyledText {
                                        id: subjText

                                        anchors.centerIn: parent
                                        text: subjChip.modelData
                                        color: subjChip.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                        font: Tokens.font.label.small

                                        Behavior on color {
                                            enabled: root.initialized
                                            CAnim {}
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 5. Bottom Control Row (Shape-Morphing Caelestia ButtonRow like Media.qml)
                ButtonRow {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    IconButton {
                        fillWidth: true
                        icon: FocusTimer.running ? "pause" : "play_arrow"
                        type: IconButton.Filled
                        isRound: true
                        shapeMorph: true
                        checked: FocusTimer.running
                        onClicked: FocusTimer.toggle()
                    }

                    // Stepper Pill [- 5m +]
                    StyledRect {
                        id: adjustPill

                        property bool fillWidth: false

                        implicitHeight: 36
                        implicitWidth: adjustRow.implicitWidth + Tokens.padding.extraSmall * 2
                        radius: Tokens.rounding.full
                        color: Colours.tPalette.m3surfaceContainerHigh
                        opacity: (!FocusTimer.sessionActive || FocusTimer.isStopwatch) ? 0.38 : 1.0

                        RowLayout {
                            id: adjustRow

                            anchors.centerIn: parent
                            spacing: 0

                            StyledRect {
                                implicitWidth: 26
                                implicitHeight: 26
                                radius: Tokens.rounding.full
                                color: "transparent"

                                StateLayer {
                                    radius: Tokens.rounding.full
                                    color: Colours.palette.m3onSurface
                                    disabled: !FocusTimer.sessionActive || FocusTimer.isStopwatch
                                    onClicked: FocusTimer.reduce()
                                }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: "remove"
                                    fontStyle: Tokens.font.icon.small
                                    color: Colours.palette.m3onSurface
                                }
                            }

                            StyledText {
                                text: "5m"
                                font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
                                color: Colours.palette.m3onSurface
                            }

                            StyledRect {
                                implicitWidth: 26
                                implicitHeight: 26
                                radius: Tokens.rounding.full
                                color: "transparent"

                                StateLayer {
                                    radius: Tokens.rounding.full
                                    color: Colours.palette.m3onSurface
                                    disabled: !FocusTimer.sessionActive || FocusTimer.isStopwatch
                                    onClicked: FocusTimer.extend()
                                }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: "add"
                                    fontStyle: Tokens.font.icon.small
                                    color: Colours.palette.m3onSurface
                                }
                            }
                        }
                    }

                    IconButton {
                        icon: FocusTimer.phase === "focus" ? "coffee" : "skip_next"
                        type: IconButton.Tonal
                        isRound: true
                        shapeMorph: true
                        disabled: !FocusTimer.sessionActive
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
        }

        // ==========================================
        // 2. RIGHT BENTO AREA: Free-Floating Caelestia Cards (542px, zero wrapper box!)
        // ==========================================
        Item {
            Layout.preferredWidth: 542
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ----------------------------------------------------
            // VIEW 0: Free-Floating Focus Overview Bento Grid
            // (Just like Performance.qml & Dash.qml!)
            // ----------------------------------------------------
            ColumnLayout {
                id: focusOverviewView

                anchors.fill: parent
                spacing: Tokens.spacing.medium
                opacity: root.rightView === 0 ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    enabled: root.initialized
                    Anim {
                        type: Anim.EmphasizedLarge
                    }
                }

                // ROW 1: Streak & 7-Day Hero Card (Left) + Daily Goal Card (Right, exact MemoryCard.qml twin)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 234
                    Layout.maximumHeight: 234
                    spacing: Tokens.spacing.medium

                    // 1A. Streak & 7-Day Card (HeroCard.qml + Calendar.qml aesthetic)
                    StyledRect {
                        id: streakCard

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Tokens.rounding.extraLarge
                        color: Colours.tPalette.m3surfaceContainer

                        HoverHandler {
                            id: streakCardHover
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.large
                            spacing: Tokens.spacing.small

                            // Top Row: Title + Notes Streak Pill (only when streak > 0) + Rest Day Toggle + View Switcher
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.spacing.small

                                MaterialIcon {
                                    text: "local_fire_department"
                                    fill: 1
                                    color: Colours.palette.m3primary
                                    fontStyle: Tokens.font.icon.medium
                                }

                                StyledText {
                                    text: Tr.tr("Streak")
                                    font: Tokens.font.title.medium
                                    color: Colours.palette.m3onSurface
                                }

                                // Exact Notes-style StreakFlame Pill Badge (only when streak > 0)
                                StyledRect {
                                    visible: (FocusLedger.streak || 0) > 0
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: Tokens.rounding.full
                                    implicitHeight: 20
                                    implicitWidth: streakPillRow.implicitWidth + 12
                                    color: Colours.palette.m3tertiaryContainer

                                    HoverHandler {
                                        id: streakPillHover
                                    }

                                    RowLayout {
                                        id: streakPillRow

                                        anchors.centerIn: parent
                                        spacing: 3

                                        StreakFlame {
                                            Layout.alignment: Qt.AlignVCenter
                                            implicitWidth: 16
                                            implicitHeight: 16
                                            outerColor: Colours.palette.m3onTertiaryContainer
                                            innerColor: Colours.palette.m3tertiaryContainer
                                            autoplay: streakPillHover.hovered || streakCardHover.hovered || FocusLedger.streak > 0
                                        }

                                        StyledText {
                                            text: String(FocusLedger.streak || 0)
                                            font: Tokens.font.label.small
                                            color: Colours.palette.m3onTertiaryContainer
                                        }
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                // Rest Day Toggle Pill
                                StyledRect {
                                    implicitHeight: 26
                                    implicitWidth: restRow.implicitWidth + Tokens.padding.small * 2
                                    radius: Tokens.rounding.full
                                    color: FocusLedger.todayRest ? Colours.palette.m3tertiaryContainer : Colours.tPalette.m3surfaceContainerHigh

                                    Behavior on color {
                                        enabled: root.initialized
                                        CAnim {}
                                    }

                                    StateLayer {
                                        radius: Tokens.rounding.full
                                        color: FocusLedger.todayRest ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurface
                                        onClicked: FocusLedger.setRestDay(FocusLedger.todayKey, !FocusLedger.todayRest)
                                    }

                                    RowLayout {
                                        id: restRow

                                        anchors.centerIn: parent
                                        spacing: 4

                                        MaterialIcon {
                                            text: "bedtime"
                                            fontStyle: Tokens.font.icon.small
                                            color: FocusLedger.todayRest ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurfaceVariant
                                        }

                                        StyledText {
                                            text: Tr.tr("Rest")
                                            font: Tokens.font.label.small
                                            color: FocusLedger.todayRest ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurfaceVariant
                                        }
                                    }
                                }
                            }

                            // Middle Row: Sub-label + HeroCard-style MaterialShape Badge on the right
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: Tokens.spacing.medium

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    StyledText {
                                        text: FocusLedger.streak > 0
                                            ? Tr.tr("%1 days in a row").arg(FocusLedger.streak)
                                            : Tr.tr("Start a streak today")
                                        font: Tokens.font.body.medium
                                        color: FocusLedger.streak > 0 ? Colours.palette.m3primary : Colours.palette.m3onSurface
                                    }

                                    StyledText {
                                        text: Tr.tr("%1 sessions completed today").arg(FocusLedger.todaySessions)
                                        font: Tokens.font.body.small
                                        color: Colours.palette.m3onSurfaceVariant
                                    }
                                }

                                // Signature Caelestia HeroCard MaterialShape Badge
                                MaterialShape {
                                    implicitSize: 54
                                    color: Colours.palette.m3secondaryContainer
                                    shape: {
                                        if (FocusLedger.streak >= 7)
                                            return MaterialShape.SoftBurst;
                                        if (FocusLedger.streak >= 3)
                                            return MaterialShape.Sunny;
                                        return MaterialShape.Cookie4Sided;
                                    }

                                    animationEasing: Tokens.anim.expressiveDefaultSpatial
                                    animationDuration: Tokens.anim.durations.expressiveDefaultSpatial * Tokens.anim.durations.scale

                                    Behavior on color {
                                        CAnim {}
                                    }

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: `${FocusLedger.streak}d`
                                        color: Colours.palette.m3primary
                                        font: Tokens.font.headline.builders.small.width(50).build()
                                    }
                                }
                            }

                            // Bottom 7-Day Row with Calendar.qml MaterialShape.Sunny for Today + StreakFlame for Done days
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Repeater {
                                    model: FocusLedger.weekKeys()

                                    ColumnLayout {
                                        id: dayCol

                                        required property string modelData
                                        required property int index
                                        readonly property string dayState: FocusLedger.dayState(modelData)
                                        readonly property bool isToday: modelData === FocusLedger.todayKey

                                        Layout.fillWidth: true
                                        spacing: 4

                                        Item {
                                            Layout.alignment: Qt.AlignHCenter
                                            implicitWidth: 30
                                            implicitHeight: 30

                                            HoverHandler {
                                                id: dayCircleHover
                                            }

                                            // MaterialShape indicator (Sunny for Today like Calendar.qml, Cookie6Sided for Done, Pill/Circle for others)
                                            MaterialShape {
                                                anchors.centerIn: parent
                                                implicitSize: dayCol.isToday ? 30 : 26
                                                shape: dayCol.dayState === "done"
                                                    ? MaterialShape.Cookie6Sided
                                                    : (dayCol.isToday ? MaterialShape.Sunny : MaterialShape.Oval)
                                                color: dayCol.dayState === "done"
                                                    ? Colours.palette.m3tertiaryContainer
                                                    : (dayCol.dayState === "rest"
                                                        ? Colours.palette.m3secondaryContainer
                                                        : (dayCol.isToday ? Colours.palette.m3primaryContainer : Colours.tPalette.m3surfaceContainerHigh))

                                                animationEasing: Tokens.anim.expressiveDefaultSpatial
                                                animationDuration: Tokens.anim.durations.expressiveDefaultSpatial * Tokens.anim.durations.scale

                                                Behavior on color {
                                                    CAnim {}
                                                }
                                            }

                                            // Animated StreakFlame ONLY on days where streak/goal is completed!
                                            StreakFlame {
                                                anchors.centerIn: parent
                                                visible: dayCol.dayState === "done"
                                                implicitWidth: 17
                                                implicitHeight: 17
                                                outerColor: Colours.palette.m3onTertiaryContainer
                                                innerColor: Colours.palette.m3tertiaryContainer
                                                autoplay: dayCol.dayState === "done" && (dayCol.isToday || dayCircleHover.hovered || streakCardHover.hovered)
                                            }

                                            MaterialIcon {
                                                anchors.centerIn: parent
                                                visible: dayCol.dayState === "rest"
                                                text: "bedtime"
                                                color: Colours.palette.m3onSecondaryContainer
                                                fontStyle: Tokens.font.icon.small
                                            }
                                        }

                                        StyledText {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: root.dayInitials[dayCol.index] || ""
                                            font: Tokens.font.body.builders.small.weight(dayCol.isToday ? Font.Bold : Font.Medium).build()
                                            color: dayCol.isToday
                                                ? Colours.palette.m3primary
                                                : ((dayCol.index === 5 || dayCol.index === 6) ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 1B. Daily Goal Card (1:1 Exact Twin of MemoryCard.qml!)
                    StyledRect {
                        readonly property color accent: Colours.palette.m3tertiary
                        readonly property real percentage: Math.max(0, Math.min(1, FocusLedger.todaySecs / Math.max(1, GlobalConfig.focus.dailyGoalMins * 60)))

                        Layout.preferredWidth: 182
                        Layout.minimumWidth: 182
                        Layout.maximumWidth: 182
                        Layout.fillHeight: true
                        color: Colours.tPalette.m3surfaceContainer
                        radius: Tokens.rounding.extraLarge

                        ColumnLayout {
                            id: goalLayout

                            anchors.centerIn: parent
                            spacing: Tokens.spacing.extraSmall

                            RowLayout {
                                Layout.leftMargin: -Tokens.padding.extraSmall
                                spacing: Tokens.spacing.small

                                MaterialIcon {
                                    text: "track_changes"
                                    fill: 1
                                    color: Colours.palette.m3tertiary
                                    fontStyle: Tokens.font.icon.builders.medium.weight(Font.DemiBold).build()
                                }

                                StyledText {
                                    text: Tr.tr("Daily Goal")
                                    font: Tokens.font.title.medium
                                }
                            }

                            CircularProgress {
                                Layout.topMargin: Tokens.spacing.medium
                                Layout.alignment: Qt.AlignHCenter
                                implicitSize: usageColumn.implicitHeight + thickness + Tokens.padding.largeIncreased * 2
                                startAngle: -225
                                sweepAngle: 270

                                fgColour: Colours.palette.m3tertiary
                                value: Math.max(0, Math.min(1, FocusLedger.todaySecs / Math.max(1, GlobalConfig.focus.dailyGoalMins * 60)))

                                Behavior on clampedVal {
                                    enabled: root.initialized
                                    Anim {}
                                }

                                ColumnLayout {
                                    id: usageColumn

                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: Tokens.padding.extraSmall
                                    spacing: 0

                                    StyledText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: Strings.percentOne(Math.max(0, Math.min(1, FocusLedger.todaySecs / Math.max(1, GlobalConfig.focus.dailyGoalMins * 60))))
                                        font: Tokens.font.title.builders.large.width(90).build()
                                        color: Colours.palette.m3tertiary
                                    }

                                    StyledText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: Tr.tr("Goal")
                                        font: Tokens.font.body.small
                                        color: Colours.palette.m3onSurfaceVariant
                                    }
                                }
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: `${FocusLedger.fmt(FocusLedger.todaySecs)} / ${FocusLedger.fmt(GlobalConfig.focus.dailyGoalMins * 60)}`
                                font: Tokens.font.body.medium
                            }
                        }
                    }
                }

                // ROW 2: This Week Card (NetworkCard.qml aesthetic + Notification-Style Wellbeing Switcher)
                StyledRect {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Tokens.rounding.extraLarge
                    color: Colours.tPalette.m3surfaceContainer

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.large
                        anchors.bottomMargin: Tokens.padding.medium
                        spacing: Tokens.spacing.small

                        // Header Row: Icon + "This Week" + Total + Expanding Pill Switcher [ 🔥 Focus | 📊 ]
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                text: "swap_vert"
                                color: Colours.palette.m3primary
                                fontStyle: Tokens.font.icon.medium
                            }

                            StyledText {
                                text: Tr.tr("This Week")
                                font: Tokens.font.title.medium
                            }

                            StyledRect {
                                radius: Tokens.rounding.full
                                color: Colours.tPalette.m3surfaceContainerHigh
                                implicitHeight: 22
                                implicitWidth: weekTotalText.implicitWidth + 12

                                StyledText {
                                    id: weekTotalText

                                    anchors.centerIn: parent
                                    text: FocusLedger.fmt(FocusLedger.weekSecs)
                                    font: Tokens.font.label.small
                                    color: Colours.palette.m3primary
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            // Notification-Panel Style Expanding Pill [ 🔥 Focus | 📊 ]
                            ViewSwitcherPill {}
                        }

                        // Stacked Horizontal Progress Bar (with default secondaryContainer track like HeroCard)
                        Item {
                            id: barContainer

                            Layout.fillWidth: true
                            implicitHeight: Tokens.padding.small
                            clip: true

                            StyledRect {
                                anchors.fill: parent
                                radius: Tokens.rounding.full
                                color: Colours.palette.m3secondaryContainer
                            }

                            Row {
                                anchors.fill: parent

                                Repeater {
                                    model: FocusLedger.weekNames

                                    StyledRect {
                                        required property string modelData
                                        required property int index

                                        height: parent.height
                                        width: (FocusLedger.weekSecs > 0) ? Math.round((FocusLedger.weekSecsFor(modelData) / FocusLedger.weekSecs) * barContainer.width) : 0
                                        color: root.subjectColors[index % root.subjectColors.length]

                                        Behavior on width {
                                            enabled: root.initialized
                                            Anim {}
                                        }
                                    }
                                }
                            }
                        }

                        // Subject Rows (NetworkCard.qml metric row style)
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            StyledText {
                                anchors.centerIn: parent
                                visible: FocusLedger.weekSecs === 0
                                text: Tr.tr("No study logged this week")
                                font: Tokens.font.body.small
                                color: Colours.palette.m3outline
                            }

                            GridLayout {
                                anchors.fill: parent
                                visible: FocusLedger.weekSecs > 0
                                columns: 2
                                columnSpacing: Tokens.spacing.large * 1.5
                                rowSpacing: 2

                                Repeater {
                                    model: FocusLedger.weekNames.slice(0, 6)

                                    RowLayout {
                                        required property string modelData
                                        required property int index

                                        Layout.fillWidth: true
                                        spacing: Tokens.spacing.small

                                        MaterialShape {
                                            implicitSize: 12
                                            shape: index === 0 ? MaterialShape.Sunny : (index === 1 ? MaterialShape.Cookie4Sided : MaterialShape.Oval)
                                            color: root.subjectColors[index % root.subjectColors.length]
                                        }

                                        StyledText {
                                            text: modelData === "__none__" ? Tr.tr("Untagged") : modelData
                                            font: Tokens.font.body.small
                                            color: Colours.palette.m3onSurfaceVariant
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        StyledText {
                                            text: FocusLedger.fmt(FocusLedger.weekSecsFor(modelData))
                                            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                                            color: root.subjectColors[index % root.subjectColors.length]
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ----------------------------------------------------
            // VIEW 1: Digital Wellbeing / Screen Time Card (GulTion Port)
            // ----------------------------------------------------
            StyledRect {
                id: screenTimeCard

                anchors.fill: parent
                radius: Tokens.rounding.extraLarge
                color: Colours.tPalette.m3surfaceContainer
                clip: true
                opacity: root.rightView === 1 ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    enabled: root.initialized
                    Anim {
                        type: Anim.EmphasizedLarge
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    spacing: Tokens.spacing.medium

                    // Top Header Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: "monitoring"
                            color: Colours.palette.m3primary
                            fontStyle: Tokens.font.icon.medium
                        }

                        StyledText {
                            text: Tr.tr("Screen Time")
                            font: Tokens.font.title.medium
                            color: Colours.palette.m3onSurface
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        ViewSwitcherPill {}
                    }

                    // Date Switcher Row
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(prevDayBtn.implicitHeight, dayCenter.implicitHeight)

                        IconButton {
                            id: prevDayBtn

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            type: IconButton.Tonal
                            icon: "chevron_left"
                            isRound: true
                            shapeMorph: true
                            disabled: root.stDayOffset >= root.stMaxDayOffset
                            onClicked: root.switchStDay(root.stDayOffset + 1)
                        }

                        Column {
                            id: dayCenter

                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Tokens.spacing.extraSmall

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.stDayTitle
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurfaceVariant
                                horizontalAlignment: Text.AlignHCenter
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.stIsEmpty ? "00h 00m" : root.prettyTotal(root.stDayTotalSeconds)
                                font: Tokens.font.body.builders.large.size(32).weight(Font.Bold).build()
                                color: Colours.palette.m3primary
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        IconButton {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            type: IconButton.Tonal
                            icon: "chevron_right"
                            isRound: true
                            shapeMorph: true
                            disabled: root.stDayOffset <= 0
                            onClicked: root.switchStDay(root.stDayOffset - 1)
                        }
                    }

                    // Chart Area
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        // Empty State
                        Column {
                            anchors.centerIn: parent
                            spacing: Tokens.spacing.small
                            visible: root.stIsEmpty

                            MaterialIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "hourglass_empty"
                                fontStyle: Tokens.font.icon.builders.extraLarge.scale(1.6).build()
                                color: Colours.palette.m3onSurfaceVariant
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Tr.tr("No activity yet")
                                font: Tokens.font.title.medium
                                color: Colours.palette.m3onSurface
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 280
                                wrapMode: Text.Wrap
                                horizontalAlignment: Text.AlignHCenter
                                text: Tr.tr("Screen Time will show your top apps here once you use the desktop for a bit.")
                                font: Tokens.font.body.small
                                color: Colours.palette.m3onSurfaceVariant
                            }
                        }

                        // Top 5 Apps Vertical Gradient Columns
                        Row {
                            id: chartRow

                            readonly property real footSlot: 60
                            readonly property real timeReserve: 36
                            readonly property real barSlot: Math.max(80, height - footSlot - timeReserve)

                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            spacing: Tokens.spacing.medium
                            visible: !root.stIsEmpty

                            Repeater {
                                model: stAppsModel

                                delegate: Item {
                                    id: col

                                    required property string appClass
                                    required property int seconds
                                    required property int index

                                    readonly property string displayName: DesktopEntries.heuristicLookup(appClass)?.name || ScreenTime.appName(appClass)
                                    readonly property real ratio: seconds / Math.max(root.stMaxSeconds, 1)
                                    readonly property real intensity: root.intensityFor(index, stAppsModel.count, ratio)
                                    readonly property bool isHero: index === 0
                                    readonly property bool isShort: ratio < 0.22
                                    readonly property int sharePct: Math.round((seconds / Math.max(root.stDayTotalSeconds, 1)) * 100)
                                    readonly property real targetBarH: root.stBarsReady ? Math.max(ratio * chartRow.barSlot, 28) : 0
                                    readonly property int timeHourSize: Math.round(10 + ratio * (isHero ? 12 : 9))
                                    readonly property int timeMinSize: Math.round(9 + ratio * (isHero ? 10 : 7))
                                    readonly property color barTop: root.mixColor(Colours.palette.m3primary, Qt.rgba(1, 1, 1, 1), 0.35 - intensity * 0.2)
                                    readonly property color barBottom: root.mixColor(Colours.palette.m3primary, Colours.palette.m3primaryContainer, 0.55 - intensity * 0.35)
                                    readonly property int gen: root.stAnimGen

                                    width: isHero ? 88 : 68
                                    height: parent.height
                                    opacity: root.stAllowAppear ? 0 : 1

                                    onGenChanged: {
                                        if (!root.stAllowAppear)
                                            return;
                                        opacity = 0;
                                        appear.restart();
                                    }

                                    Component.onCompleted: {
                                        if (root.stAllowAppear)
                                            appear.start();
                                        else
                                            opacity = 1;
                                    }

                                    SequentialAnimation {
                                        id: appear

                                        PauseAnimation {
                                            duration: Math.max(0, col.index * 40)
                                        }
                                        NumberAnimation {
                                            target: col
                                            property: "opacity"
                                            from: 0
                                            to: 1
                                            duration: 320
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    Column {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        spacing: Tokens.spacing.extraSmall

                                        Column {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            spacing: 0

                                            StyledText {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: `${col.sharePct}%`
                                                font: Tokens.font.body.builders.medium.size(col.isHero ? 17 : 14).weight(Font.Bold).build()
                                                color: col.isHero ? Colours.palette.m3primary : Colours.palette.m3secondary
                                            }
                                        }

                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: col.width
                                            height: col.targetBarH
                                            radius: Tokens.rounding.large

                                            gradient: Gradient {
                                                GradientStop {
                                                    position: 0
                                                    color: col.isHero ? Qt.lighter(Colours.palette.m3primary, 1.15) : col.barTop
                                                }
                                                GradientStop {
                                                    position: 1
                                                    color: col.isHero ? Colours.palette.m3primary : col.barBottom
                                                }
                                            }

                                            Behavior on height {
                                                enabled: root.stBarsReady
                                                NumberAnimation {
                                                    duration: 520
                                                    easing.type: Easing.OutCubic
                                                }
                                            }

                                            Column {
                                                anchors.centerIn: parent
                                                spacing: 0

                                                StyledText {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    visible: root.hourLabel(col.seconds).length > 0
                                                    text: root.hourLabel(col.seconds)
                                                    font: Tokens.font.body.builders.medium.size(col.timeHourSize).weight(Font.Bold).build()
                                                    color: Colours.palette.m3onPrimary
                                                }

                                                StyledText {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    text: root.minuteLabel(col.seconds)
                                                    font: Tokens.font.body.builders.medium.size(col.timeMinSize).weight(Font.DemiBold).build()
                                                    color: Colours.palette.m3onPrimary
                                                }
                                            }
                                        }

                                        Item {
                                            width: col.width
                                            height: chartRow.footSlot

                                            Column {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.top: parent.top
                                                anchors.topMargin: Tokens.spacing.small
                                                width: parent.width
                                                spacing: Tokens.spacing.extraSmall

                                                IconImage {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    asynchronous: true
                                                    implicitSize: 28
                                                    source: Icons.getAppIcon(col.appClass, "image-missing")
                                                }

                                                StyledText {
                                                    width: parent.width
                                                    horizontalAlignment: Text.AlignHCenter
                                                    text: col.displayName
                                                    font: Tokens.font.label.small
                                                    color: col.isHero ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 2
                                                    wrapMode: Text.Wrap
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Reusable Notification-Panel Style Expanding Pill Switcher [ 🔥 Focus | 📊 ] / [ 🔥 | 📊 Wellbeing ]
    component ViewSwitcherPill: StyledRect {
        id: viewTogglePill

        readonly property var views: [
            { label: Tr.tr("Focus"), icon: "local_fire_department" },
            { label: Tr.tr("Wellbeing"), icon: "monitoring" }
        ]

        implicitHeight: 32
        implicitWidth: viewToggleRow.width
        radius: Tokens.rounding.full
        color: Colours.tPalette.m3surfaceContainerHigh

        StyledRect {
            id: viewIndicator

            readonly property Item activeViewItem: viewRepeater.count > root.rightView
                ? viewRepeater.itemAt(root.rightView)
                : null

            height: parent.height
            radius: Tokens.rounding.full
            color: Colours.palette.m3primary
            x: root.rightView * 38
            width: activeViewItem ? activeViewItem.targetWidth : 38

            Behavior on x {
                enabled: root.initialized
                Anim {
                    type: Anim.EmphasizedLarge
                }
            }

            Behavior on width {
                enabled: root.initialized
                Anim {
                    type: Anim.EmphasizedLarge
                }
            }
        }

        Row {
            id: viewToggleRow

            height: parent.height
            spacing: 0

            Repeater {
                id: viewRepeater
                model: viewTogglePill.views

                delegate: Item {
                    id: viewBtn

                    required property var modelData
                    required property int index

                    readonly property bool active: root.rightView === index
                    readonly property real targetWidth: active
                        ? Math.ceil(viewIcon.implicitWidth + Tokens.spacing.small + viewLabelText.implicitWidth + Tokens.padding.medium * 2)
                        : 38

                    height: viewToggleRow.height
                    width: targetWidth
                    clip: true

                    Behavior on width {
                        enabled: root.initialized
                        Anim {
                            type: Anim.EmphasizedLarge
                        }
                    }

                    StateLayer {
                        id: viewState

                        radius: Tokens.rounding.full
                        color: viewBtn.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                        onClicked: root.rightView = viewBtn.index
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: viewBtn.active ? Tokens.spacing.small : 0

                        Behavior on spacing {
                            enabled: root.initialized
                            Anim {
                                type: Anim.DefaultSpatial
                            }
                        }

                        MaterialIcon {
                            id: viewIcon

                            anchors.verticalCenter: parent.verticalCenter
                            text: viewBtn.modelData.icon
                            color: viewBtn.active
                                ? Colours.palette.m3onPrimary
                                : (viewState.containsMouse ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant)
                            fontStyle: Tokens.font.icon.small
                            fill: viewBtn.active ? 1 : 0

                            Behavior on color {
                                enabled: root.initialized
                                CAnim {}
                            }

                            Behavior on fill {
                                enabled: root.initialized
                                Anim {
                                    type: Anim.DefaultEffects
                                }
                            }
                        }

                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: viewBtn.active ? viewLabelText.implicitWidth : 0
                            height: viewLabelText.implicitHeight
                            clip: true

                            Behavior on width {
                                enabled: root.initialized
                                Anim {
                                    type: Anim.EmphasizedLarge
                                }
                            }

                            StyledText {
                                id: viewLabelText

                                anchors.verticalCenter: parent.verticalCenter
                                text: viewBtn.modelData.label
                                color: Colours.palette.m3onPrimary
                                font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
                                opacity: viewBtn.active ? 1 : 0

                                Behavior on opacity {
                                    enabled: root.initialized
                                    Anim {
                                        type: Anim.FastEffects
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

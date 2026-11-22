pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import M3Shapes
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import "../components"

Item {
    id: root

    required property var wallpaper
    property bool weActive: false
    property bool locked: true
    property string sizeMode: "1x1"
    property real widgetScale: WidgetMetrics.scale
    property string surfaceStyle: ""
    property bool blurEnabled: Config.background.desktopWidgets.blur
    property real plateOpacity: Config.background.desktopWidgets.opacity
    property var widgetOptions: ({})

    property string selectedTab: FocusTimer.isStopwatch ? "stopwatch" : "focus"

    readonly property real s: Math.max(0.55, Math.min(2.2, widgetScale > 0 ? widgetScale : WidgetMetrics.scale))
    readonly property string effectiveSize: WidgetMetrics.fallbackSizeFor("timers", sizeMode)
    readonly property bool focusActive: !FocusTimer.isStopwatch
    readonly property bool stopwatchActive: FocusTimer.isStopwatch
    readonly property bool isTabRunning: selectedTab === "stopwatch"
        ? (stopwatchActive && FocusTimer.running)
        : (focusActive && FocusTimer.running)
    readonly property real ringProgress: selectedTab === "stopwatch"
        ? (stopwatchActive ? ((FocusTimer.elapsed % 60) / 60) : 0)
        : (focusActive ? FocusTimer.progress : 0)
    readonly property color accentColor: selectedTab === "stopwatch"
        ? Colours.palette.m3secondary
        : (FocusTimer.phase === "focus" ? Colours.palette.m3primary : Colours.palette.m3tertiary)
    readonly property string mainDisplay: selectedTab === "stopwatch"
        ? (stopwatchActive ? FocusTimer.display : "00:00")
        : (focusActive ? FocusTimer.display : `${String(FocusTimer.focusMins).padStart(2, "0")}:00`)
    readonly property int focusDurationMins: Math.round((FocusTimer.sessionActive ? FocusTimer.phaseTotal : FocusTimer.durationSecs) / 60)
    readonly property string stateLabel: selectedTab === "stopwatch"
        ? ((stopwatchActive && FocusTimer.running) ? Tr.tr("Running") : Tr.tr("Stopwatch"))
        : (focusActive ? (FocusTimer.running ? (FocusTimer.phase === "focus" ? Tr.tr("Focusing") : Tr.tr("Break")) : (FocusTimer.sessionActive ? Tr.tr("Paused") : Tr.tr("Focus"))) : Tr.tr("Focus"))
    readonly property string compactStateLabel: selectedTab === "stopwatch"
        ? ((stopwatchActive && FocusTimer.running) ? Tr.tr("Run") : Tr.tr("Watch"))
        : (focusActive ? (FocusTimer.phase === "focus" ? (FocusTimer.running ? Tr.tr("Focus") : (FocusTimer.sessionActive ? Tr.tr("Paused") : Tr.tr("Ready"))) : Tr.tr("Break")) : Tr.tr("Ready"))
    readonly property bool canControlTab: (selectedTab === "focus" && (focusActive || FocusTimer.canSwitchMode))
        || (selectedTab === "stopwatch" && (stopwatchActive || FocusTimer.canSwitchMode))

    function toggleCurrentTab(): void {
        if (selectedTab === "stopwatch") {
            if (!FocusTimer.isStopwatch && FocusTimer.canSwitchMode)
                FocusTimer.setMode("stopwatch");
            FocusTimer.toggle();
        } else {
            if (FocusTimer.isStopwatch && FocusTimer.canSwitchMode)
                FocusTimer.setMode("timer");
            FocusTimer.toggle();
        }
    }

    function stepDuration(deltaMins: int): void {
        if (FocusTimer.isStopwatch)
            return;
        if (FocusTimer.sessionActive) {
            if (deltaMins > 0)
                FocusTimer.extend();
            else
                FocusTimer.reduce();
        } else if (!FocusTimer.running) {
            FocusTimer.adjust(deltaMins);
        }
    }

    function applyPresetMinutes(targetMins: int): void {
        if (FocusTimer.isStopwatch && FocusTimer.canSwitchMode)
            FocusTimer.setMode("timer");
        if (!FocusTimer.running && !FocusTimer.sessionActive) {
            const cur = Math.round(FocusTimer.durationSecs / 60);
            FocusTimer.adjust(targetMins - cur);
        }
        selectedTab = "focus";
    }

    implicitWidth: WidgetMetrics.widthFor(effectiveSize, s)
    implicitHeight: WidgetMetrics.heightFor(effectiveSize, "timers", s)

    Connections {
        target: FocusTimer
        function onIsStopwatchChanged(): void {
            root.selectedTab = FocusTimer.isStopwatch ? "stopwatch" : "focus";
        }
    }

    WidgetCardShell {
        id: shell

        anchors.fill: parent
        widgetType: "timers"
        sizeMode: root.effectiveSize
        outerShape: root.widgetOptions?.outerShape ?? ""
        wallpaper: root.wallpaper
        weActive: root.weActive
        surfaceStyle: root.surfaceStyle
        blurEnabled: root.blurEnabled
        plateOpacity: root.plateOpacity
        scaleFactor: root.s

        Loader {
            id: layoutLoader

            anchors.fill: parent
            sourceComponent: {
                switch (root.effectiveSize) {
                case "1x2":
                    return layout1x2;
                case "2x2":
                    return layout2x2;
                default:
                    return layout1x1;
                }
            }
        }
    }

    // 1x1 Expressive Focus Ring Tile (tap to start/pause)
    Component {
        id: layout1x1

        Item {
            readonly property int ringStroke: Math.max(4, Math.round(6 * root.s))

            clip: true

            Item {
                id: ringBox

                anchors.centerIn: parent
                width: Math.max(40, shell.safeInnerBox)
                height: width

                CircularProgress {
                    anchors.fill: parent
                    value: root.ringProgress
                    wavy: root.visible && root.effectiveSize === "1x1" && root.isTabRunning && !GameMode.enabled
                    wavePaused: !wavy
                    strokeWidth: Math.max(4, Math.round(6 * root.s))
                    fgColour: root.accentColor
                    bgColour: shell.trackSurface
                    implicitSize: Math.max(40, shell.safeInnerBox)
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.max(24, ringBox.width - Math.max(4, Math.round(6 * root.s)) * 2 - Math.round(10 * root.s))
                    spacing: 1

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        horizontalAlignment: Text.AlignHCenter
                        text: root.mainDisplay
                        font: Tokens.font.clock.size(Math.max(11, Math.round((shell.isShaped ? 17 : 21) * root.s))).weight(Font.Bold).build()
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: parent.width
                        spacing: Math.max(2, Math.round(2 * root.s))

                        MaterialIcon {
                            text: root.isTabRunning ? "pause" : "play_arrow"
                            fontStyle: Tokens.font.icon.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.82)).build()
                            color: root.accentColor
                        }

                        StyledText {
                            Layout.minimumWidth: 0
                            text: root.compactStateLabel
                            font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.84)).weight(Font.Medium).build()
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }
                }

                StateLayer {
                    enabled: root.locked && root.canControlTab
                    radius: width / 2
                    onClicked: root.toggleCurrentTab()
                }
            }
        }
    }

    // 1x2 Wide Timer Control Strip
    Component {
        id: layout1x2

        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            spacing: Math.max(6, Math.round(Tokens.spacing.medium * root.s))

            Item {
                id: wideRing

                readonly property int ringStroke: Math.max(4, Math.round(6 * root.s))

                Layout.fillWidth: false
                Layout.preferredWidth: Math.round(96 * root.s)
                Layout.preferredHeight: Math.round(96 * root.s)
                Layout.alignment: Qt.AlignVCenter

                CircularProgress {
                    anchors.fill: parent
                    value: root.ringProgress
                    wavy: root.visible && root.effectiveSize === "1x2" && root.isTabRunning && !GameMode.enabled
                    wavePaused: !wavy
                    strokeWidth: wideRing.ringStroke
                    fgColour: root.accentColor
                    bgColour: shell.trackSurface
                    implicitSize: Math.round(96 * root.s)
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.max(24, wideRing.width - wideRing.ringStroke * 2 - Math.round(8 * root.s))
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        horizontalAlignment: Text.AlignHCenter
                        text: root.mainDisplay
                        font: Tokens.font.clock.size(Math.max(12, Math.round(19 * root.s))).weight(Font.Bold).build()
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        horizontalAlignment: Text.AlignHCenter
                        text: root.compactStateLabel
                        font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.8)).build()
                        color: root.accentColor
                        elide: Text.ElideRight
                    }
                }

                StateLayer {
                    enabled: root.locked && root.canControlTab
                    radius: width / 2
                    onClicked: root.toggleCurrentTab()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.fillHeight: true
                spacing: Math.max(3, Math.round(Tokens.spacing.small * root.s))

                ButtonRow {
                    Layout.fillWidth: true
                    spacing: Math.max(2, Math.round(Tokens.spacing.extraSmall * root.s))

                    WidgetTextButton {
                        fillWidth: true
                        text: Tr.tr("Focus")
                        isRound: true
                        translucent: shell.isTranslucent
                        scaleFactor: root.s * 0.92
                        type: root.selectedTab === "focus" ? TextButton.Filled : TextButton.Tonal
                        verticalPadding: Math.max(3, Math.round(Tokens.padding.extraSmall * root.s))
                        horizontalPadding: Math.max(4, Math.round(Tokens.padding.small * root.s))
                        onClicked: root.selectedTab = "focus"
                    }

                    WidgetTextButton {
                        fillWidth: true
                        text: Tr.tr("Watch")
                        isRound: true
                        translucent: shell.isTranslucent
                        scaleFactor: root.s * 0.92
                        type: root.selectedTab === "stopwatch" ? TextButton.Filled : TextButton.Tonal
                        verticalPadding: Math.max(3, Math.round(Tokens.padding.extraSmall * root.s))
                        horizontalPadding: Math.max(4, Math.round(Tokens.padding.small * root.s))
                        onClicked: root.selectedTab = "stopwatch"
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    visible: root.selectedTab === "focus"
                    spacing: Math.max(2, Math.round(4 * root.s))

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: `${root.focusDurationMins} min` + (FocusTimer.completedSessions > 0 ? ` · #${FocusTimer.completedSessions + 1}` : "")
                        font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.92)).build()
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }

                    WidgetIconButton {
                        icon: "remove"
                        type: IconButton.Text
                        translucent: shell.isTranslucent
                        scaleFactor: root.s * 0.9
                        disabled: !root.focusActive
                        onClicked: root.stepDuration(-5)
                    }

                    WidgetIconButton {
                        icon: "add"
                        type: IconButton.Text
                        translucent: shell.isTranslucent
                        scaleFactor: root.s * 0.9
                        disabled: !root.focusActive
                        onClicked: root.stepDuration(5)
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                ButtonRow {
                    Layout.fillWidth: true
                    spacing: Math.max(2, Math.round(Tokens.spacing.extraSmall * root.s))

                    WidgetIconButton {
                        fillWidth: true
                        icon: root.isTabRunning ? "pause" : "play_arrow"
                        type: IconButton.Filled
                        isRound: true
                        isToggle: true
                        checked: root.isTabRunning
                        translucent: shell.isTranslucent
                        scaleFactor: root.s
                        disabled: !root.canControlTab
                        onClicked: root.toggleCurrentTab()
                    }

                    WidgetIconButton {
                        fillWidth: true
                        visible: root.selectedTab === "focus"
                        icon: "skip_next"
                        type: IconButton.Tonal
                        isRound: true
                        translucent: shell.isTranslucent
                        scaleFactor: root.s
                        disabled: !root.focusActive || !FocusTimer.sessionActive
                        onClicked: FocusTimer.skipPhase()
                    }

                    WidgetIconButton {
                        fillWidth: true
                        icon: "replay"
                        type: IconButton.Tonal
                        isRound: true
                        translucent: shell.isTranslucent
                        scaleFactor: root.s
                        disabled: !root.canControlTab
                        onClicked: FocusTimer.reset()
                    }
                }
            }
        }
    }

    // 2x2 Complete Focus + Today + Presets Card
    Component {
        id: layout2x2

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            spacing: Math.max(4, Math.round(Tokens.spacing.small * root.s))

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Math.max(4, Math.round(Tokens.spacing.small * root.s))

                ButtonRow {
                    Layout.fillWidth: true
                    Layout.minimumHeight: Math.round(30 * root.s)
                    spacing: Math.max(2, Math.round(Tokens.spacing.extraSmall * root.s))

                    WidgetTextButton {
                        fillWidth: true
                        text: Tr.tr("Focus")
                        isRound: true
                        translucent: shell.isTranslucent
                        scaleFactor: root.s * 0.94
                        type: root.selectedTab === "focus" ? TextButton.Filled : TextButton.Tonal
                        verticalPadding: Math.max(3, Math.round(Tokens.padding.extraSmall * root.s))
                        horizontalPadding: Math.max(6, Math.round(Tokens.padding.small * root.s))
                        onClicked: root.selectedTab = "focus"
                    }

                    WidgetTextButton {
                        fillWidth: true
                        text: Tr.tr("Stopwatch")
                        isRound: true
                        translucent: shell.isTranslucent
                        scaleFactor: root.s * 0.94
                        type: root.selectedTab === "stopwatch" ? TextButton.Filled : TextButton.Tonal
                        verticalPadding: Math.max(3, Math.round(Tokens.padding.extraSmall * root.s))
                        horizontalPadding: Math.max(6, Math.round(Tokens.padding.small * root.s))
                        onClicked: root.selectedTab = "stopwatch"
                    }
                }

                StyledRect {
                    Layout.fillWidth: false
                    Layout.preferredHeight: Math.round(28 * root.s)
                    Layout.preferredWidth: Math.round(todayBadgeRow.implicitWidth + Math.round(14 * root.s))
                    Layout.maximumWidth: Math.round(92 * root.s)
                    clip: true
                    radius: Math.round(14 * root.s)
                    color: shell.primaryContainerTint

                    RowLayout {
                        id: todayBadgeRow

                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, Math.max(0, parent.width - Math.round(10 * root.s)))
                        spacing: Math.max(2, Math.round(3 * root.s))

                        MaterialIcon {
                            text: "local_fire_department"
                            fontStyle: Tokens.font.icon.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.85)).build()
                            color: Colours.palette.m3onPrimaryContainer
                        }

                        StyledText {
                            Layout.minimumWidth: 0
                            text: FocusLedger.fmt(FocusLedger.todaySecs)
                            font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.88)).weight(Font.Bold).build()
                            color: Colours.palette.m3onPrimaryContainer
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Item {
                id: sqRingHost

                Layout.fillWidth: true
                Layout.fillHeight: true

                Item {
                    id: sqRing

                    readonly property int ringStroke: Math.max(5, Math.round(8 * root.s))
                    readonly property int boxSize: Math.max(48, Math.round(Math.min(sqRingHost.width, sqRingHost.height, 134 * root.s)))

                    anchors.centerIn: parent
                    width: boxSize
                    height: boxSize

                    CircularProgress {
                        anchors.fill: parent
                        value: root.ringProgress
                        wavy: root.visible && root.effectiveSize === "2x2" && root.isTabRunning && !GameMode.enabled
                        wavePaused: !wavy
                        strokeWidth: sqRing.ringStroke
                        fgColour: root.accentColor
                        bgColour: shell.trackSurface
                        implicitSize: sqRing.boxSize
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: Math.max(24, sqRing.width - sqRing.ringStroke * 2 - Math.round(10 * root.s))
                        spacing: Math.max(1, Math.round(2 * root.s))

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            horizontalAlignment: Text.AlignHCenter
                            text: root.mainDisplay
                            font: Tokens.font.clock.size(Math.max(14, Math.round(27 * root.s))).weight(Font.Bold).build()
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledRect {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.maximumWidth: parent.width
                            Layout.preferredHeight: Math.round(20 * root.s)
                            Layout.preferredWidth: Math.min(parent.width, Math.round(phaseTag.implicitWidth + Math.round(14 * root.s)))
                            clip: true
                            radius: Math.round(10 * root.s)
                            color: shell.secondaryContainerTint

                            StyledText {
                                id: phaseTag

                                anchors.centerIn: parent
                                width: Math.min(implicitWidth, Math.max(0, parent.width - Math.round(10 * root.s)))
                                horizontalAlignment: Text.AlignHCenter
                                text: root.compactStateLabel + (root.selectedTab === "focus" && FocusTimer.completedSessions > 0 ? (" · #" + (FocusTimer.completedSessions + 1)) : "")
                                font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.86)).weight(Font.Medium).build()
                                color: Colours.palette.m3onSecondaryContainer
                                elide: Text.ElideRight
                            }
                        }
                    }

                    StateLayer {
                        enabled: root.locked && root.canControlTab
                        radius: width / 2
                        onClicked: root.toggleCurrentTab()
                    }
                }
            }

            // Duration stepper + Quick Presets combined row
            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                visible: root.selectedTab === "focus"
                spacing: Math.max(4, Math.round(6 * root.s))

                StyledRect {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: Math.round(30 * root.s)
                    clip: true
                    radius: Math.round(15 * root.s)
                    color: shell.innerSurface
                    border.width: 1
                    border.color: shell.innerBorder

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Math.max(3, Math.round(4 * root.s))
                        anchors.rightMargin: Math.max(3, Math.round(4 * root.s))
                        spacing: Math.max(2, Math.round(4 * root.s))

                        StyledRect {
                            Layout.fillWidth: false
                            Layout.preferredWidth: Math.round(22 * root.s)
                            Layout.preferredHeight: Math.round(22 * root.s)
                            radius: Math.round(11 * root.s)
                            color: shell.innerSurfaceStrong
                            opacity: !root.focusActive ? 0.45 : 1.0

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "remove"
                                fontStyle: Tokens.font.icon.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.88)).build()
                                color: Colours.palette.m3onSurface
                            }

                            StateLayer {
                                enabled: root.locked && root.focusActive
                                radius: parent.radius
                                onClicked: root.stepDuration(-5)
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            horizontalAlignment: Text.AlignHCenter
                            text: Tr.tr("%1m").arg(root.focusDurationMins)
                            font: Tokens.font.label.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).weight(Font.DemiBold).build()
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledRect {
                            Layout.fillWidth: false
                            Layout.preferredWidth: Math.round(22 * root.s)
                            Layout.preferredHeight: Math.round(22 * root.s)
                            radius: Math.round(11 * root.s)
                            color: shell.innerSurfaceStrong
                            opacity: !root.focusActive ? 0.45 : 1.0

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "add"
                                fontStyle: Tokens.font.icon.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.88)).build()
                                color: Colours.palette.m3onSurface
                            }

                            StateLayer {
                                enabled: root.locked && root.focusActive
                                radius: parent.radius
                                onClicked: root.stepDuration(5)
                            }
                        }
                    }
                }

                Repeater {
                    model: [15, 25, 50]

                    delegate: StyledRect {
                        id: presetChip

                        required property int modelData
                        readonly property bool active: !FocusTimer.isStopwatch && Math.round(FocusTimer.durationSecs / 60) === modelData

                        Layout.fillWidth: false
                        Layout.preferredWidth: Math.round(40 * root.s)
                        Layout.preferredHeight: Math.round(30 * root.s)
                        clip: true
                        radius: Math.round(15 * root.s)
                        color: active ? shell.primaryContainerTint : shell.innerSurfaceStrong
                        border.width: active ? 1 : 0
                        border.color: Colours.palette.m3primary

                        StyledText {
                            anchors.centerIn: parent
                            text: presetChip.modelData + "m"
                            font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.88)).weight(presetChip.active ? Font.Bold : Font.Medium).build()
                            color: presetChip.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                        }

                        StateLayer {
                            enabled: root.locked && !FocusTimer.running && !FocusTimer.sessionActive
                            radius: parent.radius
                            onClicked: root.applyPresetMinutes(presetChip.modelData)
                        }
                    }
                }
            }

            ButtonRow {
                Layout.fillWidth: true
                Layout.minimumHeight: Math.round(34 * root.s)
                spacing: Math.max(4, Math.round(Tokens.spacing.small * root.s))

                WidgetIconTextButton {
                    fillWidth: true
                    icon: root.isTabRunning ? "pause" : "play_arrow"
                    text: root.isTabRunning ? Tr.tr("Pause") : Tr.tr("Start")
                    type: IconTextButton.Filled
                    isRound: true
                    isToggle: true
                    checked: root.isTabRunning
                    translucent: shell.isTranslucent
                    scaleFactor: root.s
                    disabled: !root.canControlTab
                    onClicked: root.toggleCurrentTab()
                }

                WidgetIconButton {
                    fillWidth: false
                    visible: root.selectedTab === "focus"
                    icon: "skip_next"
                    type: IconButton.Tonal
                    isRound: true
                    translucent: shell.isTranslucent
                    scaleFactor: root.s
                    disabled: !root.focusActive || !FocusTimer.sessionActive
                    onClicked: FocusTimer.skipPhase()
                }

                WidgetIconButton {
                    fillWidth: false
                    icon: "replay"
                    type: IconButton.Tonal
                    isRound: true
                    translucent: shell.isTranslucent
                    scaleFactor: root.s
                    disabled: !root.canControlTab
                    onClicked: FocusTimer.reset()
                }
            }
        }
    }
}

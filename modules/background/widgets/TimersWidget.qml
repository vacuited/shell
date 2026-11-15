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
    property string surfaceStyle: ""
    property bool blurEnabled: Config.background.desktopWidgets.blur
    property real plateOpacity: Config.background.desktopWidgets.opacity
    property var widgetOptions: ({})

    property string selectedTab: FocusTimer.isStopwatch ? "stopwatch" : "focus"

    readonly property real s: WidgetMetrics.scale
    readonly property bool focusActive: !FocusTimer.isStopwatch
    readonly property bool stopwatchActive: FocusTimer.isStopwatch
    readonly property bool isTabRunning: selectedTab === "stopwatch"
        ? (stopwatchActive && FocusTimer.running)
        : (focusActive && FocusTimer.running)
    readonly property real ringProgress: selectedTab === "stopwatch"
        ? (stopwatchActive ? ((FocusTimer.elapsedSecs % 60) / 60) : 0)
        : (focusActive ? FocusTimer.progress : 0)
    readonly property color accentColor: selectedTab === "stopwatch"
        ? Colours.palette.m3secondary
        : (FocusTimer.phase === "focus" ? Colours.palette.m3primary : Colours.palette.m3tertiary)
    readonly property string mainDisplay: selectedTab === "stopwatch"
        ? (stopwatchActive ? FocusTimer.display : "00:00")
        : (focusActive ? FocusTimer.display : "25:00")
    readonly property string stateLabel: selectedTab === "stopwatch"
        ? ((stopwatchActive && FocusTimer.running) ? Tr.tr("Running") : Tr.tr("Stopwatch"))
        : (focusActive ? FocusTimer.phaseLabel : Tr.tr("Focus"))
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

    implicitWidth: WidgetMetrics.widthFor(sizeMode, s)
    implicitHeight: WidgetMetrics.heightFor(sizeMode, "timers", s)

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
        sizeMode: root.sizeMode
        outerShape: root.widgetOptions?.outerShape ?? ""
        wallpaper: root.wallpaper
        weActive: root.weActive
        surfaceStyle: root.surfaceStyle
        blurEnabled: root.blurEnabled
        plateOpacity: root.plateOpacity
        scaleFactor: root.s

        // 1x1 Expressive Focus Ring Tile (tap to start/pause)
        Item {
            anchors.fill: parent
            anchors.topMargin: shell.topPadding
            anchors.bottomMargin: shell.bottomPadding
            anchors.leftMargin: shell.sidePadding
            anchors.rightMargin: shell.sidePadding
            visible: root.sizeMode === "1x1"

            Item {
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height)
                height: width

                CircularProgress {
                    anchors.fill: parent
                    value: root.ringProgress
                    wavy: root.isTabRunning
                    wavePaused: !root.isTabRunning
                    strokeWidth: Math.max(5, Math.round(7 * root.s))
                    fgColour: root.accentColor
                    bgColour: WidgetMetrics.trackSurface
                    implicitSize: width
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 1

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.mainDisplay
                        font: Tokens.font.clock.size(Math.round((shell.isShaped ? 18 : 22) * root.s)).weight(Font.Bold).build()
                        color: Colours.palette.m3onSurface
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 3

                        MaterialIcon {
                            text: root.isTabRunning ? "pause" : "play_arrow"
                            fontStyle: Tokens.font.icon.builders.small.scale(0.85 * root.s).build()
                            color: root.accentColor
                        }

                        StyledText {
                            text: root.stateLabel
                            font: Tokens.font.label.builders.small.scale(Math.max(0.8, root.s * 0.85)).build()
                            color: Colours.palette.m3onSurfaceVariant
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

        // 1x2 Wide Timer Control Strip
        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "1x2"
            spacing: Math.round(Tokens.spacing.medium * root.s)

            Item {
                Layout.preferredWidth: Math.round(98 * root.s)
                Layout.preferredHeight: Math.round(98 * root.s)
                Layout.alignment: Qt.AlignVCenter

                CircularProgress {
                    anchors.fill: parent
                    value: root.ringProgress
                    wavy: root.isTabRunning
                    wavePaused: !root.isTabRunning
                    strokeWidth: Math.max(4, Math.round(6 * root.s))
                    fgColour: root.accentColor
                    bgColour: WidgetMetrics.trackSurface
                    implicitSize: width
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.mainDisplay
                        font: Tokens.font.clock.size(Math.round(20 * root.s)).weight(Font.Bold).build()
                        color: Colours.palette.m3onSurface
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.stateLabel
                        font: Tokens.font.label.builders.small.scale(0.8).build()
                        color: root.accentColor
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
                Layout.fillHeight: true
                spacing: Math.round(Tokens.spacing.small * root.s)

                ButtonRow {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    TextButton {
                        fillWidth: true
                        text: Tr.tr("Focus")
                        isRound: true
                        type: root.selectedTab === "focus" ? TextButton.Filled : TextButton.Tonal
                        isToggle: true
                        checked: root.selectedTab === "focus"
                        verticalPadding: Tokens.padding.extraSmall
                        horizontalPadding: Tokens.padding.small
                        onClicked: root.selectedTab = "focus"
                    }

                    TextButton {
                        fillWidth: true
                        text: Tr.tr("Watch")
                        isRound: true
                        type: root.selectedTab === "stopwatch" ? TextButton.Filled : TextButton.Tonal
                        isToggle: true
                        checked: root.selectedTab === "stopwatch"
                        verticalPadding: Tokens.padding.extraSmall
                        horizontalPadding: Tokens.padding.small
                        onClicked: root.selectedTab = "stopwatch"
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.selectedTab === "focus"
                    spacing: 4

                    StyledText {
                        Layout.fillWidth: true
                        text: `${Math.round(FocusTimer.durationSecs / 60)} min` + (FocusTimer.completedSessions > 0 ? ` · #${FocusTimer.completedSessions + 1}` : "")
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }

                    IconButton {
                        icon: "remove"
                        type: IconButton.Text
                        disabled: !root.focusActive || (FocusTimer.running && !FocusTimer.sessionActive)
                        onClicked: root.stepDuration(-5)
                    }

                    IconButton {
                        icon: "add"
                        type: IconButton.Text
                        disabled: !root.focusActive || (FocusTimer.running && !FocusTimer.sessionActive)
                        onClicked: root.stepDuration(5)
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                ButtonRow {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    IconButton {
                        fillWidth: true
                        icon: root.isTabRunning ? "pause" : "play_arrow"
                        type: IconButton.Filled
                        isRound: true
                        isToggle: true
                        checked: root.isTabRunning
                        disabled: !root.canControlTab
                        onClicked: root.toggleCurrentTab()
                    }

                    IconButton {
                        fillWidth: true
                        visible: root.selectedTab === "focus"
                        icon: "skip_next"
                        type: IconButton.Tonal
                        isRound: true
                        disabled: !root.focusActive || !FocusTimer.sessionActive
                        onClicked: FocusTimer.skipPhase()
                    }

                    IconButton {
                        fillWidth: true
                        icon: "replay"
                        type: IconButton.Tonal
                        isRound: true
                        disabled: !root.canControlTab
                        onClicked: FocusTimer.reset()
                    }
                }
            }
        }

        // 2x1 Tall Tower Focus Card
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "2x1"
            spacing: Math.round(Tokens.spacing.small * root.s)

            ButtonRow {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                TextButton {
                    fillWidth: true
                    text: Tr.tr("Focus")
                    isRound: true
                    type: root.selectedTab === "focus" ? TextButton.Filled : TextButton.Tonal
                    isToggle: true
                    checked: root.selectedTab === "focus"
                    verticalPadding: Tokens.padding.extraSmall
                    horizontalPadding: Tokens.padding.extraSmall
                    onClicked: root.selectedTab = "focus"
                }

                TextButton {
                    fillWidth: true
                    text: Tr.tr("Watch")
                    isRound: true
                    type: root.selectedTab === "stopwatch" ? TextButton.Filled : TextButton.Tonal
                    isToggle: true
                    checked: root.selectedTab === "stopwatch"
                    verticalPadding: Tokens.padding.extraSmall
                    horizontalPadding: Tokens.padding.extraSmall
                    onClicked: root.selectedTab = "stopwatch"
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Item {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height, Math.round(124 * root.s))
                    height: width

                    CircularProgress {
                        anchors.fill: parent
                        value: root.ringProgress
                        wavy: root.isTabRunning
                        wavePaused: !root.isTabRunning
                        strokeWidth: Math.max(5, Math.round(7 * root.s))
                        fgColour: root.accentColor
                        bgColour: WidgetMetrics.trackSurface
                        implicitSize: width
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 1

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.mainDisplay
                            font: Tokens.font.clock.size(Math.round(24 * root.s)).weight(Font.Bold).build()
                            color: Colours.palette.m3onSurface
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.stateLabel
                            font: Tokens.font.label.small
                            color: root.accentColor
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.selectedTab === "focus"
                spacing: 4

                IconButton {
                    icon: "remove"
                    type: IconButton.Tonal
                    disabled: !root.focusActive || (FocusTimer.running && !FocusTimer.sessionActive)
                    onClicked: root.stepDuration(-5)
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: `${Math.round(FocusTimer.durationSecs / 60)}m`
                    font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                }

                IconButton {
                    icon: "add"
                    type: IconButton.Tonal
                    disabled: !root.focusActive || (FocusTimer.running && !FocusTimer.sessionActive)
                    onClicked: root.stepDuration(5)
                }
            }

            ButtonRow {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                IconButton {
                    fillWidth: true
                    icon: root.isTabRunning ? "pause" : "play_arrow"
                    type: IconButton.Filled
                    isRound: true
                    isToggle: true
                    checked: root.isTabRunning
                    disabled: !root.canControlTab
                    onClicked: root.toggleCurrentTab()
                }

                IconButton {
                    fillWidth: true
                    visible: root.selectedTab === "focus"
                    icon: "skip_next"
                    type: IconButton.Tonal
                    isRound: true
                    disabled: !root.focusActive || !FocusTimer.sessionActive
                    onClicked: FocusTimer.skipPhase()
                }

                IconButton {
                    fillWidth: true
                    icon: "replay"
                    type: IconButton.Tonal
                    isRound: true
                    disabled: !root.canControlTab
                    onClicked: FocusTimer.reset()
                }
            }
        }

        // 2x2 Square Focus Card & 2x3 Split Focus + Stats Hub
        RowLayout {
            anchors.fill: parent
            anchors.topMargin: shell.topPadding
            anchors.bottomMargin: shell.bottomPadding
            anchors.leftMargin: shell.sidePadding
            anchors.rightMargin: shell.sidePadding
            visible: root.sizeMode === "2x2" || root.sizeMode === "2x3"
            spacing: Math.round(Tokens.spacing.large * root.s)

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Math.round(Tokens.spacing.small * root.s)

                ButtonRow {
                    Layout.fillWidth: true
                    Layout.minimumHeight: Math.round(32 * root.s)
                    spacing: Tokens.spacing.extraSmall

                    TextButton {
                        fillWidth: true
                        text: Tr.tr("Focus")
                        isRound: true
                        type: root.selectedTab === "focus" ? TextButton.Filled : TextButton.Tonal
                        isToggle: true
                        checked: root.selectedTab === "focus"
                        verticalPadding: Tokens.padding.extraSmall
                        horizontalPadding: Tokens.padding.small
                        onClicked: root.selectedTab = "focus"
                    }

                    TextButton {
                        fillWidth: true
                        text: Tr.tr("Stopwatch")
                        isRound: true
                        type: root.selectedTab === "stopwatch" ? TextButton.Filled : TextButton.Tonal
                        isToggle: true
                        checked: root.selectedTab === "stopwatch"
                        verticalPadding: Tokens.padding.extraSmall
                        horizontalPadding: Tokens.padding.small
                        onClicked: root.selectedTab = "stopwatch"
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Item {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height, Math.round(148 * root.s))
                        height: width

                        CircularProgress {
                            anchors.fill: parent
                            value: root.ringProgress
                            wavy: root.isTabRunning
                            wavePaused: !root.isTabRunning
                            strokeWidth: Math.max(6, Math.round(9 * root.s))
                            fgColour: root.accentColor
                            bgColour: WidgetMetrics.trackSurface
                            implicitSize: width
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.mainDisplay
                                font: Tokens.font.clock.size(Math.round(32 * root.s)).weight(Font.Bold).build()
                                color: Colours.palette.m3onSurface
                            }

                            StyledRect {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredHeight: Math.round(20 * root.s)
                                Layout.preferredWidth: Math.round(phaseTag.implicitWidth + 16)
                                radius: Math.round(10 * root.s)
                                color: Colours.palette.m3secondaryContainer

                                StyledText {
                                    id: phaseTag

                                    anchors.centerIn: parent
                                    text: root.stateLabel + (root.selectedTab === "focus" && FocusTimer.completedSessions > 0 ? (" · #" + (FocusTimer.completedSessions + 1)) : "")
                                    font: Tokens.font.label.small
                                    color: Colours.palette.m3onSecondaryContainer
                                }
                            }
                        }
                    }
                }

                StyledRect {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.min(parent.width, Math.round(188 * root.s))
                    Layout.preferredHeight: Math.round(32 * root.s)
                    visible: root.selectedTab === "focus"
                    radius: Math.round(16 * root.s)
                    color: WidgetMetrics.innerSurface
                    border.width: 1
                    border.color: WidgetMetrics.innerBorder

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        spacing: 4

                        StyledRect {
                            Layout.preferredWidth: Math.round(24 * root.s)
                            Layout.preferredHeight: Math.round(24 * root.s)
                            radius: Math.round(12 * root.s)
                            color: WidgetMetrics.innerSurfaceStrong
                            opacity: (!root.focusActive || (FocusTimer.running && !FocusTimer.sessionActive)) ? 0.45 : 1.0

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "remove"
                                fontStyle: Tokens.font.icon.small
                                color: Colours.palette.m3onSurface
                            }

                            StateLayer {
                                enabled: root.locked && root.focusActive && !(FocusTimer.running && !FocusTimer.sessionActive)
                                onClicked: root.stepDuration(-5)
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: Tr.tr("%1 min").arg(Math.round(FocusTimer.durationSecs / 60))
                            font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
                            color: Colours.palette.m3onSurface
                        }

                        StyledRect {
                            Layout.preferredWidth: Math.round(24 * root.s)
                            Layout.preferredHeight: Math.round(24 * root.s)
                            radius: Math.round(12 * root.s)
                            color: WidgetMetrics.innerSurfaceStrong
                            opacity: (!root.focusActive || (FocusTimer.running && !FocusTimer.sessionActive)) ? 0.45 : 1.0

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "add"
                                fontStyle: Tokens.font.icon.small
                                color: Colours.palette.m3onSurface
                            }

                            StateLayer {
                                enabled: root.locked && root.focusActive && !(FocusTimer.running && !FocusTimer.sessionActive)
                                onClicked: root.stepDuration(5)
                            }
                        }
                    }
                }

                ButtonRow {
                    Layout.fillWidth: true
                    Layout.minimumHeight: Math.round(34 * root.s)
                    spacing: Tokens.spacing.small

                    IconTextButton {
                        fillWidth: true
                        icon: root.isTabRunning ? "pause" : "play_arrow"
                        text: root.isTabRunning ? Tr.tr("Pause") : Tr.tr("Start")
                        type: IconTextButton.Filled
                        isRound: true
                        isToggle: true
                        checked: root.isTabRunning
                        disabled: !root.canControlTab
                        onClicked: root.toggleCurrentTab()
                    }

                    IconButton {
                        fillWidth: false
                        visible: root.selectedTab === "focus"
                        icon: "skip_next"
                        type: IconButton.Tonal
                        isRound: true
                        disabled: !root.focusActive || !FocusTimer.sessionActive
                        onClicked: FocusTimer.skipPhase()
                    }

                    IconButton {
                        fillWidth: false
                        icon: "replay"
                        type: IconButton.Tonal
                        isRound: true
                        disabled: !root.canControlTab
                        onClicked: FocusTimer.reset()
                    }
                }
            }

            // 2x3 Right Today FocusLedger + Quick Presets Panel
            StyledRect {
                visible: root.sizeMode === "2x3"
                Layout.preferredWidth: Math.round(176 * root.s)
                Layout.fillHeight: true
                radius: Tokens.rounding.extraLarge
                color: WidgetMetrics.innerSurface
                border.width: 1
                border.color: WidgetMetrics.innerBorder

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Math.round(Tokens.padding.medium * root.s)
                    spacing: Math.round(Tokens.spacing.small * root.s)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        MaterialShape {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            shape: MaterialShape.Sunny
                            color: Colours.palette.m3primaryContainer

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "local_fire_department"
                                fontStyle: Tokens.font.icon.small
                                color: Colours.palette.m3onPrimaryContainer
                            }
                        }

                        StyledText {
                            text: Tr.tr("Today")
                            font: Tokens.font.title.builders.small.weight(Font.DemiBold).build()
                            color: Colours.palette.m3onSurface
                            Layout.fillWidth: true
                        }
                    }

                    StyledRect {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(54 * root.s)
                        radius: Tokens.rounding.large
                        color: Qt.alpha(Colours.palette.m3primaryContainer, 0.45)

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 0

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: FocusLedger.fmt(FocusLedger.todaySecs)
                                font: Tokens.font.headline.builders.small.weight(Font.Bold).build()
                                color: Colours.palette.m3onSurface
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Tr.tr("%1 sessions · %2d streak").arg(FocusLedger.todaySessions).arg(FocusLedger.streak)
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurfaceVariant
                            }
                        }
                    }

                    StyledText {
                        text: Tr.tr("Quick Presets")
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.extraSmall

                        Repeater {
                            model: [15, 25, 50]

                            delegate: StyledRect {
                                id: presetChip

                                required property int modelData
                                readonly property bool active: !FocusTimer.isStopwatch && Math.round(FocusTimer.durationSecs / 60) === modelData

                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.round(30 * root.s)
                                radius: Math.round(15 * root.s)
                                color: active ? Colours.palette.m3primaryContainer : WidgetMetrics.innerSurfaceStrong

                                StyledText {
                                    anchors.centerIn: parent
                                    text: presetChip.modelData + "m"
                                    font: Tokens.font.label.builders.small.weight(presetChip.active ? Font.Bold : Font.Medium).build()
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

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
        }
    }
}

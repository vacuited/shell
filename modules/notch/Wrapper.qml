pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    property bool fullscreen: false

    property bool initialized: false
    Component.onCompleted: Qt.callLater(() => root.initialized = true)

    property bool shown: false
    property bool expanded: false
    property bool cavaWarm: false

    readonly property bool playing: Players.recentPlayer?.isPlaying ?? false
    readonly property bool hasRecent: Players.recentPlayer !== null
    readonly property bool focusActive: FocusTimer.active

    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property bool emptyWorkspace: monitor?.activeWorkspace?.toplevels?.values.every(t => t.lastIpcObject?.floating) ?? true

    readonly property bool wanted: emptyWorkspace ? Config.notch.showOnEmptyWorkspace : Config.notch.showWithWindows
    readonly property bool musicShown: Config.notch.showMusic && root.hasRecent
    readonly property bool focusShown: Config.notch.showFocus && root.focusActive
    readonly property bool showMedia: root.hasRecent && ((root.playing && root.shown) || Config.notch.showMusic)
    readonly property bool hasControls: Config.notch.expandMode !== "none" && ((focusShown && Config.notch.showFocusControls) || (showMedia && Config.notch.showMediaControls))
    readonly property bool persistent: wanted && (Config.notch.showClock || musicShown || focusShown)

    readonly property bool trackActive: (root.playing || root.focusActive) && shown

    readonly property bool shouldBeActive: !fullscreen && Config.notch.enabled && (persistent || trackActive || (expanded && hasControls)) && !screenState.dashboard && !screenState.launcher
    property real offsetScale: shouldBeActive ? 0 : 1

    Behavior on offsetScale {
        enabled: root.initialized
        Anim {
            id: offsetAnim
            type: Anim.DefaultSpatial
        }
    }

    onShouldBeActiveChanged: {
        if (!shouldBeActive)
            expanded = false;
    }

    onHasControlsChanged: {
        if (!hasControls)
            expanded = false;
    }

    function toggleExpanded(): void {
        if (!hasControls) {
            expanded = false;
            return;
        }
        expanded = !expanded;
    }

    ServiceRef {
        service: Config.notch.enabled && root.playing && !GameMode.enabled ? Audio.cava : null
    }

    readonly property bool visualiserLive: !GameMode.enabled

    visible: offsetScale < 1
    x: (parent.width - width) / 2
    y: (-height - 2) * Math.min(1, offsetScale)

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    opacity: 1 - Math.min(1, offsetScale)
    clip: true

    Connections {
        function onValuesChanged(): void {
            if (root.cavaWarm)
                return;
            const values = Audio.cava.values;
            if (!values || values.length === 0)
                return;
            for (let i = 0; i < values.length; i++) {
                if (values[i] >= 0.05) {
                    root.cavaWarm = true;
                    return;
                }
            }
        }
        enabled: !root.cavaWarm
        target: Audio.cava
    }

    Timer {
        id: showTimer
        interval: Config.notch.showDuration
        onTriggered: root.shown = false
    }

    Connections {
        function onTrackChanged(): void {
            if (!Config.notch.enabled)
                return;
            root.shown = true;
            showTimer.restart();
        }
        target: Players
    }

    Connections {
        function onPhaseEvent(): void {
            if (!Config.notch.enabled || !Config.notch.showFocus)
                return;
            root.shown = true;
            showTimer.restart();
        }
        target: FocusTimer
    }

    Loader {
        id: content

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        active: Config.notch.enabled

        sourceComponent: Pill {
            panelActive: root.shouldBeActive
            cavaWarm: root.cavaWarm
            allowLive: root.visualiserLive
            showMedia: root.showMedia
            showClock: Config.notch.showClock
            showFocus: root.focusShown
            showMediaControls: Config.notch.showMediaControls
            showFocusControls: Config.notch.showFocusControls
            compact: Config.notch.alwaysCompact || (!root.emptyWorkspace && Config.notch.compactWithWindows)
            expanded: root.expanded && root.hasControls
        }
    }
}

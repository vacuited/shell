pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Services.UPower
import Caelestia
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.misc
import qs.services

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    property bool fullscreen: false

    property bool initialized: false
    Component.onCompleted: Qt.callLater(() => root.initialized = true)

    property bool settled: false
    Timer {
        interval: 450
        running: true
        onTriggered: {
            root.prevVolume = Audio.volume;
            root.prevMuted = Audio.muted;
            root.prevSourceVolume = Audio.sourceVolume;
            root.prevSourceMuted = Audio.sourceMuted;
            root.prevBrightness = root.brightnessMonitor?.brightness ?? 0;
            root.prevOnBattery = UPower.onBattery;
            root.settled = true;
        }
    }

    property bool shown: false
    property bool expanded: false
    property bool hovered: false
    property bool cavaWarm: false

    // Transient state tracking
    property bool osdActive: false
    property string osdKind: "volume"
    property real prevVolume: Audio.volume
    property bool prevMuted: Audio.muted
    property real prevSourceVolume: Audio.sourceVolume
    property bool prevSourceMuted: Audio.sourceMuted
    property real prevBrightness: 0

    property bool chargingActive: false
    property bool chargingIsNewer: false
    property bool prevOnBattery: UPower.onBattery

    readonly property bool playing: Players.recentPlayer?.isPlaying ?? false
    readonly property bool hasRecent: Players.recentPlayer !== null
    readonly property bool focusActive: FocusTimer.active
    readonly property bool recordingActive: Config.notch.showRecording && Recorder.running

    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property Brightness.Monitor brightnessMonitor: Brightness.getMonitorForScreen(screen)
    readonly property bool emptyWorkspace: monitor?.activeWorkspace?.toplevels?.values.every(t => t.lastIpcObject?.floating) ?? true

    onBrightnessMonitorChanged: prevBrightness = brightnessMonitor?.brightness ?? 0

    readonly property var activeNotifs: Notifs.popups.filter(n => !n.closed)
    readonly property NotifData activeNotif: (Config.notch.showNotifications && activeNotifs.length > 0) ? activeNotifs[0] : null
    readonly property bool notifActive: activeNotif !== null

    readonly property var activeToastsList: {
        if (!Config.notch.enabled || !Config.notch.showToasts)
            return [];
        const list = [];
        for (const t of Toaster.toasts) {
            if (t && !t.closed)
                list.push(t);
        }
        return list;
    }
    readonly property var activeToast: activeToastsList.length > 0 ? activeToastsList[0] : null
    readonly property bool toastActive: (Config.notch.showCharging && chargingActive) || (Config.notch.showToasts && activeToast !== null)
    readonly property bool osdReadyActive: Config.notch.showOsd && osdActive

    readonly property bool wanted: emptyWorkspace ? Config.notch.showOnEmptyWorkspace : Config.notch.showWithWindows
    readonly property bool musicShown: Config.notch.showMusic && root.hasRecent
    readonly property bool focusShown: Config.notch.showFocus && root.focusActive
    readonly property bool recordingShown: root.recordingActive
    readonly property bool showMedia: root.hasRecent && ((root.playing && root.shown) || Config.notch.showMusic)
    readonly property bool anyTransient: osdReadyActive || notifActive || toastActive
    readonly property bool persistent: wanted && (Config.notch.showClock || musicShown || focusShown || recordingShown)
    readonly property bool trackActive: (root.playing || root.focusActive) && shown

    readonly property bool pinned: content.item?.replyPinned ?? false
    readonly property bool hasControls: content.item?.hasControls ?? false

    readonly property bool shouldBeActive: !fullscreen && Config.notch.enabled && (persistent || trackActive || anyTransient || (expanded && hasControls) || pinned) && !screenState.dashboard && !screenState.launcher
    property real offsetScale: shouldBeActive ? 0 : 1

    readonly property alias activeActivity: engine.main
    readonly property alias bubbleActivity: engine.bubble
    readonly property alias hasMultipleOngoing: engine.hasMultipleOngoing

    // Suppression gates exposed to Panels / popup wrappers
    readonly property bool handlesOsd: Config.notch.enabled && Config.notch.showOsd && !fullscreen && !screenState.dashboard && !screenState.launcher && !screenState.osd
    readonly property bool handlesNotifications: Config.notch.enabled && Config.notch.showNotifications && !fullscreen && !screenState.dashboard && !screenState.launcher
    readonly property bool handlesToasts: Config.notch.enabled && Config.notch.showToasts && !fullscreen && !screenState.dashboard && !screenState.launcher

    ActivityEngine {
        id: engine

        osdActive: root.osdReadyActive
        notifActive: root.notifActive
        notifPinned: root.pinned
        toastActive: root.toastActive
        recordingActive: root.recordingShown
        focusActive: root.focusShown
        musicActive: root.musicShown || (root.playing && root.shown)
        clockActive: Config.notch.showClock
        bubbleEnabled: Config.notch.showBubble
    }

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
        if (!hasControls && !pinned)
            expanded = false;
    }

    onActiveActivityChanged: {
        if (activeActivity === "osd" && expanded && !pinned)
            expanded = false;
    }

    onActiveNotifChanged: {
        if (activeNotif && (activeNotif.urgency === NotificationUrgency.Critical || activeNotif.forceExpand)) {
            expanded = true;
        } else if (!hovered && !pinned) {
            expanded = false;
        }
    }

    function showOsd(kind: string): void {
        if (!root.settled || !Config.notch.enabled || !Config.notch.showOsd || root.fullscreen || root.screenState.dashboard || root.screenState.launcher || root.screenState.osd)
            return;
        osdKind = kind;
        osdActive = true;
        osdTimer.restart();
    }

    function dismissActiveNotif(): void {
        if (activeNotif)
            activeNotif.popup = false;
        if (!hovered && !pinned)
            expanded = false;
    }

    function dismissActiveToast(): void {
        if (chargingActive && (chargingIsNewer || activeToast === null)) {
            chargingActive = false;
            chargingIsNewer = false;
            chargingTimer.stop();
        } else if (activeToast) {
            activeToast.close();
        }
        if (!hovered && !pinned)
            expanded = false;
    }

    function toggleExpanded(): void {
        if (!hasControls) {
            if (!pinned)
                expanded = false;
            return;
        }
        if (expanded && pinned)
            return;
        expanded = !expanded;
    }

    function collapse(): void {
        if (pinned)
            return;
        expanded = false;
    }

    function promoteBubble(): void {
        if (bubbleActivity.length === 0)
            return;
        engine.promote(bubbleActivity);
        if (activeActivity === "osd") {
            osdActive = false;
            osdTimer.stop();
        }
    }

    function triggerActivityAction(activity: string): void {
        if (activity === "music") {
            Players.recentPlayer?.togglePlaying();
        } else if (activity === "focus") {
            FocusTimer.toggle();
        } else if (activity === "recording") {
            Recorder.togglePause();
        } else if (activity === "osd") {
            if (osdKind === "volume") {
                if (Audio.sink?.ready && Audio.sink?.audio)
                    Audio.sink.audio.muted = !Audio.sink.audio.muted;
            } else if (osdKind === "mic") {
                if (Audio.source?.ready && Audio.source?.audio)
                    Audio.source.audio.muted = !Audio.source.audio.muted;
            } else {
                HyprSunset.toggle(5000);
            }
            osdTimer.restart();
        } else if (activity === "notification") {
            dismissActiveNotif();
        } else if (activity === "toast") {
            dismissActiveToast();
        }
    }

    function triggerMainAction(): void {
        triggerActivityAction(activeActivity);
    }

    function triggerBubbleAction(): void {
        triggerActivityAction(bubbleActivity);
    }

    function handleWheel(deltaY: real, inBubble: bool): void {
        if (Math.abs(deltaY) < 1)
            return;
        if (!inBubble && activeActivity === "osd") {
            const up = deltaY > 0;
            if (osdKind === "volume") {
                if (up)
                    Audio.incrementVolume();
                else
                    Audio.decrementVolume();
            } else if (osdKind === "mic") {
                if (up)
                    Audio.incrementSourceVolume();
                else
                    Audio.decrementSourceVolume();
            } else if (brightnessMonitor) {
                const next = Math.max(0.01, Math.min(1, brightnessMonitor.brightness + (up ? 0.05 : -0.05)));
                brightnessMonitor.setBrightness(next);
            }
            osdTimer.restart();
            return;
        }
        if (Config.notch.scrollToCycle)
            engine.cycleOngoing(deltaY > 0 ? -1 : 1);
    }

    Loader {
        active: Config.notch.enabled && Config.notch.showRecording
        sourceComponent: Ref {
            service: Recorder
        }
    }

    ServiceRef {
        service: Config.notch.enabled && root.playing && !GameMode.enabled && (root.activeActivity === "music" || root.bubbleActivity === "music" || !Config.notch.showBubble) ? Audio.cava : null
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

    Timer {
        id: osdTimer
        interval: Config.notch.osdDuration
        onTriggered: root.osdActive = false
    }

    Timer {
        id: chargingTimer
        interval: Config.notch.chargingDuration
        onTriggered: {
            root.chargingActive = false;
            root.chargingIsNewer = false;
        }
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

    Connections {
        function onVolumeChanged(): void {
            const delta = Math.abs(Audio.volume - root.prevVolume);
            root.prevVolume = Audio.volume;
            if (delta > 0.001)
                root.showOsd("volume");
        }
        function onMutedChanged(): void {
            if (Audio.muted !== root.prevMuted) {
                root.prevMuted = Audio.muted;
                root.showOsd("volume");
            }
        }
        function onSourceVolumeChanged(): void {
            const delta = Math.abs(Audio.sourceVolume - root.prevSourceVolume);
            root.prevSourceVolume = Audio.sourceVolume;
            if (delta > 0.001)
                root.showOsd("mic");
        }
        function onSourceMutedChanged(): void {
            if (Audio.sourceMuted !== root.prevSourceMuted) {
                root.prevSourceMuted = Audio.sourceMuted;
                root.showOsd("mic");
            }
        }
        target: Audio
    }

    Connections {
        function onBrightnessChanged(): void {
            const cur = root.brightnessMonitor?.brightness ?? 0;
            const delta = Math.abs(cur - root.prevBrightness);
            root.prevBrightness = cur;
            if (delta > 0.001)
                root.showOsd("brightness");
        }
        target: root.brightnessMonitor
    }

    Connections {
        function onOnBatteryChanged(): void {
            if (!root.settled || !UPower.displayDevice.ready || !Config.notch.enabled || !Config.notch.showCharging) {
                root.prevOnBattery = UPower.onBattery;
                return;
            }
            if (UPower.onBattery !== root.prevOnBattery) {
                root.prevOnBattery = UPower.onBattery;
                root.chargingActive = true;
                root.chargingIsNewer = true;
                chargingTimer.restart();
            }
        }
        target: UPower
    }

    Connections {
        function onToastsChanged(): void {
            if (root.activeToastsList.length > 0)
                root.chargingIsNewer = false;
        }
        target: Toaster
    }

    Loader {
        id: content

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        active: Config.notch.enabled

        sourceComponent: Pill {
            panelActive: root.shouldBeActive
            activeActivity: root.activeActivity
            allowStandingCoexist: !Config.notch.showBubble
            cavaWarm: root.cavaWarm
            allowLive: root.visualiserLive
            showMedia: root.showMedia
            showClock: Config.notch.showClock
            showFocus: root.focusShown
            showRecording: root.recordingShown
            showMediaControls: Config.notch.showMediaControls
            showFocusControls: Config.notch.showFocusControls
            compact: Config.notch.alwaysCompact || (!root.emptyWorkspace && Config.notch.compactWithWindows)
            expanded: root.expanded && hasControls
            hovered: root.hovered
            osdKind: root.osdKind
            brightnessMonitor: root.brightnessMonitor
            activeNotif: root.activeNotif
            activeToast: root.activeToast
            chargingActive: root.chargingActive
            chargingIsNewer: root.chargingIsNewer
            onOsdInteracted: osdTimer.restart()
            onDismissNotif: root.dismissActiveNotif()
            onDismissToast: root.dismissActiveToast()
            onEscapePressed: root.collapse()
        }
    }
}

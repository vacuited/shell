pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Notch")
    isSubPage: true

    readonly property list<string> expandModeValues: ["hover", "click", "none"]
    readonly property list<MenuItem> expandModeItems: [
        MenuItem { text: qsTr("Hover to expand") },
        MenuItem { text: qsTr("Click to expand") },
        MenuItem { text: qsTr("Disabled") }
    ]

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // General
        SectionHeader {
            first: true
            text: qsTr("General")
        }

        ToggleRow {
            first: true
            last: true
            text: qsTr("Enabled")
            subtext: qsTr("Show a dynamic notch pill for media, clock, and focus timer")
            configNode: root.targetConfig.notch
            propertyName: "enabled"
            checked: root.targetConfig.notch.enabled
            onToggled: {
                root.targetConfig.notch.enabled = checked;
                root.targetConfig.save();
            }
        }

        // Standing notch
        SectionHeader {
            text: qsTr("Standing notch")
        }

        ToggleRow {
            first: true
            text: qsTr("Show on empty workspace")
            subtext: qsTr("Keep the notch visible while no tiled windows are open")
            configNode: root.targetConfig.notch
            propertyName: "showOnEmptyWorkspace"
            checked: root.targetConfig.notch.showOnEmptyWorkspace
            onToggled: {
                root.targetConfig.notch.showOnEmptyWorkspace = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Show on workspaces with windows")
            subtext: qsTr("Keep the notch visible on workspaces that have windows too")
            configNode: root.targetConfig.notch
            propertyName: "showWithWindows"
            checked: root.targetConfig.notch.showWithWindows
            onToggled: {
                root.targetConfig.notch.showWithWindows = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Always compact")
            subtext: qsTr("Always use smaller dimensions even when no windows are open")
            configNode: root.targetConfig.notch
            propertyName: "alwaysCompact"
            checked: root.targetConfig.notch.alwaysCompact
            onToggled: {
                root.targetConfig.notch.alwaysCompact = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Compact when windows are open")
            subtext: qsTr("Use smaller dimensions when windows are open to preserve screen space")
            configNode: root.targetConfig.notch
            propertyName: "compactWithWindows"
            checked: root.targetConfig.notch.compactWithWindows
            enabled: !root.targetConfig.notch.alwaysCompact
            onToggled: {
                root.targetConfig.notch.compactWithWindows = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Show clock")
            subtext: qsTr("Show the time and date in the notch")
            configNode: root.targetConfig.notch
            propertyName: "showClock"
            checked: root.targetConfig.notch.showClock
            onToggled: {
                root.targetConfig.notch.showClock = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Show music")
            subtext: qsTr("Show the playing track and album art in the notch")
            configNode: root.targetConfig.notch
            propertyName: "showMusic"
            checked: root.targetConfig.notch.showMusic
            onToggled: {
                root.targetConfig.notch.showMusic = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            last: true
            text: qsTr("Show focus timer")
            subtext: qsTr("Show Pomodoro focus timer countdown and progress ring")
            configNode: root.targetConfig.notch
            propertyName: "showFocus"
            checked: root.targetConfig.notch.showFocus
            onToggled: {
                root.targetConfig.notch.showFocus = checked;
                root.targetConfig.save();
            }
        }

        // Quick controls
        SectionHeader {
            text: qsTr("Quick controls")
        }

        SelectRow {
            first: true
            label: qsTr("Expand controls")
            subtext: qsTr("How quick controls are revealed from the notch")
            configNode: root.targetConfig.notch
            propertyName: "expandMode"
            menuItems: root.expandModeItems
            active: root.expandModeItems[root.expandModeValues.indexOf(root.targetConfig.notch.expandMode)] ?? root.expandModeItems[0]
            onSelected: item => {
                const index = root.expandModeItems.indexOf(item);
                if (index !== -1) {
                    root.targetConfig.notch.expandMode = root.expandModeValues[index];
                    root.targetConfig.save();
                }
            }
        }

        ToggleRow {
            text: qsTr("Show media controls")
            subtext: qsTr("Show shuffle, skip, play/pause, seek, and repeat controls when expanded")
            configNode: root.targetConfig.notch
            propertyName: "showMediaControls"
            checked: root.targetConfig.notch.showMediaControls
            enabled: root.targetConfig.notch.expandMode !== "none"
            onToggled: {
                root.targetConfig.notch.showMediaControls = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            last: true
            text: qsTr("Show focus timer controls")
            subtext: qsTr("Show pause, extend, skip, and reset buttons when a focus session is active")
            configNode: root.targetConfig.notch
            propertyName: "showFocusControls"
            checked: root.targetConfig.notch.showFocusControls
            enabled: root.targetConfig.notch.expandMode !== "none"
            onToggled: {
                root.targetConfig.notch.showFocusControls = checked;
                root.targetConfig.save();
            }
        }

        // Dynamic Island activities
        SectionHeader {
            text: qsTr("Dynamic Island activities")
        }

        ToggleRow {
            first: true
            text: qsTr("Show notifications")
            subtext: qsTr("Display popup notifications in the notch instead of top-right banners")
            configNode: root.targetConfig.notch
            propertyName: "showNotifications"
            checked: root.targetConfig.notch.showNotifications
            onToggled: {
                root.targetConfig.notch.showNotifications = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Inline notification replies")
            subtext: qsTr("Show a quick reply input field on notifications that support direct replies")
            configNode: root.targetConfig.notch
            propertyName: "notifReplies"
            checked: root.targetConfig.notch.notifReplies
            enabled: root.targetConfig.notch.showNotifications
            onToggled: {
                root.targetConfig.notch.notifReplies = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Show volume and brightness OSD")
            subtext: qsTr("Take over automatic volume, microphone, and brightness popups in the notch")
            configNode: root.targetConfig.notch
            propertyName: "showOsd"
            checked: root.targetConfig.notch.showOsd
            onToggled: {
                root.targetConfig.notch.showOsd = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Show screen recording indicator")
            subtext: qsTr("Show an active recording badge, elapsed timer, and pause/stop controls")
            configNode: root.targetConfig.notch
            propertyName: "showRecording"
            checked: root.targetConfig.notch.showRecording
            onToggled: {
                root.targetConfig.notch.showRecording = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Show charging indicator")
            subtext: qsTr("Animate charger plug and battery transitions inside the notch")
            configNode: root.targetConfig.notch
            propertyName: "showCharging"
            checked: root.targetConfig.notch.showCharging
            onToggled: {
                root.targetConfig.notch.showCharging = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            last: true
            text: qsTr("Show system toasts")
            subtext: qsTr("Route utility toast banners into the notch pill")
            configNode: root.targetConfig.notch
            propertyName: "showToasts"
            checked: root.targetConfig.notch.showToasts
            onToggled: {
                root.targetConfig.notch.showToasts = checked;
                root.targetConfig.save();
            }
        }

        // Behaviour
        SectionHeader {
            text: qsTr("Behaviour")
        }

        ToggleRow {
            first: true
            text: qsTr("Secondary activity droplet")
            subtext: qsTr("Pinch off a liquid-metaball bubble on the left when two ongoing activities run")
            configNode: root.targetConfig.notch
            propertyName: "showBubble"
            checked: root.targetConfig.notch.showBubble
            onToggled: {
                root.targetConfig.notch.showBubble = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Cycle activities with scroll wheel")
            subtext: qsTr("Scroll over the notch or secondary droplet to switch active ongoing activities")
            configNode: root.targetConfig.notch
            propertyName: "scrollToCycle"
            checked: root.targetConfig.notch.scrollToCycle
            onToggled: {
                root.targetConfig.notch.scrollToCycle = checked;
                root.targetConfig.save();
            }
        }

        StepperRow {
            label: qsTr("Show duration")
            subtext: qsTr("How long the transient pill stays up after track or phase change (ms)")
            value: root.targetConfig.notch.showDuration
            from: 1000
            to: 10000
            stepSize: 500
            onMoved: v => {
                root.targetConfig.notch.showDuration = Math.round(v);
                root.targetConfig.save();
            }
        }

        StepperRow {
            label: qsTr("OSD duration")
            subtext: qsTr("How long the interactive volume/brightness OSD pill stays visible (ms)")
            value: root.targetConfig.notch.osdDuration
            from: 800
            to: 5000
            stepSize: 200
            onMoved: v => {
                root.targetConfig.notch.osdDuration = Math.round(v);
                root.targetConfig.save();
            }
        }

        StepperRow {
            last: true
            label: qsTr("Charging duration")
            subtext: qsTr("How long charging state transitions stay highlighted in the notch (ms)")
            value: root.targetConfig.notch.chargingDuration
            from: 1000
            to: 8000
            stepSize: 500
            onMoved: v => {
                root.targetConfig.notch.chargingDuration = Math.round(v);
                root.targetConfig.save();
            }
        }

        // Content
        SectionHeader {
            text: qsTr("Content")
        }

        ToggleRow {
            first: true
            text: qsTr("Show artist")
            subtext: qsTr("Include the artist name alongside the track title")
            configNode: root.targetConfig.notch
            propertyName: "showArtist"
            checked: root.targetConfig.notch.showArtist
            onToggled: {
                root.targetConfig.notch.showArtist = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Artist first")
            subtext: qsTr("\"Artist - Title\" instead of \"Title - Artist\"")
            configNode: root.targetConfig.notch
            propertyName: "artistFirst"
            checked: root.targetConfig.notch.artistFirst
            enabled: root.targetConfig.notch.showArtist
            onToggled: {
                root.targetConfig.notch.artistFirst = checked;
                root.targetConfig.save();
            }
        }

        StepperRow {
            last: true
            label: qsTr("Max title width")
            subtext: qsTr("How wide the title can grow before eliding (px)")
            value: root.targetConfig.notch.maxTitleWidth
            from: 100
            to: 600
            stepSize: 20
            onMoved: v => {
                root.targetConfig.notch.maxTitleWidth = Math.round(v);
                root.targetConfig.save();
            }
        }
    }
}

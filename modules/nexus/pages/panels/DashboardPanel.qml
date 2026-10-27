pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import M3Shapes
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Dashboard")
    isSubPage: true

    readonly property var builtinTabs: {
        const tabs = {
            dashboard: qsTr("Dashboard"),
            media: qsTr("Media"),
            weather: qsTr("Weather"),
            performance: qsTr("Performance"),
            terminal: qsTr("Terminal"),
            focus: qsTr("Focus timer"),
            notes: qsTr("Notes")
        };
        if (Hardware.isSupported) {
            tabs.hardware = qsTr("Hardware");
        }
        return tabs;
    }

    readonly property list<MenuItem> dashboardShapeItems: [
        MenuItem {
            property int value: MaterialShape.Circle
            text: qsTr("Circle")
        },
        MenuItem {
            property int value: MaterialShape.Square
            text: qsTr("Square")
        },
        MenuItem {
            property int value: MaterialShape.Pill
            text: qsTr("Pill")
        },
        MenuItem {
            property int value: MaterialShape.Diamond
            text: qsTr("Diamond")
        },
        MenuItem {
            property int value: MaterialShape.ClamShell
            text: qsTr("Clam Shell")
        },
        MenuItem {
            property int value: MaterialShape.Pentagon
            text: qsTr("Pentagon")
        },
        MenuItem {
            property int value: MaterialShape.Gem
            text: qsTr("Gem")
        },
        MenuItem {
            property int value: MaterialShape.Cookie4Sided
            text: qsTr("Cookie 4-Sided")
        },
        MenuItem {
            property int value: MaterialShape.Cookie6Sided
            text: qsTr("Cookie 6-Sided")
        },
        MenuItem {
            property int value: MaterialShape.Cookie7Sided
            text: qsTr("Cookie 7-Sided")
        },
        MenuItem {
            property int value: MaterialShape.Cookie9Sided
            text: qsTr("Cookie 9-Sided")
        },
        MenuItem {
            property int value: MaterialShape.Cookie12Sided
            text: qsTr("Cookie 12-Sided")
        }
    ]

    readonly property list<MenuItem> lockShapeItems: [
        MenuItem {
            property int value: MaterialShape.Circle
            text: qsTr("Circle")
        },
        MenuItem {
            property int value: MaterialShape.Square
            text: qsTr("Square")
        },
        MenuItem {
            property int value: MaterialShape.Pill
            text: qsTr("Pill")
        },
        MenuItem {
            property int value: MaterialShape.Diamond
            text: qsTr("Diamond")
        },
        MenuItem {
            property int value: MaterialShape.ClamShell
            text: qsTr("Clam Shell")
        },
        MenuItem {
            property int value: MaterialShape.Pentagon
            text: qsTr("Pentagon")
        },
        MenuItem {
            property int value: MaterialShape.Gem
            text: qsTr("Gem")
        },
        MenuItem {
            property int value: MaterialShape.Cookie4Sided
            text: qsTr("Cookie 4-Sided")
        },
        MenuItem {
            property int value: MaterialShape.Cookie6Sided
            text: qsTr("Cookie 6-Sided")
        },
        MenuItem {
            property int value: MaterialShape.Cookie7Sided
            text: qsTr("Cookie 7-Sided")
        },
        MenuItem {
            property int value: MaterialShape.Cookie9Sided
            text: qsTr("Cookie 9-Sided")
        },
        MenuItem {
            property int value: MaterialShape.Cookie12Sided
            text: qsTr("Cookie 12-Sided")
        }
    ]

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // General
        SectionHeader {
            first: true
            text: Tr.tr("General")
        }

        ToggleRow {
            first: true
            text: qsTr("Enabled")
            configNode: root.targetConfig.dashboard
            propertyName: "enabled"
            checked: root.targetConfig.dashboard.enabled
            onToggled: {
                root.targetConfig.dashboard.enabled = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Show on hover")
            subtext: qsTr("Reveal when the cursor reaches the screen edge")
            configNode: root.targetConfig.dashboard
            propertyName: "showOnHover"
            checked: root.targetConfig.dashboard.showOnHover
            onToggled: {
                root.targetConfig.dashboard.showOnHover = checked;
                root.targetConfig.save();
            }
        }

        SelectRow {
            Layout.fillWidth: true
            label: qsTr("Dashboard profile picture shape")
            subtext: qsTr("Choose the shape of the profile picture on the dashboard")
            configNode: root.targetConfig.dashboard
            propertyName: "profilePicShape"
            fallbackIcon: "person"
            fallbackText: qsTr("Pill")
            active: {
                for (let i = 0; i < dashboardShapeItems.length; i++) {
                    if (dashboardShapeItems[i].value === root.targetConfig.dashboard.profilePicShape)
                        return dashboardShapeItems[i];
                }
                return dashboardShapeItems[0];
            }
            menuItems: dashboardShapeItems
            onSelected: item => {
                root.targetConfig.dashboard.profilePicShape = item.value;
                root.targetConfig.save();
            }
        }

        SelectRow {
            Layout.fillWidth: true
            last: true
            label: qsTr("Lock screen profile picture shape")
            subtext: qsTr("Choose the shape of the profile picture on the lock screen")
            configNode: root.targetConfig.lock
            propertyName: "profilePicShape"
            fallbackIcon: "lock"
            fallbackText: qsTr("Clam Shell")
            active: {
                for (let i = 0; i < lockShapeItems.length; i++) {
                    if (lockShapeItems[i].value === root.targetConfig.lock.profilePicShape)
                        return lockShapeItems[i];
                }
                return lockShapeItems[0];
            }
            menuItems: lockShapeItems
            onSelected: item => {
                root.targetConfig.lock.profilePicShape = item.value;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            last: true
            text: qsTr("Show clock seconds")
            subtext: qsTr("Display seconds for the clock in the main panel")
            configNode: root.targetConfig.dashboard
            propertyName: "showClockSeconds"
            checked: root.targetConfig.dashboard.showClockSeconds
            onToggled: {
                root.targetConfig.dashboard.showClockSeconds = checked;
                root.targetConfig.save();
            }
        }

        // Tabs
        SectionHeader {
            text: Tr.tr("Tabs")
        }

        ListEditor {
            function labelFor(item: var): string {
                const prettyName = root.builtinTabs[item.id];
                if (prettyName)
                    return prettyName;
                const label = item.id.replace(/([A-Z])/g, " $1");
                return label.charAt(0).toUpperCase() + label.slice(1).toLowerCase();
            }

            function toggledFor(item: var): bool {
                return item.enabled;
            }

            z: 1
            first: true
            values: root.targetConfig.dashboard.tabs ? root.targetConfig.dashboard.tabs.values : []
            onItemMoved: (from, to) => {
                if (root.targetConfig.dashboard.tabs) {
                    root.targetConfig.dashboard.tabs.move(from, to);
                    root.targetConfig.save();
                }
            }
            onItemRemoved: index => {
                if (root.targetConfig.dashboard.tabs) {
                    root.targetConfig.dashboard.tabs.remove(index);
                    root.targetConfig.save();
                }
            }
            onItemToggled: (index, checked) => {
                if (root.targetConfig.dashboard.tabs) {
                    root.targetConfig.dashboard.tabs.at(index).enabled = checked;
                    root.targetConfig.save();
                }
            }
        }

        DialogSelectButton {
            id: addTabContainer

            rootParent: root.flickable
            icon: "add"
            label: Tr.tr("Add tab")
            header: Tr.tr("Add new tab")
            acceptLabel: Tr.trCtx("Add", "button")

            model: {
                const builtins = Object.keys(root.builtinTabs).map(k => ({
                    id: k,
                    label: root.builtinTabs[k]
                }));
                const current = root.targetConfig.dashboard.tabs ? root.targetConfig.dashboard.tabs.values : [];
                return builtins.filter(b => !current.some(v => v.id === b.id));
            }

            onAccepted: {
                if (!selectedItem || !root.targetConfig.dashboard.tabs)
                    return;

                root.targetConfig.dashboard.tabs.insert({
                    id: selectedItem,
                    enabled: true
                });
                root.targetConfig.save();
            }
        }

        // General
        SectionHeader {
            text: qsTr("General")
        }

        ToggleRow {
            first: true
            last: true
            Layout.fillWidth: true
            text: qsTr("Hyprland splash")
            subtext: qsTr("Show the current Hyprland splash text")
            configNode: root.targetConfig.dashboard
            propertyName: "showHyprlandSplash"
            checked: root.targetConfig.dashboard.showHyprlandSplash
            onToggled: {
                root.targetConfig.dashboard.showHyprlandSplash = checked;
                root.targetConfig.save();
            }
        }

        // Media
        SectionHeader {
            text: qsTr("Media")
        }

        ToggleRow {
            first: true
            Layout.fillWidth: true
            text: qsTr("Recolor media GIF")
            subtext: qsTr("Apply system theme colors to the media GIF")
            configNode: root.targetConfig.dashboard
            propertyName: "colorizeMediaGif"
            checked: root.targetConfig.dashboard.colorizeMediaGif
            onToggled: {
                root.targetConfig.dashboard.colorizeMediaGif = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Use material shapes")
            subtext: qsTr("Replace the media GIF with audio-reactive material shapes")
            configNode: root.targetConfig.dashboard
            propertyName: "useMediaShapes"
            checked: root.targetConfig.dashboard.useMediaShapes
            onToggled: {
                root.targetConfig.dashboard.useMediaShapes = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Randomize shape colors")
            subtext: qsTr("Randomly shift shape colors while morphing")
            configNode: root.targetConfig.dashboard
            propertyName: "randomizeMediaShapeColors"
            checked: root.targetConfig.dashboard.randomizeMediaShapeColors
            onToggled: {
                root.targetConfig.dashboard.randomizeMediaShapeColors = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Sync with music")
            subtext: qsTr("Randomly pick shapes to the beat instead of bass level")
            configNode: root.targetConfig.dashboard
            propertyName: "syncMediaShapesToBeat"
            checked: root.targetConfig.dashboard.syncMediaShapesToBeat
            onToggled: {
                root.targetConfig.dashboard.syncMediaShapesToBeat = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            last: true
            Layout.fillWidth: true
            text: qsTr("Replace lyrics with visuals")
            subtext: qsTr("Show the GIF/shapes in the media tab instead of lyrics")
            configNode: root.targetConfig.dashboard
            propertyName: "replaceMediaLyricsWithVisuals"
            checked: root.targetConfig.dashboard.replaceMediaLyricsWithVisuals
            onToggled: {
                root.targetConfig.dashboard.replaceMediaLyricsWithVisuals = checked;
                root.targetConfig.save();
            }
        }

        // Weather
        SectionHeader {
            text: qsTr("Weather")
        }

        ToggleRow {
            first: true
            last: true
            Layout.fillWidth: true
            text: qsTr("Weather location")
            subtext: qsTr("Show the location in the weather tab")
            configNode: root.targetConfig.dashboard
            propertyName: "showWeatherLocation"
            checked: root.targetConfig.dashboard.showWeatherLocation !== false
            onToggled: {
                root.targetConfig.dashboard.showWeatherLocation = checked;
                root.targetConfig.save();
            }
        }

        // Performance widgets
        SectionHeader {
            text: Tr.tr("Performance widgets")
        }

        ToggleRow {
            first: true
            text: qsTr("Battery")
            configNode: root.targetConfig.dashboard.performance
            propertyName: "showBattery"
            checked: root.targetConfig.dashboard.performance.showBattery
            onToggled: {
                root.targetConfig.dashboard.performance.showBattery = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("GPU")
            configNode: root.targetConfig.dashboard.performance
            propertyName: "showGpu"
            checked: root.targetConfig.dashboard.performance.showGpu
            onToggled: {
                root.targetConfig.dashboard.performance.showGpu = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("CPU")
            configNode: root.targetConfig.dashboard.performance
            propertyName: "showCpu"
            checked: root.targetConfig.dashboard.performance.showCpu
            onToggled: {
                root.targetConfig.dashboard.performance.showCpu = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Memory")
            configNode: root.targetConfig.dashboard.performance
            propertyName: "showMemory"
            checked: root.targetConfig.dashboard.performance.showMemory
            onToggled: {
                root.targetConfig.dashboard.performance.showMemory = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Storage")
            configNode: root.targetConfig.dashboard.performance
            propertyName: "showStorage"
            checked: root.targetConfig.dashboard.performance.showStorage
            onToggled: {
                root.targetConfig.dashboard.performance.showStorage = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            last: true
            text: qsTr("Network")
            configNode: root.targetConfig.dashboard.performance
            propertyName: "showNetwork"
            checked: root.targetConfig.dashboard.performance.showNetwork
            onToggled: {
                root.targetConfig.dashboard.performance.showNetwork = checked;
                root.targetConfig.save();
            }
        }

        // Behaviour
        SectionHeader {
            text: Tr.tr("Behaviour")
        }

        StepperRow {
            first: true
            last: true
            label: qsTr("Drag threshold")
            subtext: qsTr("Pixels dragged before the dashboard opens")
            configNode: root.targetConfig.dashboard
            propertyName: "dragThreshold"
            value: root.targetConfig.dashboard.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => {
                root.targetConfig.dashboard.dragThreshold = v;
                root.targetConfig.save();
            }
        }
    }
}

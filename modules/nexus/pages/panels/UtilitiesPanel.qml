pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property var builtinToggles: ({
        wifi: qsTr("Wi-Fi"),
        bluetooth: qsTr("Bluetooth"),
        mic: qsTr("Microphone"),
        settings: qsTr("Settings"),
        gameMode: qsTr("Game mode"),
        dnd: qsTr("Do not disturb"),
        nightMode: qsTr("Night mode"),
        vpn: qsTr("VPN"),
        quickshare: qsTr("Quick Share"),
        wallpaper: qsTr("Wallpaper selector"),
        badapple: qsTr("Bad Apple"),
        pauseWallpaper: qsTr("Pause video wallpaper"),
        pipPause: qsTr("Pause PiP"),
        search: qsTr("Google Lens search")
    })

    title: Tr.tr("Utilities")
    isSubPage: true

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
            last: true
            text: qsTr("Enabled")
            subtext: qsTr("Show the utilities panel")
            configNode: root.targetConfig.utilities
            propertyName: "enabled"
            checked: root.targetConfig.utilities.enabled
            onToggled: {
                root.targetConfig.utilities.enabled = checked;
                root.targetConfig.save();
            }
        }

        // Cards
        SectionHeader {
            text: Tr.tr("Cards")
        }

        ToggleRow {
            first: true
            text: qsTr("Keep awake")
            subtext: qsTr("Show the idle inhibitor card")
            configNode: root.targetConfig.utilities.cards
            propertyName: "keepAwake"
            checked: root.targetConfig.utilities.cards.keepAwake
            onToggled: {
                root.targetConfig.utilities.cards.keepAwake = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Screen recorder")
            subtext: qsTr("Show the screen recorder card")
            configNode: root.targetConfig.utilities.cards
            propertyName: "recorder"
            checked: root.targetConfig.utilities.cards.recorder
            onToggled: {
                root.targetConfig.utilities.cards.recorder = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            last: true
            text: qsTr("Quick toggles")
            subtext: qsTr("Show the quick toggles card")
            configNode: root.targetConfig.utilities.cards
            propertyName: "quickToggles"
            checked: root.targetConfig.utilities.cards.quickToggles
            onToggled: {
                root.targetConfig.utilities.cards.quickToggles = checked;
                root.targetConfig.save();
            }
        }

        // Quick toggles
        SectionHeader {
            text: Tr.tr("Quick toggles")
        }

        ListEditor {
            function labelFor(item: var): string {
                const prettyName = root.builtinToggles[item.id];
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
            values: root.targetConfig.utilities.quickToggles.values
            onItemMoved: (from, to) => {
                root.targetConfig.utilities.quickToggles.move(from, to);
                root.targetConfig.save();
            }
            onItemRemoved: index => {
                root.targetConfig.utilities.quickToggles.remove(index);
                root.targetConfig.save();
            }
            onItemToggled: (index, checked) => {
                root.targetConfig.utilities.quickToggles.at(index).enabled = checked;
                root.targetConfig.save();
            }
        }

        DialogSelectButton {
            id: addItemContainer

            rootParent: root.flickable
            icon: "add"
            label: Tr.tr("Add entry")
            header: Tr.tr("Add new entry")
            acceptLabel: Tr.trCtx("Add", "button")

            model: {
                const builtins = Object.keys(root.builtinToggles).map(k => ({
                    id: k,
                    label: root.builtinToggles[k]
                }));
                return builtins.filter(b => !root.targetConfig.utilities.quickToggles.values.some(v => v.id === b.id));
            }

            onAccepted: {
                if (!selectedItem)
                    return;

                root.targetConfig.utilities.quickToggles.insert({
                    id: selectedItem,
                    enabled: true
                });
                root.targetConfig.save();
            }
        }

        // Night Mode
        SectionHeader {
            visible: HyprSunset.available
            text: qsTr("Night mode")
        }

        SliderRow {
            readonly property int minTemp: 1000
            readonly property int maxTemp: 6500

            visible: HyprSunset.available
            first: true
            last: true
            icon: "dark_mode"
            label: qsTr("Color temperature")
            valueLabel: HyprSunset.temperature + qsTr("K")
            value: (HyprSunset.temperature - minTemp) / (maxTemp - minTemp)
            onMoved: v => {
                const temp = Math.round(minTemp + v * (maxTemp - minTemp));
                HyprSunset.start(temp);
            }
        }
    }
}

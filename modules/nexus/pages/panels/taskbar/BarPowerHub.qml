pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.utils
import qs.modules.nexus.common
import qs.modules.nexus.pages.assets

PageBase {
    id: root

    readonly property bool hubEnabled: root.targetConfig.session.powerHub === true
    readonly property bool usingVacuitedEmblem: {
        const v = (GlobalConfig.paths.sessionGif || "").trim();
        return v === "" || v === "vacuited" || v === "root:/assets/logo.svg" || v === GlobalConfig.paths.descriptorFor("sessionGif").defaultValue;
    }
    readonly property list<MenuItem> dialStyleItems: [
        MenuItem {
            property string value: "rim"
            text: qsTr("Rim wavy arc")
        },
        MenuItem {
            property string value: "minimal"
            text: qsTr("Clean")
        },
        MenuItem {
            property string value: "halo"
            text: qsTr("Emblem halo")
        }
    ]

    title: qsTr("Power hub")
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
            text: qsTr("Enable Power hub")
            subtext: qsTr("Pin the power button to the bar corner and use the fullscreen radial hub instead of the side drawer")
            configNode: root.targetConfig.session
            propertyName: "powerHub"
            checked: root.hubEnabled
            onToggled: {
                root.targetConfig.session.powerHub = checked;
                root.targetConfig.save();
            }
        }

        // Behaviour
        SectionHeader {
            text: Tr.tr("Behaviour")
        }

        ToggleRow {
            first: true
            enabled: root.hubEnabled
            text: qsTr("Dial tick sound")
            subtext: qsTr("Play a subtle click when stepping across options (requires UI sounds)")
            configNode: root.targetConfig.session
            propertyName: "powerHubTickSound"
            checked: root.targetConfig.session.powerHubTickSound === true
            onToggled: {
                root.targetConfig.session.powerHubTickSound = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            enabled: root.hubEnabled
            text: qsTr("Confirm destructive actions")
            subtext: qsTr("Require a second click or Enter press for Poweroff and Reboot")
            configNode: root.targetConfig.session
            propertyName: "powerHubConfirmDangerous"
            checked: root.targetConfig.session.powerHubConfirmDangerous !== false
            onToggled: {
                root.targetConfig.session.powerHubConfirmDangerous = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            enabled: root.hubEnabled
            text: qsTr("Active status warnings")
            subtext: qsTr("Show warning pills when screen recording or Keep Awake is active")
            configNode: root.targetConfig.session
            propertyName: "powerHubStatusChips"
            checked: root.targetConfig.session.powerHubStatusChips !== false
            onToggled: {
                root.targetConfig.session.powerHubStatusChips = checked;
                root.targetConfig.save();
            }
        }

        SelectRow {
            last: true
            enabled: root.hubEnabled
            Layout.fillWidth: true
            label: qsTr("Dial track style")
            subtext: qsTr("Visual track inside the radial dial pocket")
            configNode: root.targetConfig.session
            propertyName: "powerHubDialStyle"
            active: {
                const cur = root.targetConfig.session.powerHubDialStyle || "rim";
                for (let i = 0; i < root.dialStyleItems.length; i++) {
                    if (root.dialStyleItems[i].value === cur)
                        return root.dialStyleItems[i];
                }
                return root.dialStyleItems[0];
            }
            menuItems: root.dialStyleItems
            onSelected: item => {
                root.targetConfig.session.powerHubDialStyle = item.value;
                root.targetConfig.save();
            }
        }

        // Emblem
        SectionHeader {
            text: qsTr("Emblem")
        }

        AssetRow {
            first: true
            previewAnimated: true
            filters: ["png", "jpg", "jpeg", "webp", "svg", "gif"]
            label: qsTr("Power hub emblem")
            subtext: qsTr("Center graphic inside the dial (defaults to animated Vacuited logo)")
            option: "sessionGif"
            value: GlobalConfig.paths.sessionGif
            defaultValue: GlobalConfig.paths.descriptorFor("sessionGif").defaultValue
            previewSource: Paths.absolutePath(GlobalConfig.paths.sessionGif)
            useVacuitedDefaultPreview: root.usingVacuitedEmblem
            write: v => GlobalConfig.paths.sessionGif = v
            reset: () => GlobalConfig.paths.resetOption("sessionGif")
        }

        SliderRow {
            last: true
            Layout.fillWidth: true
            label: qsTr("Custom GIF speed")
            configNode: GlobalConfig.general
            propertyName: "sessionGifSpeed"
            showReset: true
            enabled: !root.usingVacuitedEmblem
            value: Math.max(0, Math.min(1, (GlobalConfig.general.sessionGifSpeed - 0.2) / 1.8))
            valueLabel: GlobalConfig.general.sessionGifSpeed.toFixed(1) + "×"
            onMoved: v => {
                GlobalConfig.general.sessionGifSpeed = Math.round((0.2 + v * 1.8) * 10) / 10;
            }
            onReset: GlobalConfig.general.resetOption("sessionGifSpeed")
        }
    }
}

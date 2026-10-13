pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import "../../../services"

Column {
    id: root

    // NOTE: dropped by the upstream merge (calls survived, definition did not).
    function formatSeconds(s: int): string {
        const day = Math.floor(s / 86400);
        const hr = Math.floor(s / 3600) % 24;
        const min = Math.floor(s / 60) % 60;

        let comps = [];
        if (day > 0)
            comps.push(Tr.trN("%n day", "%n days", day));
        if (hr > 0)
            comps.push(Tr.trN("%n hour", "%n hours", hr));
        if (min > 0)
            comps.push(Tr.trN("%n min", "%n mins", min));

        return comps.join(Tr.trCtx(", ", "duration component separator"));
    }
    required property var popouts
    property bool _isSidebarOpen: popouts && popouts.sidebarOpen && popouts.isHorizontal && popouts.currentSection === "end"

    spacing: Tokens.spacing.medium
    width: Math.max(Tokens.sizes.bar.batteryWidth, _isSidebarOpen ? Tokens.sizes.sidebar.width - Tokens.padding.extraLargeIncreased : 0)

    StyledText {
        text: UPower.displayDevice.isLaptopBattery ? Tr.trCtx("Remaining: %1%", "battery remaining").arg(Math.round(UPower.displayDevice.percentage * 100)) : Tr.tr("No battery detected")
    }

    StyledText {
        text: {
            const dev = UPower.displayDevice;
            if (!dev.isLaptopBattery)
                return Tr.tr("Power profile: %1").arg(root.powerProfileToString(PowerProfiles.profile));

            if (UPower.onBattery) {
                const time = root.formatSeconds(dev.timeToEmpty);
                if (time)
                    return Tr.tr("Time remaining: %1").arg(time);
                return Tr.tr("Calculating remaining battery life...");
            }

            if (dev.timeToFull > 0)
                return Tr.tr("Time until charged: %1").arg(root.formatSeconds(dev.timeToFull));
            if (Math.round(dev.percentage * 100) === 100)
                return Tr.tr("Fully charged!");
            return Tr.tr("Calculating time until charged...");
        }
    }

    Loader {
        asynchronous: true
        anchors.horizontalCenter: parent.horizontalCenter

        active: PowerProfiles.degradationReason !== PerformanceDegradationReason.None

        height: active ? ((item as Item)?.implicitHeight ?? 0) : 0

        sourceComponent: StyledRect {
            implicitWidth: child.implicitWidth + Tokens.padding.medium * 2
            implicitHeight: child.implicitHeight + Tokens.padding.large

            color: Colours.palette.m3error
            radius: Tokens.rounding.large

            Column {
                id: child

                anchors.centerIn: parent

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -font.pointSize / 10

                        text: "warning"
                        color: Colours.palette.m3onError
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        // TRANSLATORS: charger or thermal warning: the battery cannot draw full power
                        text: Tr.tr("Performance degraded")
                        color: Colours.palette.m3onError
                        font: Tokens.font.title.small
                    }

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -font.pointSize / 10

                        text: "warning"
                        color: Colours.palette.m3onError
                    }
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter

                    text: root.perfDegradationToString(PowerProfiles.degradationReason)
                    color: Colours.palette.m3onError
                }
            }
        }
    }

    StyledRect {
        id: profiles

        property string current: {
            if (Hardware.profile === "cool")
                return cool.icon;
            if (Hardware.profile === "quiet" || PowerProfiles.profile === PowerProfile.PowerSaver)
                return saver.icon;
            if (Hardware.profile === "performance" || PowerProfiles.profile === PowerProfile.Performance)
                return perf.icon;
            return balance.icon;
        }

        anchors.horizontalCenter: parent.horizontalCenter

        implicitWidth: saver.implicitHeight + cool.implicitHeight + balance.implicitHeight + perf.implicitHeight + Tokens.padding.medium * 2 + Tokens.spacing.largeIncreased * 3
        implicitHeight: Math.max(saver.implicitHeight, cool.implicitHeight, balance.implicitHeight, perf.implicitHeight) + Tokens.padding.small

        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.full

        StyledRect {
            id: indicator

            color: Colours.palette.m3primary
            radius: Tokens.rounding.full
            state: profiles.current

            states: [
                State {
                    name: saver.icon

                    Fill {
                        item: saver
                    }
                },
                State {
                    name: cool.icon

                    Fill {
                        item: cool
                    }
                },
                State {
                    name: balance.icon

                    Fill {
                        item: balance
                    }
                },
                State {
                    name: perf.icon

                    Fill {
                        item: perf
                    }
                }
            ]

            transitions: Transition {
                AnchorAnim {}
            }
        }

        Profile {
            id: saver

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Tokens.padding.extraSmall

            icon: "energy_savings_leaf"
            targetProfile: "quiet"
            fallbackProfile: PowerProfile.PowerSaver
        }

        Profile {
            id: cool

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: saver.right
            anchors.leftMargin: Tokens.spacing.largeIncreased

            icon: "ac_unit"
            targetProfile: "cool"
            fallbackProfile: -1
        }

        Profile {
            id: balance

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: cool.right
            anchors.leftMargin: Tokens.spacing.largeIncreased

            icon: "balance"
            targetProfile: "balanced"
            fallbackProfile: PowerProfile.Balanced
        }

        Profile {
            id: perf

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: balance.right
            anchors.leftMargin: Tokens.spacing.largeIncreased
            anchors.right: parent.right
            anchors.rightMargin: Tokens.padding.extraSmall

            icon: "rocket_launch"
            targetProfile: "performance"
            fallbackProfile: PowerProfile.Performance
        }
    }

    component Fill: AnchorChanges {
        required property Item item

        target: indicator
        anchors.left: item.left
        anchors.right: item.right
        anchors.top: item.top
        anchors.bottom: item.bottom
    }

    component Profile: Item {
        id: profItem
        required property string icon
        required property string targetProfile
        required property int fallbackProfile

        implicitWidth: icon.implicitHeight + Tokens.padding.small
        implicitHeight: icon.implicitHeight + Tokens.padding.small

        StateLayer {
            radius: Tokens.rounding.full
            color: profiles.current === parent.icon ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            onClicked: {
                Hardware.setProfile(profItem.targetProfile);
                if (profItem.fallbackProfile !== -1) {
                    PowerProfiles.profile = profItem.fallbackProfile;
                }
            }
        }

        MaterialIcon {
            id: icon

            anchors.centerIn: parent

            text: parent.icon
            fontStyle: Tokens.font.icon.large
            color: profiles.current === text ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
            fill: profiles.current === text ? 1 : 0

            Behavior on fill {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }
    }
}

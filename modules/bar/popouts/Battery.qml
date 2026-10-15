pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils
import "../../../services"

Item {
    id: root

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

    function perfDegradationToString(p: int): string {
        switch (p) {
        case PerformanceDegradationReason.HighTemperature:
            return Tr.tr("The device is too hot");
        case PerformanceDegradationReason.LapDetected:
            return Tr.tr("The device is on a lap");
        default:
            return Tr.tr("Unknown reason");
        }
    }

    required property var popouts
    property bool _isSidebarOpen: popouts && popouts.sidebarOpen && popouts.isHorizontal && popouts.currentSection === "end"

    readonly property bool charging: [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(UPower.displayDevice.state)
    readonly property bool isLowBattery: UPower.onBattery && UPower.displayDevice.percentage <= 0.2
    property real animPerc: UPower.displayDevice.percentage

    // Dynamic Caelestia M3 Colors
    readonly property color baseFillColour: {
        if (root.isLowBattery)
            return Colours.palette.m3error;
        if (root.charging)
            return Colours.palette.m3primary;
        return Colours.palette.m3secondary;
    }

    readonly property color baseContainerColour: {
        if (root.isLowBattery)
            return Colours.palette.m3errorContainer;
        if (root.charging)
            return Colours.palette.m3primaryContainer;
        return Colours.tPalette.m3surfaceContainerHigh;
    }

    readonly property color trackAccentColour: {
        if (root.isLowBattery)
            return Colours.palette.m3onErrorContainer;
        if (root.charging)
            return Colours.palette.m3onPrimaryContainer;
        return Colours.palette.m3primary;
    }

    readonly property color trackTextColour: {
        if (root.isLowBattery)
            return Colours.palette.m3onErrorContainer;
        if (root.charging)
            return Colours.palette.m3onPrimaryContainer;
        return Colours.palette.m3onSurface;
    }

    readonly property color fillAccentColour: {
        if (root.isLowBattery)
            return Colours.palette.m3onError;
        if (root.charging)
            return Colours.palette.m3onPrimary;
        return Colours.palette.m3primaryContainer;
    }

    readonly property color fillTextColour: {
        if (root.isLowBattery)
            return Colours.palette.m3onError;
        if (root.charging)
            return Colours.palette.m3onPrimary;
        return Colours.palette.m3onSecondary;
    }

    // true shows the clock time ("until 22:30") instead of the time left ("7h 12m left")
    readonly property bool useClockTime: false
    // "auto" follows the shell's clock setting, or use "12" / "24"
    readonly property string clockFormat: "auto"
    readonly property real widthScale: 1.05

    readonly property string timeLabel: {
        const dev = UPower.displayDevice;
        if (!dev.isLaptopBattery)
            return "";
        if (charging && Math.round(dev.percentage * 100) === 100)
            return Tr.tr("Full");

        const secs = UPower.onBattery ? dev.timeToEmpty : dev.timeToFull;
        if (secs <= 0)
            return "";

        if (useClockTime) {
            const end = Qt.formatDateTime(new Date(Date.now() + secs * 1000), (clockFormat === "auto" ? Units.twelveHourClock : clockFormat === "12") ? "h:mm A" : "HH:mm");
            return (UPower.onBattery ? Tr.tr("until %1") : Tr.tr("full at %1")).arg(end);
        }

        const h = Math.floor(secs / 3600);
        const m = Math.floor(secs / 60) % 60;
        const dur = h > 0 ? (m > 0 ? Tr.tr("%1h %2m").arg(h).arg(m) : Tr.tr("%1h").arg(h)) : Tr.tr("%1m").arg(Math.max(1, m));
        return (UPower.onBattery ? Tr.tr("%1 left") : Tr.tr("%1 to full")).arg(dur);
    }

    implicitWidth: Math.max(Tokens.sizes.bar.batteryWidth * widthScale, _isSidebarOpen ? Tokens.sizes.sidebar.width - Tokens.padding.extraLargeIncreased : 0)
    implicitHeight: mainCol.implicitHeight
    width: implicitWidth

    Behavior on animPerc {
        Anim {}
    }

    ColumnLayout {
        id: mainCol

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.medium

        StyledRect {
            id: tank

            Layout.fillWidth: true
            Layout.preferredHeight: 96

            color: root.baseContainerColour
            radius: Tokens.rounding.large

            Behavior on color {
                CAnim {
                    duration: Tokens.anim.durations.expressiveDefaultEffects
                }
            }

            // Background text layout (visible on unfilled track)
            TankContents {
                id: tankLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium

                accentColour: root.trackAccentColour
                textColour: root.trackTextColour

                Behavior on accentColour {
                    CAnim {
                        duration: Tokens.anim.durations.expressiveDefaultEffects
                    }
                }

                Behavior on textColour {
                    CAnim {
                        duration: Tokens.anim.durations.expressiveDefaultEffects
                    }
                }
            }

            // Fill background (smooth anti-aliased rectangle)
            StyledRect {
                id: fillBg

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * root.animPerc

                color: root.baseFillColour
                radius: Math.min(parent.radius, width / 2)

                Behavior on color {
                    CAnim {
                        duration: Tokens.anim.durations.expressiveDefaultEffects
                    }
                }

                Rectangle {
                    id: pulse

                    visible: root.charging
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * 0.35
                    x: -width

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0
                            color: Qt.alpha(Colours.palette.m3onPrimary, 0)
                        }
                        GradientStop {
                            position: 0.5
                            color: Qt.alpha(Colours.palette.m3onPrimary, 0.22)
                        }
                        GradientStop {
                            position: 1
                            color: Qt.alpha(Colours.palette.m3onPrimary, 0)
                        }
                    }

                    SequentialAnimation {
                        running: root.charging
                        loops: Animation.Infinite

                        NumberAnimation {
                            target: pulse
                            property: "x"
                            from: -pulse.width
                            to: fillBg.width
                            duration: Tokens.anim.durations.expressiveSlowEffects * 3
                            easing: Tokens.anim.expressiveSlowEffects
                        }
                        PauseAnimation {
                            duration: Tokens.anim.durations.expressiveSlowEffects
                        }
                    }
                }
            }

            // Clipped overlay for text on top of the fill
            Item {
                id: fillClip

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * root.animPerc
                clip: true

                TankContents {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: tankLayout.anchors.margins
                    width: tankLayout.width

                    accentColour: root.fillAccentColour
                    textColour: root.fillTextColour

                    Behavior on accentColour {
                        CAnim {
                            duration: Tokens.anim.durations.expressiveDefaultEffects
                        }
                    }

                    Behavior on textColour {
                        CAnim {
                            duration: Tokens.anim.durations.expressiveDefaultEffects
                        }
                    }
                }
            }
        }

        Loader {
            Layout.alignment: Qt.AlignHCenter
            asynchronous: true

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

            Layout.alignment: Qt.AlignHCenter

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

    component TankContents: ColumnLayout {
        id: contents

        required property color accentColour
        required property color textColour

        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: -Tokens.padding.extraSmall
                text: UPower.displayDevice.isLaptopBattery ? "battery_full" : "bolt"
                color: contents.accentColour
                fontStyle: Tokens.font.icon.medium
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: UPower.displayDevice.isLaptopBattery ? Tr.tr("Battery") : Tr.tr("Power")
                color: contents.textColour
                font: Tokens.font.title.small
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: root.timeLabel
                color: contents.accentColour
                font: Tokens.font.label.large
            }
        }

        Item {
            Layout.fillHeight: true
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                text: "bolt"
                color: contents.accentColour
                fontStyle: Tokens.font.icon.large
                fill: 1

                scale: root.charging ? 1 : 0
                opacity: root.charging ? 1 : 0

                Behavior on scale {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }

                Behavior on opacity {
                    Anim {
                        type: Anim.FastEffects
                    }
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                visible: UPower.displayDevice.isLaptopBattery
                text: Strings.percentOne(UPower.displayDevice.percentage)
                color: contents.accentColour
                font: Tokens.font.headline.small
            }
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import M3Shapes
import Caelestia.Config
import Caelestia.Services
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

    readonly property real s: Math.max(0.55, Math.min(2.2, widgetScale > 0 ? widgetScale : WidgetMetrics.scale))
    readonly property string effectiveSize: WidgetMetrics.fallbackSizeFor("battery", sizeMode)
    readonly property var dev: UPower.displayDevice
    readonly property bool isLaptop: dev?.isLaptopBattery ?? false
    readonly property real pct: Math.max(0, Math.min(1, dev?.percentage ?? 0))
    readonly property int pctInt: Math.round(pct * 100)
    readonly property bool isFull: (dev?.state ?? 0) === UPowerDeviceState.FullyCharged
    readonly property bool isCharging: (dev?.state ?? 0) === UPowerDeviceState.Charging || isFull
    readonly property real rateW: Math.abs(dev?.changeRate ?? 0)
    readonly property real seconds: isCharging ? (dev?.timeToFull ?? 0) : (dev?.timeToEmpty ?? 0)
    readonly property bool isLow: isLaptop && pct < 0.2 && !isCharging
    readonly property real desktopGpuPower: Hardware.isSupported ? Hardware.gpuPower : 0
    readonly property real desktopMetricRatio: desktopGpuPower > 0 ? Math.min(1, desktopGpuPower / 150) : Math.max(0, Math.min(1, Gpu.percentage))
    readonly property string desktopMainValue: desktopGpuPower > 0 ? (Math.round(desktopGpuPower) + " W") : (Math.round(Gpu.percentage * 100) + "%")
    readonly property string desktopSubValue: desktopGpuPower > 0 ? (desktopGpuPower.toFixed(1) + " W") : (Gpu.temperature > 0 ? Units.formatSensorTemp(Gpu.temperature) : (Gpu.name || "--"))

    readonly property color accentColor: isLow
        ? Colours.palette.m3error
        : (isCharging ? Colours.palette.m3tertiary : Colours.palette.m3primary)
    readonly property color accentContainer: isLow
        ? Colours.palette.m3errorContainer
        : (isCharging ? Colours.palette.m3tertiaryContainer : Colours.palette.m3primaryContainer)
    readonly property color accentContainerTint: shell.containerTone(accentContainer, false)
    readonly property color onAccentContainer: isLow
        ? Colours.palette.m3onErrorContainer
        : (isCharging ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onPrimaryContainer)

    readonly property string stateIcon: !isLaptop ? "bolt" : (isFull ? "battery_full" : (isCharging ? "battery_charging_full" : (isLow ? "battery_alert" : "battery_5_bar")))
    readonly property string statusText: !isLaptop
        ? (desktopGpuPower > 0 ? Tr.tr("GPU Power") : (Gpu.name || Tr.tr("GPU")))
        : (isFull ? Tr.tr("Fully charged") : (isCharging ? Tr.tr("Charging") : Tr.tr("On battery")))
    readonly property string profileLabel: {
        switch (PowerProfiles.profile) {
        case PowerProfile.Performance:
            return Tr.tr("Performance");
        case PowerProfile.PowerSaver:
            return Tr.tr("Power Saver");
        default:
            return Tr.tr("Balanced");
        }
    }

    function formatDuration(secs: real): string {
        if (!secs || secs < 60)
            return "--";
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        return h > 0 ? (h + "h " + m + "m") : (m + "m");
    }

    implicitWidth: WidgetMetrics.widthFor(effectiveSize, s)
    implicitHeight: WidgetMetrics.heightFor(effectiveSize, "battery", s)

    Loader {
        active: root.visible && !root.isLaptop && root.desktopGpuPower <= 0 && Gpu.type !== GpuType.None && !GameMode.enabled
        sourceComponent: Component {
            ServiceRef {
                service: Gpu
            }
        }
    }

    WidgetCardShell {
        id: shell

        anchors.fill: parent
        widgetType: "battery"
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

    // 1x1 Expressive Shaped Tile
    Component {
        id: layout1x1

        Item {
            readonly property int ringSize: Math.max(36, Math.round(Math.min((shell.isShaped ? 62 : 70) * root.s, shell.safeInnerBox - Math.round(30 * root.s))))

            clip: true

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.max(24, parent.width - shell.sidePadding * 2)
                spacing: Math.max(2, Math.round(3 * root.s))

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: ringSize
                    Layout.preferredHeight: ringSize

                    CircularProgress {
                        anchors.fill: parent
                        value: root.isLaptop ? root.pct : root.desktopMetricRatio
                        wavy: root.visible && root.effectiveSize === "1x1" && root.isCharging && !GameMode.enabled
                        wavePaused: !wavy
                        strokeWidth: Math.max(4, Math.round(5 * root.s))
                        fgColour: root.accentColor
                        bgColour: shell.trackSurface
                        implicitSize: ringSize
                    }

                    MaterialShape {
                        readonly property int innerBadgeSize: Math.max(22, Math.round(ringSize * 0.62))

                        anchors.centerIn: parent
                        width: innerBadgeSize
                        height: innerBadgeSize
                        implicitSize: innerBadgeSize
                        shape: MaterialShape.Cookie6Sided
                        color: root.accentContainerTint

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: root.stateIcon
                            fontStyle: Tokens.font.icon.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).build()
                            color: root.onAccentContainer
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    horizontalAlignment: Text.AlignHCenter
                    text: root.isLaptop ? (root.pctInt + "%") : root.desktopMainValue
                    font: Tokens.font.clock.size(Math.max(11, Math.round(17 * root.s))).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    horizontalAlignment: Text.AlignHCenter
                    text: root.isLaptop
                        ? (root.seconds >= 60 ? root.formatDuration(root.seconds) : root.statusText)
                        : root.statusText
                    font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.86)).build()
                    color: root.isCharging || root.isLow ? root.accentColor : Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }
        }
    }

    // 1x2 Wide Strip
    Component {
        id: layout1x2

        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            spacing: Math.max(6, Math.round(Tokens.spacing.large * root.s))

            Item {
                Layout.fillWidth: false
                Layout.preferredWidth: Math.round(84 * root.s)
                Layout.preferredHeight: Math.round(84 * root.s)
                Layout.alignment: Qt.AlignVCenter

                CircularProgress {
                    anchors.fill: parent
                    value: root.isLaptop ? root.pct : root.desktopMetricRatio
                    wavy: root.visible && root.effectiveSize === "1x2" && root.isCharging && !GameMode.enabled
                    wavePaused: !wavy
                    strokeWidth: Math.max(4, Math.round(6 * root.s))
                    fgColour: root.accentColor
                    bgColour: shell.trackSurface
                    implicitSize: Math.round(84 * root.s)
                }

                MaterialShape {
                    anchors.centerIn: parent
                    width: Math.round(50 * root.s)
                    height: Math.round(50 * root.s)
                    implicitSize: Math.round(50 * root.s)
                    shape: MaterialShape.Puffy
                    color: root.accentContainerTint

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: root.stateIcon
                        fontStyle: Tokens.font.icon.builders.large.scale(WidgetMetrics.safeFontScale(root.s, 0.96)).build()
                        color: root.onAccentContainer
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter
                spacing: Math.max(3, Math.round(6 * root.s))

                RowLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: Math.max(4, Math.round(Tokens.spacing.small * root.s))

                    StyledText {
                        Layout.fillWidth: false
                        text: root.isLaptop ? (root.pctInt + "%") : root.desktopMainValue
                        font: Tokens.font.clock.size(Math.max(14, Math.round(27 * root.s))).weight(Font.Bold).build()
                        color: Colours.palette.m3onSurface
                    }

                    StyledRect {
                        Layout.fillWidth: false
                        Layout.preferredHeight: Math.round(22 * root.s)
                        Layout.preferredWidth: Math.min(Math.round(120 * root.s), Math.round(statLabel.implicitWidth + Math.round(Tokens.padding.medium * 2 * root.s)))
                        clip: true
                        radius: Math.round(11 * root.s)
                        color: root.accentContainerTint

                        StyledText {
                            id: statLabel

                            anchors.centerIn: parent
                            width: Math.max(0, parent.width - Math.round(Tokens.padding.medium * 1.5 * root.s))
                            horizontalAlignment: Text.AlignHCenter
                            text: root.statusText
                            font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.86)).weight(Font.DemiBold).build()
                            color: root.onAccentContainer
                            elide: Text.ElideRight
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                StyledProgressBar {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(6, Math.round(12 * root.s))
                    visible: root.isLaptop
                    value: root.pct
                    wavy: root.visible && root.effectiveSize === "1x2" && root.isCharging && !GameMode.enabled
                    wavePaused: !wavy
                    fgColour: root.accentColor
                    bgColour: shell.trackSurface
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: Math.max(4, Math.round(Tokens.spacing.medium * root.s))

                    StyledText {
                        visible: root.isLaptop && root.rateW > 0.1 && !root.isFull
                        Layout.fillWidth: false
                        text: (root.isCharging ? "+" : "-") + root.rateW.toFixed(1) + " W"
                        font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.92)).build()
                        color: root.accentColor
                    }

                    StyledText {
                        visible: root.isLaptop && root.seconds >= 60
                        text: root.isCharging
                            ? Tr.tr("Full in %1").arg(root.formatDuration(root.seconds))
                            : Tr.tr("%1 left").arg(root.formatDuration(root.seconds))
                        font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.92)).build()
                        color: Colours.palette.m3onSurfaceVariant
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        elide: Text.ElideRight
                    }

                    StyledText {
                        visible: !root.isLaptop
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: root.desktopGpuPower > 0
                            ? Tr.tr("Dedicated GPU draw")
                            : (Gpu.temperature > 0 ? (Units.formatSensorTemp(Gpu.temperature) + " · " + root.profileLabel) : Tr.tr("GPU utilization"))
                        font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.92)).build()
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // 2x2 Full Dashboard Card
    Component {
        id: layout2x2

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            spacing: Math.max(4, Math.round(Tokens.spacing.medium * root.s))

            WidgetHeader {
                Layout.fillWidth: true
                title: root.isLaptop ? Tr.tr("Battery") : Tr.tr("Power draw")
                icon: root.stateIcon
                iconColor: root.accentColor
                scaleFactor: root.s
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                spacing: Math.max(6, Math.round(Tokens.spacing.large * root.s))

                Item {
                    Layout.fillWidth: false
                    Layout.preferredWidth: Math.round(108 * root.s)
                    Layout.preferredHeight: Math.round(108 * root.s)
                    Layout.alignment: Qt.AlignVCenter

                    CircularProgress {
                        anchors.fill: parent
                        value: root.isLaptop ? root.pct : root.desktopMetricRatio
                        wavy: root.visible && root.effectiveSize === "2x2" && root.isCharging && !GameMode.enabled
                        wavePaused: !wavy
                        strokeWidth: Math.max(5, Math.round(7 * root.s))
                        fgColour: root.accentColor
                        bgColour: shell.trackSurface
                        implicitSize: Math.round(108 * root.s)
                    }

                    MaterialShape {
                        anchors.centerIn: parent
                        width: Math.round(66 * root.s)
                        height: Math.round(66 * root.s)
                        implicitSize: Math.round(66 * root.s)
                        shape: MaterialShape.Puffy
                        color: root.accentContainerTint

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: root.stateIcon
                            fontStyle: Tokens.font.icon.builders.extraLarge.scale(WidgetMetrics.safeFontScale(root.s, 0.96)).build()
                            color: root.onAccentContainer
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Math.max(2, Math.round(4 * root.s))

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: root.isLaptop ? (root.pctInt + "%") : root.desktopMainValue
                        font: Tokens.font.clock.size(Math.max(16, Math.round(35 * root.s))).weight(Font.Bold).build()
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: root.statusText
                        font: Tokens.font.title.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.96)).weight(Font.DemiBold).build()
                        color: root.accentColor
                        elide: Text.ElideRight
                    }

                    StyledText {
                        visible: root.isLaptop
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: root.profileLabel
                        font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).build()
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Math.max(4, Math.round(Tokens.spacing.small * root.s))

                StyledRect {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: Math.round(52 * root.s)
                    clip: true
                    radius: Math.round(Tokens.rounding.large * Math.min(1.2, Math.max(0.75, root.s)))
                    color: shell.innerSurface
                    border.width: 1
                    border.color: shell.innerBorder

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: Math.max(0, parent.width - Math.round(Tokens.padding.small * 2 * root.s))
                        spacing: 1

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            horizontalAlignment: Text.AlignHCenter
                            text: root.isLaptop ? ((root.rateW > 0.1 && !root.isFull) ? ((root.isCharging ? "+" : "-") + root.rateW.toFixed(1) + " W") : "--") : root.desktopSubValue
                            font: Tokens.font.label.builders.large.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).weight(Font.Bold).build()
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            horizontalAlignment: Text.AlignHCenter
                            text: root.isLaptop ? Tr.tr("Rate") : (root.desktopGpuPower > 0 ? Tr.tr("Power") : (Gpu.temperature > 0 ? Tr.tr("Temp") : Tr.tr("GPU")))
                            font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.9)).build()
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: Math.round(52 * root.s)
                    clip: true
                    radius: Math.round(Tokens.rounding.large * Math.min(1.2, Math.max(0.75, root.s)))
                    color: shell.innerSurface
                    border.width: 1
                    border.color: shell.innerBorder

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: Math.max(0, parent.width - Math.round(Tokens.padding.small * 2 * root.s))
                        spacing: 1

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            horizontalAlignment: Text.AlignHCenter
                            text: root.isLaptop ? root.formatDuration(root.seconds) : root.profileLabel
                            font: Tokens.font.label.builders.large.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).weight(Font.Bold).build()
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            horizontalAlignment: Text.AlignHCenter
                            text: root.isLaptop ? (root.isCharging ? Tr.tr("To full") : Tr.tr("Remaining")) : Tr.tr("Profile")
                            font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.9)).build()
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}

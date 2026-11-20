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
    property string surfaceStyle: ""
    property bool blurEnabled: Config.background.desktopWidgets.blur
    property real plateOpacity: Config.background.desktopWidgets.opacity
    property var widgetOptions: ({})

    readonly property real s: Math.max(0.7, Math.min(1.5, Config.background.desktopWidgets.scale ?? 1.0))
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
    readonly property string desktopCompactValue: desktopGpuPower > 0 ? (Math.round(desktopGpuPower) + "W") : (Math.round(Gpu.percentage * 100) + "%")
    readonly property string desktopSubValue: desktopGpuPower > 0 ? (desktopGpuPower.toFixed(1) + " W") : (Gpu.temperature > 0 ? Units.formatSensorTemp(Gpu.temperature) : (Gpu.name || "--"))

    readonly property color accentColor: isLow
        ? Colours.palette.m3error
        : (isCharging ? Colours.palette.m3tertiary : Colours.palette.m3primary)
    readonly property color accentContainer: isLow
        ? Colours.palette.m3errorContainer
        : (isCharging ? Colours.palette.m3tertiaryContainer : Colours.palette.m3primaryContainer)
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

    implicitWidth: WidgetMetrics.widthFor(sizeMode, s)
    implicitHeight: WidgetMetrics.heightFor(sizeMode, "battery", s)

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
        sizeMode: root.sizeMode
        outerShape: root.widgetOptions?.outerShape ?? ""
        wallpaper: root.wallpaper
        weActive: root.weActive
        surfaceStyle: root.surfaceStyle
        blurEnabled: root.blurEnabled
        plateOpacity: root.plateOpacity
        scaleFactor: root.s

        // 1x1 Expressive Shaped Tile
        Item {
            anchors.fill: parent
            anchors.topMargin: shell.topPadding
            anchors.bottomMargin: shell.bottomPadding
            anchors.leftMargin: shell.sidePadding
            anchors.rightMargin: shell.sidePadding
            visible: root.sizeMode === "1x1"

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Math.round(4 * root.s)

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.round((shell.isShaped ? 64 : 74) * root.s)
                    Layout.preferredHeight: Math.round((shell.isShaped ? 64 : 74) * root.s)

                    CircularProgress {
                        anchors.fill: parent
                        value: root.isLaptop ? root.pct : root.desktopMetricRatio
                        wavy: root.visible && root.sizeMode === "1x1" && root.isCharging && !GameMode.enabled
                        wavePaused: !wavy
                        strokeWidth: Math.max(4, Math.round(5 * root.s))
                        fgColour: root.accentColor
                        bgColour: WidgetMetrics.trackSurface
                        implicitSize: width
                    }

                    MaterialShape {
                        anchors.centerIn: parent
                        width: Math.round((shell.isShaped ? 40 : 46) * root.s)
                        height: Math.round((shell.isShaped ? 40 : 46) * root.s)
                        shape: MaterialShape.Cookie6Sided
                        color: root.accentContainer

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: root.stateIcon
                            fontStyle: Tokens.font.icon.builders.medium.scale(root.s).build()
                            color: root.onAccentContainer
                        }
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.isLaptop ? (root.pctInt + "%") : root.desktopMainValue
                    font: Tokens.font.clock.size(Math.round(18 * root.s)).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.isLaptop
                        ? (root.seconds >= 60 ? root.formatDuration(root.seconds) : root.statusText)
                        : root.statusText
                    font: Tokens.font.label.builders.small.scale(Math.max(0.85, root.s * 0.9)).build()
                    color: root.isCharging || root.isLow ? root.accentColor : Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }
        }

        // 1x2 Wide Strip
        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "1x2"
            spacing: Math.round(Tokens.spacing.large * root.s)

            Item {
                Layout.preferredWidth: Math.round(86 * root.s)
                Layout.preferredHeight: Math.round(86 * root.s)
                Layout.alignment: Qt.AlignVCenter

                CircularProgress {
                    anchors.fill: parent
                    value: root.isLaptop ? root.pct : root.desktopMetricRatio
                    wavy: root.visible && root.sizeMode === "1x2" && root.isCharging && !GameMode.enabled
                    wavePaused: !wavy
                    strokeWidth: Math.max(4, Math.round(6 * root.s))
                    fgColour: root.accentColor
                    bgColour: WidgetMetrics.trackSurface
                    implicitSize: width
                }

                MaterialShape {
                    anchors.centerIn: parent
                    width: Math.round(52 * root.s)
                    height: Math.round(52 * root.s)
                    shape: MaterialShape.Puffy
                    color: root.accentContainer

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: root.stateIcon
                        fontStyle: Tokens.font.icon.builders.large.scale(root.s).build()
                        color: root.onAccentContainer
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: Math.round(6 * root.s)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: root.isLaptop ? (root.pctInt + "%") : root.desktopMainValue
                        font: Tokens.font.clock.size(Math.round(28 * root.s)).weight(Font.Bold).build()
                        color: Colours.palette.m3onSurface
                    }

                    StyledRect {
                        Layout.preferredHeight: Math.round(22 * root.s)
                        Layout.preferredWidth: Math.min(Math.round(124 * root.s), Math.round(statLabel.implicitWidth + Tokens.padding.medium * 2))
                        radius: Math.round(11 * root.s)
                        color: root.accentContainer

                        StyledText {
                            id: statLabel

                            anchors.centerIn: parent
                            width: Math.max(0, parent.width - Tokens.padding.medium * 2)
                            horizontalAlignment: Text.AlignHCenter
                            text: root.statusText
                            font: Tokens.font.label.builders.small.scale(Math.max(0.85, root.s * 0.9)).weight(Font.DemiBold).build()
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
                    Layout.preferredHeight: Math.round(12 * root.s)
                    visible: root.isLaptop
                    value: root.pct
                    wavy: root.visible && root.sizeMode === "1x2" && root.isCharging && !GameMode.enabled
                    wavePaused: !wavy
                    fgColour: root.accentColor
                    bgColour: WidgetMetrics.trackSurface
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.medium

                    StyledText {
                        visible: root.isLaptop && root.rateW > 0.1 && !root.isFull
                        text: (root.isCharging ? "+" : "-") + root.rateW.toFixed(1) + " W"
                        font: Tokens.font.label.builders.small.scale(root.s).build()
                        color: root.accentColor
                    }

                    StyledText {
                        visible: root.isLaptop && root.seconds >= 60
                        text: root.isCharging
                            ? Tr.tr("Full in %1").arg(root.formatDuration(root.seconds))
                            : Tr.tr("%1 left").arg(root.formatDuration(root.seconds))
                        font: Tokens.font.label.builders.small.scale(root.s).build()
                        color: Colours.palette.m3onSurfaceVariant
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    StyledText {
                        visible: !root.isLaptop
                        Layout.fillWidth: true
                        text: root.desktopGpuPower > 0
                            ? Tr.tr("Dedicated GPU draw")
                            : (Gpu.temperature > 0 ? (Units.formatSensorTemp(Gpu.temperature) + " · " + root.profileLabel) : Tr.tr("GPU utilization"))
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // 2x1 Tall Column
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "2x1"
            spacing: Math.round(Tokens.spacing.medium * root.s)

            WidgetHeader {
                Layout.fillWidth: true
                title: root.isLaptop ? Tr.tr("Battery") : Tr.tr("Power")
                icon: root.stateIcon
                iconColor: root.accentColor
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Item {
                    anchors.centerIn: parent
                    width: Math.round(108 * root.s)
                    height: Math.round(108 * root.s)

                    CircularProgress {
                        anchors.fill: parent
                        value: root.isLaptop ? root.pct : root.desktopMetricRatio
                        wavy: root.visible && root.sizeMode === "2x1" && root.isCharging && !GameMode.enabled
                        wavePaused: !wavy
                        strokeWidth: Math.max(5, Math.round(7 * root.s))
                        fgColour: root.accentColor
                        bgColour: WidgetMetrics.trackSurface
                        implicitSize: width
                    }

                    MaterialShape {
                        anchors.centerIn: parent
                        width: Math.round(68 * root.s)
                        height: Math.round(68 * root.s)
                        shape: MaterialShape.Cookie6Sided
                        color: root.accentContainer

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 0

                            MaterialIcon {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.stateIcon
                                fontStyle: Tokens.font.icon.builders.medium.scale(root.s).build()
                                color: root.onAccentContainer
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.isLaptop ? (root.pctInt + "%") : root.desktopCompactValue
                                font: Tokens.font.label.builders.large.scale(root.s).weight(Font.Bold).build()
                                color: root.onAccentContainer
                            }
                        }
                    }
                }
            }

            StyledProgressBar {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(10 * root.s)
                visible: root.isLaptop
                value: root.pct
                wavy: root.visible && root.sizeMode === "2x1" && root.isCharging && !GameMode.enabled
                wavePaused: !wavy
                fgColour: root.accentColor
                bgColour: WidgetMetrics.trackSurface
            }

            StyledRect {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(52 * root.s)
                radius: Tokens.rounding.large
                color: WidgetMetrics.innerSurface

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - Tokens.padding.small * 2
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.statusText
                        font: Tokens.font.label.builders.medium.scale(root.s).weight(Font.DemiBold).build()
                        color: root.accentColor
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.isLaptop
                            ? ((root.rateW > 0.1 && !root.isFull ? ((root.isCharging ? "+" : "-") + root.rateW.toFixed(1) + "W · ") : "")
                                + (root.seconds >= 60 ? root.formatDuration(root.seconds) : root.profileLabel))
                            : (root.desktopSubValue + " · " + root.profileLabel)
                        font: Tokens.font.label.builders.small.scale(Math.max(0.85, root.s * 0.9)).build()
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // 2x2 Full Dashboard Card
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "2x2"
            spacing: Math.round(Tokens.spacing.medium * root.s)

            WidgetHeader {
                Layout.fillWidth: true
                title: root.isLaptop ? Tr.tr("Battery") : Tr.tr("Power draw")
                icon: root.stateIcon
                iconColor: root.accentColor
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Math.round(Tokens.spacing.large * root.s)

                Item {
                    Layout.preferredWidth: Math.round(112 * root.s)
                    Layout.preferredHeight: Math.round(112 * root.s)
                    Layout.alignment: Qt.AlignVCenter

                    CircularProgress {
                        anchors.fill: parent
                        value: root.isLaptop ? root.pct : root.desktopMetricRatio
                        wavy: root.visible && root.sizeMode === "2x2" && root.isCharging && !GameMode.enabled
                        wavePaused: !wavy
                        strokeWidth: Math.max(6, Math.round(8 * root.s))
                        fgColour: root.accentColor
                        bgColour: WidgetMetrics.trackSurface
                        implicitSize: width
                    }

                    MaterialShape {
                        anchors.centerIn: parent
                        width: Math.round(68 * root.s)
                        height: Math.round(68 * root.s)
                        shape: MaterialShape.Puffy
                        color: root.accentContainer

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: root.stateIcon
                            fontStyle: Tokens.font.icon.builders.extraLarge.scale(root.s).build()
                            color: root.onAccentContainer
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 4

                    StyledText {
                        text: root.isLaptop ? (root.pctInt + "%") : root.desktopMainValue
                        font: Tokens.font.clock.size(Math.round(38 * root.s)).weight(Font.Bold).build()
                        color: Colours.palette.m3onSurface
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.statusText
                        font: Tokens.font.title.builders.small.scale(root.s).weight(Font.DemiBold).build()
                        color: root.accentColor
                        elide: Text.ElideRight
                    }

                    StyledText {
                        visible: root.isLaptop
                        text: root.profileLabel
                        font: Tokens.font.label.builders.small.scale(root.s).build()
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledRect {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(52 * root.s)
                    radius: Tokens.rounding.large
                    color: WidgetMetrics.innerSurface

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: Math.max(0, parent.width - Tokens.padding.small * 2)
                        spacing: 1

                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: root.isLaptop ? ((root.rateW > 0.1 && !root.isFull) ? ((root.isCharging ? "+" : "-") + root.rateW.toFixed(1) + " W") : "--") : root.desktopSubValue
                            font: Tokens.font.label.builders.large.scale(root.s).weight(Font.Bold).build()
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.isLaptop ? Tr.tr("Rate") : (root.desktopGpuPower > 0 ? Tr.tr("Power") : (Gpu.temperature > 0 ? Tr.tr("Temp") : Tr.tr("GPU")))
                            font: Tokens.font.label.small
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(52 * root.s)
                    radius: Tokens.rounding.large
                    color: WidgetMetrics.innerSurface

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: Math.max(0, parent.width - Tokens.padding.small * 2)
                        spacing: 1

                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: root.isLaptop ? root.formatDuration(root.seconds) : root.profileLabel
                            font: Tokens.font.label.builders.large.scale(root.s).weight(Font.Bold).build()
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.isLaptop ? (root.isCharging ? Tr.tr("To full") : Tr.tr("Remaining")) : Tr.tr("Profile")
                            font: Tokens.font.label.small
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }
                }
            }
        }
    }
}

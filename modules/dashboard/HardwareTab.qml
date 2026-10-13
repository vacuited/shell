pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import "../../services"

Item {
    id: root

    implicitWidth: 974
    implicitHeight: 372

    property bool initialized: false
    Component.onCompleted: Qt.callLater(() => root.initialized = true)

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.medium

        // ==========================================
        // 1. ROW 1: TWO FANS ALONE (HERO TELEMETRY)
        // ==========================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 140
            spacing: Tokens.spacing.medium

            // 1A. CPU Fan Telemetry Card
            StyledRect {
                id: cpuFanCard
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                radius: Tokens.rounding.extraLarge
                color: Colours.tPalette.m3surfaceContainer

                readonly property color accent: Colours.palette.m3primary

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    spacing: Tokens.spacing.large

                    // Spinning Fan Disc
                    StyledRect {
                        Layout.preferredWidth: 60
                        Layout.preferredHeight: 60
                        radius: Tokens.rounding.full
                        color: Colours.tPalette.m3surfaceContainerHigh

                        MaterialIcon {
                            id: cpuFanIcon
                            anchors.centerIn: parent
                            text: "mode_fan"
                            color: cpuFanCard.accent
                            fontStyle: Tokens.font.icon.builders.large.scale(1.4).build()

                            NumberAnimation on rotation {
                                loops: Animation.Infinite
                                from: 0
                                to: 360
                                duration: {
                                    const rpm = Hardware.fan1Rpm;
                                    if (rpm <= 0) return 3000;
                                    return Math.max(250, 2400 - Math.min(rpm, 5000) * 0.4);
                                }
                                running: Hardware.fan1Rpm > 0
                            }
                        }
                    }

                    // Texts & Level Track
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.extraSmall

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            StyledText {
                                text: Tr.tr("CPU Fan Speed")
                                font: Tokens.font.body.small
                                color: Colours.palette.m3onSurfaceVariant
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            StyledRect {
                                radius: Tokens.rounding.full
                                color: Colours.tPalette.m3surfaceContainerHigh
                                implicitHeight: 22
                                implicitWidth: cpuTempBadge.implicitWidth + 14

                                StyledText {
                                    id: cpuTempBadge
                                    anchors.centerIn: parent
                                    text: Hardware.cpuTemp > 0 ? `${Hardware.cpuTemp}°C` : "--°C"
                                    font: Tokens.font.body.builders.small.size(11).weight(Font.DemiBold).build()
                                    color: Hardware.cpuTemp >= 80 ? Colours.palette.m3error : (Hardware.cpuTemp >= 70 ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant)
                                }
                            }
                        }

                        StyledText {
                            text: Hardware.fan1Rpm > 0 ? `${Hardware.fan1Rpm} RPM` : Tr.tr("0 RPM")
                            font: Tokens.font.title.builders.large.size(28).weight(Font.Bold).build()
                            color: Colours.palette.m3onSurface
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            implicitHeight: 6

                            StyledRect {
                                anchors.fill: parent
                                radius: Tokens.rounding.full
                                color: Colours.palette.m3surfaceContainerHighest
                            }

                            StyledRect {
                                height: parent.height
                                width: Math.min(1.0, Hardware.fan1Rpm / 5000) * parent.width
                                radius: Tokens.rounding.full
                                color: cpuFanCard.accent

                                Behavior on width {
                                    enabled: root.initialized
                                    Anim {}
                                }
                            }
                        }
                    }
                }
            }

            // 1B. GPU Fan Telemetry Card
            StyledRect {
                id: gpuFanCard
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                radius: Tokens.rounding.extraLarge
                color: Colours.tPalette.m3surfaceContainer

                readonly property color accent: Colours.palette.m3secondary

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    spacing: Tokens.spacing.large

                    // Spinning Fan Disc
                    StyledRect {
                        Layout.preferredWidth: 60
                        Layout.preferredHeight: 60
                        radius: Tokens.rounding.full
                        color: Colours.tPalette.m3surfaceContainerHigh

                        MaterialIcon {
                            id: gpuFanIcon
                            anchors.centerIn: parent
                            text: "mode_fan"
                            color: gpuFanCard.accent
                            fontStyle: Tokens.font.icon.builders.large.scale(1.4).build()

                            NumberAnimation on rotation {
                                loops: Animation.Infinite
                                from: 0
                                to: 360
                                duration: {
                                    const rpm = Hardware.fan2Rpm;
                                    if (rpm <= 0) return 3000;
                                    return Math.max(250, 2400 - Math.min(rpm, 5000) * 0.4);
                                }
                                running: Hardware.fan2Rpm > 0
                            }
                        }
                    }

                    // Texts & Level Track
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.extraSmall

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            StyledText {
                                text: Tr.tr("GPU Fan Speed")
                                font: Tokens.font.body.small
                                color: Colours.palette.m3onSurfaceVariant
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            StyledRect {
                                radius: Tokens.rounding.full
                                color: Colours.tPalette.m3surfaceContainerHigh
                                implicitHeight: 22
                                implicitWidth: gpuPowerBadge.implicitWidth + 14

                                StyledText {
                                    id: gpuPowerBadge
                                    anchors.centerIn: parent
                                    text: Hardware.gpuPower > 0 ? `${Hardware.gpuPower.toFixed(1)}W` : "-- W"
                                    font: Tokens.font.body.builders.small.size(11).weight(Font.DemiBold).build()
                                    color: Hardware.gpuPower > 10 ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                }
                            }

                            StyledRect {
                                radius: Tokens.rounding.full
                                color: Colours.tPalette.m3surfaceContainerHigh
                                implicitHeight: 22
                                implicitWidth: gpuTempBadge.implicitWidth + 14

                                StyledText {
                                    id: gpuTempBadge
                                    anchors.centerIn: parent
                                    text: Hardware.gpuTemp > 0 ? `${Hardware.gpuTemp}°C` : "--°C"
                                    font: Tokens.font.body.builders.small.size(11).weight(Font.DemiBold).build()
                                    color: Hardware.gpuTemp >= 80 ? Colours.palette.m3error : (Hardware.gpuTemp >= 70 ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant)
                                }
                            }
                        }

                        StyledText {
                            text: Hardware.fan2Rpm > 0 ? `${Hardware.fan2Rpm} RPM` : Tr.tr("0 RPM")
                            font: Tokens.font.title.builders.large.size(28).weight(Font.Bold).build()
                            color: Colours.palette.m3onSurface
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            implicitHeight: 6

                            StyledRect {
                                anchors.fill: parent
                                radius: Tokens.rounding.full
                                color: Colours.palette.m3surfaceContainerHighest
                            }

                            StyledRect {
                                height: parent.height
                                width: Math.min(1.0, Hardware.fan2Rpm / 5000) * parent.width
                                radius: Tokens.rounding.full
                                color: gpuFanCard.accent

                                Behavior on width {
                                    enabled: root.initialized
                                    Anim {}
                                }
                            }
                        }
                    }
                }
            }
        }

        // ==========================================
        // 2. ROW 2: 3 HARDWARE CONTROLS (FAN MODE | TURBO BOOST | REFRESH RATE)
        // ==========================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 104
            spacing: Tokens.spacing.medium

            // 2A. FAN SPEED MODE CHANGER
            StyledRect {
                id: fanControlCard
                Layout.fillWidth: true
                Layout.preferredHeight: 104
                radius: Tokens.rounding.extraLarge
                color: Colours.tPalette.m3surfaceContainer

                readonly property int activeIndex: Hardware.fanMode === "max" ? 1 : 0
                readonly property color activeColor: Hardware.fanMode === "max" ? Colours.palette.m3error : Colours.palette.m3primary

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    spacing: Tokens.spacing.extraSmall

                    // Header Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: "mode_fan"
                            color: fanControlCard.activeColor
                            fontStyle: Tokens.font.icon.small

                            Behavior on color {
                                enabled: root.initialized
                                ColorAnimation { duration: 200 }
                            }
                        }

                        StyledText {
                            text: Tr.tr("Fan Mode")
                            font: Tokens.font.title.builders.small.weight(Font.DemiBold).build()
                            color: Colours.palette.m3onSurface
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        StyledRect {
                            radius: Tokens.rounding.full
                            color: Colours.tPalette.m3surfaceContainerHigh
                            implicitHeight: 22
                            implicitWidth: fanBadgeLabel.implicitWidth + 14

                            StyledText {
                                id: fanBadgeLabel
                                anchors.centerIn: parent
                                text: Hardware.fanMode === "max" ? Tr.tr("Max RPM") : Tr.tr("EC Auto")
                                font: Tokens.font.body.builders.small.size(11).weight(Font.DemiBold).build()
                                color: fanControlCard.activeColor

                                Behavior on color {
                                    enabled: root.initialized
                                    ColorAnimation { duration: 200 }
                                }
                            }
                        }
                    }

                    // 2-Pill Track
                    StyledRect {
                        id: fanPillTrack
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: Tokens.rounding.full
                        color: Colours.tPalette.m3surfaceContainerHigh

                        // Sliding Indicator Pill
                        StyledRect {
                            id: fanIndicator
                            x: 3 + fanControlCard.activeIndex * ((fanPillTrack.width - 6) / 2)
                            y: 3
                            width: (fanPillTrack.width - 6) / 2
                            height: fanPillTrack.height - 6
                            radius: Tokens.rounding.full
                            color: fanControlCard.activeColor

                            Behavior on x {
                                enabled: root.initialized
                                Anim { type: Anim.EmphasizedLarge }
                            }
                            Behavior on color {
                                enabled: root.initialized
                                ColorAnimation { duration: 200 }
                            }
                        }

                        // 2 Segment Buttons
                        RowLayout {
                            anchors.fill: parent
                            spacing: 0

                            // Auto Segment
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                readonly property bool isSelected: fanControlCard.activeIndex === 0

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Hardware.setFanMode("auto")
                                }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: Tokens.spacing.small

                                    MaterialIcon {
                                        text: "sync"
                                        fontStyle: Tokens.font.icon.small
                                        color: parent.parent.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant

                                        Behavior on color {
                                            enabled: root.initialized
                                            ColorAnimation { duration: 150 }
                                        }
                                    }

                                    StyledText {
                                        text: Tr.tr("Auto")
                                        font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                                        color: parent.parent.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant

                                        Behavior on color {
                                            enabled: root.initialized
                                            ColorAnimation { duration: 150 }
                                        }
                                    }
                                }
                            }

                            // Max Segment
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                readonly property bool isSelected: fanControlCard.activeIndex === 1

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Hardware.setFanMode("max")
                                }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: Tokens.spacing.small

                                    MaterialIcon {
                                        text: "rocket_launch"
                                        fontStyle: Tokens.font.icon.small
                                        color: parent.parent.isSelected ? Colours.palette.m3onError : Colours.palette.m3onSurfaceVariant

                                        Behavior on color {
                                            enabled: root.initialized
                                            ColorAnimation { duration: 150 }
                                        }
                                    }

                                    StyledText {
                                        text: Tr.tr("Max Boost")
                                        font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                                        color: parent.parent.isSelected ? Colours.palette.m3onError : Colours.palette.m3onSurfaceVariant

                                        Behavior on color {
                                            enabled: root.initialized
                                            ColorAnimation { duration: 150 }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 2B. INTEL TURBO BOOST CONTROLLER
            StyledRect {
                id: turboControlCard
                Layout.fillWidth: true
                Layout.preferredHeight: 104
                radius: Tokens.rounding.extraLarge
                color: Colours.tPalette.m3surfaceContainer

                readonly property int activeIndex: Hardware.turbo ? 1 : 0
                readonly property color activeColor: Hardware.turbo ? Colours.palette.m3primary : Colours.palette.m3tertiary

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    spacing: Tokens.spacing.extraSmall

                    // Header Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: "bolt"
                            color: turboControlCard.activeColor
                            fontStyle: Tokens.font.icon.small

                            Behavior on color {
                                enabled: root.initialized
                                ColorAnimation { duration: 200 }
                            }
                        }

                        StyledText {
                            text: Tr.tr("Turbo Boost")
                            font: Tokens.font.title.builders.small.weight(Font.DemiBold).build()
                            color: Colours.palette.m3onSurface
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        StyledRect {
                            radius: Tokens.rounding.full
                            color: Colours.tPalette.m3surfaceContainerHigh
                            implicitHeight: 22
                            implicitWidth: turboBadgeLabel.implicitWidth + 14

                            StyledText {
                                id: turboBadgeLabel
                                anchors.centerIn: parent
                                text: Hardware.turbo ? Tr.tr("4.4 GHz") : Tr.tr("2.0 GHz")
                                font: Tokens.font.body.builders.small.size(11).weight(Font.DemiBold).build()
                                color: turboControlCard.activeColor

                                Behavior on color {
                                    enabled: root.initialized
                                    ColorAnimation { duration: 200 }
                                }
                            }
                        }
                    }

                    // 2-Pill Track
                    StyledRect {
                        id: turboPillTrack
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: Tokens.rounding.full
                        color: Colours.tPalette.m3surfaceContainerHigh

                        // Sliding Indicator Pill
                        StyledRect {
                            id: turboIndicator
                            x: 3 + turboControlCard.activeIndex * ((turboPillTrack.width - 6) / 2)
                            y: 3
                            width: (turboPillTrack.width - 6) / 2
                            height: turboPillTrack.height - 6
                            radius: Tokens.rounding.full
                            color: turboControlCard.activeColor

                            Behavior on x {
                                enabled: root.initialized
                                Anim { type: Anim.EmphasizedLarge }
                            }
                            Behavior on color {
                                enabled: root.initialized
                                ColorAnimation { duration: 200 }
                            }
                        }

                        // 2 Segment Buttons
                        RowLayout {
                            anchors.fill: parent
                            spacing: 0

                            // Base Segment (Index 0 - Left)
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                readonly property bool isSelected: turboControlCard.activeIndex === 0

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Hardware.setTurbo(false)
                                }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: Tokens.spacing.small

                                    MaterialIcon {
                                        text: "energy_savings_leaf"
                                        fontStyle: Tokens.font.icon.small
                                        color: parent.parent.isSelected ? Colours.palette.m3onTertiary : Colours.palette.m3onSurfaceVariant

                                        Behavior on color {
                                            enabled: root.initialized
                                            ColorAnimation { duration: 150 }
                                        }
                                    }

                                    StyledText {
                                        text: Tr.tr("Base")
                                        font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                                        color: parent.parent.isSelected ? Colours.palette.m3onTertiary : Colours.palette.m3onSurfaceVariant

                                        Behavior on color {
                                            enabled: root.initialized
                                            ColorAnimation { duration: 150 }
                                        }
                                    }
                                }
                            }

                            // Boost Segment (Index 1 - Right)
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                readonly property bool isSelected: turboControlCard.activeIndex === 1

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Hardware.setTurbo(true)
                                }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: Tokens.spacing.small

                                    MaterialIcon {
                                        text: "rocket_launch"
                                        fontStyle: Tokens.font.icon.small
                                        color: parent.parent.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant

                                        Behavior on color {
                                            enabled: root.initialized
                                            ColorAnimation { duration: 150 }
                                        }
                                    }

                                    StyledText {
                                        text: Tr.tr("Boost")
                                        font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                                        color: parent.parent.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant

                                        Behavior on color {
                                            enabled: root.initialized
                                            ColorAnimation { duration: 150 }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 2C. DISPLAY REFRESH RATE CHANGER
            StyledRect {
                id: refreshCard
                Layout.fillWidth: true
                Layout.preferredHeight: 104
                radius: Tokens.rounding.extraLarge
                color: Colours.tPalette.m3surfaceContainer

                readonly property int activeIndex: Hardware.refreshRate >= 120 ? 1 : 0
                readonly property color activeAccent: activeIndex === 1 ? Colours.palette.m3primary : Colours.palette.m3tertiary

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    spacing: Tokens.spacing.extraSmall

                    // Header Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: "desktop_windows"
                            color: refreshCard.activeAccent
                            fontStyle: Tokens.font.icon.small

                            Behavior on color {
                                enabled: root.initialized
                                ColorAnimation { duration: 200 }
                            }
                        }

                        StyledText {
                            text: Tr.tr("Refresh Rate")
                            font: Tokens.font.title.builders.small.weight(Font.DemiBold).build()
                            color: Colours.palette.m3onSurface
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        StyledRect {
                            radius: Tokens.rounding.full
                            color: Colours.tPalette.m3surfaceContainerHigh
                            implicitHeight: 22
                            implicitWidth: displayBadge.implicitWidth + 14

                            StyledText {
                                id: displayBadge
                                anchors.centerIn: parent
                                text: Tr.tr("eDP-1")
                                font: Tokens.font.body.builders.small.size(11).weight(Font.DemiBold).build()
                                color: Colours.palette.m3onSurfaceVariant
                            }
                        }
                    }

                    // 2-Pill Track
                    StyledRect {
                        id: refreshPillTrack
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: Tokens.rounding.full
                        color: Colours.tPalette.m3surfaceContainerHigh

                        // Sliding Indicator Pill
                        StyledRect {
                            id: refreshIndicator
                            x: 3 + refreshCard.activeIndex * ((refreshPillTrack.width - 6) / 2)
                            y: 3
                            width: (refreshPillTrack.width - 6) / 2
                            height: refreshPillTrack.height - 6
                            radius: Tokens.rounding.full
                            color: refreshCard.activeAccent

                            Behavior on x {
                                enabled: root.initialized
                                Anim { type: Anim.EmphasizedLarge }
                            }
                            Behavior on color {
                                enabled: root.initialized
                                ColorAnimation { duration: 200 }
                            }
                        }

                        // 2 Segment Buttons
                        RowLayout {
                            anchors.fill: parent
                            spacing: 0

                            // 60 Hz Segment
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                readonly property bool isSelected: refreshCard.activeIndex === 0

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Hardware.setRefreshRate(60)
                                }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: Tokens.spacing.small

                                    MaterialIcon {
                                        text: "battery_saver"
                                        fontStyle: Tokens.font.icon.small
                                        color: parent.parent.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant

                                        Behavior on color {
                                            enabled: root.initialized
                                            ColorAnimation { duration: 150 }
                                        }
                                    }

                                    StyledText {
                                        text: "60 Hz"
                                        font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                                        color: parent.parent.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant

                                        Behavior on color {
                                            enabled: root.initialized
                                            ColorAnimation { duration: 150 }
                                        }
                                    }
                                }
                            }

                            // 144 Hz Segment
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                readonly property bool isSelected: refreshCard.activeIndex === 1

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Hardware.setRefreshRate(144)
                                }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: Tokens.spacing.small

                                    MaterialIcon {
                                        text: "bolt"
                                        fontStyle: Tokens.font.icon.small
                                        color: parent.parent.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant

                                        Behavior on color {
                                            enabled: root.initialized
                                            ColorAnimation { duration: 150 }
                                        }
                                    }

                                    StyledText {
                                        text: "144 Hz"
                                        font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                                        color: parent.parent.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant

                                        Behavior on color {
                                            enabled: root.initialized
                                            ColorAnimation { duration: 150 }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ==========================================
        // 3. ROW 3: POWER & THERMAL PROFILE (FULL WIDTH 4-PILL)
        // ==========================================
        StyledRect {
            id: profileCard
            Layout.fillWidth: true
            Layout.preferredHeight: 104
            radius: Tokens.rounding.extraLarge
            color: Colours.tPalette.m3surfaceContainer

            readonly property int activeIndex: {
                const p = Hardware.profile;
                if (p === "quiet") return 0;
                if (p === "cool") return 1;
                if (p === "balanced") return 2;
                if (p === "performance") return 3;
                return 2;
            }

            readonly property color activeAccent: {
                switch (activeIndex) {
                    case 0: return Colours.palette.m3tertiary;   // Quiet: teal
                    case 1: return Colours.palette.m3secondary;  // Cool: sky
                    case 2: return Colours.palette.m3primary;    // Balanced: violet
                    case 3: return Colours.palette.m3error;      // Performance: coral/red
                    default: return Colours.palette.m3primary;
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.extraSmall

                // Header Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "speed"
                        color: profileCard.activeAccent
                        fontStyle: Tokens.font.icon.small

                        Behavior on color {
                            enabled: root.initialized
                            ColorAnimation { duration: 200 }
                        }
                    }

                    StyledText {
                        text: Tr.tr("Power & Thermal Profile")
                        font: Tokens.font.title.builders.small.weight(Font.DemiBold).build()
                        color: Colours.palette.m3onSurface
                    }
                }

                // Generous Full-Width 4-Pill Track
                StyledRect {
                    id: profilePillTrack
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: Tokens.rounding.full
                    color: Colours.tPalette.m3surfaceContainerHigh

                    // Sliding Indicator Pill
                    StyledRect {
                        id: profileIndicator
                        x: 3 + profileCard.activeIndex * ((profilePillTrack.width - 6) / 4)
                        y: 3
                        width: (profilePillTrack.width - 6) / 4
                        height: profilePillTrack.height - 6
                        radius: Tokens.rounding.full
                        color: profileCard.activeAccent

                        Behavior on x {
                            enabled: root.initialized
                            Anim { type: Anim.EmphasizedLarge }
                        }
                        Behavior on color {
                            enabled: root.initialized
                            ColorAnimation { duration: 200 }
                        }
                    }

                    // 4 Segment Buttons
                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        // 1. Quiet
                        ProfilePillButton {
                            icon: "bedtime"
                            label: Tr.tr("Quiet")
                            isSelected: profileCard.activeIndex === 0
                            isErrorAccent: false
                            onClicked: Hardware.setProfile("quiet")
                        }

                        // 2. Cool
                        ProfilePillButton {
                            icon: "ac_unit"
                            label: Tr.tr("Cool")
                            isSelected: profileCard.activeIndex === 1
                            isErrorAccent: false
                            onClicked: Hardware.setProfile("cool")
                        }

                        // 3. Balanced
                        ProfilePillButton {
                            icon: "balance"
                            label: Tr.tr("Balanced")
                            isSelected: profileCard.activeIndex === 2
                            isErrorAccent: false
                            onClicked: Hardware.setProfile("balanced")
                        }

                        // 4. Performance
                        ProfilePillButton {
                            icon: "bolt"
                            label: Tr.tr("Performance")
                            isSelected: profileCard.activeIndex === 3
                            isErrorAccent: true
                            onClicked: Hardware.setProfile("performance")
                        }
                    }
                }
            }
        }
    }

    // Reusable Minimal Pill Button Component
    component ProfilePillButton: Item {
        id: pillBtnRoot

        required property string icon
        required property string label
        required property bool isSelected
        required property bool isErrorAccent
        signal clicked()

        Layout.fillWidth: true
        Layout.fillHeight: true

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: pillBtnRoot.clicked()
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: pillBtnRoot.icon
                fontStyle: Tokens.font.icon.small
                color: pillBtnRoot.isSelected
                    ? (pillBtnRoot.isErrorAccent ? Colours.palette.m3onError : Colours.palette.m3onPrimary)
                    : Colours.palette.m3onSurfaceVariant

                Behavior on color {
                    enabled: root.initialized
                    ColorAnimation { duration: 150 }
                }
            }

            StyledText {
                text: pillBtnRoot.label
                font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                color: pillBtnRoot.isSelected
                    ? (pillBtnRoot.isErrorAccent ? Colours.palette.m3onError : Colours.palette.m3onPrimary)
                    : Colours.palette.m3onSurfaceVariant

                Behavior on color {
                    enabled: root.initialized
                    ColorAnimation { duration: 150 }
                }
            }
        }
    }
}

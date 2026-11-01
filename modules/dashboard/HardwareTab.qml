pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import M3Shapes
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
    implicitHeight: 384

    property bool initialized: false
    Component.onCompleted: Qt.callLater(() => root.initialized = true)

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.medium

        // ==========================================
        // 1. ROW 1: TWO FANS ALONE (BIG CIRCULARPROGRESS + BIG SPINNING FAN + BOLD RPM)
        // ==========================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 152
            spacing: Tokens.spacing.medium

            // 1A. CPU Fan Telemetry Card
            FanHeroCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                label: Tr.tr("CPU Fan")
                rpm: Hardware.fan1Rpm
                powerWatts: -1
                accent: Colours.palette.m3primary
            }

            // 1B. GPU Fan Telemetry Card
            FanHeroCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                label: Tr.tr("GPU Fan")
                rpm: Hardware.fan2Rpm
                powerWatts: Hardware.gpuPower
                accent: Colours.palette.m3secondary
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
            DualPillCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                title: Tr.tr("Fan Mode")
                headerIcon: "mode_fan"
                headerShape: MaterialShape.Sunny
                badgeText: Hardware.fanMode === "max" ? Tr.tr("Max RPM") : Tr.tr("EC Auto")
                activeIndex: Hardware.fanMode === "max" ? 1 : 0
                activeColor: Colours.palette.m3primary
                activeOnColor: Colours.palette.m3onPrimary
                opt0Icon: "sync"
                opt0Label: Tr.tr("Auto")
                opt0Value: "auto"
                opt1Icon: "rocket_launch"
                opt1Label: Tr.tr("Max Boost")
                opt1Value: "max"
                onSelected: val => Hardware.setFanMode(val)
            }

            // 2B. INTEL TURBO BOOST CONTROLLER
            DualPillCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                title: Tr.tr("Turbo Boost")
                headerIcon: "bolt"
                headerShape: MaterialShape.Gem
                badgeText: Hardware.turbo ? Tr.tr("4.4 GHz") : Tr.tr("2.0 GHz")
                activeIndex: Hardware.turbo ? 1 : 0
                activeColor: Hardware.turbo ? Colours.palette.m3secondary : Colours.palette.m3tertiary
                activeOnColor: Hardware.turbo ? Colours.palette.m3onSecondary : Colours.palette.m3onTertiary
                opt0Icon: "energy_savings_leaf"
                opt0Label: Tr.tr("Base")
                opt0Value: false
                opt1Icon: "rocket_launch"
                opt1Label: Tr.tr("Boost")
                opt1Value: true
                onSelected: val => Hardware.setTurbo(val)
            }

            // 2C. DISPLAY REFRESH RATE CONTROLLER
            DualPillCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                title: Tr.tr("Refresh Rate")
                headerIcon: "desktop_windows"
                headerShape: MaterialShape.Cookie6Sided
                badgeText: "eDP-1"
                activeIndex: Hardware.refreshRate >= 120 ? 1 : 0
                activeColor: Colours.palette.m3tertiary
                activeOnColor: Colours.palette.m3onTertiary
                opt0Icon: "battery_saver"
                opt0Label: "60 Hz"
                opt0Value: 60
                opt1Icon: "bolt"
                opt1Label: "144 Hz"
                opt1Value: 144
                onSelected: val => Hardware.setRefreshRate(val)
            }
        }

        // ==========================================
        // 3. ROW 3: POWER & THERMAL PROFILE (FULL WIDTH 4-PILL SELECTOR)
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
                    case 0: return Colours.palette.m3tertiary;
                    case 1: return Colours.palette.m3secondary;
                    default: return Colours.palette.m3primary;
                }
            }

            readonly property color activeOnAccent: {
                switch (activeIndex) {
                    case 0: return Colours.palette.m3onTertiary;
                    case 1: return Colours.palette.m3onSecondary;
                    default: return Colours.palette.m3onPrimary;
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.extraSmall

                // Header Row with Morphing MaterialShape
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    MaterialShape {
                        implicitSize: 26
                        shape: {
                            switch (profileCard.activeIndex) {
                                case 0: return MaterialShape.Cookie4Sided;
                                case 1: return MaterialShape.Sunny;
                                case 2: return MaterialShape.Cookie6Sided;
                                default: return MaterialShape.SoftBurst;
                            }
                        }
                        color: Colours.palette.m3secondaryContainer

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "speed"
                            color: profileCard.activeAccent
                            fontStyle: Tokens.font.icon.small
                            fill: profileCard.activeIndex > 0 ? 1 : 0

                            Behavior on fill {
                                enabled: root.initialized
                                Anim { type: Anim.DefaultEffects }
                            }
                            Behavior on color {
                                enabled: root.initialized
                                CAnim {}
                            }
                        }
                    }

                    StyledText {
                        text: Tr.tr("Power & Thermal Profile")
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
                        implicitWidth: profileBadgeLabel.implicitWidth + 14

                        StyledText {
                            id: profileBadgeLabel

                            anchors.centerIn: parent
                            text: {
                                switch (profileCard.activeIndex) {
                                    case 0: return Tr.tr("Low Power");
                                    case 1: return Tr.tr("Cool Mode");
                                    case 2: return Tr.tr("Default");
                                    default: return Tr.tr("Max Power");
                                }
                            }
                            font: Tokens.font.body.builders.small.size(11).weight(Font.DemiBold).build()
                            color: profileCard.activeAccent

                            Behavior on color {
                                enabled: root.initialized
                                CAnim {}
                            }
                        }
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
                            Anim { type: Anim.DefaultSpatial }
                        }
                        Behavior on color {
                            enabled: root.initialized
                            CAnim {}
                        }
                    }

                    // 4 Segment Buttons
                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        ProfilePillButton {
                            icon: "bedtime"
                            label: Tr.tr("Quiet")
                            isSelected: profileCard.activeIndex === 0
                            activeOnColor: profileCard.activeOnAccent
                            onClicked: Hardware.setProfile("quiet")
                        }

                        ProfilePillButton {
                            icon: "ac_unit"
                            label: Tr.tr("Cool")
                            isSelected: profileCard.activeIndex === 1
                            activeOnColor: profileCard.activeOnAccent
                            onClicked: Hardware.setProfile("cool")
                        }

                        ProfilePillButton {
                            icon: "balance"
                            label: Tr.tr("Balanced")
                            isSelected: profileCard.activeIndex === 2
                            activeOnColor: profileCard.activeOnAccent
                            onClicked: Hardware.setProfile("balanced")
                        }

                        ProfilePillButton {
                            icon: "bolt"
                            label: Tr.tr("Performance")
                            isSelected: profileCard.activeIndex === 3
                            activeOnColor: profileCard.activeOnAccent
                            onClicked: Hardware.setProfile("performance")
                        }
                    }
                }
            }
        }
    }

    // =====================================================
    // COMPONENT 1: Fan Hero Telemetry Card (Big CircularProgress + Big Spinning Fan + Bold RPM)
    // =====================================================
    component FanHeroCard: StyledRect {
        id: fanCard

        required property string label
        required property int rpm
        required property real powerWatts
        required property color accent

        readonly property real load: Math.max(0, Math.min(1, rpm / 5000))

        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.extraLarge

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.extraLarge
            anchors.rightMargin: Tokens.padding.extraLarge
            anchors.topMargin: Tokens.padding.large
            anchors.bottomMargin: Tokens.padding.large
            spacing: Tokens.spacing.extraLarge

            // Left: Big 108px CircularProgress Ring + Large 46px Live-Spinning Fan
            CircularProgress {
                id: fanProg

                Layout.alignment: Qt.AlignVCenter
                fgColour: fanCard.accent
                spacing: Tokens.spacing.extraSmall
                strokeWidth: 7
                implicitSize: 108
                value: fanCard.load

                Behavior on clampedVal {
                    enabled: root.initialized
                    Anim {}
                }

                MaterialIcon {
                    id: fanIcon

                    anchors.centerIn: parent
                    text: "mode_fan"
                    color: fanCard.accent
                    fontStyle: Tokens.font.icon.size(46).build()

                    FrameAnimation {
                        running: fanCard.rpm > 0 && fanCard.visible
                        onTriggered: {
                            const degPerSec = Math.max(90, Math.min(1440, (fanCard.rpm / 60) * 360 * 0.04));
                            fanIcon.rotation = (fanIcon.rotation + degPerSec * frameTime) % 360;
                        }
                    }
                }
            }

            // Right: Title (+ GPU Wattage Pill) + Bold RPM Readout + Full-Width StyledProgressBar
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: Tokens.spacing.extraSmall

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: fanCard.label
                        font: Tokens.font.title.medium
                        color: fanCard.accent
                    }

                    StyledRect {
                        visible: fanCard.powerWatts >= 0
                        Layout.alignment: Qt.AlignVCenter
                        implicitHeight: 22
                        implicitWidth: wattLabel.implicitWidth + 14
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3secondaryContainer

                        StyledText {
                            id: wattLabel

                            anchors.centerIn: parent
                            text: fanCard.powerWatts > 0 ? `${fanCard.powerWatts.toFixed(1)}W` : "0.0W"
                            font: Tokens.font.body.builders.small.size(11).weight(Font.DemiBold).build()
                            color: Colours.palette.m3onSecondaryContainer
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: fanCard.rpm > 0 ? `${fanCard.rpm} RPM` : Tr.tr("0 RPM")
                    font: Tokens.font.title.builders.large.size(28).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledProgressBar {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    value: fanCard.load
                    implicitHeight: Tokens.padding.small
                    fgColour: fanCard.accent
                }
            }
        }
    }

    // =====================================================
    // COMPONENT 2: 2-Segment Hardware Control Card (With M3 MaterialShape & Smooth Spatial Slide)
    // =====================================================
    component DualPillCard: StyledRect {
        id: cardRoot

        required property string title
        required property string headerIcon
        required property int headerShape
        required property string badgeText
        required property int activeIndex
        required property color activeColor
        required property color activeOnColor
        required property string opt0Icon
        required property string opt0Label
        required property var opt0Value
        required property string opt1Icon
        required property string opt1Label
        required property var opt1Value

        signal selected(var value)

        radius: Tokens.rounding.extraLarge
        color: Colours.tPalette.m3surfaceContainer

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.extraSmall

            // Header Row with Morphing MaterialShape
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                MaterialShape {
                    implicitSize: 26
                    shape: cardRoot.activeIndex > 0 ? cardRoot.headerShape : MaterialShape.Cookie4Sided
                    color: Colours.palette.m3secondaryContainer

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: cardRoot.headerIcon
                        color: cardRoot.activeColor
                        fontStyle: Tokens.font.icon.small
                        fill: cardRoot.activeIndex > 0 ? 1 : 0

                        Behavior on fill {
                            enabled: root.initialized
                            Anim { type: Anim.DefaultEffects }
                        }
                        Behavior on color {
                            enabled: root.initialized
                            CAnim {}
                        }
                    }
                }

                StyledText {
                    text: cardRoot.title
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
                    implicitWidth: badgeLabel.implicitWidth + 14

                    StyledText {
                        id: badgeLabel

                        anchors.centerIn: parent
                        text: cardRoot.badgeText
                        font: Tokens.font.body.builders.small.size(11).weight(Font.DemiBold).build()
                        color: cardRoot.activeColor

                        Behavior on color {
                            enabled: root.initialized
                            CAnim {}
                        }
                    }
                }
            }

            // 2-Pill Track
            StyledRect {
                id: pillTrack

                Layout.fillWidth: true
                implicitHeight: 38
                radius: Tokens.rounding.full
                color: Colours.tPalette.m3surfaceContainerHigh

                // Sliding Indicator Pill
                StyledRect {
                    x: 3 + cardRoot.activeIndex * ((pillTrack.width - 6) / 2)
                    y: 3
                    width: (pillTrack.width - 6) / 2
                    height: pillTrack.height - 6
                    radius: Tokens.rounding.full
                    color: cardRoot.activeColor

                    Behavior on x {
                        enabled: root.initialized
                        Anim { type: Anim.DefaultSpatial }
                    }
                    Behavior on color {
                        enabled: root.initialized
                        CAnim {}
                    }
                }

                // 2 Segment Buttons
                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    ProfilePillButton {
                        icon: cardRoot.opt0Icon
                        label: cardRoot.opt0Label
                        isSelected: cardRoot.activeIndex === 0
                        activeOnColor: cardRoot.activeOnColor
                        onClicked: cardRoot.selected(cardRoot.opt0Value)
                    }

                    ProfilePillButton {
                        icon: cardRoot.opt1Icon
                        label: cardRoot.opt1Label
                        isSelected: cardRoot.activeIndex === 1
                        activeOnColor: cardRoot.activeOnColor
                        onClicked: cardRoot.selected(cardRoot.opt1Value)
                    }
                }
            }
        }
    }

    // =====================================================
    // COMPONENT 3: Pill Segment Button (StateLayer + Icon Fill Morph + CAnim)
    // =====================================================
    component ProfilePillButton: Item {
        id: pillBtnRoot

        required property string icon
        required property string label
        required property bool isSelected
        required property color activeOnColor
        signal clicked()

        Layout.fillWidth: true
        Layout.fillHeight: true

        StateLayer {
            radius: Tokens.rounding.full
            color: pillBtnRoot.isSelected ? pillBtnRoot.activeOnColor : Colours.palette.m3onSurface
            onClicked: pillBtnRoot.clicked()
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: pillBtnRoot.icon
                fontStyle: Tokens.font.icon.small
                fill: pillBtnRoot.isSelected ? 1 : 0
                color: pillBtnRoot.isSelected ? pillBtnRoot.activeOnColor : Colours.palette.m3onSurfaceVariant

                Behavior on fill {
                    enabled: root.initialized
                    Anim { type: Anim.DefaultEffects }
                }
                Behavior on color {
                    enabled: root.initialized
                    CAnim {}
                }
            }

            StyledText {
                text: pillBtnRoot.label
                font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                color: pillBtnRoot.isSelected ? pillBtnRoot.activeOnColor : Colours.palette.m3onSurfaceVariant

                Behavior on color {
                    enabled: root.initialized
                    CAnim {}
                }
            }
        }
    }
}

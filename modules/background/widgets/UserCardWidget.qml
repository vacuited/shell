pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import M3Shapes
import Caelestia
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.utils
import qs.modules.nexus
import "../components"

Item {
    id: root

    required property var wallpaper
    property bool weActive: false
    property bool locked: true
    property string sizeMode: "1x2"
    property string surfaceStyle: ""
    property bool blurEnabled: Config.background.desktopWidgets.blur
    property real plateOpacity: Config.background.desktopWidgets.opacity
    property var widgetOptions: ({})

    readonly property real s: WidgetMetrics.scale
    readonly property bool showActions: (widgetOptions?.showActions ?? true) !== false
    readonly property string avatarPath: {
        const home = Paths.home || Quickshell.env("HOME") || "";
        if (!home)
            return "";
        const face = home + "/.face";
        if (CUtils.fileExists(face))
            return face;
        const faceIcon = home + "/.face.icon";
        if (CUtils.fileExists(faceIcon))
            return faceIcon;
        return "";
    }

    readonly property string greetingText: {
        const h = Time.date.getHours();
        if (h < 5)
            return Tr.tr("Good night");
        if (h < 12)
            return Tr.tr("Good morning");
        if (h < 17)
            return Tr.tr("Good afternoon");
        return Tr.tr("Good evening");
    }

    function lockScreen(): void {
        Quickshell.execDetached(["caelestia", "shell", "lock", "lock"]);
    }

    function openSettings(): void {
        WindowFactory.create();
    }

    function openSession(): void {
        const st = Visibilities.getForActive();
        if (st)
            st.session = !st.session;
    }

    implicitWidth: WidgetMetrics.widthFor(sizeMode, s)
    implicitHeight: WidgetMetrics.heightFor(sizeMode, "usercard", s)

    WidgetCardShell {
        id: shell

        anchors.fill: parent
        widgetType: "usercard"
        sizeMode: root.sizeMode
        outerShape: root.widgetOptions?.outerShape ?? ""
        wallpaper: root.wallpaper
        weActive: root.weActive
        surfaceStyle: root.surfaceStyle
        blurEnabled: root.blurEnabled
        plateOpacity: root.plateOpacity
        scaleFactor: root.s

        // 1x1 Expressive Shaped User Medallion
        Item {
            anchors.fill: parent
            anchors.topMargin: shell.topPadding
            anchors.bottomMargin: shell.bottomPadding
            anchors.leftMargin: shell.sidePadding
            anchors.rightMargin: shell.sidePadding
            visible: root.sizeMode === "1x1"

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width
                spacing: Math.round(4 * root.s)

                AvatarMedallion {
                    Layout.alignment: Qt.AlignHCenter
                    avatarSize: Math.round((shell.isShaped ? 50 : 56) * root.s)
                    showBadges: true
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: SysInfo.user || Quickshell.env("USER") || "user"
                    font: Tokens.font.title.builders.small.scale(root.s).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: SysInfo.uptimeShort || SysInfo.hostname
                    font: Tokens.font.label.builders.small.scale(Math.max(0.82, root.s * 0.88)).build()
                    color: Colours.palette.m3primary
                    elide: Text.ElideRight
                }
            }

            StateLayer {
                enabled: root.locked
                radius: shell.isShaped ? width / 2 : shell.radius
                onClicked: root.openSettings()
            }
        }

        // 1x2 Wide User Card
        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "1x2"
            spacing: Math.round(Tokens.spacing.large * root.s)

            AvatarMedallion {
                Layout.alignment: Qt.AlignVCenter
                avatarSize: Math.round(80 * root.s)
                showBadges: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: Math.round(3 * root.s)

                StyledText {
                    Layout.fillWidth: true
                    text: root.greetingText
                    font: Tokens.font.label.builders.small.scale(root.s).weight(Font.DemiBold).build()
                    color: Colours.palette.m3primary
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: SysInfo.user || Quickshell.env("USER") || "user"
                    font: Tokens.font.headline.builders.small.scale(root.s).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: (SysInfo.hostname || "linux") + " · " + (SysInfo.uptimeShort || "--")
                    font: Tokens.font.label.small
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }

                ButtonRow {
                    visible: root.showActions
                    Layout.fillWidth: true
                    Layout.minimumHeight: Math.round(34 * root.s)
                    Layout.topMargin: Math.round(4 * root.s)
                    spacing: Tokens.spacing.extraSmall

                    IconButton {
                        fillWidth: true
                        icon: "lock"
                        type: IconButton.Tonal
                        isRound: true
                        onClicked: root.lockScreen()
                    }

                    IconButton {
                        fillWidth: true
                        icon: "tune"
                        type: IconButton.Tonal
                        isRound: true
                        onClicked: root.openSettings()
                    }

                    IconButton {
                        fillWidth: true
                        icon: "power_settings_new"
                        type: IconButton.Tonal
                        isRound: true
                        onClicked: root.openSession()
                    }
                }
            }
        }

        // 2x1 Tall Portrait Identity Card
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "2x1"
            spacing: Math.round(Tokens.spacing.small * root.s)

            Item {
                Layout.fillHeight: true
            }

            AvatarMedallion {
                Layout.alignment: Qt.AlignHCenter
                avatarSize: Math.round(86 * root.s)
                showBadges: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.greetingText
                    font: Tokens.font.label.builders.small.scale(root.s).weight(Font.DemiBold).build()
                    color: Colours.palette.m3primary
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: SysInfo.user || Quickshell.env("USER") || "user"
                    font: Tokens.font.headline.builders.small.scale(root.s).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: SysInfo.uptimeShort || SysInfo.hostname
                    font: Tokens.font.label.small
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            // Dash thought-bubble WM badge
            StyledRect {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(28 * root.s)
                radius: Math.round(14 * root.s)
                color: Qt.alpha(Colours.palette.m3secondaryContainer, 0.78)

                StyledText {
                    anchors.centerIn: parent
                    width: parent.width - Tokens.padding.medium * 2
                    horizontalAlignment: Text.AlignHCenter
                    text: SysInfo.wm || "Hyprland"
                    font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSecondaryContainer
                    elide: Text.ElideRight
                }
            }

            Item {
                Layout.fillHeight: true
            }

            ButtonRow {
                visible: root.showActions
                Layout.fillWidth: true
                Layout.minimumHeight: Math.round(34 * root.s)
                spacing: Tokens.spacing.extraSmall

                IconButton {
                    fillWidth: true
                    icon: "lock"
                    type: IconButton.Tonal
                    isRound: true
                    onClicked: root.lockScreen()
                }

                IconButton {
                    fillWidth: true
                    icon: "tune"
                    type: IconButton.Tonal
                    isRound: true
                    onClicked: root.openSettings()
                }

                IconButton {
                    fillWidth: true
                    icon: "power_settings_new"
                    type: IconButton.Tonal
                    isRound: true
                    onClicked: root.openSession()
                }
            }
        }

        // 2x2 Native Dash User Clone & 2x3 Split Profile Hub
        RowLayout {
            anchors.fill: parent
            anchors.topMargin: shell.topPadding
            anchors.bottomMargin: shell.bottomPadding
            anchors.leftMargin: shell.sidePadding
            anchors.rightMargin: shell.sidePadding
            visible: root.sizeMode === "2x2" || root.sizeMode === "2x3"
            spacing: Math.round(Tokens.spacing.large * root.s)

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Math.round((shell.isShaped ? Tokens.spacing.small : Tokens.spacing.medium) * root.s)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(Tokens.spacing.medium * root.s)

                    AvatarMedallion {
                        Layout.alignment: Qt.AlignVCenter
                        avatarSize: Math.round((shell.isShaped ? 68 : 82) * root.s)
                        showBadges: true
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: root.greetingText
                            font: Tokens.font.label.builders.medium.scale(root.s).weight(Font.DemiBold).build()
                            color: Colours.palette.m3primary
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: SysInfo.user || Quickshell.env("USER") || "user"
                            font: Tokens.font.headline.builders.medium.scale(root.s * (shell.isShaped ? 0.9 : 1.0)).weight(Font.Bold).build()
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: SysInfo.osPrettyName || SysInfo.osName || "Linux"
                            font: Tokens.font.label.small
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }
                }

                // Thought-bubble tail + WM / Uptime badge (dash/User.qml signature colors)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(4 * root.s)

                    RowLayout {
                        spacing: Math.round(6 * root.s)
                        Layout.leftMargin: Math.round(24 * root.s)

                        Rectangle {
                            Layout.preferredWidth: Math.round(8 * root.s)
                            Layout.preferredHeight: Math.round(8 * root.s)
                            radius: Math.round(4 * root.s)
                            color: Qt.alpha(Colours.palette.m3secondaryContainer, 0.9)
                        }

                        Rectangle {
                            Layout.preferredWidth: Math.round(12 * root.s)
                            Layout.preferredHeight: Math.round(12 * root.s)
                            radius: Math.round(6 * root.s)
                            color: Qt.alpha(Colours.palette.m3secondaryContainer, 0.9)
                        }
                    }

                    StyledRect {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(50 * root.s)
                        radius: Tokens.rounding.extraLarge
                        color: Qt.alpha(Colours.palette.m3secondaryContainer, 0.88)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Math.round(Tokens.padding.small * root.s)
                            anchors.leftMargin: Math.round(Tokens.padding.medium * root.s)
                            anchors.rightMargin: Math.round(Tokens.padding.medium * root.s)
                            spacing: Math.round(Tokens.spacing.small * root.s)

                            MaterialIcon {
                                text: "select_window"
                                fontStyle: Tokens.font.icon.medium
                                color: Colours.palette.m3onSecondaryContainer
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    text: (SysInfo.hostname || "linux") + " · " + (SysInfo.wm || "Hyprland")
                                    font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
                                    color: Colours.palette.m3onSecondaryContainer
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: Tr.tr("up %1").arg(SysInfo.uptimeShort || "--")
                                    font: Tokens.font.body.small
                                    color: Qt.alpha(Colours.palette.m3onSecondaryContainer, 0.82)
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                ButtonRow {
                    visible: root.showActions
                    Layout.fillWidth: true
                    Layout.minimumHeight: Math.round(34 * root.s)
                    Layout.preferredHeight: Math.round(36 * root.s)
                    spacing: Tokens.spacing.extraSmall

                    IconTextButton {
                        fillWidth: true
                        text: Tr.tr("Lock")
                        icon: "lock"
                        type: IconTextButton.Tonal
                        isRound: true
                        verticalPadding: Math.round(6 * root.s)
                        horizontalPadding: Math.round(10 * root.s)
                        onClicked: root.lockScreen()
                    }

                    IconButton {
                        fillWidth: false
                        icon: "tune"
                        type: IconButton.Tonal
                        isRound: true
                        onClicked: root.openSettings()
                    }

                    IconTextButton {
                        fillWidth: true
                        text: Tr.tr("Power")
                        icon: "power_settings_new"
                        type: IconTextButton.Tonal
                        isRound: true
                        verticalPadding: Math.round(6 * root.s)
                        horizontalPadding: Math.round(10 * root.s)
                        onClicked: root.openSession()
                    }
                }
            }

            // 2x3 Right Info & Session Strip
            StyledRect {
                visible: root.sizeMode === "2x3"
                Layout.preferredWidth: Math.round(156 * root.s)
                Layout.fillHeight: true
                radius: Tokens.rounding.extraLarge
                color: WidgetMetrics.innerSurface
                border.width: 1
                border.color: WidgetMetrics.innerBorder

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Math.round(Tokens.padding.medium * root.s)
                    spacing: Math.round(Tokens.spacing.small * root.s)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        MaterialIcon {
                            text: "schedule"
                            fontStyle: Tokens.font.icon.small
                            color: Colours.palette.m3tertiary
                        }

                        StyledText {
                            text: Tr.tr("Uptime")
                            font: Tokens.font.label.small
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: SysInfo.uptimeShort || "--"
                        font: Tokens.font.title.builders.medium.scale(root.s).weight(Font.Bold).build()
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Qt.alpha(Colours.palette.m3outlineVariant, 0.45)
                    }

                    StyledText {
                        text: Tr.tr("Compositor")
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: SysInfo.wm || "Hyprland"
                        font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
                        color: Colours.palette.m3primary
                        elide: Text.ElideRight
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Qt.formatTime(Time.date, "hh:mm ap")
                        font: Tokens.font.clock.size(Math.round(20 * root.s)).weight(Font.Bold).build()
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    component AvatarMedallion: Item {
        id: av

        property int avatarSize: 72
        property bool showBadges: true

        implicitWidth: avatarSize
        implicitHeight: avatarSize

        MaterialShape {
            id: avatarFrame

            anchors.centerIn: parent
            width: av.avatarSize
            height: av.avatarSize
            implicitSize: av.avatarSize
            shape: GlobalConfig.dashboard.profilePicShape
            color: Colours.palette.m3primaryContainer
        }

        MaterialShape {
            id: avatarMask

            anchors.centerIn: parent
            width: Math.max(8, av.avatarSize - 4)
            height: Math.max(8, av.avatarSize - 4)
            implicitSize: width
            visible: false
            layer.enabled: width > 0 && height > 0 && root.avatarPath !== ""
            shape: GlobalConfig.dashboard.profilePicShape
            color: "#ffffff"
        }

        Image {
            id: avatarImg

            anchors.centerIn: parent
            width: Math.max(8, av.avatarSize - 4)
            height: Math.max(8, av.avatarSize - 4)
            visible: root.avatarPath !== "" && status === Image.Ready
            source: root.avatarPath ? ("file://" + root.avatarPath) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            layer.enabled: visible && width > 0 && height > 0
            layer.smooth: true
            layer.effect: Mask {
                maskSource: avatarMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            visible: !avatarImg.visible
            text: "person"
            fontStyle: Tokens.font.icon.builders.extraLarge.scale(av.avatarSize / 72).build()
            color: Colours.palette.m3onPrimaryContainer
        }

        // Overlapping OS/Caelestia MaterialShape.Gem badge (from dash/User.qml)
        MaterialShape {
            visible: av.showBadges
            width: Math.round(av.avatarSize * 0.36)
            height: width
            implicitSize: width
            x: -Math.round(width * 0.14)
            y: -Math.round(height * 0.14)
            shape: MaterialShape.Gem
            color: Colours.palette.m3primaryContainer

            Loader {
                anchors.centerIn: parent
                sourceComponent: SysInfo.isDefaultLogo ? caelLogoComp : distroLogoComp
            }

            Component {
                id: caelLogoComp

                Logo {
                    implicitWidth: Math.round(av.avatarSize * 0.21)
                    implicitHeight: Math.round(av.avatarSize * 0.21)
                    topColour: Colours.palette.m3primary
                    bottomColour: Colours.palette.m3onPrimaryContainer
                }
            }

            Component {
                id: distroLogoComp

                ColouredIcon {
                    source: SysInfo.osLogo
                    implicitSize: Math.round(av.avatarSize * 0.21)
                    colour: Colours.palette.m3onPrimaryContainer
                }
            }
        }

        // Overlapping MaterialShape.ClamShell status accent
        MaterialShape {
            visible: av.showBadges
            width: Math.round(av.avatarSize * 0.32)
            height: width
            implicitSize: width
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: -Math.round(width * 0.12)
            anchors.bottomMargin: -Math.round(height * 0.12)
            shape: MaterialShape.ClamShell
            color: Colours.palette.m3tertiaryContainer

            MaterialIcon {
                anchors.centerIn: parent
                text: "verified_user"
                fontStyle: Tokens.font.icon.builders.small.scale(Math.max(0.75, av.avatarSize / 88)).build()
                color: Colours.palette.m3onTertiaryContainer
            }
        }
    }
}

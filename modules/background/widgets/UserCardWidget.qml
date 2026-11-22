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
    property real widgetScale: WidgetMetrics.scale
    property string surfaceStyle: ""
    property bool blurEnabled: Config.background.desktopWidgets.blur
    property real plateOpacity: Config.background.desktopWidgets.opacity
    property var widgetOptions: ({})

    readonly property real s: Math.max(0.55, Math.min(2.2, widgetScale > 0 ? widgetScale : WidgetMetrics.scale))
    readonly property string effectiveSize: WidgetMetrics.fallbackSizeFor("usercard", sizeMode)
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
        const h = Time.hours;
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

    implicitWidth: WidgetMetrics.widthFor(effectiveSize, s)
    implicitHeight: WidgetMetrics.heightFor(effectiveSize, "usercard", s)

    WidgetCardShell {
        id: shell

        anchors.fill: parent
        widgetType: "usercard"
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
                case "1x1":
                    return layout1x1;
                case "2x2":
                    return layout2x2;
                default:
                    return layout1x2;
                }
            }
        }
    }

    // 1x1 Expressive Shaped User Medallion
    Component {
        id: layout1x1

        Item {
            readonly property int safeAvatarSize: Math.max(30, Math.round(Math.min((shell.isShaped ? 48 : 54) * root.s, shell.safeInnerBox - Math.round(34 * root.s))))

            clip: true

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.max(24, parent.width - shell.sidePadding * 2)
                spacing: Math.max(2, Math.round(3 * root.s))

                AvatarMedallion {
                    Layout.alignment: Qt.AlignHCenter
                    avatarSize: safeAvatarSize
                    showBadges: true
                    activeMask: root.effectiveSize === "1x1"
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    horizontalAlignment: Text.AlignHCenter
                    text: SysInfo.user || Quickshell.env("USER") || "user"
                    font: Tokens.font.title.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.92)).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    horizontalAlignment: Text.AlignHCenter
                    text: SysInfo.uptimeShort || SysInfo.hostname
                    font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.84)).build()
                    color: Colours.palette.m3primary
                    elide: Text.ElideRight
                }
            }

            StateLayer {
                anchors.fill: parent
                anchors.topMargin: shell.topPadding
                anchors.bottomMargin: shell.bottomPadding
                anchors.leftMargin: shell.sidePadding
                anchors.rightMargin: shell.sidePadding
                enabled: root.locked
                radius: shell.isShaped ? width / 2 : shell.radius
                onClicked: root.openSettings()
            }
        }
    }

    // 1x2 Wide User Card
    Component {
        id: layout1x2

        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            spacing: Math.max(6, Math.round(Tokens.spacing.large * root.s))

            AvatarMedallion {
                Layout.fillWidth: false
                Layout.alignment: Qt.AlignVCenter
                avatarSize: Math.round(78 * root.s)
                showBadges: true
                activeMask: root.effectiveSize === "1x2"
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter
                spacing: Math.max(2, Math.round(3 * root.s))

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: root.greetingText
                    font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.92)).weight(Font.DemiBold).build()
                    color: Colours.palette.m3primary
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: SysInfo.user || Quickshell.env("USER") || "user"
                    font: Tokens.font.headline.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.92)).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: (SysInfo.hostname || "linux") + " · " + (SysInfo.uptimeShort || "--")
                    font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.9)).build()
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }

                ButtonRow {
                    visible: root.showActions
                    Layout.fillWidth: true
                    Layout.minimumHeight: Math.round(32 * root.s)
                    Layout.topMargin: Math.round(3 * root.s)
                    spacing: Math.max(2, Math.round(Tokens.spacing.extraSmall * root.s))

                    WidgetIconButton {
                        fillWidth: true
                        icon: "lock"
                        type: IconButton.Tonal
                        isRound: true
                        translucent: shell.isTranslucent
                        scaleFactor: root.s * 0.94
                        onClicked: root.lockScreen()
                    }

                    WidgetIconButton {
                        fillWidth: true
                        icon: "tune"
                        type: IconButton.Tonal
                        isRound: true
                        translucent: shell.isTranslucent
                        scaleFactor: root.s * 0.94
                        onClicked: root.openSettings()
                    }

                    WidgetIconButton {
                        fillWidth: true
                        icon: "power_settings_new"
                        type: IconButton.Tonal
                        isRound: true
                        translucent: shell.isTranslucent
                        scaleFactor: root.s * 0.94
                        onClicked: root.openSession()
                    }
                }
            }
        }
    }

    // 2x2 Native Dash User Clone
    Component {
        id: layout2x2

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            spacing: Math.max(4, Math.round(Tokens.spacing.medium * root.s))

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Math.max(6, Math.round(Tokens.spacing.medium * root.s))

                AvatarMedallion {
                    Layout.fillWidth: false
                    Layout.alignment: Qt.AlignVCenter
                    avatarSize: Math.round(80 * root.s)
                    showBadges: true
                    activeMask: root.effectiveSize === "2x2"
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Math.max(1, Math.round(2 * root.s))

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: root.greetingText
                        font: Tokens.font.label.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.96)).weight(Font.DemiBold).build()
                        color: Colours.palette.m3primary
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: SysInfo.user || Quickshell.env("USER") || "user"
                        font: Tokens.font.headline.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).weight(Font.Bold).build()
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: SysInfo.osPrettyName || SysInfo.osName || "Linux"
                        font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.92)).build()
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }
            }

            // Thought-bubble tail + WM / Uptime badge
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Math.max(2, Math.round(4 * root.s))

                RowLayout {
                    spacing: Math.max(4, Math.round(6 * root.s))
                    Layout.leftMargin: Math.round(24 * root.s)

                    Rectangle {
                        Layout.fillWidth: false
                        Layout.preferredWidth: Math.round(8 * root.s)
                        Layout.preferredHeight: Math.round(8 * root.s)
                        radius: Math.round(4 * root.s)
                        color: shell.secondaryContainerTint
                    }

                    Rectangle {
                        Layout.fillWidth: false
                        Layout.preferredWidth: Math.round(12 * root.s)
                        Layout.preferredHeight: Math.round(12 * root.s)
                        radius: Math.round(6 * root.s)
                        color: shell.secondaryContainerTint
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(50 * root.s)
                    clip: true
                    radius: Math.round(Tokens.rounding.extraLarge * Math.min(1.2, Math.max(0.75, root.s)))
                    color: shell.secondaryContainerTint

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Math.round(Tokens.padding.small * root.s)
                        anchors.leftMargin: Math.round(Tokens.padding.medium * root.s)
                        anchors.rightMargin: Math.round(Tokens.padding.medium * root.s)
                        spacing: Math.max(4, Math.round(Tokens.spacing.small * root.s))

                        MaterialIcon {
                            text: "select_window"
                            fontStyle: Tokens.font.icon.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.96)).build()
                            color: Colours.palette.m3onSecondaryContainer
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: (SysInfo.hostname || "linux") + " · " + (SysInfo.wm || "Hyprland")
                                font: Tokens.font.label.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).weight(Font.DemiBold).build()
                                color: Colours.palette.m3onSecondaryContainer
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: Tr.tr("up %1").arg(SysInfo.uptimeShort || "--")
                                font: Tokens.font.body.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.9)).build()
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
                spacing: Math.max(2, Math.round(Tokens.spacing.extraSmall * root.s))

                WidgetIconTextButton {
                    fillWidth: true
                    text: Tr.tr("Lock")
                    icon: "lock"
                    type: IconTextButton.Tonal
                    isRound: true
                    translucent: shell.isTranslucent
                    scaleFactor: root.s
                    verticalPadding: Math.max(3, Math.round(6 * root.s))
                    horizontalPadding: Math.max(6, Math.round(10 * root.s))
                    onClicked: root.lockScreen()
                }

                WidgetIconButton {
                    fillWidth: false
                    icon: "tune"
                    type: IconButton.Tonal
                    isRound: true
                    translucent: shell.isTranslucent
                    scaleFactor: root.s
                    onClicked: root.openSettings()
                }

                WidgetIconTextButton {
                    fillWidth: true
                    text: Tr.tr("Power")
                    icon: "power_settings_new"
                    type: IconTextButton.Tonal
                    isRound: true
                    translucent: shell.isTranslucent
                    scaleFactor: root.s
                    verticalPadding: Math.max(3, Math.round(6 * root.s))
                    horizontalPadding: Math.max(6, Math.round(10 * root.s))
                    onClicked: root.openSession()
                }
            }
        }
    }

    component AvatarMedallion: Item {
        id: av

        property int avatarSize: 72
        property bool showBadges: true
        property bool activeMask: true

        implicitWidth: Math.max(16, Math.round(avatarSize))
        implicitHeight: Math.max(16, Math.round(avatarSize))

        MaterialShape {
            id: avatarFrame

            anchors.centerIn: parent
            width: av.avatarSize
            height: av.avatarSize
            implicitSize: Math.max(1, Math.round(av.avatarSize))
            shape: GlobalConfig.dashboard.profilePicShape
            color: shell.primaryContainerTint
        }

        MaterialShape {
            id: avatarMask

            readonly property int maskSize: Math.max(8, av.avatarSize - 4)

            anchors.centerIn: parent
            width: maskSize
            height: maskSize
            implicitSize: maskSize
            visible: false
            layer.enabled: av.activeMask && av.avatarSize > 4 && root.avatarPath !== ""
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
            layer.enabled: visible && av.activeMask && width > 0 && height > 0
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
            fontStyle: Tokens.font.icon.builders.extraLarge.scale(Math.max(0.45, av.avatarSize / 72)).build()
            color: Colours.palette.m3onPrimaryContainer
        }

        // Overlapping OS/Caelestia MaterialShape.Gem badge
        MaterialShape {
            readonly property int gemSize: Math.max(10, Math.round(av.avatarSize * 0.36))

            visible: av.showBadges
            width: gemSize
            height: gemSize
            implicitSize: gemSize
            x: -Math.round(gemSize * 0.14)
            y: -Math.round(gemSize * 0.14)
            shape: MaterialShape.Gem
            color: shell.primaryContainerTint

            Loader {
                anchors.centerIn: parent
                sourceComponent: SysInfo.isDefaultLogo ? vacuitedLogoComp : distroLogoComp
            }

            Component {
                id: vacuitedLogoComp

                Logo {
                    implicitWidth: Math.max(6, Math.round(av.avatarSize * 0.22))
                    implicitHeight: Math.max(6, Math.round(av.avatarSize * 0.22))
                    topColour: Colours.palette.m3primary
                    bottomColour: Colours.palette.m3onPrimaryContainer
                }
            }

            Component {
                id: distroLogoComp

                ColouredIcon {
                    source: SysInfo.osLogo
                    implicitSize: Math.max(6, Math.round(av.avatarSize * 0.21))
                    colour: Colours.palette.m3onPrimaryContainer
                }
            }
        }

        // Overlapping MaterialShape.ClamShell status accent
        MaterialShape {
            readonly property int statusSize: Math.max(10, Math.round(av.avatarSize * 0.32))

            visible: av.showBadges
            width: statusSize
            height: statusSize
            implicitSize: statusSize
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: -Math.round(statusSize * 0.12)
            anchors.bottomMargin: -Math.round(statusSize * 0.12)
            shape: MaterialShape.ClamShell
            color: shell.tertiaryContainerTint

            MaterialIcon {
                anchors.centerIn: parent
                text: "verified_user"
                fontStyle: Tokens.font.icon.builders.small.scale(Math.max(0.55, av.avatarSize / 88)).build()
                color: Colours.palette.m3onTertiaryContainer
            }
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import M3Shapes
import Caelestia.Config
import qs.components
import qs.components.filedialog
import qs.services
import qs.utils
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
    readonly property int widgetSize: Math.max(88, Math.round(Number(widgetOptions?.size ?? 196) * s))
    readonly property string imagePath: String(widgetOptions?.path ?? "")
    readonly property bool isAnimatedGif: imagePath.toLowerCase().endsWith(".gif")
    readonly property string stickerUrl: localPathToFileUrl(imagePath)
    readonly property bool imageFailed: stickerUrl !== "" && (isAnimatedGif ? stickerGif.status === AnimatedImage.Error : stickerImg.status === Image.Error)

    signal optionsUpdated(var patch)

    function localPathToFileUrl(rawPath: string): string {
        if (!rawPath)
            return "";
        if (/^https?:\/\//i.test(rawPath))
            return rawPath;
        let p = rawPath;
        if (p.startsWith("file://")) {
            try {
                p = decodeURIComponent(p.slice(7));
            } catch (e) {
                p = p.slice(7);
            }
        }
        const expanded = p.replace(/^~(?=\/|$)|(\$({?)HOME(}?))+/, Paths.home).replace(/^root:/, Quickshell.shellDir + "/");
        const abs = (!expanded.includes("#") && !expanded.includes("?") && !expanded.includes("%"))
            ? (Paths.absolutePath(expanded) || expanded)
            : expanded;
        return "file://" + abs.split("/").map(seg => encodeURIComponent(seg)).join("/");
    }

    function openPicker(): void {
        stickerPicker.open();
    }

    function acceptDropUrl(raw: string): void {
        if (!raw)
            return;
        let clean = raw;
        if (raw.startsWith("file://")) {
            try {
                clean = decodeURIComponent(raw.slice(7));
            } catch (e) {
                clean = raw.slice(7);
            }
        }
        if (clean)
            optionsUpdated({ path: clean });
    }

    implicitWidth: widgetSize
    implicitHeight: widgetSize

    FileDialog {
        id: stickerPicker

        title: qsTr("Choose Sticker")
        filterLabel: qsTr("Stickers")
        filters: ["png", "webp", "gif", "svg", "avif", "jpg", "jpeg"]
        cwd: ["Home", "Pictures"]

        onAccepted: path => {
            if (path)
                root.optionsUpdated({ path: path });
        }
    }

    WidgetCardShell {
        id: emptyShell

        anchors.fill: parent
        visible: root.stickerUrl === ""
        widgetType: "sticker"
        sizeMode: "1x1"
        forceRounded: true
        wallpaper: root.wallpaper
        weActive: root.weActive
        surfaceStyle: root.surfaceStyle
        blurEnabled: root.blurEnabled
        plateOpacity: root.plateOpacity
        scaleFactor: root.s

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.max(40, parent.width - emptyShell.contentPadding * 2)
            spacing: Math.round(6 * root.s)

            MaterialShape {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.round(46 * root.s)
                Layout.preferredHeight: Math.round(46 * root.s)
                shape: MaterialShape.SoftBurst
                color: Colours.palette.m3tertiaryContainer

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "sentiment_satisfied"
                    fontStyle: Tokens.font.icon.large
                    color: Colours.palette.m3onTertiaryContainer
                }
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Pick sticker")
                font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
                color: Colours.palette.m3onSurface
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Transparent PNG / GIF")
                font: Tokens.font.label.small
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }
        }

        StateLayer {
            enabled: root.stickerUrl === ""
            radius: emptyShell.radius
            onClicked: root.openPicker()
        }
    }

    Item {
        id: stickerHolder

        anchors.fill: parent
        visible: root.stickerUrl !== ""
        scale: stickerHover.hovered && root.locked ? 1.05 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: Tokens.anim.durations.expressiveFastEffects
                easing: Tokens.anim.expressiveDefaultSpatial
            }
        }

        HoverHandler {
            id: stickerHover
        }

        Image {
            id: stickerImg

            anchors.fill: parent
            visible: !root.isAnimatedGif && !root.imageFailed
            source: !root.isAnimatedGif ? root.stickerUrl : ""
            sourceSize.width: Math.max(256, Math.round(root.widgetSize * 2))
            sourceSize.height: Math.max(256, Math.round(root.widgetSize * 2))
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            mipmap: true
        }

        AnimatedImage {
            id: stickerGif

            anchors.fill: parent
            visible: root.isAnimatedGif && !root.imageFailed
            source: root.isAnimatedGif ? root.stickerUrl : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            playing: visible && root.visible && !GameMode.enabled
        }

        WidgetCardShell {
            anchors.fill: parent
            visible: root.imageFailed
            widgetType: "sticker"
            sizeMode: "1x1"
            forceRounded: true
            wallpaper: root.wallpaper
            weActive: root.weActive
            surfaceStyle: root.surfaceStyle
            blurEnabled: root.blurEnabled
            plateOpacity: root.plateOpacity
            scaleFactor: root.s

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.max(40, parent.width - emptyShell.contentPadding * 2)
                spacing: Math.round(6 * root.s)

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "broken_image"
                    fontStyle: Tokens.font.icon.large
                    color: Colours.palette.m3error
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Sticker missing")
                    font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Tap to pick another")
                    font: Tokens.font.label.small
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            StateLayer {
                enabled: root.locked && root.imageFailed
                radius: emptyShell.radius
                onClicked: root.openPicker()
            }
        }

        layer.enabled: !GameMode.enabled && !root.weActive && root.stickerUrl !== "" && !root.imageFailed && width > 0 && height > 0
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 0.45
            shadowOpacity: 0.34
            shadowVerticalOffset: 4
            shadowColor: "#000000"
        }
    }

    DropArea {
        anchors.fill: parent
        enabled: !root.locked || root.stickerUrl === ""
        onDropped: drop => {
            if (drop.hasUrls && drop.urls.length > 0)
                root.acceptDropUrl(String(drop.urls[0]));
        }
    }
}

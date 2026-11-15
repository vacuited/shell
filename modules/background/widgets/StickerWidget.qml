pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
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
    readonly property real s: WidgetMetrics.scale
    readonly property int widgetSize: Math.max(88, Math.round(Number(widgetOptions?.size ?? 196) * s))
    readonly property string imagePath: String(widgetOptions?.path ?? "")
    readonly property bool isAnimatedGif: imagePath.toLowerCase().endsWith(".gif")
    readonly property string stickerUrl: {
        if (!imagePath)
            return "";
        return imagePath.startsWith("file://") ? imagePath : ("file://" + imagePath);
    }

    signal optionsUpdated(var patch)

    function openPicker(): void {
        stickerPicker.open();
    }

    function acceptDropUrl(raw: string): void {
        if (!raw)
            return;
        const clean = raw.startsWith("file://") ? decodeURIComponent(raw.slice(7)) : raw;
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
        cwd: Paths.pictures

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
            anchors.fill: parent
            visible: !root.isAnimatedGif
            source: !root.isAnimatedGif ? root.stickerUrl : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            mipmap: true
        }

        AnimatedImage {
            anchors.fill: parent
            visible: root.isAnimatedGif
            source: root.isAnimatedGif ? root.stickerUrl : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            playing: visible
        }

        layer.enabled: !GameMode.enabled && !root.weActive && root.stickerUrl !== "" && width > 0 && height > 0
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

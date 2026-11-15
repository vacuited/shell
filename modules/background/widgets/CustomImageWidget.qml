pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import M3Shapes
import Caelestia.Config
import qs.components
import qs.components.effects
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
    readonly property int widgetSize: Math.max(96, Math.round(Number(widgetOptions?.size ?? 200) * s))
    readonly property string imagePath: String(widgetOptions?.path ?? "")
    readonly property string fitMode: String(widgetOptions?.fitMode ?? "shape") // "shape" | "auto"
    readonly property string shapeKey: String(widgetOptions?.outerShape ?? "Rounded")
    readonly property int resolvedShape: WidgetMetrics.resolveShapeEnum(shapeKey, "Rounded")
    readonly property bool isShaped: fitMode === "shape" && resolvedShape >= 0
    readonly property bool isAnimatedGif: imagePath.toLowerCase().endsWith(".gif")
    readonly property real naturalRatio: {
        const iw = isAnimatedGif ? gifImg.implicitWidth : mainImg.implicitWidth;
        const ih = isAnimatedGif ? gifImg.implicitHeight : mainImg.implicitHeight;
        if (fitMode === "auto" && !isShaped && iw > 0 && ih > 0)
            return Math.max(0.35, Math.min(2.8, iw / ih));
        return 1.0;
    }

    readonly property int boxWidth: widgetSize
    readonly property int boxHeight: Math.max(80, Math.round(widgetSize / naturalRatio))
    readonly property string imageSourceUrl: {
        if (!imagePath)
            return "";
        return imagePath.startsWith("file://") ? imagePath : ("file://" + imagePath);
    }

    signal optionsUpdated(var patch)

    function openPicker(): void {
        imagePicker.open();
    }

    function acceptDropUrl(raw: string): void {
        if (!raw)
            return;
        const clean = raw.startsWith("file://") ? decodeURIComponent(raw.slice(7)) : raw;
        if (clean)
            optionsUpdated({ path: clean });
    }

    implicitWidth: boxWidth
    implicitHeight: boxHeight

    FileDialog {
        id: imagePicker

        title: qsTr("Choose Image")
        filterLabel: qsTr("Images")
        filters: ["png", "jpg", "jpeg", "webp", "avif", "bmp", "gif", "tiff", "tif", "svg"]
        cwd: Paths.pictures

        onAccepted: path => {
            if (path)
                root.optionsUpdated({ path: path });
        }
    }

    // Empty / Add Image placeholder plate
    WidgetCardShell {
        id: emptyShell

        anchors.fill: parent
        visible: root.imageSourceUrl === ""
        widgetType: "customImage"
        sizeMode: "1x1"
        outerShape: root.shapeKey
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
                Layout.preferredWidth: Math.round(44 * root.s)
                Layout.preferredHeight: Math.round(44 * root.s)
                shape: MaterialShape.Flower
                color: Colours.palette.m3primaryContainer

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "add_photo_alternate"
                    fontStyle: Tokens.font.icon.medium
                    color: Colours.palette.m3onPrimaryContainer
                }
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Tap to add image")
                font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
                color: Colours.palette.m3onSurface
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("or drop file")
                font: Tokens.font.label.small
                color: Colours.palette.m3onSurfaceVariant
            }
        }

        StateLayer {
            enabled: root.imageSourceUrl === ""
            radius: emptyShell.isShaped ? width / 2 : emptyShell.radius
            onClicked: root.openPicker()
        }
    }

    // Rendered Image (Masked cleanly to M3Shape or Rounded Card)
    Item {
        id: imageFrame

        anchors.fill: parent
        visible: root.imageSourceUrl !== ""

        MaterialShape {
            id: imgMaskSource

            anchors.fill: parent
            visible: false
            layer.enabled: root.isShaped && width > 0 && height > 0
            shape: root.resolvedShape >= 0 ? root.resolvedShape : MaterialShape.Circle
            color: "#ffffff"
        }

        Rectangle {
            id: roundMaskSource

            anchors.fill: parent
            visible: false
            layer.enabled: !root.isShaped && width > 0 && height > 0
            radius: Tokens.rounding.extraLarge
            color: "#ffffff"
        }

        Item {
            id: maskedMedia

            anchors.fill: parent
            layer.enabled: width > 0 && height > 0
            layer.smooth: true
            layer.effect: Mask {
                maskSource: root.isShaped ? imgMaskSource : roundMaskSource
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            Image {
                id: mainImg

                anchors.fill: parent
                visible: !root.isAnimatedGif
                source: !root.isAnimatedGif ? root.imageSourceUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                mipmap: true
            }

            AnimatedImage {
                id: gifImg

                anchors.fill: parent
                visible: root.isAnimatedGif
                source: root.isAnimatedGif ? root.imageSourceUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                playing: visible
            }
        }

        // Crisp subtle perimeter border matching either MaterialShape or Rounded corners
        MaterialShape {
            visible: root.isShaped && width > 0 && height > 0
            anchors.fill: parent
            shape: root.resolvedShape >= 0 ? root.resolvedShape : MaterialShape.Circle
            color: "transparent"
            strokeColor: Qt.alpha(Colours.palette.m3outlineVariant, 0.55)
            strokeWidth: 1.5
        }

        Rectangle {
            visible: !root.isShaped
            anchors.fill: parent
            color: "transparent"
            radius: Tokens.rounding.extraLarge
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.45)
        }

        // Elevation shadow behind the rendered frame only
        layer.enabled: !GameMode.enabled && !root.weActive && root.imageSourceUrl !== "" && width > 0 && height > 0
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 0.4
            shadowOpacity: 0.28
            shadowVerticalOffset: 4
            shadowColor: "#000000"
        }
    }

    DropArea {
        anchors.fill: parent
        enabled: !root.locked || root.imageSourceUrl === ""
        onDropped: drop => {
            if (drop.hasUrls && drop.urls.length > 0)
                root.acceptDropUrl(String(drop.urls[0]));
        }
    }
}

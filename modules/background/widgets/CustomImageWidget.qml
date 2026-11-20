pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
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
    readonly property real s: Math.max(0.7, Math.min(1.5, Config.background.desktopWidgets.scale ?? 1.0))
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
    readonly property string imageSourceUrl: localPathToFileUrl(imagePath)
    readonly property bool imageFailed: imageSourceUrl !== "" && (isAnimatedGif ? gifImg.status === AnimatedImage.Error : mainImg.status === Image.Error)

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
        imagePicker.open();
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

    implicitWidth: boxWidth
    implicitHeight: boxHeight

    FileDialog {
        id: imagePicker

        title: qsTr("Choose Image")
        filterLabel: qsTr("Images")
        filters: ["png", "jpg", "jpeg", "webp", "avif", "bmp", "gif", "tiff", "tif", "svg"]
        cwd: ["Home", "Pictures"]

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
            layer.enabled: root.visible && root.isShaped && !root.imageFailed && width > 0 && height > 0
            shape: root.resolvedShape >= 0 ? root.resolvedShape : MaterialShape.Circle
            color: "#ffffff"
        }

        Rectangle {
            id: roundMaskSource

            anchors.fill: parent
            visible: false
            layer.enabled: root.visible && !root.isShaped && !root.imageFailed && width > 0 && height > 0
            radius: Tokens.rounding.extraLarge
            color: "#ffffff"
        }

        Item {
            id: maskedMedia

            anchors.fill: parent
            visible: !root.imageFailed
            layer.enabled: root.visible && !root.imageFailed && width > 0 && height > 0
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
                sourceSize.width: Math.max(256, Math.round(root.boxWidth * 2))
                sourceSize.height: Math.max(256, Math.round(root.boxHeight * 2))
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
                playing: visible && root.visible && !GameMode.enabled
            }
        }

        WidgetCardShell {
            anchors.fill: parent
            visible: root.imageFailed
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

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "broken_image"
                    fontStyle: Tokens.font.icon.large
                    color: Colours.palette.m3error
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Image unavailable")
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
                radius: emptyShell.isShaped ? width / 2 : emptyShell.radius
                onClicked: root.openPicker()
            }
        }

        // Crisp subtle perimeter border matching either MaterialShape or Rounded corners
        MaterialShape {
            visible: root.isShaped && !root.imageFailed && width > 0 && height > 0
            anchors.fill: parent
            shape: root.resolvedShape >= 0 ? root.resolvedShape : MaterialShape.Circle
            color: "transparent"
            strokeColor: Qt.alpha(Colours.palette.m3outlineVariant, 0.55)
            strokeWidth: 1.5
        }

        Rectangle {
            visible: !root.isShaped && !root.imageFailed
            anchors.fill: parent
            color: "transparent"
            radius: Tokens.rounding.extraLarge
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.45)
        }

        // Elevation shadow behind the rendered frame only
        layer.enabled: !GameMode.enabled && !root.weActive && root.imageSourceUrl !== "" && !root.imageFailed && width > 0 && height > 0
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

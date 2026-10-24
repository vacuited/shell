import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.Models
import Caelestia.Multimedia
import qs.components
import qs.components.effects
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root

    required property FileSystemEntry modelData
    required property ScreenState screenState

    readonly property string thumbPath: Wallpapers.getThumbnailPath(root.modelData.path)
    readonly property string cleanThumbPath: String(root.thumbPath).split(/[?#]/)[0]
    readonly property bool isGif: root.cleanThumbPath.toLowerCase().endsWith(".gif")
    property int retryNonce: 0

    scale: 0.5
    opacity: 0
    z: PathView.z ?? 0 // qmllint disable missing-property

    Component.onCompleted: {
        scale = Qt.binding(() => PathView.isCurrentItem ? 1 : PathView.onPath ? 0.8 : 0);
        opacity = Qt.binding(() => PathView.onPath ? 1 : 0);
    }

    implicitWidth: image.width + Tokens.padding.medium * 2
    implicitHeight: image.height + label.height + Tokens.spacing.extraSmall + Tokens.padding.large + Tokens.padding.medium

    Process {
        id: thumbGenerator
        command: ["bash", "-c", `mkdir -p "$(dirname "${root.cleanThumbPath.replace("file://", "")}")" && ffmpeg -i "${root.modelData.path}" -vframes 1 -q:v 2 "${root.cleanThumbPath.replace("file://", "")}" -y`]
        onExited: {
            root.retryNonce++;
        }
    }

    StateLayer {
        id: stateLayer

        radius: Tokens.rounding.large
        onClicked: {
            Wallpapers.setWallpaper(root.modelData.path);
            root.screenState.launcher = false;
        }
    }

    Elevation {
        anchors.fill: image
        radius: image.radius
        opacity: root.PathView.isCurrentItem ? 1 : 0
        level: 4

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    ClipRect {
        id: image

        anchors.horizontalCenter: parent.horizontalCenter
        y: Tokens.padding.large
        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.large

        implicitWidth: Tokens.sizes.launcher.wallpaperWidth
        implicitHeight: implicitWidth / 16 * 9

        MaterialIcon {
            anchors.centerIn: parent
            text: "image"
            color: Colours.tPalette.m3outline
            fontStyle: Tokens.font.icon.builders.extraLarge.scale(2).weight(Font.DemiBold).build()
            visible: root.isGif ? (gifLoader.item?.status !== Image.Ready) : !visImg.ready
        }

        Visual {
            id: visImg

            anchors.fill: parent
            visible: !root.isGif
            playing: !root.isGif && root.PathView.isCurrentItem
            source: {
                void root.retryNonce;
                return root.isGif ? "" : root.cleanThumbPath;
            }
            onReadyChanged: {
                if (!ready && Images.isVideo(root.modelData.name) && !CUtils.fileExists(root.cleanThumbPath)) {
                    if (!thumbGenerator.running) {
                        thumbGenerator.running = true;
                    }
                }
            }
        }

        Loader {
            id: gifLoader

            anchors.fill: parent
            active: root.isGif
            visible: active

            sourceComponent: CachingAnimatedImage {
                anchors.fill: parent
                path: root.thumbPath
                smooth: !root.PathView.view.moving
                playing: root.PathView.isCurrentItem
                sourceSize: {
                    const dpr = (QsWindow.window as QsWindow)?.devicePixelRatio ?? 1;
                    return Qt.size(image.implicitWidth * dpr, image.implicitHeight * dpr);
                }
            }
        }
    }

    StyledText {
        id: label

        anchors.top: image.bottom
        anchors.topMargin: Tokens.spacing.extraSmall
        anchors.horizontalCenter: parent.horizontalCenter

        width: image.width - Tokens.padding.medium * 2
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        renderType: Text.QtRendering
        text: {
            if (root.modelData.name === "project.json") {
                let content = CUtils.readFile(root.modelData.path);
                try {
                    let json = JSON.parse(content);
                    if (json.title) return json.title;
                } catch (e) {}
                return root.modelData.path.split('/').slice(-2, -1)[0];
            }
            return root.modelData.name;
        }
        font: Tokens.font.label.medium
    }

    Behavior on scale {
        Anim {}
    }

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }
}

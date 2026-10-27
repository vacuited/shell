pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components.containers
import qs.services

Variants {
    model: Quickshell.screens

    StyledWindow {
        id: root
        required property ShellScreen modelData
        screen: modelData
        name: "drawers" // Use 'drawers' namespace so Hyprland blurs it automatically
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        color: "transparent"

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        visible: BadApplePlayer.shouldPlay
        mask: Region {}

        Item {
            id: badAppleMaskContainer
            anchors.fill: parent
            layer.enabled: BadApplePlayer.shouldPlay
            layer.effect: BadApplePlayer.shouldPlay ? badAppleShaderComponent : null

            Rectangle {
                anchors.fill: parent
                color: GlobalConfig.appearance.pitchBlack ? "#000000" : Colours.tPalette.m3surface
                visible: BadApplePlayer.shouldPlay
                opacity: 1.0
            }
        }

        Component {
            id: badAppleShaderComponent
            ShaderEffect {
                property variant mask: ShaderEffectSource {
                    sourceItem: badAppleMaskSource.videoOutput
                    hideSource: true
                }
                property real videoRatio: 4.0 / 3.0
                property real screenRatio: root.width / Math.max(1, root.height)
                fragmentShader: Qt.resolvedUrl("../../assets/shaders/badapple.frag.qsb")
            }
        }

        BadAppleVideo {
            id: badAppleMaskSource
            screenModel: root.screen
            anchors.fill: parent
            opacity: 0.0
        }
    }
}

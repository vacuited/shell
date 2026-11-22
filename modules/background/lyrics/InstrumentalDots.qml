pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Caelestia.Config
import qs.services

Item {
    id: root

    property real progress: 0
    property int alignment: 1
    property real lyricsScale: 1.0
    property color activeColor: Colours.palette.m3primary
    property color unsungColor: Qt.alpha(Colours.palette.m3onSurface, 0.35)
    property color glowColor: activeColor
    property real glowStrength: 0.4
    property bool active: true
    property bool textShadowEnabled: false
    property real textShadowOpacity: 0.45
    property real textShadowBlur: 0.5
    property real focusProgress: active ? 1.0 : 0.0

    readonly property int dotSize: Math.max(4, Math.round(8 * lyricsScale))
    readonly property int dotGap: Math.max(4, Math.round(8 * lyricsScale))

    function mixColor(c1: color, c2: color, t: real): color {
        const k = Math.max(0, Math.min(1, t));
        return Qt.rgba(
            c1.r + (c2.r - c1.r) * k,
            c1.g + (c2.g - c1.g) * k,
            c1.b + (c2.b - c1.b) * k,
            c1.a + (c2.a - c1.a) * k
        );
    }

    implicitWidth: dotRow.implicitWidth
    implicitHeight: Math.max(dotSize + 6, Math.round(dotSize * 1.6))

    Behavior on focusProgress {
        enabled: !GameMode.enabled

        NumberAnimation {
            duration: Tokens.anim.durations.expressiveDefaultSpatial
            easing: Tokens.anim.emphasizedDecel
        }
    }

    Row {
        id: dotRow

        readonly property bool hasGlowMode: root.glowStrength > 0.05
        readonly property real targetGlowOpacity: hasGlowMode ? Math.min(0.75, root.glowStrength * 0.65) : 0.0
        readonly property real targetGlowBlur: hasGlowMode ? Math.min(0.85, 0.30 + root.glowStrength * 0.45) : 0.0
        readonly property real idleShadowOpacity: root.textShadowEnabled ? Math.min(0.55, root.textShadowOpacity * 0.60) : 0.0
        readonly property real idleShadowBlur: root.textShadowEnabled ? Math.max(0.15, Math.min(0.75, root.textShadowBlur * 0.65)) : 0.0
        readonly property real glowBlend: hasGlowMode ? root.focusProgress : 0.0
        readonly property real effOpacity: idleShadowOpacity * (1.0 - glowBlend) + targetGlowOpacity * glowBlend
        readonly property real effBlur: idleShadowBlur * (1.0 - glowBlend) + targetGlowBlur * glowBlend
        readonly property color effColor: root.mixColor(Colours.palette.m3shadow, root.glowColor, glowBlend)
        readonly property real effOffsetY: Math.round(2 * root.lyricsScale) * (1.0 - glowBlend)

        x: {
            if (root.alignment === 0)
                return 0;
            if (root.alignment === 2)
                return Math.max(0, root.width - width);
            return Math.round((root.width - width) / 2);
        }
        spacing: root.dotGap
        anchors.verticalCenter: root.verticalCenter
        scale: 0.84 + 0.16 * root.focusProgress
        transformOrigin: root.alignment === 0 ? Item.Left : (root.alignment === 2 ? Item.Right : Item.Center)

        layer.enabled: !GameMode.enabled && dotRow.width > 0 && dotRow.height > 0 && dotRow.effOpacity > 0.005
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: dotRow.effColor
            shadowOpacity: dotRow.effOpacity
            shadowBlur: dotRow.effBlur
            shadowHorizontalOffset: 0
            shadowVerticalOffset: dotRow.effOffsetY
            autoPaddingEnabled: true
        }

        Repeater {
            model: 3

            delegate: Rectangle {
                id: dot

                required property int index

                readonly property real clampedProg: Math.max(0, Math.min(1, root.progress))
                readonly property real dotFill: Math.max(0, Math.min(1, (clampedProg - index / 3.0) * 3.0))
                readonly property bool isCurrent: dotFill > 0.001 && dotFill < 0.999
                readonly property real pulse: root.active && !GameMode.enabled
                    ? 0.07 * Math.sin(clampedProg * Math.PI * 8.0 - index * 1.15)
                    : 0.0

                width: root.dotSize
                height: root.dotSize
                radius: root.dotSize / 2
                color: root.mixColor(root.unsungColor, root.activeColor, dotFill)
                opacity: (0.28 + 0.72 * root.focusProgress) * (0.45 + 0.55 * dotFill)
                scale: 0.86 + 0.24 * dotFill + (isCurrent ? 0.10 : 0.0) + pulse
                transformOrigin: Item.Center
            }
        }
    }
}

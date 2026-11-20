pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import M3Shapes
import Caelestia.Config
import qs.components
import qs.services

// Unified 4-mode desktop backdrop ("glass" | "blur" | "frosted" | "material"):
// - "glass" / "blur": QML ShaderEffectSource + MultiEffect on static/video wallpapers,
//   or Hyprland compositor blur on Wallpaper Engine (weActive) over matching M3 plate.
// - "frosted": ditherglass.frag.qsb bokeh/glare shader on static/video, with WE fallback.
// - "material": solid M3 surface.
Item {
    id: root

    // --- Public API ---
    property Item wallpaper: null
    property bool weActive: wallpaper?.weSurfaceActive ?? wallpaper?.weSurfaceVisible ?? false
    property string surfaceStyle: "glass"
    property bool blur: true
    property real plateOpacity: 0.7
    property real radius: Tokens.rounding.extraLarge
    property color materialColor: Colours.palette.m3surfaceContainer
    property color glassColor: Colours.palette.m3surface
    property color borderColor: Colours.palette.m3outlineVariant
    property real borderWidth: 1
    property Item shapeMask: null
    property int maskShape: -1
    property bool maskBorder: true

    property bool shadowEnabled: true
    property real shadowOpacity: 0.35
    property real shadowBlur: 0.6
    property real shadowVerticalOffset: 4

    // Optional explicit coordinates in wallpaper space; -1 auto-tracks ancestor positions.
    property real absX: -1
    property real absY: -1

    readonly property bool isMaterial: surfaceStyle === "material"
    readonly property bool isBlur: surfaceStyle === "blur"
    readonly property bool isFrosted: surfaceStyle === "frosted"
    readonly property bool isGlass: !isMaterial && !isBlur && !isFrosted
    readonly property bool hasWallpaperPixels: root.visible && !GameMode.enabled && !weActive && wallpaper !== null && wallpaper.width > 0 && wallpaper.height > 0
    readonly property bool canQmlBlur: (isBlur || isFrosted || blur) && hasWallpaperPixels
    readonly property bool blurActive: (isBlur || (isGlass && blur)) && hasWallpaperPixels
    readonly property bool frostedActive: isFrosted && hasWallpaperPixels

    readonly property int blurBleed: 36
    readonly property real wallW: wallpaper ? Math.max(1, wallpaper.width) : Math.max(1, width)
    readonly property real wallH: wallpaper ? Math.max(1, wallpaper.height) : Math.max(1, height)
    readonly property color resolvedRimColor: {
        if (isFrosted)
            return Qt.alpha(Qt.tint(borderColor, Qt.alpha("#ffffff", Colours.light ? 0.42 : 0.30)), 0.66);
        if (isGlass)
            return Qt.alpha(Qt.tint(borderColor, Qt.alpha("#ffffff", Colours.light ? 0.35 : 0.24)), 0.58);
        return Qt.alpha(borderColor, 0.44);
    }

    readonly property point origin: {
        if (root.absX >= 0 && root.absY >= 0)
            return Qt.point(root.absX, root.absY);
        let ox = root.x;
        let oy = root.y;
        let p = root.parent;
        const stop = root.wallpaper ? root.wallpaper.parent : null;
        for (let i = 0; i < 12 && p && p !== stop; i++) {
            ox += p.x;
            oy += p.y;
            p = p.parent;
        }
        if (root.wallpaper) {
            ox -= root.wallpaper.x;
            oy -= root.wallpaper.y;
        }
        return Qt.point(ox, oy);
    }

    function updateOrigin(): void {
        // Maintained for callers; origin binding tracks ancestor geometry automatically.
    }

    layer.enabled: root.visible && !GameMode.enabled && !root.weActive && root.shadowEnabled && root.shadowOpacity > 0
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Colours.palette.m3shadow
        shadowOpacity: root.shadowOpacity
        shadowBlur: root.shadowBlur
        shadowVerticalOffset: root.shadowVerticalOffset
    }

    MaterialShape {
        id: maskRim

        visible: root.maskShape >= 0 && root.maskBorder && root.borderWidth > 0 && width > 0 && height > 0
        anchors.fill: parent
        z: 5
        shape: root.maskShape >= 0 ? root.maskShape : MaterialShape.Circle
        color: "transparent"
        strokeColor: root.resolvedRimColor
        strokeWidth: root.borderWidth
    }

    Item {
        id: surfaceLayer

        anchors.fill: parent
        layer.enabled: root.visible && root.shapeMask !== null && width > 0 && height > 0
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: root.shapeMask
            maskSpreadAtMin: 1
            maskThresholdMin: 0.5
        }

        // --- 1. Material Mode ---
        StyledRect {
            anchors.fill: parent
            visible: root.isMaterial
            radius: root.shapeMask ? 0 : root.radius
            color: root.materialColor
            border.width: root.shapeMask ? 0 : root.borderWidth
            border.color: root.resolvedRimColor
        }

        // --- 2. Glass & Blur Modes ---
        Item {
            anchors.fill: parent
            visible: root.isGlass || root.isBlur

            Rectangle {
                id: qmlBlurMask

                anchors.fill: parent
                radius: root.radius
                color: "black"
                visible: false
                layer.enabled: root.blurActive && root.shapeMask === null && root.width > 0 && root.height > 0
            }

            // Padded capture eliminates inward dark edge clamping around MultiEffect blur boundaries.
            Item {
                id: blurClipHost

                anchors.fill: parent
                clip: true
                visible: root.blurActive && root.width > 0 && root.height > 0
                layer.enabled: root.blurActive && root.shapeMask === null && root.width > 0 && root.height > 0
                layer.smooth: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: qmlBlurMask
                    maskSpreadAtMin: 1
                    maskThresholdMin: 0.5
                }

                Loader {
                    id: blurLoader

                    readonly property real cropX: Math.max(0, Math.floor(root.origin.x - root.blurBleed))
                    readonly property real cropY: Math.max(0, Math.floor(root.origin.y - root.blurBleed))
                    readonly property real cropX2: Math.min(root.wallW, Math.ceil(root.origin.x + root.width + root.blurBleed))
                    readonly property real cropY2: Math.min(root.wallH, Math.ceil(root.origin.y + root.height + root.blurBleed))

                    x: cropX - root.origin.x
                    y: cropY - root.origin.y
                    width: Math.max(1, cropX2 - cropX)
                    height: Math.max(1, cropY2 - cropY)
                    active: root.blurActive && root.width > 0 && root.height > 0 && width > 1 && height > 1

                    sourceComponent: MultiEffect {
                        source: ShaderEffectSource {
                            sourceItem: root.wallpaper
                            sourceRect: Qt.rect(blurLoader.cropX, blurLoader.cropY, blurLoader.width, blurLoader.height)
                        }
                        blurEnabled: true
                        blur: 1
                        blurMax: root.isBlur ? 64 : 36
                        autoPaddingEnabled: false
                    }
                }
            }

            StyledRect {
                id: glassPlate

                anchors.fill: parent
                radius: root.shapeMask ? 0 : root.radius
                color: root.glassColor
                opacity: {
                    if (root.isBlur) {
                        if (!GameMode.enabled && (root.weActive || root.hasWallpaperPixels))
                            return Math.max(0.28, Math.min(0.76, root.plateOpacity > 0 ? root.plateOpacity * 0.78 : 0.48));
                        return Math.max(0.85, root.plateOpacity);
                    }
                    if (root.weActive)
                        return Math.max(0.24, Math.min(0.56, root.plateOpacity * 0.54));
                    if (root.blurActive)
                        return Math.max(0.16, Math.min(0.58, root.plateOpacity * 0.56));
                    return Math.max(0.22, Math.min(0.72, root.plateOpacity * 0.68));
                }
            }

            // Specular highlight sheen for Glass vs soft ambient M3 tint for Blur.
            Rectangle {
                anchors.fill: parent
                radius: root.shapeMask ? 0 : root.radius
                visible: root.isGlass
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.alpha("#ffffff", Colours.light ? 0.30 : 0.15) }
                    GradientStop { position: 0.40; color: Qt.alpha("#ffffff", Colours.light ? 0.06 : 0.03) }
                    GradientStop { position: 1.0; color: Qt.alpha(Colours.palette.m3shadow, Colours.light ? 0.02 : 0.07) }
                }
            }

            StyledRect {
                anchors.fill: parent
                radius: root.shapeMask ? 0 : root.radius
                color: Qt.alpha(Colours.palette.m3primary, root.isBlur ? 0.05 : 0.03)
                border.width: root.shapeMask === null ? root.borderWidth : 0
                border.color: root.resolvedRimColor
            }
        }

        // --- 3. Frosted Bokeh Shader Mode ---
        Item {
            anchors.fill: parent
            visible: root.isFrosted

            Loader {
                id: ditherLoader

                readonly property int frostBleed: 48
                readonly property real cropX: Math.max(0, Math.floor(root.origin.x - frostBleed))
                readonly property real cropY: Math.max(0, Math.floor(root.origin.y - frostBleed))
                readonly property real cropX2: Math.min(root.wallW, Math.ceil(root.origin.x + root.width + frostBleed))
                readonly property real cropY2: Math.min(root.wallH, Math.ceil(root.origin.y + root.height + frostBleed))
                readonly property real cropW: Math.max(1, cropX2 - cropX)
                readonly property real cropH: Math.max(1, cropY2 - cropY)

                anchors.fill: parent
                active: root.frostedActive && root.width > 0 && root.height > 0 && cropW > 1 && cropH > 1

                sourceComponent: ShaderEffect {
                    property variant sourceTex: ShaderEffectSource {
                        sourceItem: root.wallpaper
                        sourceRect: Qt.rect(ditherLoader.cropX, ditherLoader.cropY, ditherLoader.cropW, ditherLoader.cropH)
                        live: true
                        smooth: true
                        hideSource: false
                    }
                    property real itemWidth: root.width
                    property real itemHeight: root.height
                    property real cornerRadius: root.shapeMask ? -1.0 : root.radius
                    property vector2d uvOffset: Qt.vector2d(
                        (root.origin.x - ditherLoader.cropX) / ditherLoader.cropW,
                        (root.origin.y - ditherLoader.cropY) / ditherLoader.cropH
                    )
                    property vector2d uvScale: Qt.vector2d(
                        root.width / ditherLoader.cropW,
                        root.height / ditherLoader.cropH
                    )
                    property real blurRadius: Math.min(0.45, 28.0 / ditherLoader.cropH)
                    property real ditherStrength: 0.007
                    property real frostOpacity: Math.max(0.14, Math.min(0.62, root.plateOpacity * (Colours.light ? 0.56 : 0.46)))
                    property real brightnessBoost: Colours.light ? 0.05 : 0.07
                    property real saturation: 1.24
                    property real rimGlow: 0.65
                    property real pad0: ditherLoader.cropW / ditherLoader.cropH
                    property real pad1: 0.0
                    property color tintColor: root.glassColor
                    property color highlightColor: Qt.alpha("#ffffff", Colours.light ? 0.85 : 0.72)

                    blending: true
                    fragmentShader: Qt.resolvedUrl("../../../assets/shaders/ditherglass.frag.qsb")
                }
            }

            // Fallback & Wallpaper Engine plate (triggers Hyprland blur above ignore_alpha = 0.22)
            StyledRect {
                anchors.fill: parent
                visible: !ditherLoader.active
                radius: root.shapeMask ? 0 : root.radius
                color: root.glassColor
                opacity: (!GameMode.enabled && root.weActive)
                    ? Math.max(0.28, Math.min(0.62, root.plateOpacity * 0.62))
                    : Math.max(0.85, root.plateOpacity)
            }

            Rectangle {
                anchors.fill: parent
                radius: root.shapeMask ? 0 : root.radius
                visible: !ditherLoader.active && !GameMode.enabled && root.weActive
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.alpha("#ffffff", Colours.light ? 0.34 : 0.18) }
                    GradientStop { position: 0.45; color: Qt.alpha(Colours.palette.m3primary, 0.05) }
                    GradientStop { position: 1.0; color: Qt.alpha("#ffffff", Colours.light ? 0.12 : 0.06) }
                }
            }

            StyledRect {
                anchors.fill: parent
                visible: root.shapeMask === null
                radius: root.radius
                color: Qt.alpha(Colours.palette.m3primary, ditherLoader.active ? 0.03 : 0.06)
                border.width: ditherLoader.active ? 0 : root.borderWidth
                border.color: root.resolvedRimColor
            }
        }
    }
}

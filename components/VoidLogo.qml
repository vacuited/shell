pragma ComponentBehavior: Bound

import QtQuick
import qs.services

Item {
    id: root

    readonly property real designWidth: 128
    readonly property real designHeight: 128

    property bool animated: true
    property bool interactive: true
    property bool monoMode: false
    property bool skipIntroAnimation: false
    property bool reduceMotion: skipIntroAnimation
    property bool lightSurface: Colours.light

    // Dynamic M3 scheme-driven moon palette (with backward-compatible aliases)
    property color voidColor: "#000000"
    property color horizonColor: Colours.palette.m3primary
    property color veinsColor: Qt.darker(baseTone, 2.55)
    property color highlightColor: Qt.tint(baseTone, "#E0FFFFFF")
    property color particleColor: Qt.lighter(baseTone, 1.14)

    property alias ringColour: root.horizonColor
    property alias highlightColour: root.highlightColor
    property alias particleColour: root.particleColor
    property alias voidColour: root.voidColor

    readonly property color baseTone: tuneHorizon(root.horizonColor)
    readonly property string hTopHex: hexRgb(Qt.lighter(baseTone, 1.18))
    readonly property string hMidHex: hexRgb(baseTone)
    readonly property string hBotHex: hexRgb(Qt.darker(baseTone, 1.45))
    readonly property string vTopHex: hexRgb(Qt.darker(baseTone, 2.15))
    readonly property string vMidHex: hexRgb(Qt.darker(baseTone, 2.85))
    readonly property string vBotHex: hexRgb(Qt.darker(baseTone, 4.20))
    readonly property string hlMidHex: hexRgb(Qt.tint(baseTone, "#E0FFFFFF"))
    readonly property string hlBotHex: hexRgb(Qt.tint(baseTone, "#98FFFFFF"))
    readonly property string sTopHex: hexRgb(Qt.tint(baseTone, "#68FFFFFF"))
    readonly property string sBotHex: hexRgb(Qt.lighter(baseTone, 1.12))
    readonly property string voidTopHex: hexRgb(Qt.darker(baseTone, 5.5))
    readonly property string voidRimHex: hexRgb(Qt.darker(baseTone, 2.4))

    property real shaderTime: 0.0
    property real introProgress: reduceMotion ? 1.0 : 0.0
    property real rippleProgress: 0.0
    property real hoverAmount: 0.0
    property real pointerX: 0.0
    property real pointerY: 0.0

    signal clicked
    signal animationCompleted

    readonly property string voidPath: "M 95.5 34.5 C 77.5 14.5 43.5 13.5 24.2 33.2 C 20.5 37 17.8 41.5 15.8 46.5 C 17.8 44.5 19.8 43.2 21.5 42.8 C 12.5 58.5 13.2 79.5 24.5 95.2 C 22.2 93.2 20.5 90.5 19.2 87.2 C 22.2 95.5 28.5 102.5 37.2 107.2 C 56.2 117.2 81.5 111.2 97.2 93.2 C 82.5 105.5 62.2 107.2 46.2 97.8 C 52.2 99.5 58.2 99.2 63.8 97.2 C 48.8 96.2 37.2 86.8 33.2 73.2 C 36.2 78.5 41.2 82.5 46.8 84.5 C 36.2 76.5 31.5 62.8 34.8 49.2 C 34.8 55.5 37.5 61.2 41.8 65.2 C 36.8 54.5 39.2 41.2 48.5 32.8 C 45.2 36.8 43.8 41.5 44.2 46.2 C 47.8 34.8 58.2 27.2 70.5 26.2 C 79.8 25.5 88.8 28.5 95.5 34.5 Z"
    readonly property string horizonPath: "M 92 33 C 75 17.5 44 16.5 26.5 34.5 C 23.2 38.2 20.8 42.2 19.2 46.8 C 20.8 44.8 22.4 43.8 23.8 43.5 C 15.8 58.5 16.2 78.2 26.8 92.8 C 24.8 90.8 23.2 88.2 22.2 85.2 C 24.5 92.5 30.2 99.2 38.2 103.8 C 55.5 113.5 79.5 108.2 94 92 C 80.5 103.2 61.5 104.8 46.5 95.8 C 51.5 97.2 56.8 97.2 61.5 95.5 C 47.5 94.8 36.2 86.2 31.8 73.5 C 34.5 78.2 38.8 81.8 43.8 83.8 C 33.8 76.2 29.2 63.2 32.2 50.2 C 32.2 55.8 34.5 60.8 38.2 64.5 C 33.5 54.5 35.8 42.2 44.5 34.2 C 41.8 37.8 40.5 41.8 40.8 45.8 C 44.2 35.2 54.2 27.8 66.2 26.8 C 75.5 26 84.8 28.2 92 33 Z"
    readonly property string monoCutoutPath: "M 28.5 48.5 C 27.5 52.8 28.2 57.5 30.8 61.5 C 30.2 68.5 31.2 75.5 33.8 81.8 C 38.2 92.5 47.2 100.2 58.2 103.5 C 45.2 102.2 33.8 94.8 28.2 83.8 C 22.8 72.8 23.2 59.5 28.5 48.5 Z"
    readonly property string veinsPath: "M 31.5 36.5 C 22.8 48.5 19.8 64.5 24.5 79.5 C 29.2 94.2 42.5 104.5 58.5 106.2 C 68.5 107.2 78.5 104.5 86.5 98.5 C 75.2 103.2 62.2 103.5 50.8 98.8 C 54.8 99.5 58.8 99.2 62.5 97.8 C 48.2 96.8 36.2 87.8 30.8 74.8 C 33.5 78.8 37.2 81.8 41.5 83.5 C 31.8 75.8 27.2 62.8 29.5 49.8 C 29.8 54.5 31.5 58.8 34.5 62.2 C 29.8 53.5 30.2 43.5 35.2 35.5 C 33.8 35.8 32.5 36.2 31.5 36.5 Z"
    readonly property string highlightPath: "M 74.5 24.2 C 56.5 19.2 36.8 25.8 26.8 41.2 C 21.2 49.8 19.2 60.2 20.8 70.2 C 21.2 61.5 24.2 52.8 29.8 45.8 C 27.8 50.2 26.8 54.8 27.2 59.5 C 29.5 46.8 38.2 35.5 50.5 30.2 C 46.8 32.8 43.8 36.2 41.8 40.2 C 49.5 30.5 61.8 24.8 74.5 24.2 Z"
    readonly property string p1Path: "M 96 17 Q 97 21.8 101 23 Q 97 24.2 96 29 Q 95 24.2 91 23 Q 95 21.8 96 17 Z"
    readonly property string p2Path: "M 92 77.2 Q 92.84 80.99 96 82 Q 92.84 83.01 92 86.8 Q 91.16 83.01 88 82 Q 91.16 80.99 92 77.2 Z"
    readonly property string p3Path: "M 14 29.8 Q 14.74 33.12 17.5 34 Q 14.74 34.88 14 38.2 Q 13.26 34.88 10.5 34 Q 13.26 33.12 14 29.8 Z"

    function hexRgb(c: color): string {
        const r = Math.round(c.r * 255).toString(16).padStart(2, "0");
        const g = Math.round(c.g * 255).toString(16).padStart(2, "0");
        const b = Math.round(c.b * 255).toString(16).padStart(2, "0");
        return `#${r}${g}${b}`;
    }

    function tuneHorizon(c: color): color {
        const l = Math.max(0.36, Math.min(0.68, c.hslLightness));
        return Qt.hsla(c.hslHue, c.hslSaturation, l, 1.0);
    }

    function wrapSvg(body: string): string {
        return "data:image/svg+xml;utf8," + encodeURIComponent(
            `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">${body}</svg>`
        );
    }

    implicitWidth: 164
    implicitHeight: 164

    function surge(): void {
        if (!root.reduceMotion) {
            rippleAnim.restart();
            recoilAnim.restart();
        }
    }

    Behavior on hoverAmount {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutCubic
        }
    }

    Behavior on pointerX {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutCubic
        }
    }

    Behavior on pointerY {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutCubic
        }
    }

    FrameAnimation {
        running: root.animated && !root.reduceMotion && root.visible && root.opacity > 0.01
        onTriggered: root.shaderTime += frameTime
    }

    // Scheme-adaptive crescent corona & interactive shockwave ripple
    Item {
        id: haloStage

        anchors.centerIn: parent
        width: Math.min(root.width, root.height)
        height: width
        visible: !root.monoMode

        ShaderEffect {
            anchors.fill: parent
            blending: true

            readonly property real time: root.shaderTime
            readonly property real intro: root.introProgress
            readonly property real ripple: root.rippleProgress
            readonly property real hover: root.hoverAmount
            readonly property real lightMode: root.lightSurface ? 1.0 : 0.0
            readonly property vector2d pointer: Qt.vector2d(root.pointerX, root.pointerY)
            property color auraColor: root.baseTone

            Behavior on auraColor {
                ColorAnimation {
                    duration: 380
                    easing.type: Easing.OutCubic
                }
            }

            fragmentShader: Qt.resolvedUrl("../assets/shaders/voidlogo.frag.qsb")
        }
    }

    // Scaled 128 x 128 supersampled QtSvg layers with 3D parallax, brooding idle pulse & starlight drift
    Item {
        id: stage

        property real recoilScale: 1.0
        property real recoilRotation: 0.0
        readonly property real baseScale: Math.min(root.width / root.designWidth, root.height / root.designHeight) * 0.92
        readonly property real stageW: root.designWidth * baseScale * recoilScale
        readonly property real stageH: root.designHeight * baseScale * recoilScale

        anchors.centerIn: parent
        width: stageW
        height: stageH
        rotation: recoilRotation

        // 1. Pitch-black liquid ink void aura backing the crescent moon
        Image {
            id: voidLayer

            anchors.fill: parent
            visible: !root.monoMode
            sourceSize: Qt.size(512, 512)
            smooth: true
            mipmap: true
            asynchronous: false
            transformOrigin: Item.Center
            property real introScale: root.reduceMotion ? 1.0 : 0.45
            property real introRotation: root.reduceMotion ? 0.0 : -75.0
            opacity: root.reduceMotion ? 1.0 : 0.0
            scale: introScale * (1.0 + 0.014 * Math.sin(root.shaderTime * 0.95))
            rotation: introRotation
            x: -root.pointerX * root.hoverAmount * 1.6
            y: -root.pointerY * root.hoverAmount * 1.6
            source: root.wrapSvg(
                `<defs><linearGradient id="vg" gradientUnits="userSpaceOnUse" x1="16" y1="20" x2="96" y2="108">` +
                `<stop offset="0%" stop-color="${root.voidTopHex}"/><stop offset="48%" stop-color="#050507"/><stop offset="100%" stop-color="#000000"/>` +
                `</linearGradient></defs>` +
                `<path fill="url(#vg)" stroke="${root.voidRimHex}" stroke-width="0.55" stroke-opacity="${root.lightSurface ? "0.0" : "0.55"}" d="${root.voidPath}"/>`
            )
        }

        // 2. Dimensional scheme-colored crescent moon body
        Image {
            id: horizonLayer

            anchors.fill: parent
            sourceSize: Qt.size(512, 512)
            smooth: true
            mipmap: true
            asynchronous: false
            transformOrigin: Item.Center
            property real introScale: root.reduceMotion ? 1.0 : 1.48
            property real introRotation: root.reduceMotion ? 0.0 : -110.0
            opacity: root.reduceMotion ? 1.0 : 0.0
            scale: introScale * (1.0 + 0.015 * Math.sin(root.shaderTime * 0.85))
            rotation: introRotation + 2.8 * Math.sin(root.shaderTime * 0.85) + root.pointerX * root.hoverAmount * 2.2
            x: root.pointerX * root.hoverAmount * 1.2
            y: root.pointerY * root.hoverAmount * 1.2
            source: root.monoMode
                ? root.wrapSvg(`<path fill="#FFFFFF" fill-rule="evenodd" d="${root.horizonPath} ${root.monoCutoutPath}"/>`)
                : root.wrapSvg(
                    `<defs><linearGradient id="hg" gradientUnits="userSpaceOnUse" x1="22" y1="22" x2="90" y2="106">` +
                    `<stop offset="0%" stop-color="${root.hTopHex}"/><stop offset="48%" stop-color="${root.hMidHex}"/><stop offset="100%" stop-color="${root.hBotHex}"/>` +
                    `</linearGradient></defs>` +
                    `<path fill="url(#hg)" d="${root.horizonPath}"/>`
                )
        }

        // 3. Dark inner tendrils (counter-breathing liquid depth)
        Image {
            id: veinsLayer

            anchors.fill: parent
            visible: !root.monoMode
            sourceSize: Qt.size(512, 512)
            smooth: true
            mipmap: true
            asynchronous: false
            transformOrigin: Item.Center
            property real introScale: root.reduceMotion ? 1.0 : 1.58
            property real introRotation: root.reduceMotion ? 0.0 : -130.0
            property real surgeRotation: 0.0
            opacity: root.reduceMotion ? 1.0 : 0.0
            scale: introScale * (1.0 + 0.022 * Math.sin(root.shaderTime * 1.15 + 0.8))
            rotation: introRotation + surgeRotation - 2.4 * Math.sin(root.shaderTime * 1.15 + 0.8) - root.pointerX * root.hoverAmount * 1.8
            x: root.pointerX * root.hoverAmount * 1.6
            y: root.pointerY * root.hoverAmount * 1.6
            source: root.wrapSvg(
                `<defs><linearGradient id="vng" gradientUnits="userSpaceOnUse" x1="20" y1="36" x2="86" y2="106">` +
                `<stop offset="0%" stop-color="${root.vTopHex}"/><stop offset="54%" stop-color="${root.vMidHex}"/><stop offset="100%" stop-color="${root.vBotHex}"/>` +
                `</linearGradient></defs>` +
                `<path fill="url(#vng)" d="${root.veinsPath}"/>`
            )
        }

        // 4. Moonlit upper-left specular rim highlight
        Image {
            id: highlightLayer

            anchors.fill: parent
            visible: !root.monoMode
            sourceSize: Qt.size(512, 512)
            smooth: true
            mipmap: true
            asynchronous: false
            transformOrigin: Item.Center
            opacity: horizonLayer.opacity * (0.92 + 0.08 * Math.sin(root.shaderTime * 1.7))
            scale: horizonLayer.scale
            rotation: horizonLayer.rotation
            x: root.pointerX * root.hoverAmount * 2.1
            y: root.pointerY * root.hoverAmount * 2.1
            source: root.wrapSvg(
                `<defs><linearGradient id="hlg" gradientUnits="userSpaceOnUse" x1="20" y1="22" x2="74" y2="70">` +
                `<stop offset="0%" stop-color="#FFFFFF"/><stop offset="58%" stop-color="${root.hlMidHex}"/><stop offset="100%" stop-color="${root.hlBotHex}"/>` +
                `</linearGradient></defs>` +
                `<path fill="url(#hlg)" d="${root.highlightPath}"/>`
            )
        }

        // 5. Three 4-point scheme-tinted stars with orbital drift & twinkle
        Image {
            id: star1Layer

            anchors.fill: parent
            sourceSize: Qt.size(512, 512)
            smooth: true
            mipmap: true
            asynchronous: false
            transformOrigin: Item.Center
            property real introOpacity: root.reduceMotion ? 1.0 : 0.0
            property real introScale: root.reduceMotion ? 1.0 : 0.0
            opacity: introOpacity * (0.86 + 0.14 * Math.sin(root.shaderTime * 1.8))
            scale: introScale * (1.0 + 0.05 * Math.sin(root.shaderTime * 1.8))
            x: 1.3 * Math.sin(root.shaderTime * 1.35) + root.pointerX * root.hoverAmount * 2.6
            y: -1.1 * Math.cos(root.shaderTime * 1.35) + root.pointerY * root.hoverAmount * 2.6
            source: root.monoMode
                ? root.wrapSvg(`<path fill="#FFFFFF" d="${root.p1Path}"/>`)
                : root.wrapSvg(
                    `<defs><linearGradient id="sg1" gradientUnits="userSpaceOnUse" x1="91" y1="17" x2="101" y2="29">` +
                    `<stop offset="0%" stop-color="${root.sTopHex}"/><stop offset="100%" stop-color="${root.sBotHex}"/>` +
                    `</linearGradient></defs>` +
                    `<path fill="url(#sg1)" d="${root.p1Path}"/>`
                )
        }

        Image {
            id: star2Layer

            anchors.fill: parent
            sourceSize: Qt.size(512, 512)
            smooth: true
            mipmap: true
            asynchronous: false
            transformOrigin: Item.Center
            property real introOpacity: root.reduceMotion ? 1.0 : 0.0
            property real introScale: root.reduceMotion ? 1.0 : 0.0
            opacity: introOpacity * (0.84 + 0.16 * Math.sin(root.shaderTime * 2.1 + 1.7))
            scale: introScale * (1.0 + 0.05 * Math.sin(root.shaderTime * 2.1 + 1.7))
            x: -1.3 * Math.cos(root.shaderTime * 1.2 + 1.2) + root.pointerX * root.hoverAmount * 2.4
            y: 1.0 * Math.sin(root.shaderTime * 1.2 + 1.2) + root.pointerY * root.hoverAmount * 2.4
            source: root.monoMode
                ? root.wrapSvg(`<path fill="#FFFFFF" d="${root.p2Path}"/>`)
                : root.wrapSvg(
                    `<defs><linearGradient id="sg2" gradientUnits="userSpaceOnUse" x1="88" y1="77" x2="96" y2="87">` +
                    `<stop offset="0%" stop-color="${root.sTopHex}"/><stop offset="100%" stop-color="${root.sBotHex}"/>` +
                    `</linearGradient></defs>` +
                    `<path fill="url(#sg2)" d="${root.p2Path}"/>`
                )
        }

        Image {
            id: star3Layer

            anchors.fill: parent
            sourceSize: Qt.size(512, 512)
            smooth: true
            mipmap: true
            asynchronous: false
            transformOrigin: Item.Center
            property real introOpacity: root.reduceMotion ? 1.0 : 0.0
            property real introScale: root.reduceMotion ? 1.0 : 0.0
            opacity: introOpacity * (0.84 + 0.16 * Math.sin(root.shaderTime * 1.6 + 3.4))
            scale: introScale * (1.0 + 0.05 * Math.sin(root.shaderTime * 1.6 + 3.4))
            x: -1.2 * Math.sin(root.shaderTime * 1.1 + 2.5) + root.pointerX * root.hoverAmount * 2.2
            y: -1.0 * Math.cos(root.shaderTime * 1.1 + 2.5) + root.pointerY * root.hoverAmount * 2.2
            source: root.monoMode
                ? root.wrapSvg(`<path fill="#FFFFFF" d="${root.p3Path}"/>`)
                : root.wrapSvg(
                    `<defs><linearGradient id="sg3" gradientUnits="userSpaceOnUse" x1="10" y1="29" x2="18" y2="39">` +
                    `<stop offset="0%" stop-color="${root.sTopHex}"/><stop offset="100%" stop-color="${root.sBotHex}"/>` +
                    `</linearGradient></defs>` +
                    `<path fill="url(#sg3)" d="${root.p3Path}"/>`
                )
        }
    }

    ParallelAnimation {
        id: openAnim

        running: !root.reduceMotion
        onFinished: root.animationCompleted()

        NumberAnimation {
            target: root
            property: "introProgress"
            from: 0.0
            to: 1.0
            duration: 950
            easing.type: Easing.OutCubic
        }

        // 1. Void ink aura slash-in
        ParallelAnimation {
            NumberAnimation {
                target: voidLayer
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 240
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: voidLayer
                property: "introRotation"
                from: -75.0
                to: 0.0
                duration: 680
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: voidLayer
                property: "introScale"
                from: 0.45
                to: 1.0
                duration: 680
                easing.type: Easing.OutBack
            }
        }

        // 2. Crescent moon slash-in
        SequentialAnimation {
            PauseAnimation {
                duration: 120
            }

            ParallelAnimation {
                NumberAnimation {
                    target: horizonLayer
                    property: "opacity"
                    from: 0.0
                    to: 1.0
                    duration: 220
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: horizonLayer
                    property: "introScale"
                    from: 1.48
                    to: 1.0
                    duration: 860
                    easing.type: Easing.OutExpo
                }

                NumberAnimation {
                    target: horizonLayer
                    property: "introRotation"
                    from: -110.0
                    to: 0.0
                    duration: 860
                    easing.type: Easing.OutExpo
                }
            }
        }

        // 3. Inner veins whip-in
        SequentialAnimation {
            PauseAnimation {
                duration: 160
            }

            ParallelAnimation {
                NumberAnimation {
                    target: veinsLayer
                    property: "opacity"
                    from: 0.0
                    to: 1.0
                    duration: 240
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: veinsLayer
                    property: "introScale"
                    from: 1.58
                    to: 1.0
                    duration: 900
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: veinsLayer
                    property: "introRotation"
                    from: -130.0
                    to: 0.0
                    duration: 900
                    easing.type: Easing.OutCubic
                }
            }
        }

        // 4. Three stars staggered pop-in
        SequentialAnimation {
            PauseAnimation {
                duration: 420
            }

            ParallelAnimation {
                NumberAnimation {
                    target: star1Layer
                    property: "introOpacity"
                    from: 0.0
                    to: 1.0
                    duration: 260
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: star1Layer
                    property: "introScale"
                    from: 0.0
                    to: 1.0
                    duration: 400
                    easing.type: Easing.OutBack
                }
            }
        }

        SequentialAnimation {
            PauseAnimation {
                duration: 510
            }

            ParallelAnimation {
                NumberAnimation {
                    target: star2Layer
                    property: "introOpacity"
                    from: 0.0
                    to: 1.0
                    duration: 260
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: star2Layer
                    property: "introScale"
                    from: 0.0
                    to: 1.0
                    duration: 380
                    easing.type: Easing.OutBack
                }
            }
        }

        SequentialAnimation {
            PauseAnimation {
                duration: 600
            }

            ParallelAnimation {
                NumberAnimation {
                    target: star3Layer
                    property: "introOpacity"
                    from: 0.0
                    to: 1.0
                    duration: 260
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: star3Layer
                    property: "introScale"
                    from: 0.0
                    to: 1.0
                    duration: 380
                    easing.type: Easing.OutBack
                }
            }
        }
    }

    NumberAnimation {
        id: rippleAnim

        target: root
        property: "rippleProgress"
        from: 0.0
        to: 1.0
        duration: 780
        easing.type: Easing.OutCubic
    }

    ParallelAnimation {
        id: recoilAnim

        SequentialAnimation {
            NumberAnimation {
                target: stage
                property: "recoilScale"
                to: 0.93
                duration: 110
                easing.type: Easing.OutQuad
            }

            NumberAnimation {
                target: stage
                property: "recoilScale"
                to: 1.06
                duration: 220
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: stage
                property: "recoilScale"
                to: 1.0
                duration: 340
                easing.type: Easing.OutCubic
            }
        }

        SequentialAnimation {
            NumberAnimation {
                target: stage
                property: "recoilRotation"
                to: -6.5
                duration: 110
                easing.type: Easing.OutQuad
            }

            NumberAnimation {
                target: stage
                property: "recoilRotation"
                to: 2.0
                duration: 220
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: stage
                property: "recoilRotation"
                to: 0.0
                duration: 340
                easing.type: Easing.OutCubic
            }
        }

        SequentialAnimation {
            NumberAnimation {
                target: veinsLayer
                property: "surgeRotation"
                to: -9.0
                duration: 160
                easing.type: Easing.OutQuad
            }

            NumberAnimation {
                target: veinsLayer
                property: "surgeRotation"
                to: 0.0
                duration: 440
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        visible: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hoverAmount = 1.0
        onExited: {
            root.hoverAmount = 0.0;
            root.pointerX = 0.0;
            root.pointerY = 0.0;
        }
        onPositionChanged: mouse => {
            if (width <= 0 || height <= 0)
                return;
            root.pointerX = ((mouse.x / width) - 0.5) * 2.0;
            root.pointerY = ((mouse.y / height) - 0.5) * 2.0;
        }
        onClicked: {
            root.surge();
            root.clicked();
        }
    }
}

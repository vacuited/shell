pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.components
import qs.services

Item {
    id: root

    implicitWidth: 128
    implicitHeight: 128

    // Material 3 / Caelestia dark-crimson palette bindings
    property color voidColor: "#000000"
    property color horizonColor: "#E6002B"
    property color veinsColor: "#4A000E"
    property color highlightColor: "#FFF0F3"
    property color particleColor: "#FF1F4B"

    property alias ringColour: root.horizonColor
    property alias highlightColour: root.highlightColor
    property alias particleColour: root.particleColor
    property alias voidColour: root.voidColor

    property bool monoMode: false
    property bool skipIntroAnimation: false
    property bool reduceMotion: skipIntroAnimation

    signal animationCompleted

    readonly property real scaleFactor: Math.min(width, height) / 128.0

    // Call surge() on launcher open, workspace switch, or hover
    function surge() {
        if (!root.reduceMotion) {
            surgeAnim.restart();
        }
    }

    Item {
        id: scene

        width: 128
        height: 128
        anchors.centerIn: parent
        scale: root.scaleFactor

        // 1. VOID
        Shape {
            id: voidLayer

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            visible: !root.monoMode
            scale: root.reduceMotion ? 1.0 : 0.0
            transformOrigin: Item.Center

            ShapePath {
                strokeWidth: -1
                strokeColor: "transparent"
                fillColor: root.voidColor

                PathSvg {
                    path: "M 30 64 A 34 34 0 1 1 98 64 A 34 34 0 1 1 30 64 Z"
                }
            }
        }

        // 2. HORIZON (Main Bloody Moon Body)
        Item {
            id: horizonIdle

            anchors.fill: parent
            transformOrigin: Item.Center

            Shape {
                id: horizonLayer

                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                transformOrigin: Item.Center
                scale: root.reduceMotion ? 1.0 : 1.6
                rotation: root.reduceMotion ? 0.0 : -120.0
                opacity: root.reduceMotion ? 1.0 : 0.0

                ShapePath {
                    strokeWidth: -1
                    strokeColor: "transparent"
                    fillColor: root.monoMode ? "#FFFFFF" : root.horizonColor

                    PathSvg {
                        path: root.monoMode
                            ? "M 23.5 85.6 A 41.2 38.2 -28.07 1 1 96.25 46.8 A 41.2 38.2 -28.07 1 1 23.5 85.6 Z M 80 94 A 34 34 0 0 0 48 34 C 40.8 37.5 36 43.2 34.5 49.5 C 36.5 48.2 38.5 48 40.5 48.8 C 35.5 52.5 32.8 57.8 32.2 63.8 C 34.8 62.5 37.2 62.4 39.8 63.5 C 36.2 67.8 34.8 73.5 35.8 79.2 C 38.2 78 40.8 77.8 43.5 78.8 C 42.8 84 46.2 89.5 53.8 93.2 C 61.8 96.8 71.2 96.8 80 94 Z M 33.5 40.5 C 26.2 48.5 22.4 59.5 22.8 70.8 C 23.5 82.8 30.8 92.8 43.2 97.2 C 50.8 99.8 59.2 100.2 66.8 98.8 C 55.8 98.2 45.2 94.2 39.2 86.8 C 40.8 87.2 42.5 87 44.2 86.2 C 37.5 83.5 32.8 78.2 31.2 71.8 C 32.8 72.2 34.5 72 36.2 71.2 C 30.8 68.2 27.8 62.8 27.5 56.5 C 29.2 57 30.8 56.8 32.5 56 C 29.5 51.8 29.8 45.8 33.5 40.5 Z"
                            : "M 23.5 85.6 A 41.2 38.2 -28.07 1 1 96.25 46.8 A 41.2 38.2 -28.07 1 1 23.5 85.6 Z M 80 94 A 34 34 0 0 0 48 34 C 40.8 37.5 36 43.2 34.5 49.5 C 36.5 48.2 38.5 48 40.5 48.8 C 35.5 52.5 32.8 57.8 32.2 63.8 C 34.8 62.5 37.2 62.4 39.8 63.5 C 36.2 67.8 34.8 73.5 35.8 79.2 C 38.2 78 40.8 77.8 43.5 78.8 C 42.8 84 46.2 89.5 53.8 93.2 C 61.8 96.8 71.2 96.8 80 94 Z"
                    }
                }
            }
        }

        // 3. HORIZON-VEINS (Dark Coagulated Blood Layer)
        Item {
            id: veinsIdle

            anchors.fill: parent
            transformOrigin: Item.Center
            visible: !root.monoMode

            Shape {
                id: veinsLayer

                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                transformOrigin: Item.Center
                scale: root.reduceMotion ? 1.0 : 1.68
                rotation: root.reduceMotion ? 0.0 : -138.0
                opacity: root.reduceMotion ? 1.0 : 0.0

                ShapePath {
                    strokeWidth: -1
                    strokeColor: "transparent"
                    fillColor: root.veinsColor

                    PathSvg {
                        path: "M 33.5 40.5 C 26.2 48.5 22.4 59.5 22.8 70.8 C 23.5 82.8 30.8 92.8 43.2 97.2 C 50.8 99.8 59.2 100.2 66.8 98.8 C 55.8 98.2 45.2 94.2 39.2 86.8 C 40.8 87.2 42.5 87 44.2 86.2 C 37.5 83.5 32.8 78.2 31.2 71.8 C 32.8 72.2 34.5 72 36.2 71.2 C 30.8 68.2 27.8 62.8 27.5 56.5 C 29.2 57 30.8 56.8 32.5 56 C 29.5 51.8 29.8 45.8 33.5 40.5 Z"
                    }
                }
            }
        }

        // 4. HORIZON-HIGHLIGHT (Bright Moonlit Rim Sliver)
        Shape {
            id: highlightLayer

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            visible: !root.monoMode
            transformOrigin: Item.Center
            scale: horizonLayer.scale
            rotation: horizonLayer.rotation + horizonIdle.rotation
            opacity: horizonLayer.opacity

            ShapePath {
                strokeWidth: -1
                strokeColor: "transparent"
                fillColor: root.highlightColor

                PathSvg {
                    path: "M 64 30 C 58.5 30 53 31.4 48 34 C 40.8 37.5 36 43.2 34.5 49.5 C 36.5 48.2 38.5 48 40.5 48.8 C 35.5 52.5 32.8 57.8 32.2 63.8 C 34.8 62.5 37.2 62.4 39.8 63.5 C 36.2 67.8 34.8 73.5 35.8 79.2 C 33.2 73.2 33.8 67.2 36.8 62.8 C 34.4 62 32 62.4 29.8 64 C 30.4 57.2 33.2 51.5 37.5 47.8 C 35.4 47.2 33.4 47.8 31.8 49.5 C 33.8 42.2 39.2 35.8 47.2 32.2 C 52.5 29.8 58.2 29.2 64 30 Z"
                }
            }
        }

        // 5. BLOOD DROPLETS / SPLASHES
        Shape {
            id: p1

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            transformOrigin: Item.Center
            opacity: root.reduceMotion ? 1.0 : 0.0

            property real ox: root.reduceMotion ? 0.0 : -5.2
            property real oy: root.reduceMotion ? 0.0 : -3.2
            property real dx: 0.0
            property real dy: 0.0
            property real rotAngle: root.reduceMotion ? 0.0 : -18.0

            transform: [
                Translate {
                    x: p1.ox + p1.dx
                    y: p1.oy + p1.dy
                },
                Rotation {
                    origin.x: 64
                    origin.y: 64
                    angle: p1.rotAngle
                }
            ]

            ShapePath {
                strokeWidth: -1
                strokeColor: "transparent"
                fillColor: root.monoMode ? "#FFFFFF" : root.particleColor

                PathSvg {
                    path: "M 22.8 38.8 C 17.5 37.8 12.2 35.2 9.2 31.2 C 7.5 28.8 9.2 25.8 12.2 26.8 C 15.8 28.2 18.8 32.2 22.8 38.8 Z"
                }
            }
        }

        Shape {
            id: p2

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            transformOrigin: Item.Center
            opacity: root.reduceMotion ? 1.0 : 0.0

            property real ox: root.reduceMotion ? 0.0 : 4.8
            property real oy: root.reduceMotion ? 0.0 : -3.6
            property real dx: 0.0
            property real dy: 0.0
            property real rotAngle: root.reduceMotion ? 0.0 : -18.0

            transform: [
                Translate {
                    x: p2.ox + p2.dx
                    y: p2.oy + p2.dy
                },
                Rotation {
                    origin.x: 64
                    origin.y: 64
                    angle: p2.rotAngle
                }
            ]

            ShapePath {
                strokeWidth: -1
                strokeColor: "transparent"
                fillColor: root.monoMode ? "#FFFFFF" : root.particleColor

                PathSvg {
                    path: "M 99.5 33.5 C 102.2 29.2 105.8 25.5 109.5 24.2 C 111.8 23.5 113.2 25.8 111.2 28.2 C 108.8 31.2 104.5 32.8 99.5 33.5 Z"
                }
            }
        }

        Shape {
            id: p3

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            transformOrigin: Item.Center
            opacity: root.reduceMotion ? 1.0 : 0.0

            property real ox: root.reduceMotion ? 0.0 : 3.8
            property real oy: root.reduceMotion ? 0.0 : 4.4
            property real dx: 0.0
            property real dy: 0.0
            property real rotAngle: root.reduceMotion ? 0.0 : -18.0

            transform: [
                Translate {
                    x: p3.ox + p3.dx
                    y: p3.oy + p3.dy
                },
                Rotation {
                    origin.x: 64
                    origin.y: 64
                    angle: p3.rotAngle
                }
            ]

            ShapePath {
                strokeWidth: -1
                strokeColor: "transparent"
                fillColor: root.monoMode ? "#FFFFFF" : root.particleColor

                PathSvg {
                    path: "M 90.5 101.8 C 94.8 102.5 99.2 104.5 101.8 107.8 C 103.2 109.8 101.2 111.8 98.8 110.2 C 95.8 108.2 93.2 105.2 90.5 101.8 Z"
                }
            }
        }
    }

    // INTERACTIVE SURGE PULSE (on hover / click / trigger)
    ParallelAnimation {
        id: surgeAnim

        SequentialAnimation {
            NumberAnimation {
                target: horizonLayer
                property: "scale"
                to: 1.06
                duration: 160
                easing.type: Easing.OutQuad
            }

            NumberAnimation {
                target: horizonLayer
                property: "scale"
                to: 1.0
                duration: 420
                easing.type: Easing.OutElastic
            }
        }

        SequentialAnimation {
            NumberAnimation {
                target: veinsLayer
                property: "rotation"
                to: -8.0
                duration: 180
                easing.type: Easing.OutQuad
            }

            NumberAnimation {
                target: veinsLayer
                property: "rotation"
                to: 0.0
                duration: 460
                easing.type: Easing.OutCubic
            }
        }
    }

    // OPEN + IDLE BROODING PULSE ANIMATION
    ParallelAnimation {
        id: openAnim

        running: !root.reduceMotion
        onFinished: root.animationCompleted()

        // 1. Void expansion (0 -> 700ms)
        SequentialAnimation {
            NumberAnimation {
                target: voidLayer
                property: "scale"
                from: 0.0
                to: 1.03
                duration: 545
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: voidLayer
                property: "scale"
                from: 1.03
                to: 1.0
                duration: 155
                easing.type: Easing.InOutQuad
            }
        }

        // 2a. Main Bloody Crescent Slash-In (200 -> 1300ms) + Idle Pulse
        SequentialAnimation {
            PauseAnimation {
                duration: 200
            }

            ParallelAnimation {
                NumberAnimation {
                    target: horizonLayer
                    property: "opacity"
                    from: 0.0
                    to: 1.0
                    duration: 200
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: horizonLayer
                    property: "scale"
                    from: 1.6
                    to: 1.0
                    duration: 1100
                    easing.type: Easing.OutExpo
                }

                NumberAnimation {
                    target: horizonLayer
                    property: "rotation"
                    from: -120.0
                    to: 0.0
                    duration: 1100
                    easing.type: Easing.OutExpo
                }
            }

            SequentialAnimation {
                loops: Animation.Infinite

                ParallelAnimation {
                    NumberAnimation {
                        target: horizonIdle
                        property: "rotation"
                        from: 0.0
                        to: 3.5
                        duration: 6400
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: horizonIdle
                        property: "scale"
                        from: 1.0
                        to: 1.015
                        duration: 6400
                        easing.type: Easing.InOutSine
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: horizonIdle
                        property: "rotation"
                        from: 3.5
                        to: 0.0
                        duration: 6400
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: horizonIdle
                        property: "scale"
                        from: 1.015
                        to: 1.0
                        duration: 6400
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }

        // 2b. Coagulated Veins Whip-In (240 -> 1360ms) + Counter-Pulse
        SequentialAnimation {
            PauseAnimation {
                duration: 240
            }

            ParallelAnimation {
                NumberAnimation {
                    target: veinsLayer
                    property: "opacity"
                    from: 0.0
                    to: 1.0
                    duration: 220
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: veinsLayer
                    property: "scale"
                    from: 1.68
                    to: 1.0
                    duration: 1120
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: veinsLayer
                    property: "rotation"
                    from: -138.0
                    to: 0.0
                    duration: 1120
                    easing.type: Easing.OutCubic
                }
            }

            SequentialAnimation {
                loops: Animation.Infinite

                ParallelAnimation {
                    NumberAnimation {
                        target: veinsIdle
                        property: "rotation"
                        from: 0.0
                        to: -2.5
                        duration: 4800
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: veinsIdle
                        property: "scale"
                        from: 1.0
                        to: 1.025
                        duration: 4800
                        easing.type: Easing.InOutSine
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: veinsIdle
                        property: "rotation"
                        from: -2.5
                        to: 0.0
                        duration: 4800
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: veinsIdle
                        property: "scale"
                        from: 1.025
                        to: 1.0
                        duration: 4800
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }

        // 3a. Droplet 1 (800 -> 1360ms + idle drift)
        SequentialAnimation {
            PauseAnimation {
                duration: 800
            }

            ParallelAnimation {
                NumberAnimation {
                    target: p1
                    property: "opacity"
                    from: 0.0
                    to: 1.0
                    duration: 560
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: p1
                    property: "ox"
                    from: -5.2
                    to: 0.0
                    duration: 560
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: p1
                    property: "oy"
                    from: -3.2
                    to: 0.0
                    duration: 560
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: p1
                    property: "rotAngle"
                    from: -18.0
                    to: 0.0
                    duration: 560
                    easing.type: Easing.OutCubic
                }
            }

            SequentialAnimation {
                loops: Animation.Infinite

                ParallelAnimation {
                    NumberAnimation {
                        target: p1
                        property: "dx"
                        from: 0.0
                        to: 1.8
                        duration: 2300
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p1
                        property: "dy"
                        from: 0.0
                        to: 1.1
                        duration: 2300
                        easing.type: Easing.InOutSine
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: p1
                        property: "dx"
                        from: 1.8
                        to: -1.4
                        duration: 4600
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p1
                        property: "dy"
                        from: 1.1
                        to: -0.9
                        duration: 4600
                        easing.type: Easing.InOutSine
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: p1
                        property: "dx"
                        from: -1.4
                        to: 0.0
                        duration: 2300
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p1
                        property: "dy"
                        from: -0.9
                        to: 0.0
                        duration: 2300
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }

        // 3b. Droplet 2 (920 -> 1480ms + idle drift)
        SequentialAnimation {
            PauseAnimation {
                duration: 920
            }

            ParallelAnimation {
                NumberAnimation {
                    target: p2
                    property: "opacity"
                    from: 0.0
                    to: 1.0
                    duration: 560
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: p2
                    property: "ox"
                    from: 4.8
                    to: 0.0
                    duration: 560
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: p2
                    property: "oy"
                    from: -3.6
                    to: 0.0
                    duration: 560
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: p2
                    property: "rotAngle"
                    from: -18.0
                    to: 0.0
                    duration: 560
                    easing.type: Easing.OutCubic
                }
            }

            SequentialAnimation {
                loops: Animation.Infinite

                ParallelAnimation {
                    NumberAnimation {
                        target: p2
                        property: "dx"
                        from: 0.0
                        to: -1.6
                        duration: 2600
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p2
                        property: "dy"
                        from: 0.0
                        to: 1.2
                        duration: 2600
                        easing.type: Easing.InOutSine
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: p2
                        property: "dx"
                        from: -1.6
                        to: 1.2
                        duration: 5200
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p2
                        property: "dy"
                        from: 1.2
                        to: -1.0
                        duration: 5200
                        easing.type: Easing.InOutSine
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: p2
                        property: "dx"
                        from: 1.2
                        to: 0.0
                        duration: 2600
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p2
                        property: "dy"
                        from: -1.0
                        to: 0.0
                        duration: 2600
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }

        // 3c. Droplet 3 (1040 -> 1600ms + idle drift)
        SequentialAnimation {
            PauseAnimation {
                duration: 1040
            }

            ParallelAnimation {
                NumberAnimation {
                    target: p3
                    property: "opacity"
                    from: 0.0
                    to: 1.0
                    duration: 560
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: p3
                    property: "ox"
                    from: 3.8
                    to: 0.0
                    duration: 560
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: p3
                    property: "oy"
                    from: 4.4
                    to: 0.0
                    duration: 560
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: p3
                    property: "rotAngle"
                    from: -18.0
                    to: 0.0
                    duration: 560
                    easing.type: Easing.OutCubic
                }
            }

            SequentialAnimation {
                loops: Animation.Infinite

                ParallelAnimation {
                    NumberAnimation {
                        target: p3
                        property: "dx"
                        from: 0.0
                        to: -1.3
                        duration: 2900
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p3
                        property: "dy"
                        from: 0.0
                        to: -1.6
                        duration: 2900
                        easing.type: Easing.InOutSine
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: p3
                        property: "dx"
                        from: -1.3
                        to: 1.1
                        duration: 5800
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p3
                        property: "dy"
                        from: -1.6
                        to: 1.3
                        duration: 5800
                        easing.type: Easing.InOutSine
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: p3
                        property: "dx"
                        from: 1.1
                        to: 0.0
                        duration: 2900
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p3
                        property: "dy"
                        from: 1.3
                        to: 0.0
                        duration: 2900
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }
}

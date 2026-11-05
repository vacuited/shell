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

        // 1. VOID (Pitch-black liquid ink aura backing the crescent moon)
        Shape {
            id: voidLayer

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            visible: !root.monoMode
            scale: root.reduceMotion ? 1.0 : 0.4
            rotation: root.reduceMotion ? 0.0 : -90.0
            opacity: root.reduceMotion ? 1.0 : 0.0
            transformOrigin: Item.Center

            ShapePath {
                strokeWidth: -1
                strokeColor: "transparent"
                fillColor: root.voidColor

                PathSvg {
                    path: "M 95.5 34.5 C 77.5 14.5 43.5 13.5 24.2 33.2 C 20.5 37 17.8 41.5 15.8 46.5 C 17.8 44.5 19.8 43.2 21.5 42.8 C 12.5 58.5 13.2 79.5 24.5 95.2 C 22.2 93.2 20.5 90.5 19.2 87.2 C 22.2 95.5 28.5 102.5 37.2 107.2 C 56.2 117.2 81.5 111.2 97.2 93.2 C 82.5 105.5 62.2 107.2 46.2 97.8 C 52.2 99.5 58.2 99.2 63.8 97.2 C 48.8 96.2 37.2 86.8 33.2 73.2 C 36.2 78.5 41.2 82.5 46.8 84.5 C 36.2 76.5 31.5 62.8 34.8 49.2 C 34.8 55.5 37.5 61.2 41.8 65.2 C 36.8 54.5 39.2 41.2 48.5 32.8 C 45.2 36.8 43.8 41.5 44.2 46.2 C 47.8 34.8 58.2 27.2 70.5 26.2 C 79.8 25.5 88.8 28.5 95.5 34.5 Z"
                }
            }
        }

        // 2. HORIZON (Main Bloody Crescent Moon Body)
        Item {
            id: horizonIdle

            anchors.fill: parent
            transformOrigin: Item.Center

            Shape {
                id: horizonLayer

                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                transformOrigin: Item.Center
                scale: root.reduceMotion ? 1.0 : 1.55
                rotation: root.reduceMotion ? 0.0 : -120.0
                opacity: root.reduceMotion ? 1.0 : 0.0

                ShapePath {
                    strokeWidth: -1
                    strokeColor: "transparent"
                    fillColor: root.monoMode ? "#FFFFFF" : root.horizonColor

                    PathSvg {
                        path: root.monoMode
                            ? "M 92 33 C 75 17.5 44 16.5 26.5 34.5 C 23.2 38.2 20.8 42.2 19.2 46.8 C 20.8 44.8 22.4 43.8 23.8 43.5 C 15.8 58.5 16.2 78.2 26.8 92.8 C 24.8 90.8 23.2 88.2 22.2 85.2 C 24.5 92.5 30.2 99.2 38.2 103.8 C 55.5 113.5 79.5 108.2 94 92 C 80.5 103.2 61.5 104.8 46.5 95.8 C 51.5 97.2 56.8 97.2 61.5 95.5 C 47.5 94.8 36.2 86.2 31.8 73.5 C 34.5 78.2 38.8 81.8 43.8 83.8 C 33.8 76.2 29.2 63.2 32.2 50.2 C 32.2 55.8 34.5 60.8 38.2 64.5 C 33.5 54.5 35.8 42.2 44.5 34.2 C 41.8 37.8 40.5 41.8 40.8 45.8 C 44.2 35.2 54.2 27.8 66.2 26.8 C 75.5 26 84.8 28.2 92 33 Z M 28.5 48.5 C 27.5 52.8 28.2 57.5 30.8 61.5 C 30.2 68.5 31.2 75.5 33.8 81.8 C 38.2 92.5 47.2 100.2 58.2 103.5 C 45.2 102.2 33.8 94.8 28.2 83.8 C 22.8 72.8 23.2 59.5 28.5 48.5 Z"
                            : "M 92 33 C 75 17.5 44 16.5 26.5 34.5 C 23.2 38.2 20.8 42.2 19.2 46.8 C 20.8 44.8 22.4 43.8 23.8 43.5 C 15.8 58.5 16.2 78.2 26.8 92.8 C 24.8 90.8 23.2 88.2 22.2 85.2 C 24.5 92.5 30.2 99.2 38.2 103.8 C 55.5 113.5 79.5 108.2 94 92 C 80.5 103.2 61.5 104.8 46.5 95.8 C 51.5 97.2 56.8 97.2 61.5 95.5 C 47.5 94.8 36.2 86.2 31.8 73.5 C 34.5 78.2 38.8 81.8 43.8 83.8 C 33.8 76.2 29.2 63.2 32.2 50.2 C 32.2 55.8 34.5 60.8 38.2 64.5 C 33.5 54.5 35.8 42.2 44.5 34.2 C 41.8 37.8 40.5 41.8 40.8 45.8 C 44.2 35.2 54.2 27.8 66.2 26.8 C 75.5 26 84.8 28.2 92 33 Z"
                    }
                }
            }
        }

        // 3. HORIZON-VEINS (Dark Coagulated Blood Tendrils)
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
                scale: root.reduceMotion ? 1.0 : 1.65
                rotation: root.reduceMotion ? 0.0 : -138.0
                opacity: root.reduceMotion ? 1.0 : 0.0

                ShapePath {
                    strokeWidth: -1
                    strokeColor: "transparent"
                    fillColor: root.veinsColor

                    PathSvg {
                        path: "M 31.5 36.5 C 22.8 48.5 19.8 64.5 24.5 79.5 C 29.2 94.2 42.5 104.5 58.5 106.2 C 68.5 107.2 78.5 104.5 86.5 98.5 C 75.2 103.2 62.2 103.5 50.8 98.8 C 54.8 99.5 58.8 99.2 62.5 97.8 C 48.2 96.8 36.2 87.8 30.8 74.8 C 33.5 78.8 37.2 81.8 41.5 83.5 C 31.8 75.8 27.2 62.8 29.5 49.8 C 29.8 54.5 31.5 58.8 34.5 62.2 C 29.8 53.5 30.2 43.5 35.2 35.5 C 33.8 35.8 32.5 36.2 31.5 36.5 Z"
                    }
                }
            }
        }

        // 4. HORIZON-HIGHLIGHT (Bright Moonlit Upper-Left Rim Sliver)
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
                    path: "M 74.5 24.2 C 56.5 19.2 36.8 25.8 26.8 41.2 C 21.2 49.8 19.2 60.2 20.8 70.2 C 21.2 61.5 24.2 52.8 29.8 45.8 C 27.8 50.2 26.8 54.8 27.2 59.5 C 29.5 46.8 38.2 35.5 50.5 30.2 C 46.8 32.8 43.8 36.2 41.8 40.2 C 49.5 30.5 61.8 24.8 74.5 24.2 Z"
                }
            }
        }

        // 5. THREE 4-POINT CRIMSON STARS
        Shape {
            id: p1

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            transformOrigin: Item.Center
            opacity: root.reduceMotion ? 1.0 : 0.0

            property real ox: root.reduceMotion ? 0.0 : 4.2
            property real oy: root.reduceMotion ? 0.0 : -4.2
            property real dx: 0.0
            property real dy: 0.0
            property real rotAngle: root.reduceMotion ? 0.0 : -16.0

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
                    path: "M 96 17 Q 97 21.8 101 23 Q 97 24.2 96 29 Q 95 24.2 91 23 Q 95 21.8 96 17 Z"
                }
            }
        }

        Shape {
            id: p2

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            transformOrigin: Item.Center
            opacity: root.reduceMotion ? 1.0 : 0.0

            property real ox: root.reduceMotion ? 0.0 : 4.2
            property real oy: root.reduceMotion ? 0.0 : 2.8
            property real dx: 0.0
            property real dy: 0.0
            property real rotAngle: root.reduceMotion ? 0.0 : -16.0

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
                    path: "M 92 77.2 Q 92.84 80.99 96 82 Q 92.84 83.01 92 86.8 Q 91.16 83.01 88 82 Q 91.16 80.99 92 77.2 Z"
                }
            }
        }

        Shape {
            id: p3

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            transformOrigin: Item.Center
            opacity: root.reduceMotion ? 1.0 : 0.0

            property real ox: root.reduceMotion ? 0.0 : -4.8
            property real oy: root.reduceMotion ? 0.0 : -2.8
            property real dx: 0.0
            property real dy: 0.0
            property real rotAngle: root.reduceMotion ? 0.0 : -16.0

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
                    path: "M 14 29.8 Q 14.74 33.12 17.5 34 Q 14.74 34.88 14 38.2 Q 13.26 34.88 10.5 34 Q 13.26 33.12 14 29.8 Z"
                }
            }
        }
    }

    // INTERACTIVE SURGE PULSE
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

        // 1. Void aura slash-in (0 -> 700ms)
        ParallelAnimation {
            NumberAnimation {
                target: voidLayer
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 220
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: voidLayer
                property: "rotation"
                from: -90.0
                to: 0.0
                duration: 700
                easing.type: Easing.OutCubic
            }

            SequentialAnimation {
                NumberAnimation {
                    target: voidLayer
                    property: "scale"
                    from: 0.4
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
                    from: 1.55
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
                    from: 1.65
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

        // 3a. Star 1 (800 -> 1360ms + idle drift)
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
                    from: 4.2
                    to: 0.0
                    duration: 560
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: p1
                    property: "oy"
                    from: -4.2
                    to: 0.0
                    duration: 560
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: p1
                    property: "rotAngle"
                    from: -16.0
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
                        to: 1.4
                        duration: 2300
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p1
                        property: "dy"
                        from: 0.0
                        to: -1.2
                        duration: 2300
                        easing.type: Easing.InOutSine
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: p1
                        property: "dx"
                        from: 1.4
                        to: -1.2
                        duration: 4600
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p1
                        property: "dy"
                        from: -1.2
                        to: 1.0
                        duration: 4600
                        easing.type: Easing.InOutSine
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: p1
                        property: "dx"
                        from: -1.2
                        to: 0.0
                        duration: 2300
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p1
                        property: "dy"
                        from: 1.0
                        to: 0.0
                        duration: 2300
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }

        // 3b. Star 2 (920 -> 1480ms + idle drift)
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
                    from: 4.2
                    to: 0.0
                    duration: 560
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: p2
                    property: "oy"
                    from: 2.8
                    to: 0.0
                    duration: 560
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: p2
                    property: "rotAngle"
                    from: -16.0
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
                        to: -1.5
                        duration: 2600
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p2
                        property: "dy"
                        from: 0.0
                        to: 1.1
                        duration: 2600
                        easing.type: Easing.InOutSine
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: p2
                        property: "dx"
                        from: -1.5
                        to: 1.2
                        duration: 5200
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p2
                        property: "dy"
                        from: 1.1
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

        // 3c. Star 3 (1040 -> 1600ms + idle drift)
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
                    from: -4.8
                    to: 0.0
                    duration: 560
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: p3
                    property: "oy"
                    from: -2.8
                    to: 0.0
                    duration: 560
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: p3
                    property: "rotAngle"
                    from: -16.0
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
                        to: -1.4
                        duration: 2900
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p3
                        property: "dy"
                        from: 0.0
                        to: -1.1
                        duration: 2900
                        easing.type: Easing.InOutSine
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: p3
                        property: "dx"
                        from: -1.4
                        to: 1.2
                        duration: 5800
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p3
                        property: "dy"
                        from: -1.1
                        to: 1.0
                        duration: 5800
                        easing.type: Easing.InOutSine
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: p3
                        property: "dx"
                        from: 1.2
                        to: 0.0
                        duration: 2900
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p3
                        property: "dy"
                        from: 1.0
                        to: 0.0
                        duration: 2900
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }
}

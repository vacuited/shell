pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.components
import qs.services

Item {
    id: root

    implicitWidth: 128
    implicitHeight: 128

    // Active Material 3 palette bindings
    property color voidColor: "#000000"
    property color horizonColor: Colours.palette.m3primary
    property color highlightColor: Colours.palette.m3onSurface
    property color particleColor: Colours.palette.m3tertiary

    property alias ringColour: root.horizonColor
    property alias highlightColour: root.highlightColor
    property alias particleColour: root.particleColor
    property alias voidColour: root.voidColor

    Behavior on horizonColor {
        CAnim {}
    }

    Behavior on highlightColor {
        CAnim {}
    }

    Behavior on particleColor {
        CAnim {}
    }

    property bool monoMode: false
    property bool skipIntroAnimation: false
    property bool reduceMotion: skipIntroAnimation

    signal animationCompleted

    readonly property real scaleFactor: Math.min(width, height) / 128.0

    Item {
        id: scene

        width: 128
        height: 128
        anchors.centerIn: parent
        scale: root.scaleFactor

        // 1. VOID (Event Horizon)
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
                    path: "M 38.5 64 A 25.5 25.5 0 1 1 89.5 64 A 25.5 25.5 0 1 1 38.5 64 Z"
                }
            }
        }

        // 2. INNER SPINNING PHOTON RING (id="horizon-highlight" — spins 360° behind the front accretion disk)
        Item {
            id: photonIdleSpin

            anchors.fill: parent
            transformOrigin: Item.Center

            Shape {
                id: highlightLayer

                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                transformOrigin: Item.Center
                scale: root.reduceMotion ? 1.0 : 1.45
                rotation: root.reduceMotion ? 0.0 : -200.0
                opacity: root.reduceMotion ? 1.0 : 0.0

                ShapePath {
                    strokeWidth: -1
                    strokeColor: "transparent"
                    fillColor: root.monoMode ? "#FFFFFF" : root.highlightColor

                    PathSvg {
                        path: "M 34.1 64.6 A 28.5 28.5 0 1 1 91.1 64.6 A 28.5 28.5 0 1 1 34.1 64.6 Z M 38.5 64 A 25.5 25.5 0 1 0 89.5 64 A 25.5 25.5 0 1 0 38.5 64 Z"
                    }
                }
            }
        }

        // 3. CAELESTIA ACCRETION DISK + UPPER/LOWER LENSED ARCHES (id="horizon" — stays horizontal!)
        Item {
            id: diskIdleFloat

            anchors.fill: parent
            transformOrigin: Item.Center

            Shape {
                id: horizonLayer

                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                transformOrigin: Item.Center
                scale: root.reduceMotion ? 1.0 : 0.72
                rotation: root.reduceMotion ? 0.0 : -14.0
                opacity: root.reduceMotion ? 1.0 : 0.0

                ShapePath {
                    strokeWidth: -1
                    strokeColor: "transparent"
                    fillColor: root.monoMode ? "#FFFFFF" : root.horizonColor

                    PathSvg {
                        path: "M 23.5 61.5 C 29.5 42 43 25 61 25 C 73.5 25 83 29 87.5 33.8 C 90.2 36.6 88 40.8 84.2 38.6 C 77.5 34.5 69.5 32.2 61.5 32.2 C 47.5 32.2 36.8 42.2 35.8 54.8 C 35.5 57.5 28 59.5 23.5 61.5 Z M 7.5 78 C 8.8 73.5 26 62.5 56 54.5 C 82 47.6 102 47.2 115.5 48.2 C 119.2 48.5 120.8 50.2 120.5 52.2 C 120.2 54.2 118.2 55.8 114.5 57.5 C 108.5 60.2 101 63.5 96.2 64.8 C 94 65.4 93.5 63.2 93.5 59.8 C 93.5 56.8 91.2 56 86 56.5 C 70 58 54 62.2 43.5 67.8 C 34.8 72.4 34.8 84.5 43.5 91.5 C 53.5 99 69.5 98.5 79.5 92 C 84.5 88.5 88 83.5 90.5 79.5 C 92.5 76.5 96.8 78.5 95 82.5 C 89 95.5 76.5 104.2 61.5 104.2 C 45 104.2 35 92 23 85.8 C 15 81.6 6.5 81.5 7.5 78 Z"
                    }
                }
            }
        }

        // 4. PARTICLES
        Shape {
            id: p1

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            transformOrigin: Item.Center
            opacity: root.reduceMotion ? 1.0 : 0.0

            property real ox: root.reduceMotion ? 0.0 : 3.8
            property real oy: root.reduceMotion ? 0.0 : -4.4
            property real dx: 0.0
            property real dy: 0.0
            property real rotAngle: root.reduceMotion ? 0.0 : -12.0

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
                    path: "M 95 20.5 Q 96.65 26.35 102.5 28 Q 96.65 29.65 95 35.5 Q 93.35 29.65 87.5 28 Q 93.35 26.35 95 20.5 Z"
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
            property real oy: root.reduceMotion ? 0.0 : -2.8
            property real dx: 0.0
            property real dy: 0.0
            property real rotAngle: root.reduceMotion ? 0.0 : -12.0

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
                    path: "M 109 33.5 Q 110.05 36.95 113.5 38 Q 110.05 39.05 109 42.5 Q 107.95 39.05 104.5 38 Q 107.95 36.95 109 33.5 Z"
                }
            }
        }

        Shape {
            id: p3

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            transformOrigin: Item.Center
            opacity: root.reduceMotion ? 1.0 : 0.0

            property real ox: root.reduceMotion ? 0.0 : 5.0
            property real oy: root.reduceMotion ? 0.0 : 2.0
            property real dx: 0.0
            property real dy: 0.0
            property real rotAngle: root.reduceMotion ? 0.0 : -12.0

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
                    path: "M 109 78 Q 109.95 81.05 113 82 Q 109.95 82.95 109 86 Q 108.05 82.95 105 82 Q 108.05 81.05 109 78 Z"
                }
            }
        }
    }

    // OPEN + IDLE ANIMATIONS
    ParallelAnimation {
        id: openAnim

        running: !root.reduceMotion
        onFinished: root.animationCompleted()

        // 1. Void 0 -> 650ms (with 3% overshoot)
        SequentialAnimation {
            NumberAnimation {
                target: voidLayer
                property: "scale"
                from: 0.0
                to: 1.03
                duration: 500
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: voidLayer
                property: "scale"
                from: 1.03
                to: 1.0
                duration: 150
                easing.type: Easing.InOutQuad
            }
        }

        // 2. Inner Photon Ring spins in (150 -> 1200ms) then spins 360° continuously in idle!
        SequentialAnimation {
            PauseAnimation {
                duration: 150
            }

            ParallelAnimation {
                NumberAnimation {
                    target: highlightLayer
                    property: "opacity"
                    from: 0.0
                    to: 1.0
                    duration: 210
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: highlightLayer
                    property: "scale"
                    from: 1.45
                    to: 1.0
                    duration: 1050
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: highlightLayer
                    property: "rotation"
                    from: -200.0
                    to: 0.0
                    duration: 1050
                    easing.type: Easing.OutCubic
                }
            }

            NumberAnimation {
                target: photonIdleSpin
                property: "rotation"
                from: 0.0
                to: 360.0
                duration: 10000
                loops: Animation.Infinite
                easing.type: Easing.Linear
            }
        }

        // 3. Caelestia Accretion Disk unfurls smoothly (250 -> 1250ms) then floats gently in idle
        SequentialAnimation {
            PauseAnimation {
                duration: 250
            }

            ParallelAnimation {
                NumberAnimation {
                    target: horizonLayer
                    property: "opacity"
                    from: 0.0
                    to: 1.0
                    duration: 250
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: horizonLayer
                    property: "scale"
                    from: 0.72
                    to: 1.0
                    duration: 1000
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: horizonLayer
                    property: "rotation"
                    from: -14.0
                    to: 0.0
                    duration: 1000
                    easing.type: Easing.OutCubic
                }
            }

            SequentialAnimation {
                loops: Animation.Infinite

                NumberAnimation {
                    target: diskIdleFloat
                    property: "rotation"
                    from: 0.0
                    to: 1.2
                    duration: 3000
                    easing.type: Easing.InOutSine
                }

                NumberAnimation {
                    target: diskIdleFloat
                    property: "rotation"
                    from: 1.2
                    to: -1.2
                    duration: 6000
                    easing.type: Easing.InOutSine
                }

                NumberAnimation {
                    target: diskIdleFloat
                    property: "rotation"
                    from: -1.2
                    to: 0.0
                    duration: 3000
                    easing.type: Easing.InOutSine
                }
            }
        }

        // 4. Particle 1 (750 -> 1310ms + idle drift)
        SequentialAnimation {
            PauseAnimation {
                duration: 750
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
                    from: 3.8
                    to: 0.0
                    duration: 560
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: p1
                    property: "oy"
                    from: -4.4
                    to: 0.0
                    duration: 560
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: p1
                    property: "rotAngle"
                    from: -12.0
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
                        duration: 2600
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p1
                        property: "dy"
                        from: 0.0
                        to: -1.1
                        duration: 2600
                        easing.type: Easing.InOutSine
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: p1
                        property: "dx"
                        from: 1.4
                        to: -1.4
                        duration: 5200
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p1
                        property: "dy"
                        from: -1.1
                        to: 1.1
                        duration: 5200
                        easing.type: Easing.InOutSine
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: p1
                        property: "dx"
                        from: -1.4
                        to: 0.0
                        duration: 2600
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p1
                        property: "dy"
                        from: 1.1
                        to: 0.0
                        duration: 2600
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }

        // 5. Particle 2 (870 -> 1430ms + idle drift)
        SequentialAnimation {
            PauseAnimation {
                duration: 870
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
                    from: -2.8
                    to: 0.0
                    duration: 560
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: p2
                    property: "rotAngle"
                    from: -12.0
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
                        to: -1.3
                        duration: 2800
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p2
                        property: "dy"
                        from: 0.0
                        to: -1.2
                        duration: 2800
                        easing.type: Easing.InOutSine
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: p2
                        property: "dx"
                        from: -1.3
                        to: 1.3
                        duration: 5600
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p2
                        property: "dy"
                        from: -1.2
                        to: 1.2
                        duration: 5600
                        easing.type: Easing.InOutSine
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: p2
                        property: "dx"
                        from: 1.3
                        to: 0.0
                        duration: 2800
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p2
                        property: "dy"
                        from: 1.2
                        to: 0.0
                        duration: 2800
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }

        // 6. Particle 3 (990 -> 1550ms + idle drift)
        SequentialAnimation {
            PauseAnimation {
                duration: 990
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
                    from: 5.0
                    to: 0.0
                    duration: 560
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: p3
                    property: "oy"
                    from: 2.0
                    to: 0.0
                    duration: 560
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: p3
                    property: "rotAngle"
                    from: -12.0
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
                        to: -1.5
                        duration: 3000
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p3
                        property: "dy"
                        from: 0.0
                        to: 1.0
                        duration: 3000
                        easing.type: Easing.InOutSine
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: p3
                        property: "dx"
                        from: -1.5
                        to: 1.5
                        duration: 6000
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p3
                        property: "dy"
                        from: 1.0
                        to: -1.0
                        duration: 6000
                        easing.type: Easing.InOutSine
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: p3
                        property: "dx"
                        from: 1.5
                        to: 0.0
                        duration: 3000
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p3
                        property: "dy"
                        from: -1.0
                        to: 0.0
                        duration: 3000
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }
}

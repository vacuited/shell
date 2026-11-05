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
    // Set true if you want full 360° continuous idle rotation in addition to the open spin
    property bool fullSpinIdle: false

    signal animationCompleted

    readonly property real scaleFactor: Math.min(width, height) / 128.0

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
                    path: "M 36 64 A 28 28 0 1 1 92 64 A 28 28 0 1 1 36 64 Z"
                }
            }
        }

        // 2 & 3. ACCRETION DISK + PHOTON ARCHES + HIGHLIGHT
        Item {
            id: ringOrbit

            anchors.fill: parent
            transformOrigin: Item.Center

            Item {
                id: ringOpenContainer

                anchors.fill: parent
                transformOrigin: Item.Center
                scale: root.reduceMotion ? 1.0 : 1.6
                rotation: root.reduceMotion ? 0.0 : -120.0
                opacity: root.reduceMotion ? 1.0 : 0.0

                Shape {
                    id: horizonLayer

                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeWidth: -1
                        strokeColor: "transparent"
                        fillColor: root.monoMode ? "#FFFFFF" : root.horizonColor

                        PathSvg {
                            path: "M 53.91 31.01 C 38.13 35.83 32.48 53.25 30.66 62.69 C 28.84 72.13 8.37 78.71 9.74 83.2 C 11.29 88.27 32.87 81.88 40.32 87.45 C 47.77 93.01 59.12 101.05 73.94 96.51 C 88.29 92.13 92.13 77.36 95.2 68.58 C 98.27 59.8 118.97 50.54 117.59 46.05 C 116.34 41.93 96.74 51.38 89.95 44.56 C 83.16 37.75 69.21 26.33 53.91 31.01 Z M 38.54 74.4 A 27.5 27.5 0 1 1 90.44 56.44 C 74.97 65.67 56.13 72.47 38.54 74.4 Z M 43.85 82.71 C 59.54 80.21 76.35 73.61 91.46 65.54 A 27.5 27.5 0 0 1 43.85 82.71 Z"
                        }
                    }
                }

                Shape {
                    id: highlightLayer

                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    property real bx: 0.0
                    property real by: 0.0

                    transform: Translate {
                        x: highlightLayer.bx
                        y: highlightLayer.by
                    }

                    ShapePath {
                        strokeWidth: -1
                        strokeColor: "transparent"
                        fillColor: root.monoMode ? "#FFFFFF" : root.highlightColor

                        PathSvg {
                            path: "M 17.42 80.96 C 50.92 75.95 81.06 65.06 108.12 49.26 C 82.28 69.08 52.15 79.96 17.42 80.96 Z M 37.44 71.12 A 27.5 27.5 0 0 1 63.04 36.52 C 46.75 36.65 29.9 55.08 37.44 71.12 Z"
                        }
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

            property real ox: root.reduceMotion ? 0.0 : -4.6
            property real oy: root.reduceMotion ? 0.0 : -3.1
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
                    path: "M 16 25.5 Q 17.43 30.57 22.5 32 Q 17.43 33.43 16 38.5 Q 14.57 33.43 9.5 32 Q 14.57 30.57 16 25.5 Z"
                }
            }
        }

        Shape {
            id: p2

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            transformOrigin: Item.Center
            opacity: root.reduceMotion ? 1.0 : 0.0

            property real ox: root.reduceMotion ? 0.0 : 4.1
            property real oy: root.reduceMotion ? 0.0 : -3.9
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
                    path: "M 106 19 Q 107.15 22.85 111 24 Q 107.15 25.15 106 29 Q 104.85 25.15 101 24 Q 104.85 22.85 106 19 Z"
                }
            }
        }

        Shape {
            id: p3

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            transformOrigin: Item.Center
            opacity: root.reduceMotion ? 1.0 : 0.0

            property real ox: root.reduceMotion ? 0.0 : 4.1
            property real oy: root.reduceMotion ? 0.0 : 3.7
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
                    path: "M 102 94 Q 102.96 97.04 106 98 Q 102.96 98.96 102 102 Q 101.04 98.96 98 98 Q 101.04 97.04 102 94 Z"
                }
            }
        }
    }

    // OPEN + IDLE ANIMATIONS
    ParallelAnimation {
        id: openAnim

        running: !root.reduceMotion
        onFinished: root.animationCompleted()

        // 1. Void 0 -> 700ms (with 3% overshoot)
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

        // 2. Accretion Disk Spin-In (200 -> 1300ms) + Idle Motion
        SequentialAnimation {
            PauseAnimation {
                duration: 200
            }

            ParallelAnimation {
                NumberAnimation {
                    target: ringOpenContainer
                    property: "opacity"
                    from: 0.0
                    to: 1.0
                    duration: 200
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: ringOpenContainer
                    property: "scale"
                    from: 1.6
                    to: 1.0
                    duration: 1100
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: ringOpenContainer
                    property: "rotation"
                    from: -120.0
                    to: 0.0
                    duration: 1100
                    easing.type: Easing.OutCubic
                }
            }

            ParallelAnimation {
                // Disk idle rotation (either subtle gravitational rock or 360° continuous spin)
                SequentialAnimation {
                    loops: Animation.Infinite

                    NumberAnimation {
                        target: ringOrbit
                        property: "rotation"
                        from: 0.0
                        to: root.fullSpinIdle ? 360.0 : 2.5
                        duration: root.fullSpinIdle ? 24000 : 3200
                        easing.type: root.fullSpinIdle ? Easing.Linear : Easing.InOutSine
                    }

                    NumberAnimation {
                        target: ringOrbit
                        property: "rotation"
                        from: 2.5
                        to: -2.5
                        duration: root.fullSpinIdle ? 0 : 6400
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: ringOrbit
                        property: "rotation"
                        from: -2.5
                        to: 0.0
                        duration: root.fullSpinIdle ? 0 : 3200
                        easing.type: Easing.InOutSine
                    }
                }

                // Relativistic highlight surge along the -17° accretion disk plane
                SequentialAnimation {
                    loops: Animation.Infinite

                    ParallelAnimation {
                        NumberAnimation {
                            target: highlightLayer
                            property: "bx"
                            from: 0.0
                            to: 1.8
                            duration: 1600
                            easing.type: Easing.InOutSine
                        }

                        NumberAnimation {
                            target: highlightLayer
                            property: "by"
                            from: 0.0
                            to: -0.55
                            duration: 1600
                            easing.type: Easing.InOutSine
                        }
                    }

                    ParallelAnimation {
                        NumberAnimation {
                            target: highlightLayer
                            property: "bx"
                            from: 1.8
                            to: -1.8
                            duration: 3200
                            easing.type: Easing.InOutSine
                        }

                        NumberAnimation {
                            target: highlightLayer
                            property: "by"
                            from: -0.55
                            to: 0.55
                            duration: 3200
                            easing.type: Easing.InOutSine
                        }
                    }

                    ParallelAnimation {
                        NumberAnimation {
                            target: highlightLayer
                            property: "bx"
                            from: -1.8
                            to: 0.0
                            duration: 1600
                            easing.type: Easing.InOutSine
                        }

                        NumberAnimation {
                            target: highlightLayer
                            property: "by"
                            from: 0.55
                            to: 0.0
                            duration: 1600
                            easing.type: Easing.InOutSine
                        }
                    }
                }
            }
        }

        // 3. Particle 1 (800 -> 1360ms + idle drift)
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
                    from: -4.6
                    to: 0.0
                    duration: 560
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: p1
                    property: "oy"
                    from: -3.1
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
                        to: 1.6
                        duration: 2600
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p1
                        property: "dy"
                        from: 0.0
                        to: 0.9
                        duration: 2600
                        easing.type: Easing.InOutSine
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: p1
                        property: "dx"
                        from: 1.6
                        to: -1.6
                        duration: 5200
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p1
                        property: "dy"
                        from: 0.9
                        to: -0.9
                        duration: 5200
                        easing.type: Easing.InOutSine
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: p1
                        property: "dx"
                        from: -1.6
                        to: 0.0
                        duration: 2600
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p1
                        property: "dy"
                        from: -0.9
                        to: 0.0
                        duration: 2600
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }

        // 4. Particle 2 (920 -> 1480ms + idle drift)
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
                    from: 4.1
                    to: 0.0
                    duration: 560
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: p2
                    property: "oy"
                    from: -3.9
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
                        to: -1.4
                        duration: 2800
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p2
                        property: "dy"
                        from: 0.0
                        to: 1.2
                        duration: 2800
                        easing.type: Easing.InOutSine
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: p2
                        property: "dx"
                        from: -1.4
                        to: 1.4
                        duration: 5600
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p2
                        property: "dy"
                        from: 1.2
                        to: -1.2
                        duration: 5600
                        easing.type: Easing.InOutSine
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: p2
                        property: "dx"
                        from: 1.4
                        to: 0.0
                        duration: 2800
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p2
                        property: "dy"
                        from: -1.2
                        to: 0.0
                        duration: 2800
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }

        // 5. Particle 3 (1040 -> 1600ms + idle drift)
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
                    from: 4.1
                    to: 0.0
                    duration: 560
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: p3
                    property: "oy"
                    from: 3.7
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
                        to: -1.1
                        duration: 3000
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p3
                        property: "dy"
                        from: 0.0
                        to: -1.5
                        duration: 3000
                        easing.type: Easing.InOutSine
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: p3
                        property: "dx"
                        from: -1.1
                        to: 1.1
                        duration: 6000
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p3
                        property: "dy"
                        from: -1.5
                        to: 1.5
                        duration: 6000
                        easing.type: Easing.InOutSine
                    }
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: p3
                        property: "dx"
                        from: 1.1
                        to: 0.0
                        duration: 3000
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: p3
                        property: "dy"
                        from: 1.5
                        to: 0.0
                        duration: 3000
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }
}

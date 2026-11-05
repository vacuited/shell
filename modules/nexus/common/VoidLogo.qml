pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.components
import qs.services

Item {
    id: root

    property bool skipIntroAnimation: false
    property bool introDone: skipIntroAnimation

    signal animationCompleted

    // Colours follow the active Material 3 scheme
    property color ringColour: Colours.palette.m3primary
    property color highlightColour: Colours.palette.m3onSurface
    property color particleColour: Colours.palette.m3tertiary
    property color voidColour: "#000000"

    Behavior on ringColour {
        CAnim {}
    }

    Behavior on highlightColour {
        CAnim {}
    }

    Behavior on particleColour {
        CAnim {}
    }

    // Animated state (intro start values; skipIntroAnimation jumps straight to the end state)
    property real blurAmount: skipIntroAnimation ? 0.0 : 1.0
    property real voidScale: skipIntroAnimation ? 1.0 : 0.0
    property real horizonScale: skipIntroAnimation ? 1.0 : 1.6
    property real horizonRotation: skipIntroAnimation ? 0.0 : -120.0
    property real horizonOpacity: skipIntroAnimation ? 1.0 : 0.0
    property real idleRotation: 0.0

    property real p1Opacity: skipIntroAnimation ? 1.0 : 0.0
    property real p2Opacity: skipIntroAnimation ? 1.0 : 0.0
    property real p3Opacity: skipIntroAnimation ? 1.0 : 0.0
    property real p1Scale: skipIntroAnimation ? 1.0 : 0.0
    property real p2Scale: skipIntroAnimation ? 1.0 : 0.0
    property real p3Scale: skipIntroAnimation ? 1.0 : 0.0
    property real p1Spiral: skipIntroAnimation ? 0.0 : 6.0
    property real p2Spiral: skipIntroAnimation ? 0.0 : 6.0
    property real p3Spiral: skipIntroAnimation ? 0.0 : 6.0
    property real p1Drift: 0.0
    property real p2Drift: 0.0
    property real p3Drift: 0.0

    implicitWidth: 128
    implicitHeight: 128

    Item {
        id: logo

        anchors.fill: parent

        layer.enabled: root.blurAmount > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root.blurAmount
            blurMax: 60
        }

        // Layer order = z-order (bottom to top). Every Shape is 128x128 so Item.Center == SVG (64,64).
        Shape {
            id: voidShape

            width: 128
            height: 128
            anchors.centerIn: parent
            scale: root.voidScale
            transformOrigin: Item.Center
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: root.voidColour
                strokeColor: "transparent"

                PathSvg {
                    path: "M 30 64 A 34 34 0 1 1 98 64 A 34 34 0 1 1 30 64 Z"
                }
            }
        }

        Shape {
            id: horizonShape

            width: 128
            height: 128
            anchors.centerIn: parent
            scale: root.horizonScale
            rotation: root.horizonRotation + root.idleRotation
            opacity: root.horizonOpacity
            transformOrigin: Item.Center
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: root.ringColour
                strokeColor: "transparent"

                PathSvg {
                    path: "M 24.25 85.2 A 40.8 38 -28.07 1 1 96.25 46.8 A 40.8 38 -28.07 1 1 24.25 85.2 Z M 30 64 A 34 34 0 1 0 98 64 A 34 34 0 1 0 30 64 Z"
                }
            }
        }

        Shape {
            id: highlightShape

            width: 128
            height: 128
            anchors.centerIn: parent
            scale: root.horizonScale
            rotation: root.horizonRotation + root.idleRotation
            opacity: root.horizonOpacity
            transformOrigin: Item.Center
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: root.highlightColour
                strokeColor: "transparent"

                PathSvg {
                    path: "M 40.24 39.68 A 34 34 0 0 0 70.96 97.28 A 32.9 32.9 0 0 1 40.24 39.68 Z"
                }
            }
        }

        Shape {
            id: particle1

            width: 128
            height: 128
            anchors.centerIn: parent
            x: root.p1Spiral
            y: root.p1Drift
            opacity: root.p1Opacity
            scale: root.p1Scale
            transformOrigin: Item.Center
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: root.particleColour
                strokeColor: "transparent"

                PathSvg {
                    path: "M 16 31 Q 17.54 36.46 23 38 Q 17.54 39.54 16 45 Q 14.46 39.54 9 38 Q 14.46 36.46 16 31 Z"
                }
            }
        }

        Shape {
            id: particle2

            width: 128
            height: 128
            anchors.centerIn: parent
            x: root.p2Spiral
            y: root.p2Drift
            opacity: root.p2Opacity
            scale: root.p2Scale
            transformOrigin: Item.Center
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: root.particleColour
                strokeColor: "transparent"

                PathSvg {
                    path: "M 104 25 Q 105.15 28.85 109 30 Q 105.15 31.15 104 35 Q 102.85 31.15 99 30 Q 102.85 28.85 104 25 Z"
                }
            }
        }

        Shape {
            id: particle3

            width: 128
            height: 128
            anchors.centerIn: parent
            x: root.p3Spiral
            y: root.p3Drift
            opacity: root.p3Opacity
            scale: root.p3Scale
            transformOrigin: Item.Center
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: root.particleColour
                strokeColor: "transparent"

                PathSvg {
                    path: "M 95 100 Q 95.96 103.04 99 104 Q 95.96 104.96 95 108 Q 94.04 104.96 91 104 Q 94.04 103.04 95 100 Z"
                }
            }
        }
    }

    // Intro (total ~1.8 s)
    SequentialAnimation {
        running: !root.skipIntroAnimation
        onFinished: {
            root.introDone = true;
            root.animationCompleted();
        }

        ParallelAnimation {
            // Void appears
            NumberAnimation {
                target: root
                property: "voidScale"
                from: 0.0
                to: 1.0
                duration: 700
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: root
                property: "blurAmount"
                from: 1.0
                to: 0.0
                duration: 900
                easing.type: Easing.OutCubic
            }

            // Event horizon sweeps in and contracts onto the void
            SequentialAnimation {
                PauseAnimation {
                    duration: 200
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: root
                        property: "horizonScale"
                        from: 1.6
                        to: 1.0
                        duration: 1100
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: root
                        property: "horizonRotation"
                        from: -120.0
                        to: 0.0
                        duration: 1100
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        target: root
                        property: "horizonOpacity"
                        from: 0.0
                        to: 1.0
                        duration: 300
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            // Particles settle in, staggered 120 ms
            SequentialAnimation {
                PauseAnimation {
                    duration: 800
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: root
                        property: "p1Opacity"
                        from: 0.0
                        to: 1.0
                        duration: 500
                    }

                    NumberAnimation {
                        target: root
                        property: "p1Scale"
                        from: 0.0
                        to: 1.0
                        duration: 500
                        easing.type: Easing.OutBack
                    }

                    NumberAnimation {
                        target: root
                        property: "p1Spiral"
                        from: 6.0
                        to: 0.0
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }
            }

            SequentialAnimation {
                PauseAnimation {
                    duration: 920
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: root
                        property: "p2Opacity"
                        from: 0.0
                        to: 1.0
                        duration: 500
                    }

                    NumberAnimation {
                        target: root
                        property: "p2Scale"
                        from: 0.0
                        to: 1.0
                        duration: 500
                        easing.type: Easing.OutBack
                    }

                    NumberAnimation {
                        target: root
                        property: "p2Spiral"
                        from: 6.0
                        to: 0.0
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }
            }

            SequentialAnimation {
                PauseAnimation {
                    duration: 1040
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: root
                        property: "p3Opacity"
                        from: 0.0
                        to: 1.0
                        duration: 500
                    }

                    NumberAnimation {
                        target: root
                        property: "p3Scale"
                        from: 0.0
                        to: 1.0
                        duration: 500
                        easing.type: Easing.OutBack
                    }

                    NumberAnimation {
                        target: root
                        property: "p3Spiral"
                        from: 6.0
                        to: 0.0
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    // Idle loop (starts only after the intro; the void itself never moves)
    NumberAnimation {
        target: root
        property: "idleRotation"
        from: 0.0
        to: 360.0
        duration: 24000
        loops: Animation.Infinite
        running: root.introDone
    }

    SequentialAnimation {
        running: root.introDone
        loops: Animation.Infinite

        NumberAnimation {
            target: root
            property: "p1Drift"
            to: -2.0
            duration: 5000
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            target: root
            property: "p1Drift"
            to: 0.0
            duration: 5000
            easing.type: Easing.InOutSine
        }
    }

    SequentialAnimation {
        running: root.introDone
        loops: Animation.Infinite

        NumberAnimation {
            target: root
            property: "p2Drift"
            to: 2.0
            duration: 6000
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            target: root
            property: "p2Drift"
            to: 0.0
            duration: 6000
            easing.type: Easing.InOutSine
        }
    }

    SequentialAnimation {
        running: root.introDone
        loops: Animation.Infinite

        NumberAnimation {
            target: root
            property: "p3Drift"
            to: -2.0
            duration: 5500
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            target: root
            property: "p3Drift"
            to: 0.0
            duration: 5500
            easing.type: Easing.InOutSine
        }
    }
}

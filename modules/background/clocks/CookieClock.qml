pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import M3Shapes
import Caelestia.Config
import qs.components
import qs.services
import "../components"

// M3 Expressive morphing cookie clock with configurable dial, hands, date, and surface style.
Item {
    id: root

    required property Item wallpaper
    required property real absX
    required property real absY
    property real clockScale: 1.0
    property string surfaceStyle: "glass"
    property var options: ({})

    readonly property int baseSize: 230
    readonly property bool isMaterial: surfaceStyle === "material"
    readonly property bool isBlur: surfaceStyle === "blur"
    readonly property bool isFrosted: surfaceStyle === "frosted"
    readonly property bool isGlass: !isMaterial && !isBlur && !isFrosted
    readonly property bool isTranslucentBlur: isBlur || isFrosted
    readonly property bool surfaceHidden: QsWindow.window ? !QsWindow.window.visible : false

    readonly property int cookieShape: resolveShape(String(options?.shape ?? "Cookie9Sided"))
    readonly property bool constantlyRotate: Boolean(options?.constantlyRotate ?? false)
    readonly property string hourHandStyle: String(options?.hourHandStyle ?? "classic")
    readonly property string minuteHandStyle: String(options?.minuteHandStyle ?? "classic")
    readonly property string secondHandStyle: String(options?.secondHandStyle ?? "line")
    readonly property bool showTimeIndicators: Boolean(options?.timeIndicators ?? true)
    readonly property string ticksMode: {
        if (options?.dialNumberStyle !== undefined)
            return String(options.dialNumberStyle);
        if (typeof options?.dialTicks === "string")
            return options.dialTicks;
        return (options?.dialTicks ?? true) ? "full" : "none";
    }
    readonly property bool showNumbers: {
        if (options?.dialNumberStyle !== undefined)
            return String(options.dialNumberStyle) === "numbers";
        return Boolean(options?.dialNumbers ?? false);
    }
    readonly property string dateStyle: (options?.showDate === false) ? "hide" : String(options?.dateStyle ?? "bubble")

    readonly property color colBackground: Qt.alpha(Colours.palette.m3primaryContainer, 0.95)
    readonly property color colOnBackground: isMaterial ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
    readonly property color colHourHand: Colours.palette.m3primary
    readonly property color colMinuteHand: Colours.palette.m3tertiary
    readonly property color colSecondHand: Colours.palette.m3secondary
    readonly property color colDateContainer: isMaterial ? Colours.palette.m3secondaryContainer : (isTranslucentBlur ? Qt.alpha("#ffffff", 0.20) : Colours.palette.m3surfaceContainerHigh)
    readonly property color colOnDateContainer: isMaterial ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface

    readonly property int clockHour: Time.hours % 12
    readonly property int clockMinute: Time.minutes
    readonly property int clockSecond: Time.seconds
    readonly property string displayFont: "Titan One"

    function resolveShape(name: string): int {
        const shapes = {
            "Circle": MaterialShape.Circle,
            "Square": MaterialShape.Square,
            "Slanted": MaterialShape.Slanted,
            "Arch": MaterialShape.Arch,
            "Fan": MaterialShape.Fan,
            "Arrow": MaterialShape.Arrow,
            "SemiCircle": MaterialShape.SemiCircle,
            "Oval": MaterialShape.Oval,
            "Pill": MaterialShape.Pill,
            "Triangle": MaterialShape.Triangle,
            "Diamond": MaterialShape.Diamond,
            "ClamShell": MaterialShape.ClamShell,
            "Pentagon": MaterialShape.Pentagon,
            "Gem": MaterialShape.Gem,
            "Sunny": MaterialShape.Sunny,
            "VerySunny": MaterialShape.VerySunny,
            "Cookie4Sided": MaterialShape.Cookie4Sided,
            "Cookie6Sided": MaterialShape.Cookie6Sided,
            "Cookie7Sided": MaterialShape.Cookie7Sided,
            "Cookie9Sided": MaterialShape.Cookie9Sided,
            "Cookie12Sided": MaterialShape.Cookie12Sided,
            "Ghostish": MaterialShape.Ghostish,
            "Clover4Leaf": MaterialShape.Clover4Leaf,
            "Clover8Leaf": MaterialShape.Clover8Leaf,
            "Burst": MaterialShape.Burst,
            "SoftBurst": MaterialShape.SoftBurst,
            "Boom": MaterialShape.Boom,
            "SoftBoom": MaterialShape.SoftBoom,
            "Flower": MaterialShape.Flower,
            "Puffy": MaterialShape.Puffy,
            "PuffyDiamond": MaterialShape.PuffyDiamond,
            "PixelCircle": MaterialShape.PixelCircle,
            "PixelTriangle": MaterialShape.PixelTriangle,
            "Bun": MaterialShape.Bun,
            "Heart": MaterialShape.Heart
        };
        return shapes[name] ?? MaterialShape.Cookie9Sided;
    }

    implicitWidth: Math.round(baseSize * clockScale)
    implicitHeight: Math.round(baseSize * clockScale)
    width: implicitWidth
    height: implicitHeight

    onConstantlyRotateChanged: cookieRotator.settleRotation()
    onSurfaceHiddenChanged: cookieRotator.settleRotation()
    Component.onCompleted: {
        if (constantlyRotate && !surfaceHidden)
            ambientSpin.start();
    }

    Item {
        id: cookieRotator

        visible: false
        property real ambientRotation: 0

        function settleRotation(): void {
            ambientSpin.stop();
            if (root.surfaceHidden)
                return;
            if (root.constantlyRotate) {
                ambientReset.stop();
                ambientSpin.start();
            } else if (ambientRotation > 0.5) {
                ambientReset.to = ambientRotation > 180 ? 360 : 0;
                ambientReset.restart();
            }
        }

        RotationAnimation on ambientRotation {
            id: ambientSpin

            running: false
            duration: 30000
            from: 0
            to: 360
            loops: Animation.Infinite
        }

        Anim {
            id: ambientReset

            target: cookieRotator
            property: "ambientRotation"
            type: Anim.DefaultSpatial
            onStopped: cookieRotator.ambientRotation = 0
        }
    }

    // Offscreen rotating cookie mask; WidgetSurface stays upright so blur UVs never distort.
    Item {
        id: cookieMask

        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.smooth: true

        MaterialShape {
            anchors.fill: parent
            implicitSize: root.width
            shape: root.cookieShape
            color: "black"
            rotation: cookieRotator.ambientRotation
        }
    }

    WidgetSurface {
        anchors.fill: parent
        wallpaper: root.wallpaper
        absX: root.absX
        absY: root.absY
        surfaceStyle: root.surfaceStyle
        blur: Config.background.desktopClock.background.blur && !GameMode.enabled
        plateOpacity: Config.background.desktopClock.background.opacity
        materialColor: root.colBackground
        shadowEnabled: Config.background.desktopClock.shadow.enabled
        shadowOpacity: Config.background.desktopClock.shadow.opacity
        shadowBlur: Config.background.desktopClock.shadow.blur
        shapeMask: cookieMask
    }

    Item {
        id: dialStage

        anchors.centerIn: parent
        width: root.baseSize
        height: root.baseSize
        scale: root.clockScale

        MinuteMarks {
            anchors.fill: parent
            color: root.colOnBackground
            ticksMode: root.ticksMode
            showNumbers: root.showNumbers
        }

        TimeColumn {
            anchors.centerIn: parent
            color: Qt.alpha(root.colOnBackground, 0.4)
            hour: root.clockHour
            minute: root.clockMinute
            opacity: root.showTimeIndicators ? 1 : 0
            visible: opacity > 0
            scale: 1.4 - 0.4 * opacity

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Behavior on scale {
                MorphAnim {}
            }
        }

        FadeGroup {
            anchors.fill: parent
            shown: minuteHand.style !== "hide"

            MinuteHand {
                id: minuteHand

                anchors.fill: parent
                clockMinute: root.clockMinute
                color: root.colMinuteHand
                style: root.minuteHandStyle
            }
        }

        FadeGroup {
            anchors.fill: parent
            shown: hourHand.style !== "hide"

            HourHand {
                id: hourHand

                anchors.fill: parent
                clockHour: root.clockHour
                clockMinute: root.clockMinute
                color: root.colHourHand
                style: root.hourHandStyle
            }
        }

        FadeGroup {
            anchors.fill: parent
            shown: secondHand.style !== "hide"

            SecondHand {
                id: secondHand

                anchors.fill: parent
                clockSecond: root.clockSecond
                color: root.colSecondHand
                style: root.secondHandStyle
            }
        }

        Rectangle {
            z: 12
            anchors.centerIn: parent
            width: 10
            height: 10
            radius: 5
            color: root.colMinuteHand
        }

        FadeGroup {
            anchors.fill: parent
            shown: dateIndicator.style !== "hide"

            DateIndicator {
                id: dateIndicator

                anchors.fill: parent
                color: root.colDateContainer
                onColor: root.colOnDateContainer
                style: root.dateStyle
            }
        }
    }

    component MorphAnim: Anim {
        type: Anim.DefaultSpatial
    }

    component FadeGroup: Item {
        id: fadeRoot

        default property alias content: fadeHolder.data
        property bool shown: true

        opacity: shown ? 1 : 0
        visible: opacity > 0

        Item {
            id: fadeHolder

            anchors.fill: parent
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    component MinuteMarks: Item {
        id: marksRoot

        property color color: Colours.palette.m3onPrimaryContainer
        property string ticksMode: "full"
        property bool showNumbers: false

        FadeGroup {
            anchors.fill: parent
            shown: marksRoot.showNumbers

            Repeater {
                model: 4

                Item {
                    id: numRotator

                    required property int index

                    anchors.fill: parent
                    rotation: (360 / 4) * (index + 1)

                    Item {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: 12
                        width: 60
                        height: 60

                        Text {
                            anchors.centerIn: parent
                            rotation: -numRotator.rotation
                            text: String((numRotator.index + 1) * 3)
                            color: Qt.alpha(marksRoot.color, 0.22)
                            font.family: root.displayFont
                            font.pixelSize: 52
                            font.bold: true
                        }
                    }
                }
            }
        }

        FadeGroup {
            anchors.fill: parent
            shown: marksRoot.ticksMode === "dots"

            Repeater {
                model: 12

                Item {
                    required property int index

                    anchors.fill: parent
                    rotation: (360 / 12) * index

                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6
                        height: 6
                        radius: 3
                        color: Qt.alpha(marksRoot.color, 0.6)
                    }
                }
            }
        }

        FadeGroup {
            anchors.fill: parent
            shown: marksRoot.ticksMode === "full"

            Repeater {
                model: 12

                Item {
                    required property int index

                    anchors.fill: parent
                    rotation: (360 / 12) * index

                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12
                        height: 3
                        radius: 1.5
                        color: Qt.alpha(marksRoot.color, 0.6)
                    }
                }
            }

            Repeater {
                model: 60

                Item {
                    required property int index

                    visible: index % 5 !== 0
                    anchors.fill: parent
                    rotation: (360 / 60) * index

                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5
                        height: 1.5
                        radius: 0.75
                        color: Qt.alpha(marksRoot.color, 0.3)
                    }
                }
            }
        }
    }

    component TimeColumn: Column {
        id: colRoot

        property int hour: 0
        property int minute: 0
        property color color: Colours.palette.m3onPrimaryContainer

        spacing: -15

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ("0" + (colRoot.hour === 0 ? 12 : colRoot.hour)).slice(-2)
            color: colRoot.color
            font.family: root.displayFont
            font.pixelSize: 70
            font.weight: Font.Medium
            font.letterSpacing: 4
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ("0" + colRoot.minute).slice(-2)
            color: colRoot.color
            font.family: root.displayFont
            font.pixelSize: 70
            font.weight: Font.Medium
            font.letterSpacing: 4
        }
    }

    component HourHand: Item {
        id: hourHandRoot

        required property int clockHour
        required property int clockMinute
        property string style: "fill"
        property color color: Colours.palette.m3primary
        readonly property real handLength: 74
        readonly property real handWidth: style === "classic" ? 10 : 20
        property real fillColorAlpha: style === "hollow" ? 0 : 1

        rotation: -90 + (360 / 12) * (clockHour + clockMinute / 60)

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: Math.round(parent.width / 2 - hourHandRoot.handWidth / 2)
            width: hourHandRoot.handLength
            height: hourHandRoot.handWidth
            radius: height / 2
            color: Qt.rgba(hourHandRoot.color.r, hourHandRoot.color.g, hourHandRoot.color.b, hourHandRoot.fillColorAlpha)
            border.color: hourHandRoot.color
            border.width: 4

            Behavior on x {
                MorphAnim {}
            }

            Behavior on height {
                MorphAnim {}
            }
        }

        Behavior on fillColorAlpha {
            MorphAnim {}
        }

        Behavior on rotation {
            RotationAnimation {
                direction: RotationAnimation.Clockwise
                duration: Tokens.anim.durations.expressiveDefaultSpatial
                easing: Tokens.anim.expressiveDefaultSpatial
            }
        }
    }

    component MinuteHand: Item {
        id: minuteHandRoot

        required property int clockMinute
        property string style: "medium"
        property color color: Colours.palette.m3tertiary
        readonly property real handLength: 95
        readonly property real handWidth: style === "bold" ? 20 : (style === "medium" ? 14 : (style === "classic" ? 5 : 6))

        rotation: -90 + (360 / 60) * clockMinute

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: Math.round(parent.width / 2 - minuteHandRoot.handWidth / 2) - (minuteHandRoot.style === "classic" ? 15 : 0)
            width: minuteHandRoot.handLength
            height: minuteHandRoot.handWidth
            radius: height / 2
            color: minuteHandRoot.color

            Behavior on x {
                MorphAnim {}
            }

            Behavior on height {
                MorphAnim {}
            }
        }

        Behavior on rotation {
            RotationAnimation {
                direction: RotationAnimation.Clockwise
                duration: Tokens.anim.durations.expressiveDefaultSpatial
                easing: Tokens.anim.expressiveDefaultSpatial
            }
        }
    }

    component SecondHand: Item {
        id: secondHandRoot

        required property int clockSecond
        property string style: "dot"
        property color color: Colours.palette.m3secondary
        readonly property real dotSize: 18

        rotation: -90 + (360 / 60) * clockSecond

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: Math.round(parent.width / 2 - 1)
            width: secondHandRoot.style === "dot" ? 0 : 95
            height: 2
            radius: 1
            color: secondHandRoot.color
            visible: width > 0

            Behavior on width {
                MorphAnim {}
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: Math.round(parent.width / 2 + 92 - secondHandRoot.dotSize / 2)
            width: secondHandRoot.dotSize
            height: secondHandRoot.dotSize
            radius: secondHandRoot.dotSize / 2
            scale: secondHandRoot.style === "line" ? 0 : 1
            color: secondHandRoot.color
            visible: scale > 0

            Behavior on scale {
                MorphAnim {}
            }
        }

        Behavior on rotation {
            RotationAnimation {
                direction: RotationAnimation.Clockwise
                duration: Tokens.anim.durations.expressiveFastSpatial
                easing.type: Easing.OutQuad
            }
        }
    }

    component DateIndicator: Item {
        id: dateRoot

        property string style: "bubble"
        property color color: Colours.palette.m3secondaryContainer
        property color onColor: Colours.palette.m3onSecondaryContainer

        FadeGroup {
            anchors.fill: parent
            shown: dateRoot.style === "bubble"

            Item {
                z: 10
                x: 2
                y: 2
                width: 52
                height: 52

                MaterialShape {
                    anchors.fill: parent
                    implicitSize: 52
                    shape: MaterialShape.Pentagon
                    color: root.isMaterial ? Colours.palette.m3tertiaryContainer : (root.isTranslucentBlur ? Qt.alpha("#ffffff", 0.22) : Qt.alpha(Colours.palette.m3primaryContainer, 0.85))
                }

                Text {
                    anchors.centerIn: parent
                    text: Time.format("d")
                    color: root.isMaterial ? Colours.palette.m3onTertiaryContainer : (root.isTranslucentBlur ? Colours.palette.m3onSurface : Colours.palette.m3onPrimaryContainer)
                    font.family: root.displayFont
                    font.pixelSize: 22
                    font.bold: true
                }
            }

            Item {
                z: 10
                width: 52
                height: 52
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 2
                anchors.bottomMargin: 2

                MaterialShape {
                    anchors.fill: parent
                    implicitSize: 52
                    shape: MaterialShape.Pill
                    color: root.isMaterial ? Colours.palette.m3secondaryContainer : (root.isTranslucentBlur ? Qt.alpha("#ffffff", 0.16) : Qt.alpha(Colours.palette.m3secondaryContainer, 0.85))
                }

                Text {
                    anchors.centerIn: parent
                    text: Time.format("MM")
                    color: root.isTranslucentBlur ? Colours.palette.m3onSurface : Colours.palette.m3onSecondaryContainer
                    font.family: root.displayFont
                    font.pixelSize: 20
                    font.bold: true
                }
            }
        }

        FadeGroup {
            anchors.fill: parent
            shown: dateRoot.style === "rect" || dateRoot.style === "border"

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 16
                width: 36
                height: 28
                radius: 6
                color: dateRoot.style === "rect" ? dateRoot.color : "transparent"
                border.color: dateRoot.style === "border" ? dateRoot.color : "transparent"
                border.width: dateRoot.style === "border" ? 2 : 0

                Text {
                    anchors.centerIn: parent
                    text: Time.format("d")
                    color: dateRoot.onColor
                    font.family: root.displayFont
                    font.pixelSize: 14
                    font.bold: true
                }
            }
        }
    }
}

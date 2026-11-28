pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import M3Shapes
import Caelestia.Components
import Caelestia.Config
import qs.components
import "Dial.js" as Dial

Item {
    id: root

    required property var colours
    property var actions: Dial.actions
    property bool flipTextX: false
    property bool flipTextY: false
    property int selected: -1
    property real angle: 0
    property bool immediate: false
    property real displayedAngle: angle

    Behavior on displayedAngle {
        enabled: !root.immediate
        NumberAnimation { duration: 85; easing.type: Easing.OutCubic }
    }

    property color accent: colours.m3primary
    property color accentForeground: colours.m3onPrimary
    property color optionColour: colours.m3surfaceContainerHigh
    readonly property color primaryColour: colours.m3primary
    readonly property color outlineVariantColour: colours.m3outlineVariant
    property string fontFamily: "GoogleSansFlex"
    property string iconFontFamily: "Material Symbols Rounded"
    property string dialStyle: "rim"
    property real reveal: 1
    property real centerX: 28
    property real centerY: height - 32

    readonly property real trackRadius: 242
    readonly property real minTrackAngle: {
        if (!actions || actions.length === 0)
            return 2;
        let lo = 90;
        for (let i = 0; i < actions.length; ++i)
            lo = Math.min(lo, actions[i].angle);
        return Math.max(0, lo - 7);
    }
    readonly property real maxTrackAngle: {
        if (!actions || actions.length === 0)
            return 82;
        let hi = 0;
        for (let i = 0; i < actions.length; ++i)
            hi = Math.max(hi, actions[i].angle);
        return Math.min(90, hi + 7);
    }
    readonly property real trackSpan: Math.max(1, maxTrackAngle - minTrackAngle)
    readonly property real beadGapDeg: 7.2
    readonly property real activeTrackEnd: selected >= 0 ? Math.max(minTrackAngle, displayedAngle - beadGapDeg) : minTrackAngle
    readonly property real remainingTrackStart: selected >= 0 ? Math.min(maxTrackAngle, displayedAngle + beadGapDeg) : minTrackAngle

    function arcSvg(cx: real, cy: real, r: real, startDeg: real, endDeg: real): string {
        if (Math.abs(endDeg - startDeg) < 0.5)
            return "";
        const sRad = -startDeg * Math.PI / 180;
        const eRad = -endDeg * Math.PI / 180;
        const largeArc = Math.abs(endDeg - startDeg) > 180 ? 1 : 0;
        const sweep = endDeg >= startDeg ? 0 : 1;
        return [
            "M", cx + r * Math.cos(sRad), cy + r * Math.sin(sRad),
            "A", r, r, 0, largeArc, sweep, cx + r * Math.cos(eRad), cy + r * Math.sin(eRad)
        ].join(" ");
    }

    function roundedRectSvg(w: real, h: real, r: real): string {
        const sw = Math.max(1, w);
        const sh = Math.max(1, h);
        const cr = Math.max(0, Math.min(r, sw / 2, sh / 2));
        if (cr <= 0.01) {
            return ["M", 0, 0, "L", sw, 0, "L", sw, sh, "L", 0, sh, "Z"].join(" ");
        }
        return [
            "M", cr, 0,
            "L", sw - cr, 0,
            "A", cr, cr, 0, 0, 1, sw, cr,
            "L", sw, sh - cr,
            "A", cr, cr, 0, 0, 1, sw - cr, sh,
            "L", cr, sh,
            "A", cr, cr, 0, 0, 1, 0, sh - cr,
            "L", 0, cr,
            "A", cr, cr, 0, 0, 1, cr, 0,
            "Z"
        ].join(" ");
    }

    // Remaining inactive track arc ahead of the Diamond pointer (with CircularProgress-style gap)
    Shape {
        anchors.fill: parent
        visible: root.dialStyle === "rim" && (root.maxTrackAngle - root.remainingTrackStart) > 1.0
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeWidth: 6
            capStyle: ShapePath.RoundCap
            strokeColor: Qt.alpha(root.colours.m3secondaryContainer, 0.55)
            PathSvg { path: root.arcSvg(root.centerX, root.centerY, root.trackRadius, root.remainingTrackStart, root.maxTrackAngle) }
        }
    }

    // Signature Caelestia CircularProgress end-indicator dot at maxTrackAngle
    Rectangle {
        visible: root.dialStyle === "rim" && (root.maxTrackAngle - root.remainingTrackStart) > 4.0
        x: root.centerX + root.trackRadius * Math.cos(-root.maxTrackAngle * Math.PI / 180) - 2
        y: root.centerY + root.trackRadius * Math.sin(-root.maxTrackAngle * Math.PI / 180) - 2
        width: 4
        height: 4
        radius: 2
        color: root.accent

        Behavior on color {
            enabled: !root.immediate
            CAnim {}
        }
    }

    // Anchored Y-mirrored WavyLine growing continuously from minTrackAngle up to the Diamond gap
    Item {
        id: wavyFlipWrap

        readonly property real pad: 24
        readonly property real activeSweep: Math.max(0, root.activeTrackEnd - root.minTrackAngle)

        x: root.centerX - root.trackRadius - pad
        y: root.centerY - root.trackRadius - pad
        width: (root.trackRadius + pad) * 2
        height: width
        opacity: (root.dialStyle === "rim" && root.selected >= 0 && activeSweep > 1.5) ? 1 : 0
        visible: opacity > 0.01
        transform: Scale {
            origin.x: wavyFlipWrap.width / 2
            origin.y: wavyFlipWrap.height / 2
            yScale: -1
        }

        Behavior on opacity {
            enabled: !root.immediate
            Anim { type: Anim.FastEffects }
        }

        WavyLine {
            id: wavyTrack

            anchors.fill: parent
            lineWidth: 6
            color: root.accent
            pathType: WavyLine.Arc
            radius: root.trackRadius
            startAngle: root.minTrackAngle
            fullAngle: root.trackSpan
            value: Math.max(0, Math.min(1, wavyFlipWrap.activeSweep / root.trackSpan))
            frequency: 6
            amplitudeMultiplier: root.selected >= 0 ? 0.55 : 0

            Anim on waveProgress {
                running: wavyFlipWrap.visible && root.visible && wavyTrack.amplitudeMultiplier > 0.01
                from: 1
                to: 0
                duration: 2000
                easing.type: Easing.Linear
                loops: Animation.Infinite
            }

            Behavior on color {
                enabled: !root.immediate
                CAnim {}
            }

            Behavior on amplitudeMultiplier {
                enabled: !root.immediate
                Anim { type: Anim.DefaultEffects }
            }
        }
    }

    // Borderless tonal M3 option pills around the dial rim
    Repeater {
        model: root.actions

        Item {
            id: option

            required property var modelData
            required property int index
            readonly property bool current: root.selected === index
            readonly property real uprightAngle: (root.flipTextX !== root.flipTextY ? -1 : 1) * modelData.angle
            readonly property real staggerSpan: Math.min(0.28, Math.max(0, root.actions.length - 1) * 0.055)
            readonly property real itemReveal: Math.max(0, Math.min(1, (root.reveal - index * 0.055) / Math.max(0.3, 1 - staggerSpan)))

            x: root.centerX
            y: root.centerY
            rotation: -modelData.angle
            opacity: Math.max(0, Math.min(1, itemReveal))

            Item {
                id: pill

                objectName: "powerMenuDialPill" + option.index
                property real pillRadius: option.current ? 26 : 18
                property color fillCol: option.current ? root.accent : root.optionColour

                transform: Scale {
                    origin.x: pill.width / 2
                    origin.y: pill.height / 2
                    xScale: root.flipTextX ? -1 : 1
                    yScale: root.flipTextY ? -1 : 1
                }
                x: 278 - (1 - option.itemReveal) * 12
                y: -26
                width: option.current ? label.implicitWidth + 68 : 52
                height: 52

                Behavior on width {
                    enabled: !root.immediate
                    Anim { type: Anim.FastSpatial }
                }
                Behavior on pillRadius {
                    enabled: !root.immediate
                    Anim { type: Anim.FastSpatial }
                }
                Behavior on fillCol {
                    enabled: !root.immediate
                    CAnim {}
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: pill.fillCol
                        strokeWidth: -1
                        PathSvg { path: root.roundedRectSvg(pill.width, pill.height, pill.pillRadius) }
                    }
                }

                Item {
                    objectName: "powerMenuDialIconSlot" + option.index
                    x: 12
                    width: 28
                    height: 28
                    anchors.verticalCenter: parent.verticalCenter
                    rotation: option.current ? 0 : option.uprightAngle

                    Behavior on rotation {
                        enabled: !root.immediate
                        Anim { type: Anim.FastSpatial }
                    }

                    TextMetrics {
                        id: iconMetrics
                        font: symbol.font
                        text: symbol.text
                    }

                    Text {
                        id: symbol

                        objectName: "powerMenuDialIcon" + option.index
                        renderType: Text.CurveRendering
                        x: (parent.width - iconMetrics.tightBoundingRect.width) / 2 - iconMetrics.tightBoundingRect.x
                        y: (parent.height - iconMetrics.tightBoundingRect.height) / 2 - iconMetrics.tightBoundingRect.y - baselineOffset
                        text: option.modelData.icon
                        color: option.current ? root.accentForeground : root.colours.m3onSurfaceVariant
                        font.family: root.iconFontFamily
                        font.pixelSize: 24
                        font.variableAxes: ({ "FILL": option.current ? 1 : 0, "wght": 500, "GRAD": 0, "opsz": 24 })

                        Behavior on color {
                            enabled: !root.immediate
                            CAnim {}
                        }
                    }
                }

                Text {
                    id: label

                    renderType: Text.CurveRendering
                    x: 46
                    anchors.verticalCenter: parent.verticalCenter
                    text: option.modelData.title
                    color: root.accentForeground
                    font.family: root.fontFamily
                    font.pixelSize: 18
                    font.variableAxes: ({ "wght": 600, "ROND": 100 })
                    opacity: option.current ? Math.max(0, Math.min(1, (pill.width - 56) / 28)) : 0
                    visible: opacity > 0
                }
            }
        }
    }

    // Rotating MaterialShape.Diamond pointer with upright degree readout
    Item {
        id: puck

        objectName: "powerMenuDialBead"
        property color beadColor: root.accent

        x: root.centerX + root.trackRadius * Math.cos(-root.displayedAngle * Math.PI / 180) - width / 2
        y: root.centerY + root.trackRadius * Math.sin(-root.displayedAngle * Math.PI / 180) - height / 2
        width: 48
        height: 48
        opacity: (root.dialStyle === "rim" && root.selected >= 0) ? 1 : 0
        scale: root.selected >= 0 ? 1 : 0.35
        transformOrigin: Item.Center
        visible: opacity > 0.01

        Behavior on opacity {
            enabled: !root.immediate
            Anim { type: Anim.FastEffects }
        }
        Behavior on scale {
            enabled: !root.immediate
            Anim { type: Anim.FastSpatial }
        }
        Behavior on beadColor {
            enabled: !root.immediate
            CAnim {}
        }

        MaterialShape {
            anchors.fill: parent
            implicitSize: 48
            shape: MaterialShape.Diamond
            color: puck.beadColor
            rotation: 90 - root.displayedAngle
            transformOrigin: Item.Center
            layer.enabled: true
            layer.smooth: true
            layer.mipmap: true
            layer.textureSize: Qt.size(192, 192)
        }

        Text {
            id: angleLabel

            renderType: Text.CurveRendering
            anchors.centerIn: parent
            transform: Scale {
                origin.x: angleLabel.width / 2
                origin.y: angleLabel.height / 2
                xScale: root.flipTextX ? -1 : 1
                yScale: root.flipTextY ? -1 : 1
            }
            text: Math.round(root.displayedAngle) + "°"
            color: root.accentForeground
            font.family: root.fontFamily
            font.pixelSize: 13
            font.variableAxes: ({ "wght": 750, "ROND": 100 })

            Behavior on color {
                enabled: !root.immediate
                CAnim {}
            }
        }
    }
}

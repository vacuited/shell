pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

Item {
    id: root

    required property color baseColour
    required property color panelColour
    required property color panelEdgeColour
    required property color outlineColour
    required property color glowColour
    required property real unit
    required property real centerX
    required property real centerY
    required property real railWidth
    property string barPosition: "left"
    property real borderThickness: 10
    property real borderRounding: 25
    property real cornerReveal: 1
    property real frameReveal: 1
    property real backdropReveal: 1

    readonly property real safeUnit: Math.max(0.25, unit)
    readonly property real logicalW: width > 0 ? width / safeUnit : 1920
    readonly property real logicalH: height > 0 ? height / safeUnit : 1200
    readonly property bool isHorizontal: barPosition === "top" || barPosition === "bottom"
    readonly property bool isRight: barPosition === "right"
    readonly property bool isTop: barPosition === "top"
    readonly property bool flipX: isRight || isHorizontal
    readonly property bool flipY: isTop
    readonly property real logicalCx: (flipX ? (width - centerX) : centerX) / safeUnit
    readonly property real logicalCy: (flipY ? (height - centerY) : centerY) / safeUnit
    readonly property real cornerRadius: 263 * Math.max(0, cornerReveal)

    // Build inner panel SVG path in logical reference coordinates.
    // All 4 bar positions mirror onto the bottom-left cutout geometry via Shape Scale.
    readonly property string outline: {
        const w = logicalW;
        const h = logicalH;
        const m = Math.max(8, borderThickness / safeUnit);
        const cr = Math.max(14, Math.min(30, borderRounding / safeUnit));

        if (isHorizontal) {
            const left = m;
            const right = w - m;
            const top = m;
            const bottom = Math.min(h - m, h - railWidth / safeUnit);
            const cx = logicalCx;
            const cy = logicalCy;
            const r = cornerRadius;

            const path = [
                "M", left + cr, top,
                "L", right - cr, top,
                "Q", right, top, right, top + cr,
                "L", right, bottom - cr,
                "Q", right, bottom, right - cr, bottom
            ];

            if (r > Math.hypot(left - cx, bottom - cy) + 4) {
                const dy = Math.max(0, cy - bottom);
                const bRounding = Math.min(24, Math.max(4, (r - dy) / 4));
                const sinArg = Math.max(-1, Math.min(1, (dy + bRounding * 2 / 3) / r));
                const startAngle = -Math.asin(sinArg);
                const startX = cx + r * Math.cos(startAngle);
                const startY = cy + r * Math.sin(startAngle);

                const lRounding = Math.min(cr, Math.max(4, (r - Math.abs(cx - left)) / 4));
                const cosArg = Math.max(-1, Math.min(1, (left + lRounding * 2 / 3 - cx) / r));
                const endAngle = -Math.acos(cosArg);
                const arcX = cx + r * Math.cos(endAngle);
                const arcY = cy + r * Math.sin(endAngle);

                if (startX > arcX + 1 && startY > arcY + 1 && startX + bRounding < right - cr && arcY - lRounding > top + cr) {
                    path.push(
                        "L", startX + bRounding, bottom,
                        "Q", startX, bottom, startX, startY,
                        "A", r, r, 0, 0, 0, arcX, arcY,
                        "Q", left, arcY, left, arcY - lRounding
                    );
                } else {
                    path.push(
                        "L", left + cr, bottom,
                        "Q", left, bottom, left, bottom - cr
                    );
                }
            } else {
                path.push(
                    "L", left + cr, bottom,
                    "Q", left, bottom, left, bottom - cr
                );
            }

            path.push(
                "L", left, top + cr,
                "Q", left, top, left + cr, top,
                "Z"
            );
            return path.join(" ");
        }

        const left = Math.max(m, railWidth / safeUnit);
        const right = w - m;
        const top = m;
        const bottom = h - m;
        const cx = logicalCx;
        const cy = logicalCy;
        const r = cornerRadius;

        const path = [
            "M", left + cr, top,
            "L", right - cr, top,
            "Q", right, top, right, top + cr,
            "L", right, bottom - cr,
            "Q", right, bottom, right - cr, bottom
        ];
        if (r > left - cx + 0.5) {
            const rounding = Math.min(24, (r - (left - cx)) / 4);
            const bottomFillet = cr;
            const cosArg = Math.max(-1, Math.min(1, (left + rounding * 2 / 3 - cx) / r));
            const end = -Math.acos(cosArg);
            const arcX = cx + r * Math.cos(end);
            const arcY = cy + r * Math.sin(end);
            path.push(
                "L", cx + r + bottomFillet, bottom,
                "Q", cx + r, bottom, cx + r, cy,
                "A", r, r, 0, 0, 0, arcX, arcY,
                "Q", left, arcY, left, arcY - rounding
            );
        } else {
            path.push(
                "L", left + cr, bottom,
                "Q", left, bottom, left, bottom - cr
            );
        }
        path.push(
            "L", left, top + cr,
            "Q", left, top, left + cr, top,
            "Z"
        );
        return path.join(" ");
    }

    // Outer frame minus the inner panel cutout: painted in one pass so transparent
    // surfaces never double-blend where the outer frame meets the inner panel.
    readonly property string frameOutline: {
        const w = logicalW;
        const h = logicalH;
        return "M 0 0 L " + w + " 0 L " + w + " " + h + " L 0 " + h + " Z " + outline;
    }

    Item {
        objectName: "powerBackdropFrameMirror"
        anchors.fill: parent
        opacity: root.frameReveal
        visible: opacity > 0
        transform: Scale {
            origin.x: root.width / 2
            origin.y: root.height / 2
            xScale: root.flipX ? -1 : 1
            yScale: root.flipY ? -1 : 1
        }

        Shape {
            width: root.logicalW
            height: root.logicalH
            scale: root.safeUnit
            transformOrigin: Item.TopLeft
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: -1
                fillRule: ShapePath.OddEvenFill
                fillColor: root.baseColour
                PathSvg { path: root.frameOutline }
            }
        }
    }

    Item {
        id: panelLayer

        anchors.fill: parent
        opacity: Math.max(0, Math.min(1, root.backdropReveal))
        scale: 0.97 + 0.03 * opacity
        transformOrigin: Item.Center
        visible: opacity > 0.001

        Item {
            objectName: "powerBackdropPanelMirror"
            anchors.fill: parent
            transform: Scale {
                origin.x: root.width / 2
                origin.y: root.height / 2
                xScale: root.flipX ? -1 : 1
                yScale: root.flipY ? -1 : 1
            }

            Shape {
                width: root.logicalW
                height: root.logicalH
                scale: root.safeUnit
                transformOrigin: Item.TopLeft
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: -1
                    fillGradient: RadialGradient {
                        centerX: root.logicalW * 0.46
                        centerY: root.logicalH * 0.58
                        centerRadius: root.logicalW * 0.72
                        focalX: centerX
                        focalY: centerY
                        focalRadius: 100
                        GradientStop { position: 0; color: root.panelColour }
                        GradientStop { position: 1; color: root.panelEdgeColour }
                    }
                    PathSvg { path: root.outline }
                }

                ShapePath {
                    strokeWidth: -1
                    fillGradient: RadialGradient {
                        centerX: root.logicalCx
                        centerY: root.logicalCy
                        centerRadius: 700
                        focalX: centerX
                        focalY: centerY
                        focalRadius: Math.max(0, root.cornerRadius - 33)
                        GradientStop { position: 0; color: Qt.alpha(root.glowColour, 0.18) }
                        GradientStop { position: 0.18; color: Qt.alpha(root.glowColour, 0.09) }
                        GradientStop { position: 0.55; color: Qt.alpha(root.glowColour, 0.03) }
                        GradientStop { position: 1; color: "transparent" }
                    }
                    PathSvg { path: root.outline }
                }

                ShapePath {
                    fillColor: "transparent"
                    strokeWidth: 1
                    strokeColor: Qt.alpha(root.outlineColour, 0.22)
                    PathSvg { path: root.outline }
                }
            }
        }
    }
}

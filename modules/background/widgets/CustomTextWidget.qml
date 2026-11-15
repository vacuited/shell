pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Caelestia.Config
import qs.components
import qs.services
import "../components"

Item {
    id: root

    required property var wallpaper
    property bool weActive: false
    property bool locked: true
    property string sizeMode: "1x1"
    property string surfaceStyle: ""
    property bool blurEnabled: Config.background.desktopWidgets.blur
    property real plateOpacity: Config.background.desktopWidgets.opacity
    property var widgetOptions: ({})
    readonly property real s: WidgetMetrics.scale
    readonly property string rawText: String(widgetOptions?.content ?? widgetOptions?.text ?? "")
    readonly property string displayText: rawText.trim() !== "" ? rawText : qsTr("Note to self")
    readonly property bool isEmpty: rawText.trim() === ""
    readonly property int baseFontSize: Math.max(12, Math.min(140, Math.round(Number(widgetOptions?.fontSize ?? 28))))
    readonly property int fontSize: Math.max(11, Math.round(baseFontSize * s))
    readonly property string colorRole: String(widgetOptions?.colorRole ?? "onSurface")
    readonly property string alignMode: String(widgetOptions?.align ?? widgetOptions?.alignment ?? "center").toLowerCase()
    readonly property string backdropMode: String(widgetOptions?.backdropMode ?? "none") // "none" | "pill" | "card" | "shape"
    readonly property int maxLineWidth: Math.max(140, Math.round(Number(widgetOptions?.maxWidth ?? 640) * s))
    readonly property bool hasBackdrop: backdropMode !== "none" || !root.locked

    readonly property color resolvedColor: {
        if (isEmpty && backdropMode === "none")
            return Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.72);
        switch (colorRole) {
        case "primary":
            return Colours.palette.m3primary;
        case "secondary":
            return Colours.palette.m3secondary;
        case "tertiary":
            return Colours.palette.m3tertiary;
        case "white":
            return "#ffffff";
        case "onSurfaceVariant":
            return Colours.palette.m3onSurfaceVariant;
        default:
            return Colours.palette.m3onSurface;
        }
    }

    readonly property int hAlign: {
        if (alignMode === "left" || alignMode === "start")
            return Text.AlignLeft;
        if (alignMode === "right" || alignMode === "end")
            return Text.AlignRight;
        return Text.AlignHCenter;
    }

    readonly property int padH: {
        if (backdropMode === "shape")
            return Math.round(28 * s);
        if (backdropMode === "pill")
            return Math.round(22 * s);
        if (backdropMode === "card")
            return Math.round(18 * s);
        return Math.round(12 * s);
    }

    readonly property int padV: {
        if (backdropMode === "shape")
            return Math.round(28 * s);
        if (backdropMode === "pill" || backdropMode === "card")
            return Math.round(14 * s);
        return Math.round(8 * s);
    }

    readonly property int measuredW: Math.min(maxLineWidth, Math.ceil(measureMetrics.advanceWidth) + 8)
    readonly property int shapeMinBox: backdropMode === "shape" ? Math.round(140 * s) : 100

    signal optionsUpdated(var patch)

    implicitWidth: Math.max(shapeMinBox, measuredW + padH * 2)
    implicitHeight: Math.max(backdropMode === "shape" ? implicitWidth : Math.round(48 * s), Math.ceil(displayLabel.implicitHeight) + padV * 2)

    TextMetrics {
        id: measureMetrics

        font: Tokens.font.clock.size(root.fontSize).weight(Font.Bold).build()
        text: root.displayText
    }

    WidgetCardShell {
        id: shell

        anchors.fill: parent
        visible: root.hasBackdrop
        widgetType: "customText"
        sizeMode: "1x1"
        forceRounded: root.backdropMode !== "shape"
        outerShape: root.backdropMode === "shape" ? (root.widgetOptions?.outerShape || "Puffy") : "Rounded"
        radius: root.backdropMode === "pill" ? Math.round(height / 2) : Tokens.rounding.extraLarge
        wallpaper: root.wallpaper
        weActive: root.weActive
        surfaceStyle: root.surfaceStyle
        blurEnabled: root.blurEnabled
        plateOpacity: root.plateOpacity
        scaleFactor: root.s
    }

    StyledText {
        id: displayLabel

        anchors.centerIn: parent
        width: Math.max(40, root.width - root.padH * 2)
        text: root.displayText
        font: Tokens.font.clock.size(root.fontSize).weight(Font.Bold).build()
        color: root.resolvedColor
        horizontalAlignment: root.hAlign
        wrapMode: Text.WordWrap

        layer.enabled: !root.hasBackdrop && !GameMode.enabled && !root.weActive && width > 0 && height > 0
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 0.4
            shadowOpacity: 0.55
            shadowVerticalOffset: 2
            shadowColor: "#000000"
        }
    }
}

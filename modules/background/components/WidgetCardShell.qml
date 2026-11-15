pragma ComponentBehavior: Bound

import QtQuick
import M3Shapes
import Caelestia.Config
import qs.components.effects
import qs.services

Item {
    id: root

    property string widgetType: ""
    property string sizeMode: "1x1"
    property string outerShape: ""
    property var wallpaper: null
    property bool weActive: false
    property string surfaceStyle: Config.background.desktopWidgets.surfaceStyle
    property bool blurEnabled: Config.background.desktopWidgets.blur
    property real plateOpacity: Config.background.desktopWidgets.opacity
    property color materialColor: Colours.palette.m3surfaceContainer
    property color glassColor: Colours.palette.m3surface
    property color borderColor: Colours.palette.m3outlineVariant
    property real borderWidth: 1
    property bool shadowEnabled: true
    property bool forceRounded: false
    property bool showMaskBorder: true
    property real scaleFactor: WidgetMetrics.scale
    property int radius: WidgetMetrics.radiusFor(scaleFactor)

    readonly property string resolvedShapeKey: forceRounded
        ? "Rounded"
        : WidgetMetrics.effectiveShapeKey(widgetType, sizeMode, outerShape)
    readonly property int resolvedShapeEnum: resolvedShapeKey === "Rounded"
        ? -1
        : WidgetMetrics.resolveShapeEnum(resolvedShapeKey, "Rounded")
    readonly property bool isShaped: resolvedShapeEnum >= 0
    readonly property var contentInsets: WidgetMetrics.insetsFor(sizeMode, resolvedShapeKey, scaleFactor)
    readonly property int contentPadding: contentInsets.left
    readonly property int topPadding: contentInsets.top
    readonly property int bottomPadding: contentInsets.bottom
    readonly property int sidePadding: contentInsets.left

    default property alias contentData: contentSlot.data
    property alias backdropData: surfaceOverlaySlot.data

    MaterialShape {
        id: shapeMaskSource

        anchors.fill: parent
        visible: false
        layer.enabled: root.isShaped && width > 0 && height > 0
        shape: root.resolvedShapeEnum >= 0 ? root.resolvedShapeEnum : MaterialShape.Circle
        color: "#ffffff"
    }

    WidgetSurface {
        id: surface

        anchors.fill: parent
        wallpaper: root.wallpaper
        weActive: root.weActive
        surfaceStyle: root.surfaceStyle
        blur: root.blurEnabled
        plateOpacity: root.plateOpacity
        radius: root.radius
        shadowEnabled: root.shadowEnabled
        materialColor: root.materialColor
        glassColor: root.glassColor
        borderColor: root.borderColor
        borderWidth: root.borderWidth
        shapeMask: (root.isShaped && width > 0 && height > 0) ? shapeMaskSource : null
        maskShape: root.resolvedShapeEnum
        maskBorder: root.showMaskBorder
    }

    Item {
        id: surfaceOverlaySlot

        anchors.fill: parent
        layer.enabled: root.isShaped && children.length > 0 && width > 0 && height > 0
        layer.smooth: true
        layer.effect: Mask {
            maskSource: shapeMaskSource
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }

    Item {
        id: contentSlot

        anchors.fill: parent
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import "components"

Item {
    id: root

    required property Item wallpaper
    property string title
    property string icon
    property string surfaceStyle: Config.background.desktopWidgets.surfaceStyle || "glass"
    property color materialColor: Colours.palette.m3surfaceContainer
    property bool weActive: wallpaper?.weSurfaceActive ?? wallpaper?.weSurfaceVisible ?? false
    property real plateOpacity: Config.background.desktopWidgets.opacity
    property bool blur: Config.background.desktopWidgets.blur && !GameMode.enabled
    property real radius: Tokens.rounding.extraLarge
    property real padding: Tokens.padding.largeIncreased
    default property alias content: col.data

    property point origin: Qt.point(0, 0)

    function updateOrigin(): void {
        if (wallpaper)
            origin = mapToItem(wallpaper, 0, 0);
    }

    implicitWidth: 300
    implicitHeight: col.implicitHeight + padding * 2

    onXChanged: updateOrigin()
    onYChanged: updateOrigin()
    onWidthChanged: updateOrigin()
    onHeightChanged: updateOrigin()
    onParentChanged: updateOrigin()
    Component.onCompleted: updateOrigin()

    WidgetSurface {
        id: surface

        anchors.fill: parent
        wallpaper: root.wallpaper
        weActive: root.weActive
        surfaceStyle: root.surfaceStyle
        blur: root.blur
        plateOpacity: root.plateOpacity
        radius: root.radius
        materialColor: root.materialColor
        shadowEnabled: true
        shadowOpacity: 0.35
        shadowBlur: 0.6
        shadowVerticalOffset: 4
    }

    ColumnLayout {
        id: col

        anchors.fill: parent
        anchors.margins: root.padding
        spacing: Tokens.spacing.medium

        RowLayout {
            visible: root.title !== ""
            spacing: Tokens.spacing.small

            MaterialIcon {
                visible: root.icon !== ""
                text: root.icon
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                elide: Text.ElideRight
                text: root.title.toUpperCase()
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.builders.small.letterSpacing(1.5).weight(Font.DemiBold).build()
            }
        }
    }
}

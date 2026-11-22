pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// Caelestia-native uppercase card header matching DesktopCard / Dashboard cards.
RowLayout {
    id: root

    property string title: ""
    property string icon: ""
    property color iconColor: Colours.palette.m3primary
    property color titleColor: Colours.palette.m3onSurfaceVariant
    property real scaleFactor: 1.0
    default property alias actions: actionsSlot.data

    readonly property real s: Math.max(0.68, scaleFactor > 0 ? scaleFactor : 1.0)

    Layout.fillWidth: true
    Layout.minimumWidth: 0
    spacing: Math.max(4, Math.round(Tokens.spacing.small * s))

    MaterialIcon {
        visible: root.icon !== ""
        text: root.icon
        color: root.iconColor
        fontStyle: Tokens.font.icon.builders.small.scale(root.s).build()
        fill: 1
    }

    StyledText {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        elide: Text.ElideRight
        text: root.title.toUpperCase()
        color: root.titleColor
        font: Tokens.font.label.builders.small.scale(root.s).letterSpacing(1.3).weight(Font.DemiBold).build()
    }

    RowLayout {
        id: actionsSlot

        Layout.fillWidth: false
        spacing: Math.max(2, Math.round(Tokens.spacing.extraSmall * root.s))
    }
}

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
    default property alias actions: actionsSlot.data

    Layout.fillWidth: true
    spacing: Tokens.spacing.small

    MaterialIcon {
        visible: root.icon !== ""
        text: root.icon
        color: root.iconColor
        fontStyle: Tokens.font.icon.small
        fill: 1
    }

    StyledText {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        elide: Text.ElideRight
        text: root.title.toUpperCase()
        color: root.titleColor
        font: Tokens.font.label.builders.small.letterSpacing(1.5).weight(Font.DemiBold).build()
    }

    RowLayout {
        id: actionsSlot

        spacing: Tokens.spacing.extraSmall
    }
}

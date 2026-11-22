pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components.controls
import qs.services

IconButton {
    id: root

    property bool translucent: true
    property real scaleFactor: 1.0
    readonly property real s: Math.max(0.65, scaleFactor > 0 ? scaleFactor : 1.0)

    font: Tokens.font.icon.builders.medium.scale(s).build()
    padding: type === IconButton.Text
        ? Math.max(2, Math.round(Tokens.padding.extraSmall / 2 * s))
        : Math.max(4, Math.round(Tokens.padding.small * s))

    activeColour: translucent
        ? Qt.alpha(type === IconButton.Filled ? Colours.palette.m3primary : Colours.palette.m3secondary, Colours.light ? 0.82 : 0.72)
        : (type === IconButton.Filled ? Colours.palette.m3primary : Colours.palette.m3secondary)

    inactiveColour: {
        if (translucent) {
            if (!isToggle && type === IconButton.Filled)
                return Qt.alpha(Colours.palette.m3primary, Colours.light ? 0.82 : 0.72);
            if (type === IconButton.Filled)
                return Qt.alpha(Colours.palette.m3primaryContainer, Colours.light ? 0.70 : 0.50);
            if (type === IconButton.Tonal)
                return Qt.alpha(Colours.palette.m3secondaryContainer, Colours.light ? 0.62 : 0.44);
            return "transparent";
        }
        if (!isToggle && type === IconButton.Filled)
            return Colours.palette.m3primary;
        if (type === IconButton.Filled)
            return Colours.palette.m3primaryContainer;
        return type === IconButton.Tonal ? Colours.palette.m3secondaryContainer : "transparent";
    }

    activeOnColour: type === IconButton.Filled
        ? Colours.palette.m3onPrimary
        : (type === IconButton.Tonal ? Colours.palette.m3onSecondary : Colours.palette.m3primary)

    inactiveOnColour: {
        if (!isToggle && type === IconButton.Filled)
            return Colours.palette.m3onPrimary;
        if (type === IconButton.Filled)
            return Colours.palette.m3onPrimaryContainer;
        return type === IconButton.Tonal ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant;
    }

    disabledColour: translucent
        ? Qt.alpha(Colours.palette.m3surfaceContainerHigh, Colours.light ? 0.48 : 0.38)
        : Qt.alpha(Colours.palette.m3onSurface, 0.14)
    disabledOnColour: Qt.alpha(Colours.palette.m3onSurface, 0.50)
}

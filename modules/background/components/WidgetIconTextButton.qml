pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components.controls
import qs.services

IconTextButton {
    id: root

    property bool translucent: true
    property real scaleFactor: 1.0
    readonly property real s: Math.max(0.65, scaleFactor > 0 ? scaleFactor : 1.0)

    font: Tokens.font.body.builders.small.scale(s).weight(Font.Medium).build()
    horizontalPadding: Math.max(6, Math.round(Tokens.padding.medium * s))
    verticalPadding: Math.max(3, Math.round(Tokens.padding.small * s))

    label.elide: Text.ElideRight

    activeColour: translucent
        ? Qt.alpha(type === IconTextButton.Filled ? Colours.palette.m3primary : Colours.palette.m3secondary, Colours.light ? 0.82 : 0.72)
        : (type === IconTextButton.Filled ? Colours.palette.m3primary : Colours.palette.m3secondary)

    inactiveColour: {
        if (translucent) {
            if (!isToggle && type === IconTextButton.Filled)
                return Qt.alpha(Colours.palette.m3primary, Colours.light ? 0.82 : 0.72);
            if (type === IconTextButton.Filled)
                return Qt.alpha(Colours.palette.m3primaryContainer, Colours.light ? 0.70 : 0.50);
            if (type === IconTextButton.Tonal)
                return Qt.alpha(Colours.palette.m3secondaryContainer, Colours.light ? 0.62 : 0.44);
            return "transparent";
        }
        if (!isToggle && type === IconTextButton.Filled)
            return Colours.palette.m3primary;
        if (type === IconTextButton.Filled)
            return Colours.palette.m3primaryContainer;
        return type === IconTextButton.Tonal ? Colours.palette.m3secondaryContainer : "transparent";
    }

    activeOnColour: {
        if (type === IconTextButton.Text)
            return Colours.palette.m3primary;
        return type === IconTextButton.Filled ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondary;
    }

    inactiveOnColour: {
        if (!isToggle && type === IconTextButton.Filled)
            return Colours.palette.m3onPrimary;
        if (type === IconTextButton.Text)
            return Colours.palette.m3primary;
        return type === IconTextButton.Filled ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSecondaryContainer;
    }

    disabledColour: translucent
        ? Qt.alpha(Colours.palette.m3surfaceContainerHigh, Colours.light ? 0.48 : 0.38)
        : Qt.alpha(Colours.palette.m3onSurface, 0.14)
    disabledOnColour: Qt.alpha(Colours.palette.m3onSurface, 0.50)
}

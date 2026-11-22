import QtQuick
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    implicitWidth: Math.round(Tokens.font.body.large.pointSize * 1.2)
    implicitHeight: Math.round(Tokens.font.body.large.pointSize * 1.2)

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const screenState = ShellState.forActive();
            screenState.launcher = !screenState.launcher;
        }
    }

    Loader {
        asynchronous: true
        anchors.centerIn: parent
        scale: mouseArea.pressed ? 0.9 : (mouseArea.containsMouse ? 1.12 : 1.0)
        sourceComponent: SysInfo.isDefaultLogo ? vacuitedLogo : distroIcon

        Behavior on scale {
            Anim {
                type: Anim.FastSpatial
            }
        }
    }

    Component {
        id: vacuitedLogo

        Logo {
            implicitWidth: Math.round(Tokens.font.body.large.pointSize * 1.65)
            implicitHeight: Math.round(Tokens.font.body.large.pointSize * 1.65)
        }
    }

    Component {
        id: distroIcon

        ColouredIcon {
            source: SysInfo.osLogo
            implicitSize: Math.round(Tokens.font.body.large.pointSize * 1.2)
            colour: Colours.palette.m3tertiary
        }
    }
}

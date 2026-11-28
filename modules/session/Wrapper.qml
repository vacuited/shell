pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components

Item {
    id: root

    required property ScreenState screenState
    required property bool sidebarVisible

    readonly property bool powerHub: Config.session.powerHub === true
    readonly property real nonAnimWidth: powerHub ? 0 : content.implicitWidth

    readonly property bool shouldBeActive: !powerHub && screenState.session && Config.session.enabled
    property real offsetScale: shouldBeActive ? 0 : 1
    property real sidebarOffset: sidebarVisible ? 14 : 0

    visible: !powerHub && offsetScale < 1
    anchors.leftMargin: Config.bar.position === "right" ? (-implicitWidth - 5 - sidebarOffset) * offsetScale : 0
    anchors.rightMargin: Config.bar.position !== "right" ? (-implicitWidth - 5 - sidebarOffset) * offsetScale : 0
    implicitWidth: powerHub ? 0 : content.implicitWidth
    implicitHeight: powerHub ? 0 : (content.implicitHeight || 510)
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {}
    }

    Loader {
        id: content

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left

        active: !root.powerHub && (root.shouldBeActive || root.visible)

        sourceComponent: Content {
            screenState: root.screenState
        }
    }
}

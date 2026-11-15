pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property Wrapper notch
    required property ShellScreen screen

    property bool initialized: false
    Component.onCompleted: Qt.callLater(() => root.initialized = true)

    property bool hovered: false

    readonly property string activity: notch.bubbleActivity ?? ""
    readonly property bool shouldBeActive: activity.length > 0 && notch.shouldBeActive && notch.offsetScale < 0.5
    readonly property real gap: Tokens.spacing.small + 3

    property real detachProg: shouldBeActive ? 1 : 0
    Behavior on detachProg {
        enabled: root.initialized
        Anim { type: Anim.DefaultSpatial }
    }

    readonly property real offsetScale: notch.offsetScale

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    // Starts inside main notch left edge and pinches out left via BlobGroup circular smin
    x: notch.x - (implicitWidth + gap) * detachProg
    y: notch.y
    visible: detachProg > 0.01

    opacity: Math.min(1, detachProg * 2.2)

    Loader {
        id: content

        anchors.fill: parent
        active: Config.notch.enabled && Config.notch.showBubble && root.detachProg > 0.01

        sourceComponent: BubblePill {
            activity: root.activity
            compact: Config.notch.alwaysCompact || (!root.notch.emptyWorkspace && Config.notch.compactWithWindows)
            allowLive: root.notch.visualiserLive
            hovered: root.hovered
        }
    }
}

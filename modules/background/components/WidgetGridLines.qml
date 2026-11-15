pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.services

Item {
    id: root

    property real safeLeft: 0
    property real safeTop: 0
    property real safeRight: width
    property real safeBottom: height
    property real workCenterX: Math.round(width / 2)
    property real workCenterY: Math.round(height / 2)
    property bool centerXActive: false
    property bool centerYActive: false
    property var guideLines: []

    readonly property real safeW: Math.max(0, safeRight - safeLeft)
    readonly property real safeH: Math.max(0, safeBottom - safeTop)

    // Subtle workspace margin perimeter so bar & border bounds remain obvious while arranging.
    Rectangle {
        x: root.safeLeft
        y: root.safeTop
        width: root.safeW
        height: root.safeH
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.22)
        radius: Tokens.rounding.large
    }

    // Minimal vertical workspace center guideline.
    Rectangle {
        x: Math.round(root.workCenterX - width / 2)
        y: root.safeTop
        width: root.centerXActive ? 2 : 1
        height: root.safeH
        color: root.centerXActive ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.22)
        opacity: root.centerXActive ? 0.92 : 0.7

        Behavior on width {
            NumberAnimation {
                duration: Tokens.anim.durations.expressiveFastEffects
            }
        }
    }

    // Minimal horizontal workspace center guideline.
    Rectangle {
        x: root.safeLeft
        y: Math.round(root.workCenterY - height / 2)
        width: root.safeW
        height: root.centerYActive ? 2 : 1
        color: root.centerYActive ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.22)
        opacity: root.centerYActive ? 0.92 : 0.7

        Behavior on height {
            NumberAnimation {
                duration: Tokens.anim.durations.expressiveFastEffects
            }
        }
    }

    // Subtle bullseye when snapped cleanly to the workspace axis.
    Rectangle {
        visible: root.centerXActive || root.centerYActive
        width: (root.centerXActive && root.centerYActive) ? 12 : 8
        height: width
        radius: width / 2
        x: Math.round(root.workCenterX - width / 2)
        y: Math.round(root.workCenterY - height / 2)
        color: (root.centerXActive && root.centerYActive) ? Colours.palette.m3primary : "transparent"
        border.width: 2
        border.color: Colours.palette.m3primary
    }

    // Dynamic sibling edge, center, and uniform-gap alignment lines.
    Repeater {
        model: root.guideLines ?? []

        delegate: Item {
            id: guideDelegate

            required property var modelData

            readonly property bool vertical: modelData.orientation === "v"
            readonly property bool isGap: modelData.kind === "gap"
            readonly property color lineCol: isGap
                ? Colours.palette.m3tertiary
                : (modelData.kind === "center" ? Colours.palette.m3primary : Colours.palette.m3secondary)

            anchors.fill: parent

            Rectangle {
                visible: !guideDelegate.isGap
                x: guideDelegate.vertical ? Math.round(guideDelegate.modelData.pos) : Math.round(guideDelegate.modelData.start)
                y: guideDelegate.vertical ? Math.round(guideDelegate.modelData.start) : Math.round(guideDelegate.modelData.pos)
                width: guideDelegate.vertical ? 1.5 : Math.max(2, Math.round(guideDelegate.modelData.end - guideDelegate.modelData.start))
                height: guideDelegate.vertical ? Math.max(2, Math.round(guideDelegate.modelData.end - guideDelegate.modelData.start)) : 1.5
                radius: 1
                color: Qt.alpha(guideDelegate.lineCol, 0.85)
            }

            // Gap bracket connector between neighboring widgets spaced 12px apart.
            Rectangle {
                visible: guideDelegate.isGap
                x: guideDelegate.vertical ? Math.round(guideDelegate.modelData.gapStart) : Math.round(guideDelegate.modelData.pos - 3)
                y: guideDelegate.vertical ? Math.round(guideDelegate.modelData.pos - 3) : Math.round(guideDelegate.modelData.gapStart)
                width: guideDelegate.vertical ? Math.max(4, Math.round(guideDelegate.modelData.gapEnd - guideDelegate.modelData.gapStart)) : 6
                height: guideDelegate.vertical ? 6 : Math.max(4, Math.round(guideDelegate.modelData.gapEnd - guideDelegate.modelData.gapStart))
                radius: 3
                color: Qt.alpha(Colours.palette.m3tertiary, 0.78)
            }
        }
    }
}

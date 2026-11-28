import QtQuick
import Caelestia.Config
import qs.components

Item {
    id: root

    property bool opened: false
    property real panelReveal: 0
    property real backdropReveal: 0
    property real clockReveal: 0
    property real detailsReveal: 0
    property real dialReveal: 0
    property real spatialReveal: 0
    readonly property real contentReveal: clockReveal
    readonly property real expansion: Math.max(0, Math.min(1, spatialReveal))
    readonly property real cornerReveal: Math.max(0, spatialReveal)
    property bool initialized: false
    readonly property bool animating: enter.running || leave.running
    readonly property bool active: opened || animating || panelReveal > 0 || backdropReveal > 0 || cornerReveal > 0 || dialReveal > 0 || clockReveal > 0 || detailsReveal > 0

    signal closed()

    function transition(): void {
        if (opened) {
            leave.stop();
            enter.restart();
        } else {
            enter.stop();
            leave.restart();
        }
    }

    visible: false
    onOpenedChanged: if (initialized) transition()
    Component.onCompleted: {
        initialized = true;
        if (opened)
            transition();
    }

    ParallelAnimation {
        id: enter

        NumberAnimation {
            target: root
            property: "panelReveal"
            to: 1
            duration: 300
            easing: Tokens.anim.emphasizedDecel
        }
        NumberAnimation {
            target: root
            property: "backdropReveal"
            to: 1
            duration: 360
            easing: Tokens.anim.emphasizedDecel
        }
        Anim {
            target: root
            property: "spatialReveal"
            to: 1
            type: Anim.DefaultSpatial
        }
        SequentialAnimation {
            PauseAnimation { duration: 45 }
            NumberAnimation {
                target: root
                property: "dialReveal"
                to: 1
                duration: 360
                easing: Tokens.anim.emphasizedDecel
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 80 }
            NumberAnimation {
                target: root
                property: "clockReveal"
                to: 1
                duration: 380
                easing: Tokens.anim.emphasizedDecel
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 130 }
            NumberAnimation {
                target: root
                property: "detailsReveal"
                to: 1
                duration: 400
                easing: Tokens.anim.emphasizedDecel
            }
        }
    }

    ParallelAnimation {
        id: leave

        NumberAnimation {
            target: root
            property: "detailsReveal"
            to: 0
            duration: 150
            easing: Tokens.anim.emphasizedAccel
        }
        NumberAnimation {
            target: root
            property: "clockReveal"
            to: 0
            duration: 165
            easing: Tokens.anim.emphasizedAccel
        }
        NumberAnimation {
            target: root
            property: "dialReveal"
            to: 0
            duration: 180
            easing: Tokens.anim.emphasizedAccel
        }
        NumberAnimation {
            target: root
            property: "backdropReveal"
            to: 0
            duration: 220
            easing: Tokens.anim.emphasizedAccel
        }
        NumberAnimation {
            target: root
            property: "panelReveal"
            to: 0
            duration: 220
            easing: Tokens.anim.emphasizedAccel
        }
        Anim {
            target: root
            property: "spatialReveal"
            to: 0
            type: Anim.FastSpatial
        }
        // Keep the corner visible until its spatial retraction finishes.
        onFinished: {
            if (!root.opened) {
                root.dialReveal = 0;
                root.closed();
            }
        }
    }
}

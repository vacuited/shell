pragma ComponentBehavior: Bound

import QtQuick
import M3Shapes
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.effects
import "Dial.js" as Dial

Item {
    id: root

    required property var colours
    property var actions: Dial.actions
    required property string fontFamily
    property string iconFontFamily: "Material Symbols Rounded"
    property int selected: -1
    property bool immediate: false
    property bool dragging: false
    property string armedActionId: ""
    property bool confirmDangerous: true
    property int idleShape: MaterialShape.Flower
    property string facePath: ""

    readonly property var currentAction: (selected >= 0 && selected < actions.length) ? actions[selected] : null
    readonly property bool isDanger: currentAction?.dangerous === true
    readonly property bool isArmed: currentAction !== null && armedActionId === currentAction.id
    readonly property color accent: isDanger ? colours.m3error : colours.m3primary
    readonly property color accentForeground: isDanger ? colours.m3onError : colours.m3onPrimary
    readonly property int targetShape: currentAction ? resolveShape(currentAction.shape) : idleShape
    readonly property bool showAvatar: currentAction === null && facePath !== "" && faceImg.status === Image.Ready

    implicitWidth: 560
    implicitHeight: 278

    function show(index: int, animate: bool): void {
    }

    function resolveShape(name: string): int {
        switch (name) {
        case "Gem":
            return MaterialShape.Gem;
        case "Arch":
            return MaterialShape.Arch;
        case "SoftBurst":
            return MaterialShape.SoftBurst;
        case "Clover4Leaf":
            return MaterialShape.Clover4Leaf;
        case "Cookie7Sided":
            return MaterialShape.Cookie7Sided;
        case "Sunny":
            return MaterialShape.Sunny;
        case "Puffy":
            return MaterialShape.Puffy;
        case "Pentagon":
            return MaterialShape.Pentagon;
        case "ClamShell":
            return MaterialShape.ClamShell;
        case "Cookie6Sided":
            return MaterialShape.Cookie6Sided;
        case "Flower":
            return MaterialShape.Flower;
        default:
            return MaterialShape.Cookie9Sided;
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.width
        spacing: 14

        // Persistent 128x128 liquid-morphing MaterialShape hero (~/.face when idle -> per-action shape)
        Item {
            id: heroWrap

            objectName: "powerMenuHeroShape"
            anchors.horizontalCenter: parent.horizontalCenter
            width: 128
            height: 128
            scale: root.isArmed ? 1.07 : (root.currentAction ? 1.02 : 1.0)
            transformOrigin: Item.Center

            Behavior on scale {
                enabled: !root.immediate
                Anim { type: Anim.FastSpatial }
            }

            MaterialShape {
                id: heroShape

                anchors.fill: parent
                implicitSize: 128
                shape: root.targetShape
                animationDuration: Tokens.anim.durations.expressiveDefaultSpatial
                animationEasing: Tokens.anim.expressiveDefaultSpatial
                rotation: root.currentAction ? (root.selected * 12 - 18) : 0
                color: root.isArmed
                    ? root.accent
                    : (root.isDanger
                        ? root.colours.m3errorContainer
                        : (root.currentAction ? root.colours.m3primaryContainer : root.colours.m3surfaceContainerHigh))

                Behavior on rotation {
                    enabled: !root.immediate
                    Anim { type: Anim.DefaultSpatial }
                }
                Behavior on color {
                    enabled: !root.immediate
                    CAnim {}
                }
            }

            MaterialShape {
                id: avatarMask

                anchors.fill: parent
                implicitSize: 128
                visible: false
                layer.enabled: root.showAvatar
                layer.smooth: true
                shape: root.targetShape
                color: "#ffffff"
                animationDuration: Tokens.anim.durations.expressiveDefaultSpatial
                animationEasing: Tokens.anim.expressiveDefaultSpatial
            }

            Image {
                id: faceImg

                anchors.fill: parent
                source: root.facePath !== "" ? ("file://" + root.facePath) : ""
                sourceSize: Qt.size(256, 256)
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true
                asynchronous: true
                opacity: root.showAvatar ? 1 : 0
                visible: opacity > 0.01
                layer.enabled: visible
                layer.smooth: true
                layer.effect: Mask {
                    maskSource: avatarMask
                }

                Behavior on opacity {
                    enabled: !root.immediate
                    Anim { type: Anim.FastEffects }
                }
            }

            TextMetrics {
                id: heroIconMetrics
                font: heroIcon.font
                text: heroIcon.text
            }

            Text {
                id: heroIcon

                renderType: Text.CurveRendering
                x: (parent.width - heroIconMetrics.tightBoundingRect.width) / 2 - heroIconMetrics.tightBoundingRect.x
                y: (parent.height - heroIconMetrics.tightBoundingRect.height) / 2 - heroIconMetrics.tightBoundingRect.y - baselineOffset
                text: root.currentAction ? root.currentAction.icon : "power_settings_new"
                color: root.isArmed
                    ? root.accentForeground
                    : (root.isDanger
                        ? root.colours.m3onErrorContainer
                        : (root.currentAction ? root.colours.m3onPrimaryContainer : root.colours.m3onSurfaceVariant))
                font.family: root.iconFontFamily
                font.pixelSize: 48
                font.variableAxes: ({ "FILL": root.currentAction ? 1 : 0, "wght": 500, "GRAD": 0, "opsz": 48 })
                opacity: (root.currentAction !== null || !root.showAvatar) ? 1 : 0
                scale: root.currentAction !== null ? 1.0 : 0.72
                transformOrigin: Item.Center

                Behavior on opacity {
                    enabled: !root.immediate
                    Anim { type: Anim.FastEffects }
                }
                Behavior on scale {
                    enabled: !root.immediate
                    Anim { type: Anim.FastSpatial }
                }
                Behavior on color {
                    enabled: !root.immediate
                    CAnim {}
                }
            }
        }

        // Minimal Caelestia title (replaces boilerplate 2-line prose)
        Text {
            id: actionTitle

            objectName: "powerMenuActionTitle"
            renderType: Text.CurveRendering
            width: parent.width
            height: 48
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.currentAction ? root.currentAction.title : Tr.tr("Session")
            color: root.isDanger ? root.colours.m3error : root.colours.m3onSurface
            font.family: root.fontFamily
            font.pixelSize: 38
            font.variableAxes: ({ "wght": 800, "ROND": 100 })

            Behavior on color {
                enabled: !root.immediate
                CAnim {}
            }
        }

        // Borderless filled M3 tonal action pill
        Rectangle {
            id: actionPill

            anchors.horizontalCenter: parent.horizontalCenter
            height: 36
            width: Math.max(150, actionPillLabel.implicitWidth + 36)
            radius: 18
            border.width: 0
            color: root.isArmed
                ? root.accent
                : (root.isDanger
                    ? root.colours.m3errorContainer
                    : (root.currentAction ? root.colours.m3primaryContainer : root.colours.m3surfaceContainerHigh))
            transformOrigin: Item.Center

            Behavior on width {
                enabled: !root.immediate
                Anim { type: Anim.FastSpatial }
            }
            Behavior on color {
                enabled: !root.immediate
                CAnim {}
            }

            SequentialAnimation on scale {
                running: root.isArmed && root.visible
                loops: Animation.Infinite
                onStopped: actionPill.scale = 1.0

                NumberAnimation { to: 1.05; duration: 420; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 420; easing.type: Easing.InOutSine }
            }

            Text {
                id: actionPillLabel

                renderType: Text.CurveRendering
                anchors.centerIn: parent
                text: root.isArmed
                    ? Tr.tr("Click again to %1").arg(root.currentAction.title)
                    : (root.currentAction
                        ? (root.dragging ? Tr.tr("Release to %1") : Tr.tr("Click to %1")).arg(root.currentAction.title)
                        : Tr.tr("Hover or scroll the dial"))
                color: root.isArmed
                    ? root.accentForeground
                    : (root.isDanger
                        ? root.colours.m3onErrorContainer
                        : (root.currentAction ? root.colours.m3onPrimaryContainer : root.colours.m3onSurfaceVariant))
                font.family: root.fontFamily
                font.pixelSize: 14
                font.variableAxes: ({ "wght": 650, "ROND": 100 })

                Behavior on color {
                    enabled: !root.immediate
                    CAnim {}
                }
            }
        }

        // Compact borderless keybind hints
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            opacity: 0.78

            Rectangle {
                height: 26
                width: primaryHintText.implicitWidth + 22
                radius: 13
                color: root.colours.m3surfaceContainerHigh

                Text {
                    id: primaryHintText

                    renderType: Text.CurveRendering
                    anchors.centerIn: parent
                    text: root.isArmed
                        ? Tr.tr("Right-click or Esc to cancel")
                        : Tr.tr("Scroll / 1–%1").arg(Math.max(1, root.actions.length))
                    color: root.colours.m3onSurfaceVariant
                    font.family: root.fontFamily
                    font.pixelSize: 12
                    font.variableAxes: ({ "wght": 550, "ROND": 100 })
                }
            }

            Rectangle {
                visible: !root.isArmed
                height: 26
                width: dismissHintText.implicitWidth + 22
                radius: 13
                color: root.colours.m3surfaceContainerHigh

                Text {
                    id: dismissHintText

                    renderType: Text.CurveRendering
                    anchors.centerIn: parent
                    text: Tr.tr("Right-click · Esc")
                    color: root.colours.m3onSurfaceVariant
                    font.family: root.fontFamily
                    font.pixelSize: 12
                    font.variableAxes: ({ "wght": 550, "ROND": 100 })
                }
            }
        }
    }
}

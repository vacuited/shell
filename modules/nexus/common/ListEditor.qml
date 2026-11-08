pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

ListView {
    id: root

    property alias values: valuesModel.values
    property bool first
    property bool last

    signal itemMoved(from: int, to: int)
    signal itemRemoved(index: int)
    signal itemToggled(index: int, checked: bool)

    function labelFor(item: var): string {
        return item.label;
    }

    function toggledFor(item: var): bool {
        return false;
    }

    function dampOvershoot(overshoot: real, maxOvershoot: real): real {
        return overshoot / (1 + overshoot / maxOvershoot);
    }

    Layout.fillWidth: true
    implicitHeight: contentHeight

    spacing: Tokens.spacing.extraSmall / 2
    interactive: false

    model: DelegateModel {
        id: visualModel

        model: ScriptModel {
            id: valuesModel
        }

        delegate: ListRow {}
    }

    add: Transition {
        Anim {
            properties: "opacity"
            type: Anim.DefaultEffects
            from: 0
            to: 1
        }
    }

    remove: Transition {
        Anim {
            properties: "opacity"
            type: Anim.DefaultEffects
            to: 0
        }
    }

    move: Transition {
        Anim {
            properties: "opacity"
            type: Anim.DefaultEffects
            to: 1
        }
    }

    displaced: Transition {
        Anim {
            properties: "opacity"
            type: Anim.DefaultEffects
            to: 1
        }
        Anim {
            properties: "y"
        }
    }

    Behavior on implicitHeight {
        Anim {}
    }

    component ListRow: Item {
        id: item

        required property var modelData
        property bool held
        property point pressPos
        property int pressIndex

        property real topRadius: root?.first && DelegateModel.itemsIndex === 0 ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
        property real bottomRadius: root?.last && DelegateModel.itemsIndex === (root?.count ?? 0) - 1 ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
        property real radiusLerpProg

        function lerpRadius(a: real, b: real): real {
            return a + (b - a) * radiusLerpProg;
        }

        anchors.left: root?.contentItem.left
        anchors.right: root?.contentItem.right
        implicitHeight: row.implicitHeight + row.anchors.margins * 2
        z: held || returnAnim.running ? 1 : 0

        state: held ? "held" : ""

        states: State {
            name: "held"

            PropertyChanges {
                item.radiusLerpProg: 1
                placeholder.opacity: 0.1
                elevation.opacity: 1
                itemBg.color: Colours.palette.m3primaryContainer
                dragIcon.color: Colours.palette.m3onPrimaryContainer
                label.color: Colours.palette.m3onPrimaryContainer
            }
        }

        transitions: Transition {
            Anim {
                properties: "opacity,radiusLerpProg"
                type: Anim.SlowEffects
            }
            PropertyAction {
                properties: "color,inactiveOnColour"
            }
        }

        Behavior on topRadius {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on bottomRadius {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        StyledRect {
            id: placeholder

            anchors.fill: parent
            color: Colours.palette.m3primary
            radius: Tokens.rounding.extraSmall
            topLeftRadius: item.topRadius
            topRightRadius: item.topRadius
            bottomLeftRadius: item.bottomRadius
            bottomRightRadius: item.bottomRadius
            opacity: 0
        }

        MouseArea {
            id: mouse

            anchors.fill: parent
            preventStealing: true

            onPressed: e => {
                returnAnim.stop();
                item.pressPos = Qt.point(e.x, e.y);
                item.pressIndex = item.DelegateModel.itemsIndex;
                item.held = true;

                itemContent.x = Qt.binding(() => {
                    if (!root)
                        return 0;

                    const maxOvershoot = Tokens.padding.extraExtraLarge;
                    const x = mouse.mouseX - item.pressPos.x;
                    return root.dampOvershoot(Math.abs(x), maxOvershoot) * Math.sign(x);
                });
                itemContent.y = Qt.binding(() => {
                    if (!root)
                        return 0;

                    const maxOvershoot = Tokens.padding.extraLarge;
                    const curContentY = item.mapToItem(root.contentItem, 0, mouse.mouseY).y;
                    const desiredTop = curContentY - item.pressPos.y;
                    const maxY = Math.max(0, root.implicitHeight - item.implicitHeight);
                    let clampedTop = desiredTop;
                    if (desiredTop < 0)
                        clampedTop = -root.dampOvershoot(-desiredTop, maxOvershoot);
                    else if (desiredTop > maxY)
                        clampedTop = maxY + root.dampOvershoot(desiredTop - maxY, maxOvershoot);
                    return clampedTop - item.y;
                });
            }

            onPositionChanged: e => {
                if (!root || root.count <= 1)
                    return;

                const curContentY = item.mapToItem(root.contentItem, 0, e.y).y;
                const centerY = curContentY - item.pressPos.y + item.implicitHeight / 2;
                const stride = item.implicitHeight + root.spacing;
                if (stride <= 0)
                    return;

                const idx = item.DelegateModel.itemsIndex;
                const swapIdx = Math.max(0, Math.min(root.count - 1, Math.floor(centerY / stride)));
                if (swapIdx !== idx)
                    visualModel.items.move(idx, swapIdx);
            }

            onReleased: e => {
                // Break bindings
                itemContent.x = itemContent.x;
                itemContent.y = itemContent.y;
                returnAnim.start();
                item.held = false;

                const idx = item.DelegateModel.itemsIndex;
                if (idx !== item.pressIndex)
                    root.itemMoved(item.pressIndex, idx);
            }
        }

        Anim {
            id: returnAnim

            target: itemContent
            properties: "x,y"
            to: 0
        }

        Item {
            id: itemContent

            implicitWidth: item.width
            implicitHeight: item.implicitHeight

            Elevation {
                id: elevation

                anchors.fill: parent
                radius: itemBg.radius
                topLeftRadius: itemBg.topLeftRadius
                topRightRadius: itemBg.topRightRadius
                bottomLeftRadius: itemBg.bottomLeftRadius
                bottomRightRadius: itemBg.bottomRightRadius
                level: 3
                opacity: 0
            }

            StyledRect {
                id: itemBg

                anchors.fill: parent
                color: Colours.tPalette.m3surfaceContainer
                radius: item.lerpRadius(Tokens.rounding.extraSmall, Tokens.rounding.large)
                topLeftRadius: item.lerpRadius(item.topRadius, Tokens.rounding.large)
                topRightRadius: item.lerpRadius(item.topRadius, Tokens.rounding.large)
                bottomLeftRadius: item.lerpRadius(item.bottomRadius, Tokens.rounding.large)
                bottomRightRadius: item.lerpRadius(item.bottomRadius, Tokens.rounding.large)
            }

            MouseArea {
                id: stateLayer

                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
                cursorShape: mouse.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                StyledRect {
                    anchors.fill: parent
                    radius: itemBg.radius
                    topLeftRadius: itemBg.topLeftRadius
                    topRightRadius: itemBg.topRightRadius
                    bottomLeftRadius: itemBg.bottomLeftRadius
                    bottomRightRadius: itemBg.bottomRightRadius
                    color: Colours.palette.m3onSurface
                    opacity: parent.containsMouse && !item.held ? 0.08 : 0

                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }
                }
            }

            RowLayout {
                id: row

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.large

                spacing: Tokens.spacing.medium

                MaterialIcon {
                    id: dragIcon

                    text: "drag_indicator"
                    color: Qt.alpha(Colours.palette.m3onSurfaceVariant, enabledSwitch.checked ? 1 : 0.5)
                    fontStyle: Tokens.font.icon.medium
                }

                StyledText {
                    id: label

                    Layout.fillWidth: true
                    text: root.labelFor(item.modelData)
                    color: Qt.alpha(Colours.palette.m3onSurface, enabledSwitch.checked ? 1 : 0.5)
                    elide: Text.ElideRight
                }

                StyledSwitch {
                    id: enabledSwitch

                    checked: root.toggledFor(item.modelData)
                    font: Tokens.font.icon.medium
                    onToggled: root.itemToggled(item.DelegateModel.itemsIndex, checked)
                }

                IconButton {
                    type: IconButton.Text
                    isRound: true
                    icon: "delete"
                    inactiveOnColour: Colours.palette.m3error
                    font: Tokens.font.icon.medium
                    label.fill: 0

                    onClicked: root.itemRemoved(item.DelegateModel.itemsIndex)
                }
            }
        }
    }
}

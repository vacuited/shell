pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import Quickshell
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.modules.drawers

MouseArea {
    id: root

    enum Side {
        Top,
        Bottom,
        Left,
        Right
    }

    required property Item attachTo
    property int attachSideX: Menu.Side.Right
    property int attachSideY: Menu.Side.Bottom
    property int thisSideX: Menu.Side.Right
    property int thisSideY: Menu.Side.Top
    property real marginX
    property real marginY

    property list<MenuItem> items
    property MenuItem active: items[0] ?? null
    property bool expanded
    property real maxHeight: 320
    readonly property Item boundsItem: {
        let node = root.attachTo;
        let lastBeforePanels = null;
        while (node && node.parent) {
            if (node.parent.utilitiesShortcutActive !== undefined) {
                if (node === node.parent.panels && lastBeforePanels)
                    return lastBeforePanels;
                return root.parent;
            }
            lastBeforePanels = node;
            node = node.parent;
        }
        return root.parent;
    }

    signal itemSelected(item: MenuItem)

    parent: {
        let node = root.attachTo;
        let interactionsNode = null;
        
        while (node && node.parent) {
            if (node.utilitiesShortcutActive !== undefined) {
                interactionsNode = node;
            }
            node = node.parent;
        }

        if (interactionsNode) {
            return interactionsNode;
        }

        return node || root.parent;
    }
    anchors.fill: parent
    z: expanded ? 2 : (opacity > 0 ? 1 : 0)

    enabled: expanded
    hoverEnabled: expanded
    cursorShape: expanded ? Qt.ArrowCursor : undefined
    onClicked: expanded = false

    opacity: expanded ? 1 : 0

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    TransformWatcher {
        id: watcher

        a: root.parent
        b: root.attachTo
    }

    Elevation {
        id: menu

        readonly property real edgePad: Tokens.padding.small
        readonly property real gapY: Math.abs(root.marginY)
        readonly property bool isAttachTop: root.attachSideY === Menu.Side.Top || root.attachSideY === Menu.Top
        readonly property bool isThisBottom: root.thisSideY === Menu.Side.Bottom || root.thisSideY === Menu.Bottom
        readonly property bool isDropdownY: isAttachTop === isThisBottom
        readonly property bool prefersUp: isThisBottom
        readonly property real desiredHeight: Math.min(root.maxHeight, column.implicitHeight + Tokens.padding.extraSmall * 2)

        readonly property var layoutMetrics: {
            CUtils.dependency(watcher.transform); // mapToItem is not reactive so this forces updates
            const p = root.parent;
            const item = root.attachTo;
            if (!p || !item)
                return {
                    valid: false,
                    left: 0,
                    top: 0,
                    right: 0,
                    bottom: 0,
                    attachTop: 0,
                    attachBottom: 0
                };

            const bItem = (root.boundsItem && root.boundsItem.width > 0 && root.boundsItem.height > 0) ? root.boundsItem : p;
            const bw = bItem.width;
            const bh = bItem.height;
            const topLeft = bItem === p ? Qt.point(0, 0) : bItem.mapToItem(p, 0, 0);
            const bottomRight = bItem === p ? Qt.point(bw, bh) : bItem.mapToItem(p, bw, bh);
            const aTop = item.mapToItem(p, 0, 0).y;
            const aBottom = item.mapToItem(p, 0, item.height).y;

            const left = Math.min(topLeft.x, bottomRight.x);
            const right = Math.max(topLeft.x, bottomRight.x);
            const top = Math.min(topLeft.y, bottomRight.y);
            const bottom = Math.max(topLeft.y, bottomRight.y);

            return {
                valid: (bottom - top) > edgePad * 2 && (right - left) > edgePad * 2,
                left: left,
                top: top,
                right: right,
                bottom: bottom,
                attachTop: Math.min(aTop, aBottom),
                attachBottom: Math.max(aTop, aBottom)
            };
        }

        readonly property real spaceBelow: Math.max(0, layoutMetrics.bottom - edgePad - (layoutMetrics.attachBottom + gapY))
        readonly property real spaceAbove: Math.max(0, (layoutMetrics.attachTop - gapY) - (layoutMetrics.top + edgePad))

        readonly property bool openUp: {
            if (!isDropdownY || !layoutMetrics.valid)
                return prefersUp;
            if (prefersUp)
                return desiredHeight <= spaceAbove || spaceAbove >= spaceBelow;
            return desiredHeight > spaceBelow && spaceAbove > spaceBelow;
        }

        readonly property real availableHeight: {
            if (!layoutMetrics.valid)
                return desiredHeight;
            const containerHeight = Math.max(0, layoutMetrics.bottom - layoutMetrics.top - edgePad * 2);
            if (!isDropdownY)
                return containerHeight;
            const sideSpace = openUp ? spaceAbove : spaceBelow;
            const minUsable = Math.min(desiredHeight, containerHeight, 120);
            return Math.max(sideSpace, minUsable);
        }

        x: {
            CUtils.dependency(watcher.transform); // mapToItem is not reactive so this forces updates
            const item = root.attachTo;
            if (!item || !root.parent)
                return 0;
            let off = (root.attachSideX === Menu.Side.Left || root.attachSideX === Menu.Left) ? 0 : item.width;
            if (root.thisSideX === Menu.Side.Right || root.thisSideX === Menu.Right)
                off -= width;
            let posX = item.mapToItem(root.parent, off, 0).x + root.marginX;
            if (layoutMetrics.valid) {
                const minAllowedX = layoutMetrics.left + edgePad;
                const maxAllowedX = layoutMetrics.right - width - edgePad;
                if (maxAllowedX >= minAllowedX)
                    posX = Math.max(minAllowedX, Math.min(posX, maxAllowedX));
            }
            return posX;
        }
        y: {
            CUtils.dependency(watcher.transform); // mapToItem is not reactive so this forces updates
            const item = root.attachTo;
            if (!item || !root.parent)
                return 0;
            let posY;
            if (isDropdownY) {
                posY = openUp ? (layoutMetrics.attachTop - gapY - height) : (layoutMetrics.attachBottom + gapY);
            } else {
                let off = isAttachTop ? 0 : item.height;
                if (isThisBottom)
                    off -= height;
                posY = item.mapToItem(root.parent, 0, off).y + root.marginY;
            }
            if (layoutMetrics.valid) {
                const minAllowedY = layoutMetrics.top + edgePad;
                const maxAllowedY = layoutMetrics.bottom - height - edgePad;
                if (maxAllowedY >= minAllowedY)
                    posY = Math.max(minAllowedY, Math.min(posY, maxAllowedY));
            }
            return posY;
        }

        radius: Tokens.rounding.large
        level: 2

        implicitWidth: Math.max(200, column.implicitWidth + Tokens.padding.extraSmall * 2)
        implicitHeight: Math.min(desiredHeight, availableHeight)

        transform: Scale {
            yScale: root.expanded ? 1 : 0.1
            origin.y: menu.openUp ? menu.height : 0

            Behavior on yScale {
                Anim {}
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onWheel: e => e.accepted = true
        }

        StyledRect {
            anchors.fill: parent
            radius: parent.radius
            color: Colours.palette.m3surfaceContainerLow

            Flickable {
                id: flickable

                anchors.fill: parent
                anchors.margins: Tokens.padding.extraSmall
                contentWidth: width
                contentHeight: column.implicitHeight
                clip: true

                interactive: contentHeight > height

                QQC.ScrollBar.vertical: StyledScrollBar {
                    flickable: flickable
                }

                ColumnLayout {
                    id: column

                    width: parent.width
                    spacing: 0

                    Repeater {
                        id: repeater

                        model: root.items

                    StyledRect {
                        id: item

                        required property int index
                        required property MenuItem modelData
                        readonly property bool active: modelData === root?.active

                        Layout.fillWidth: true
                        implicitWidth: menuOptionRow.implicitWidth + Tokens.padding.medium * 2
                        implicitHeight: menuOptionRow.implicitHeight + Tokens.padding.medium * 2

                        radius: active ? Tokens.rounding.medium : Tokens.rounding.extraSmall
                        topLeftRadius: index === 0 ? Tokens.rounding.medium : radius
                        topRightRadius: index === 0 ? Tokens.rounding.medium : radius
                        bottomLeftRadius: index === repeater?.count - 1 ? Tokens.rounding.medium : radius
                        bottomRightRadius: index === repeater?.count - 1 ? Tokens.rounding.medium : radius

                        color: Qt.alpha(Colours.palette.m3tertiaryContainer, active ? 1 : 0)

                        Behavior on radius {
                            Anim {}
                        }

                        StateLayer {
                            topLeftRadius: parent.topLeftRadius
                            topRightRadius: parent.topRightRadius
                            bottomLeftRadius: parent.bottomLeftRadius
                            bottomRightRadius: parent.bottomRightRadius

                            color: item.active ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurface
                            disabled: !root.expanded
                            onClicked: {
                                root.itemSelected(item.modelData);
                                root.active = item.modelData;
                                item.modelData.clicked();
                                root.expanded = false;
                            }
                        }

                        RowLayout {
                            id: menuOptionRow

                            anchors.fill: parent
                            anchors.margins: Tokens.padding.medium
                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                Layout.alignment: Qt.AlignVCenter
                                text: item.modelData?.icon ?? ""
                                color: item.active ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurfaceVariant
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillWidth: true
                                text: item.modelData?.text ?? ""
                                color: item.active ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurface
                            }

                            Loader {
                                asynchronous: true
                                Layout.alignment: Qt.AlignVCenter
                                active: item.modelData?.trailingIcon.length > 0
                                visible: active

                                sourceComponent: MaterialIcon {
                                    text: item.modelData.trailingIcon
                                    color: item.active ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurfaceVariant
                                }
                            }
                        }
                    }
                }
            }
        }
        }
    }
}

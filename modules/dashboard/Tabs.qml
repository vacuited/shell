pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property real nonAnimWidth
    required property ScreenState screenState
    required property var tabs

    readonly property int count: tabRepeater.count
    readonly property int currentIndex: root.screenState.dashboardTab
    readonly property Item currentItem: {
        tabRepeater.count;
        return tabRepeater.itemAt(currentIndex);
    }

    implicitHeight: bar.implicitHeight + bar.anchors.topMargin + indicator.implicitHeight + indicator.anchors.topMargin + separator.implicitHeight

    RowLayout {
        id: bar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Tokens.sizes.dashboard.tabIndicatorSpacing
        spacing: 0

        Repeater {
            id: tabRepeater

            model: root.tabs

            delegate: Tab {}
        }
    }

    onTabsChanged: {
        if (root.tabs && root.tabs.length > 0 && root.screenState.dashboardTab >= root.tabs.length)
            root.screenState.dashboardTab = root.tabs.length - 1;
    }

    Item {
        id: indicator

        anchors.top: bar.bottom
        anchors.topMargin: 5
        visible: root.count > 0

        implicitWidth: {
            const tab = root.currentItem;
            if (tab)
                return tab.implicitWidth;
            const count = Math.max(1, root.count);
            const width = (root.nonAnimWidth - bar.spacing * (count - 1)) / count;
            return width;
        }
        implicitHeight: 3

        x: {
            const tab = root.currentItem;
            const count = Math.max(1, root.count);
            const width = (root.nonAnimWidth - bar.spacing * (count - 1)) / count;
            const tabWidth = tab?.implicitWidth ?? width;
            return width * root.currentIndex + (width - tabWidth) / 2;
        }

        clip: true

        StyledRect {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            implicitHeight: parent.implicitHeight * 2

            color: Colours.palette.m3primary
            radius: Tokens.rounding.full
        }

        Behavior on x {
            Anim {}
        }

        Behavior on implicitWidth {
            Anim {}
        }
    }

    StyledRect {
        id: separator

        anchors.top: indicator.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        implicitHeight: 1
        color: Colours.palette.m3outlineVariant
    }

    component Tab: Item {
        id: tab

        required property int index
        required property var modelData

        readonly property string iconName: modelData.iconName ?? ""
        readonly property string text: modelData.text ?? ""
        readonly property bool current: root.currentIndex === tab.index

        Layout.fillWidth: true
        Layout.preferredWidth: 1 // Uniform width across all tabs
        implicitWidth: mouse.implicitWidth
        implicitHeight: mouse.implicitHeight

        CustomMouseArea {
            id: mouse

            anchors.fill: parent

            function onWheel(event: WheelEvent): void {
                if (event.angleDelta.y < 0)
                    root.screenState.dashboardTab = Math.min(root.screenState.dashboardTab + 1, root.count - 1);
                else if (event.angleDelta.y > 0)
                    root.screenState.dashboardTab = Math.max(root.screenState.dashboardTab - 1, 0);
            }

            implicitWidth: Math.max(icon.width, label.width)
            implicitHeight: icon.height + label.height

            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onPressed: root.screenState.dashboardTab = tab.index

            StateLayer {
                id: stateLayer

                anchors.fill: undefined
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: parent.height + Tokens.sizes.dashboard.tabIndicatorSpacing * 2

                radius: Tokens.rounding.medium
                color: tab.current ? Colours.palette.m3primary : Colours.palette.m3onSurface
                onClicked: root.screenState.dashboardTab = tab.index
            }

            MaterialIcon {
                id: icon

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: label.top

                text: tab.iconName
                color: tab.current ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                fill: tab.current ? 1 : 0
                fontStyle: Tokens.font.icon.medium

                Behavior on fill {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            StyledText {
                id: label

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom

                text: tab.text
                color: tab.current ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            }
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Desktop widgets")
    isSubPage: true

    readonly property var widgetsConfig: root.targetConfig.background.desktopWidgets

    readonly property list<string> positionValues: ["top-left", "top-right", "bottom-left", "bottom-right"]
    readonly property list<MenuItem> positionItems: [
        MenuItem { text: qsTr("Top Left") },
        MenuItem { text: qsTr("Top Right") },
        MenuItem { text: qsTr("Bottom Left") },
        MenuItem { text: qsTr("Bottom Right") }
    ]

    readonly property var widgetNames: ({
        calendar: qsTr("Calendar"),
        weather: qsTr("Weather"),
        pomodoro: qsTr("Focus timer"),
        resources: qsTr("System resources"),
        media: qsTr("Now playing"),
        battery: qsTr("Battery")
    })

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("General")
        }

        ToggleRow {
            first: true
            text: qsTr("Enabled")
            subtext: qsTr("Show widget cards on the desktop")
            configNode: root.widgetsConfig
            propertyName: "enabled"
            checked: root.widgetsConfig.enabled
            onToggled: {
                root.widgetsConfig.enabled = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Hide when windows are open")
            subtext: qsTr("Fade the widget cards out while the workspace has windows on it")
            configNode: root.widgetsConfig
            propertyName: "hideWithWindows"
            checked: root.widgetsConfig.hideWithWindows
            onToggled: {
                root.widgetsConfig.hideWithWindows = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Blur background")
            subtext: qsTr("Blur the wallpaper behind each card")
            configNode: root.widgetsConfig
            propertyName: "blur"
            checked: root.widgetsConfig.blur
            onToggled: {
                root.widgetsConfig.blur = checked;
                root.targetConfig.save();
            }
        }

        StepperRow {
            label: qsTr("Card opacity")
            subtext: qsTr("How opaque the card backgrounds are (%)")
            value: Math.round(root.widgetsConfig.opacity * 100)
            from: 10
            to: 100
            stepSize: 5
            onMoved: v => {
                root.widgetsConfig.opacity = Math.round(v) / 100;
                root.targetConfig.save();
            }
        }

        SelectRow {
            label: qsTr("Default corner position")
            configNode: root.widgetsConfig
            propertyName: "position"
            menuItems: root.positionItems
            active: root.positionItems[root.positionValues.indexOf(root.widgetsConfig.position)] ?? root.positionItems[0]
            onSelected: item => {
                const index = root.positionItems.indexOf(item);
                if (index !== -1) {
                    root.widgetsConfig.position = root.positionValues[index];
                    root.targetConfig.save();
                }
            }
        }

        StepperRow {
            last: true
            label: qsTr("Columns")
            subtext: qsTr("Number of widget columns when unplaced")
            value: root.widgetsConfig.columns
            from: 1
            to: 6
            stepSize: 1
            onMoved: v => {
                root.widgetsConfig.columns = Math.round(v);
                root.targetConfig.save();
            }
        }

        SectionHeader {
            text: qsTr("Widget list")
        }

        ListEditor {
            function labelFor(item: var): string {
                return root.widgetNames[item.id] ?? item.id;
            }

            function toggledFor(item: var): bool {
                return item.enabled;
            }

            z: 1
            first: true
            values: root.widgetsConfig.entries.values
            onItemMoved: (from, to) => {
                root.widgetsConfig.entries.move(from, to);
                root.targetConfig.save();
            }
            onItemRemoved: index => {
                root.widgetsConfig.entries.remove(index);
                root.targetConfig.save();
            }
            onItemToggled: (index, checked) => {
                root.widgetsConfig.entries.at(index).enabled = checked;
                root.targetConfig.save();
            }
        }

        DialogSelectButton {
            rootParent: root.flickable
            icon: "add"
            label: qsTr("Add widget")
            header: qsTr("Add a widget")
            acceptLabel: qsTr("Add")

            model: Object.keys(root.widgetNames).filter(id => !root.widgetsConfig.entries.values.some(e => e.id === id)).map(id => ({
                id: id,
                label: root.widgetNames[id]
            }))

            onAccepted: {
                if (!selectedItem)
                    return;
                root.widgetsConfig.entries.insert({
                    id: selectedItem,
                    enabled: true
                });
                root.targetConfig.save();
            }
        }

        SectionHeader {
            text: qsTr("Widget layout")
        }

        WidgetGridEditor {
            Layout.topMargin: Tokens.spacing.small
            entries: root.widgetsConfig.entries.values
            columns: root.widgetsConfig.columns
            position: root.widgetsConfig.position
            names: root.widgetNames
            scroller: root.flickable
            screenWidth: root.nState.screen?.width ?? 1920
            screenHeight: root.nState.screen?.height ?? 1080
            onPlaced: placements => {
                const list = root.widgetsConfig.entries;
                placements.forEach((p, i) => {
                    if (!p.enabled)
                        return;
                    list.at(i).col = p.col;
                    list.at(i).row = p.row;
                    list.at(i).right = p.right;
                });
                root.targetConfig.save();
            }
        }

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: qsTr("Drag a widget to move it; it snaps to the grid and can go anywhere it doesn't overlap another.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        TextButton {
            Layout.alignment: Qt.AlignRight
            text: qsTr("Reset layout")
            type: TextButton.Tonal
            onClicked: {
                const list = root.widgetsConfig.entries;
                for (let i = 0; i < root.widgetsConfig.entries.values.length; i++) {
                    list.at(i).col = -1;
                    list.at(i).row = -1;
                    list.at(i).right = false;
                }
                root.targetConfig.save();
            }
        }
    }
}

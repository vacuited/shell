pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    property string filterText: ""
    property int selectedIndex: 0

    signal commandTriggered(string cmdId)

    readonly property var allCommands: [
        { id: "new", cmd: "/new", icon: "add_comment", desc: qsTr("Start a fresh conversation") },
        { id: "reset", cmd: "/reset", icon: "restart_alt", desc: qsTr("Clear the current conversation") },
        { id: "clear", cmd: "/clear", icon: "delete_sweep", desc: qsTr("Alias for /reset") },
        { id: "history", cmd: "/history", icon: "history", desc: qsTr("Toggle chat sessions history") },
        { id: "model", cmd: "/model", icon: "auto_awesome", desc: qsTr("Switch AI provider or model") },
        { id: "tools", cmd: "/tools", icon: "handyman", desc: qsTr("Open AI tools & settings in Nexus") }
    ]

    readonly property var filteredCommands: {
        var f = (filterText || "").trim().toLowerCase();
        if (!f || f.indexOf("/") !== 0 || f.indexOf(" ") !== -1) return [];
        var list = [];
        for (var i = 0; i < allCommands.length; i++) {
            if (allCommands[i].cmd.indexOf(f) === 0) {
                list.push(allCommands[i]);
            }
        }
        return list;
    }

    readonly property bool isOpen: filteredCommands.length > 0
    readonly property real targetHeight: isOpen ? (menuCol.implicitHeight + Tokens.padding.small * 2 + 4) : 0

    onFilteredCommandsChanged: {
        if (selectedIndex >= filteredCommands.length) {
            selectedIndex = Math.max(0, filteredCommands.length - 1);
        }
    }

    function moveUp() {
        if (filteredCommands.length === 0) return;
        selectedIndex = (selectedIndex - 1 + filteredCommands.length) % filteredCommands.length;
    }

    function moveDown() {
        if (filteredCommands.length === 0) return;
        selectedIndex = (selectedIndex + 1) % filteredCommands.length;
    }

    function acceptCurrent() {
        if (filteredCommands.length === 0) return false;
        var idx = Math.max(0, Math.min(selectedIndex, filteredCommands.length - 1));
        commandTriggered(filteredCommands[idx].id);
        return true;
    }

    implicitHeight: targetHeight
    opacity: isOpen ? 1 : 0
    visible: implicitHeight > 0.5
    clip: true

    Behavior on implicitHeight {
        Anim { type: Anim.Standard }
    }
    Behavior on opacity {
        Anim { type: Anim.DefaultEffects }
    }

    StyledRect {
        id: innerBox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 2
        implicitHeight: menuCol.implicitHeight + Tokens.padding.small * 2
        radius: 18
        color: Colours.tPalette.m3surfaceContainerHigh

        transform: Scale {
            yScale: root.isOpen ? 1.0 : 0.95
            xScale: root.isOpen ? 1.0 : 0.98
            origin.x: innerBox.width / 2
            origin.y: innerBox.height
            Behavior on yScale { Anim { type: Anim.Standard } }
            Behavior on xScale { Anim { type: Anim.Standard } }
        }

        // Animated Sliding Selection Pill
        StyledRect {
            x: Tokens.padding.small
            width: innerBox.width - Tokens.padding.small * 2
            height: 34
            radius: Tokens.rounding.medium
            color: Colours.tPalette.m3secondaryContainer
            visible: root.filteredCommands.length > 0
            y: Tokens.padding.small + root.selectedIndex * (34 + 2)

            Behavior on y {
                Anim { type: Anim.Standard }
            }
        }

        Column {
            id: menuCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.small
            spacing: 2

            Repeater {
                model: root.filteredCommands

                delegate: Item {
                    id: cmdRow

                    required property var modelData
                    required property int index

                    readonly property bool isSelected: index === root.selectedIndex

                    width: menuCol.width
                    height: 34

                    StateLayer {
                        anchors.fill: parent
                        radius: Tokens.rounding.medium
                        color: Colours.palette.m3onSurface
                        onEntered: root.selectedIndex = cmdRow.index
                        onClicked: root.commandTriggered(cmdRow.modelData.id)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.small
                        anchors.rightMargin: Tokens.padding.small
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: cmdRow.modelData.icon
                            fontStyle: Tokens.font.icon.small
                            color: cmdRow.isSelected
                                ? Colours.palette.m3onSecondaryContainer
                                : Colours.palette.m3primary
                            Behavior on color { CAnim {} }
                        }

                        StyledText {
                            text: cmdRow.modelData.cmd
                            font: Tokens.font.mono.small
                            color: cmdRow.isSelected
                                ? Colours.palette.m3onSecondaryContainer
                                : Colours.palette.m3onSurface
                            Behavior on color { CAnim {} }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: cmdRow.modelData.desc
                            font: Tokens.font.body.small
                            color: cmdRow.isSelected
                                ? Colours.palette.m3onSecondaryContainer
                                : Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignRight
                            Behavior on color { CAnim {} }
                        }
                    }
                }
            }
        }
    }
}

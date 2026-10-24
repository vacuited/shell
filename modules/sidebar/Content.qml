pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property Props props
    required property ScreenState screenState

    property var popouts
    property var utilities
    property bool sidebarStreaming: AiEngine.isStreaming

    readonly property bool isBarHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"
    readonly property bool showPopoutSeparator: isBarHorizontal && root.screenState.sidebar && popouts && popouts.hasCurrent && popouts.currentName !== "dockhover" && popouts.currentName !== "dockcontext" && popouts.currentName !== "activewindow" && popouts.currentName !== "github"

    property string activeTab: Visibilities.initialSidebarTab || "notifications"

    onActiveTabChanged: Visibilities.currentSidebarTab = root.activeTab

    readonly property bool aiAvailable: GlobalConfig.ai.enableOllama !== false

    readonly property var sidebarTabs: {
        var list = [
            { id: "notifications", label: qsTr("Notifications"), icon: "notifications" }
        ];
        if (root.aiAvailable) {
            list.push({ id: "ai", label: qsTr("Lilith"), icon: "smart_toy" });
        }
        if (GlobalConfig.sidebar.showNews !== false) {
            list.push({ id: "news", label: qsTr("News"), icon: "newspaper" });
        }
        return list;
    }

    readonly property int activeTabIndex: {
        for (var i = 0; i < sidebarTabs.length; i++) {
            if (sidebarTabs[i].id === root.activeTab) return i;
        }
        return 0;
    }

    Connections {
        target: GlobalConfig.ai
        function onEnableOllamaChanged() { root.checkTabs(); }
    }

    Connections {
        target: GlobalConfig.sidebar
        function onShowNewsChanged() { root.checkTabs(); }
    }

    Connections {
        target: root.screenState
        function onSidebarChanged() {
            if (root.screenState.sidebar) {
                root.activeTab = Visibilities.initialSidebarTab || "notifications";
                root.checkTabs();
                Visibilities.currentSidebarTab = root.activeTab;
            } else {
                Visibilities.initialSidebarTab = "notifications";
                Visibilities.currentSidebarTab = "";
            }
        }
    }

    Connections {
        target: Visibilities
        function onInitialSidebarTabChanged() {
            if (root.screenState.sidebar) {
                root.activeTab = Visibilities.initialSidebarTab || "notifications";
                root.checkTabs();
            }
        }
    }

    function checkTabs() {
        if (!root.aiAvailable && root.activeTab === "ai") {
            root.activeTab = "notifications";
        }
        if (GlobalConfig.sidebar.showNews === false && root.activeTab === "news") {
            root.activeTab = "notifications";
        }
    }

    Component.onCompleted: {
        if (root.screenState.sidebar && Visibilities.initialSidebarTab) {
            root.activeTab = Visibilities.initialSidebarTab;
        }
        checkTabs();
        if (root.screenState.sidebar) {
            Visibilities.currentSidebarTab = root.activeTab;
        }
    }

    GridLayout {
        id: layout

        anchors.fill: parent
        columns: 1
        rowSpacing: Tokens.spacing.medium

        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.row: root.isBarHorizontal ? 1 : 0

            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainerLow

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Dynamic Expanding Pill Header (Exact 250ms OutCubic math from original modeSwitcherRow)
                Item {
                    id: headerContainer
                    Layout.fillWidth: true
                    implicitHeight: 52
                    visible: root.sidebarTabs.length > 1

                    StyledRect {
                        id: headerNewChatBtn
                        anchors.left: parent.left
                        anchors.leftMargin: Tokens.padding.medium
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 34
                        implicitHeight: 34
                        radius: Tokens.rounding.full
                        color: Colours.tPalette.m3surfaceContainer
                        readonly property bool shown: root.activeTab === "ai" && !AiEngine.isHistoryOpen && AiEngine.chatHistory.count > 0
                        opacity: shown ? 1 : 0
                        scale: shown ? 1 : 0.75
                        visible: opacity > 0.01

                        Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                        Behavior on scale { Anim { type: Anim.DefaultSpatial } }

                        StateLayer {
                            radius: Tokens.rounding.full
                            color: Colours.palette.m3onSurface
                            onClicked: AiEngine.createNewChat()
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "add"
                            fontStyle: Tokens.font.icon.small
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }

                    StyledRect {
                        id: pillTrack
                        anchors.centerIn: parent
                        implicitWidth: pillRow.width
                        implicitHeight: 34
                        radius: Tokens.rounding.full
                        color: Colours.tPalette.m3surfaceContainer

                        // Sliding Active Pill Indicator
                        StyledRect {
                            id: activePillIndicator
                            height: parent.height
                            radius: Tokens.rounding.full
                            color: Colours.palette.m3primary

                            readonly property Item activeTabItem: pillRepeater.count > root.activeTabIndex
                                ? pillRepeater.itemAt(root.activeTabIndex)
                                : null

                            x: root.activeTabIndex * 42
                            width: activeTabItem ? activeTabItem.targetWidth : 42

                            Behavior on x {
                                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                            }
                            Behavior on width {
                                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                            }
                        }

                        Row {
                            id: pillRow
                            height: parent.height
                            spacing: 0

                            Repeater {
                                id: pillRepeater
                                model: root.sidebarTabs

                                delegate: Item {
                                    id: tabBtn

                                    required property var modelData
                                    required property int index

                                    readonly property bool active: root.activeTab === modelData.id
                                    readonly property real targetWidth: active
                                        ? Math.ceil(tabContent.implicitWidth + Tokens.padding.medium * 2)
                                        : 42

                                    height: pillRow.height
                                    width: targetWidth
                                    clip: true

                                    Behavior on width {
                                        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                                    }

                                    StateLayer {
                                        id: tabState
                                        radius: Tokens.rounding.full
                                        color: tabBtn.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                        onClicked: root.activeTab = tabBtn.modelData.id
                                    }

                                    Row {
                                        id: tabContent
                                        anchors.centerIn: parent
                                        spacing: Tokens.spacing.small

                                        MaterialIcon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: tabBtn.modelData.icon
                                            color: tabBtn.active
                                                ? Colours.palette.m3onPrimary
                                                : (tabState.containsMouse ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant)
                                            fontStyle: Tokens.font.icon.small
                                            fill: tabBtn.active ? 1 : 0

                                            Behavior on color { CAnim {} }
                                            Behavior on fill { Anim { type: Anim.DefaultEffects } }
                                        }

                                        StyledText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: tabBtn.modelData.label
                                            color: tabBtn.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                            font: Tokens.font.body.small
                                            visible: tabBtn.active
                                        }
                                    }
                                }
                            }
                        }
                    }

                    StyledRect {
                        id: headerHistoryBtn
                        anchors.right: parent.right
                        anchors.rightMargin: Tokens.padding.medium
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property bool shown: root.activeTab === "ai"
                        readonly property bool inHistory: AiEngine.isHistoryOpen
                        implicitWidth: 34
                        implicitHeight: 34
                        radius: Tokens.rounding.full
                        color: inHistory ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer
                        opacity: shown ? 1 : 0
                        scale: shown ? 1 : 0.75
                        visible: opacity > 0.01

                        Behavior on color { CAnim {} }
                        Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                        Behavior on scale { Anim { type: Anim.DefaultSpatial } }

                        StateLayer {
                            radius: Tokens.rounding.full
                            color: headerHistoryBtn.inHistory ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                            onClicked: AiEngine.isHistoryOpen = !AiEngine.isHistoryOpen
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "history"
                            fontStyle: Tokens.font.icon.small
                            color: Colours.palette.m3onSurfaceVariant
                            opacity: headerHistoryBtn.inHistory ? 0 : 1
                            scale: headerHistoryBtn.inHistory ? 0.65 : 1
                            rotation: headerHistoryBtn.inHistory ? -45 : 0

                            Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                            Behavior on scale { Anim { type: Anim.DefaultSpatial } }
                            Behavior on rotation { Anim { type: Anim.DefaultSpatial } }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "chat_bubble"
                            fill: 1
                            fontStyle: Tokens.font.icon.small
                            color: Colours.palette.m3onSecondaryContainer
                            opacity: headerHistoryBtn.inHistory ? 1 : 0
                            scale: headerHistoryBtn.inHistory ? 1 : 0.65
                            rotation: headerHistoryBtn.inHistory ? 0 : 45

                            Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                            Behavior on scale { Anim { type: Anim.DefaultSpatial } }
                            Behavior on rotation { Anim { type: Anim.DefaultSpatial } }
                        }
                    }
                }

                // Subtle Divider
                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Colours.tPalette.m3outlineVariant
                    opacity: 0.4
                    visible: headerContainer.visible
                }

                // Content Panel Stack
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    NotifDock {
                        objectName: "sidebarNotifications"
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width
                        x: root.activeTab === "notifications" ? 0 : -width
                        opacity: root.activeTab === "notifications" ? 1 : 0
                        visible: opacity > 0
                        props: root.props
                        screenState: root.screenState

                        Behavior on x { Anim { type: Anim.DefaultSpatial } }
                        Behavior on opacity { Anim { type: Anim.DefaultSpatial } }
                    }

                    AiAssistant {
                        id: aiAssistant
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width
                        x: root.activeTab === "ai" ? 0 : (root.activeTabIndex < 1 ? width : -width)
                        opacity: root.activeTab === "ai" ? 1 : 0
                        visible: opacity > 0

                        Behavior on x { Anim { type: Anim.DefaultSpatial } }
                        Behavior on opacity { Anim { type: Anim.DefaultSpatial } }
                    }

                    News {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width
                        x: root.activeTab === "news" ? 0 : width
                        opacity: root.activeTab === "news" ? 1 : 0
                        visible: opacity > 0

                        Behavior on x { Anim { type: Anim.DefaultSpatial } }
                        Behavior on opacity { Anim { type: Anim.DefaultSpatial } }
                    }
                }
            }
        }

        // Utilities Separator
        StyledRect {
            visible: root.utilities && root.utilities.offsetScale < 1
            Layout.row: Config.bar.position === "bottom" ? 0 : (Config.bar.position === "top" ? 2 : 1)
            Layout.topMargin: Config.bar.position === "bottom" ? 0 : (visible ? 18 : 0)
            Layout.bottomMargin: Config.bar.position === "bottom" ? (visible ? 18 : 0) : 0
            Layout.fillWidth: true
            implicitHeight: 1

            color: Colours.tPalette.m3outlineVariant
        }

        // Popout Separator
        StyledRect {
            visible: root.showPopoutSeparator
            Layout.row: Config.bar.position === "bottom" ? 2 : 0
            Layout.topMargin: Config.bar.position === "top" ? 0 : 12
            Layout.bottomMargin: Config.bar.position === "top" ? 12 : 0
            Layout.fillWidth: true
            implicitHeight: 1

            color: Colours.tPalette.m3outlineVariant
        }
    }
}

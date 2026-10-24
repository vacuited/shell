pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    readonly property bool isOpen: AiEngine.selectorOpen
    property string selectedTabId: ""
    property int highlightedIndex: 0

    readonly property real targetListHeight: Math.min(Math.max(displayedModels.length * 36 - 2, 40), 214)
    readonly property real targetCardHeight: isOpen
        ? (Tokens.padding.small * 2 + 38 + (providerTabsFlick.visible ? 30 + Tokens.spacing.small : 0) + Tokens.spacing.small + targetListHeight + 4)
        : 0

    implicitHeight: targetCardHeight
    opacity: isOpen ? 1 : 0
    visible: implicitHeight > 0.5
    clip: true

    Behavior on implicitHeight {
        Anim { type: Anim.Standard }
    }
    Behavior on opacity {
        Anim { type: Anim.DefaultEffects }
    }

    Timer {
        id: searchDebounce
        interval: 50
        repeat: false
        onTriggered: AiEngine.modelQuery = modelSearch.text.trim()
    }

    readonly property var activeSectionObj: {
        var secs = AiEngine.visibleSections;
        if (!secs || secs.length === 0) return null;
        if (AiEngine.modelQuery.length > 0) {
            var merged = [];
            for (var i = 0; i < secs.length; i++) {
                if (secs[i].id === "recent") continue;
                var mList = secs[i].models || [];
                for (var j = 0; j < mList.length; j++) {
                    merged.push(mList[j]);
                }
            }
            return { id: "search", label: qsTr("Results"), models: merged };
        }
        for (var k = 0; k < secs.length; k++) {
            if (secs[k].id === root.selectedTabId) return secs[k];
        }
        for (var p = 0; p < secs.length; p++) {
            if (secs[p].id === AiEngine.activeProvider) return secs[p];
        }
        return secs[0];
    }

    readonly property int activeTabIndex: {
        var secs = AiEngine.orderedSections;
        if (!secs || !activeSectionObj) return 0;
        for (var i = 0; i < secs.length; i++) {
            if (secs[i].id === activeSectionObj.id) return i;
        }
        return 0;
    }

    readonly property var displayedModels: activeSectionObj && activeSectionObj.models ? activeSectionObj.models : []

    function ensureVisible() {
        var rowY = highlightedIndex * 36;
        if (rowY < listContainer.contentY) {
            listContainer.contentY = rowY;
        } else if (rowY + 34 > listContainer.contentY + listContainer.height) {
            listContainer.contentY = Math.max(0, rowY + 34 - listContainer.height);
        }
    }

    onDisplayedModelsChanged: {
        var activeIdx = 0;
        for (var i = 0; i < displayedModels.length; i++) {
            if (displayedModels[i].name === AiEngine.currentModel && displayedModels[i].providerId === AiEngine.activeProvider) {
                activeIdx = i;
                break;
            }
        }
        highlightedIndex = activeIdx;
        ensureVisible();
    }

    function moveUp() {
        if (displayedModels.length === 0) return;
        highlightedIndex = (highlightedIndex - 1 + displayedModels.length) % displayedModels.length;
        ensureVisible();
    }

    function moveDown() {
        if (displayedModels.length === 0) return;
        highlightedIndex = (highlightedIndex + 1) % displayedModels.length;
        ensureVisible();
    }

    function prevProvider() {
        var secs = AiEngine.orderedSections;
        if (!secs || secs.length <= 1) return;
        var nextIdx = (activeTabIndex - 1 + secs.length) % secs.length;
        selectedTabId = secs[nextIdx].id;
        tabSwitchAnim.restart();
    }

    function nextProvider() {
        var secs = AiEngine.orderedSections;
        if (!secs || secs.length <= 1) return;
        var nextIdx = (activeTabIndex + 1) % secs.length;
        selectedTabId = secs[nextIdx].id;
        tabSwitchAnim.restart();
    }

    function acceptCurrent() {
        if (displayedModels.length === 0) return false;
        var idx = Math.max(0, Math.min(highlightedIndex, displayedModels.length - 1));
        var item = displayedModels[idx];
        AiEngine.setActiveModel(item.providerId, item.name);
        AiEngine.selectorOpen = false;
        return true;
    }

    Connections {
        target: AiEngine
        function onSelectorOpenChanged() {
            if (AiEngine.selectorOpen) {
                root.selectedTabId = AiEngine.activeProvider || (AiEngine.orderedSections.length > 0 ? AiEngine.orderedSections[0].id : "");
                var activeIdx = 0;
                for (var i = 0; i < root.displayedModels.length; i++) {
                    if (root.displayedModels[i].name === AiEngine.currentModel && root.displayedModels[i].providerId === AiEngine.activeProvider) {
                        activeIdx = i;
                        break;
                    }
                }
                root.highlightedIndex = activeIdx;
                Qt.callLater(() => modelSearch.forceActiveFocus());
            } else {
                modelSearch.text = "";
                AiEngine.modelQuery = "";
            }
        }
    }

    // Silky smooth list transition when switching provider tabs (zero overshoot)
    ParallelAnimation {
        id: tabSwitchAnim
        NumberAnimation {
            target: listContainer
            property: "opacity"
            from: 0.35
            to: 1.0
            duration: 240
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: listSlideTransform
            property: "y"
            from: 6
            to: 0
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    StyledRect {
        id: innerCard
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 2
        height: Math.max(0, parent.height - 4)
        radius: 18
        color: Colours.tPalette.m3surfaceContainerHigh
        clip: true

        transform: Scale {
            yScale: root.isOpen ? 1.0 : 0.95
            xScale: root.isOpen ? 1.0 : 0.98
            origin.x: innerCard.width / 2
            origin.y: innerCard.height
            Behavior on yScale { Anim { type: Anim.Standard } }
            Behavior on xScale { Anim { type: Anim.Standard } }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onWheel: e => e.accepted = true
        }

        ColumnLayout {
            id: selectorCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.small
            spacing: Tokens.spacing.small

            // Top Filter SearchBar
            SearchBar {
                id: modelSearch
                Layout.fillWidth: true
                topPadding: Tokens.padding.small
                bottomPadding: Tokens.padding.small
                placeholderText: qsTr("Filter configured models...")
                font: Tokens.font.body.small
                onTextEdited: searchDebounce.restart()
                onAccepted: root.acceptCurrent()

                Keys.onUpPressed: event => {
                    root.moveUp();
                    event.accepted = true;
                }
                Keys.onDownPressed: event => {
                    root.moveDown();
                    event.accepted = true;
                }
                Keys.onEscapePressed: event => {
                    AiEngine.selectorOpen = false;
                    event.accepted = true;
                }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Tab) {
                        if (root.acceptCurrent()) event.accepted = true;
                    }
                }
            }

            // Horizontal Provider Filter Pills
            Flickable {
                id: providerTabsFlick
                Layout.fillWidth: true
                implicitHeight: 30
                contentWidth: providerTabsTrack.width
                contentHeight: 30
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                visible: AiEngine.modelQuery.length === 0 && AiEngine.orderedSections.length > 1

                Item {
                    id: providerTabsTrack
                    width: providerTabsRow.implicitWidth
                    height: 30

                    // Smooth Sliding Primary Pill Indicator
                    StyledRect {
                        id: slidingProvPill
                        readonly property Item activeChip: provRepeater.count > root.activeTabIndex
                            ? provRepeater.itemAt(root.activeTabIndex)
                            : null
                        height: 28
                        y: 1
                        radius: 14
                        color: Colours.palette.m3primary
                        x: activeChip ? activeChip.x : 0
                        width: activeChip ? activeChip.width : 64

                        Behavior on x {
                            Anim { type: Anim.Standard }
                        }
                        Behavior on width {
                            Anim { type: Anim.Standard }
                        }
                    }

                    Row {
                        id: providerTabsRow
                        height: 30
                        spacing: 6

                        Repeater {
                            id: provRepeater
                            model: AiEngine.orderedSections

                            delegate: Item {
                                id: provPill

                                required property var modelData
                                required property int index
                                readonly property bool isTabActive: index === root.activeTabIndex

                                implicitWidth: provPillRow.implicitWidth + 20
                                width: implicitWidth
                                height: 28
                                y: 1

                                StyledRect {
                                    anchors.fill: parent
                                    radius: 14
                                    color: Colours.tPalette.m3surfaceContainerHighest
                                    opacity: provPill.isTabActive ? 0 : 1
                                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                                }

                                StateLayer {
                                    radius: 14
                                    color: provPill.isTabActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                    onClicked: {
                                        root.selectedTabId = provPill.modelData.id;
                                        tabSwitchAnim.restart();
                                        modelSearch.forceActiveFocus();
                                    }
                                }

                                Row {
                                    id: provPillRow
                                    anchors.centerIn: parent
                                    spacing: 4

                                    MaterialIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: provPill.modelData.id === "recent" ? "history" : "auto_awesome"
                                        fontStyle: Tokens.font.icon.small
                                        color: provPill.isTabActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                        Behavior on color { CAnim {} }
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: provPill.modelData.label
                                        font: Tokens.font.label.small
                                        color: provPill.isTabActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                        Behavior on color { CAnim {} }
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: String((provPill.modelData.models || []).length)
                                        font: Tokens.font.label.small
                                        opacity: 0.7
                                        color: provPill.isTabActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                        Behavior on color { CAnim {} }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Animated List Container (slides + fades on provider switch)
            Flickable {
                id: listContainer
                Layout.fillWidth: true
                implicitHeight: root.targetListHeight
                contentWidth: width
                contentHeight: modelsCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Behavior on implicitHeight {
                    Anim { type: Anim.Standard }
                }

                Behavior on contentY {
                    Anim { type: Anim.Standard }
                }

                transform: [
                    Translate { id: listSlideTransform; y: 0 }
                ]

                // Exact Caelestia Launcher / SlashMenu Sliding Selection Box
                StyledRect {
                    id: selectionBox
                    x: 0
                    width: listContainer.width
                    height: 34
                    radius: Tokens.rounding.medium
                    color: Colours.tPalette.m3secondaryContainer
                    visible: root.displayedModels.length > 0
                    y: root.highlightedIndex * (34 + 2)

                    Behavior on y {
                        Anim { type: Anim.Standard }
                    }
                }

                Column {
                    id: modelsCol
                    width: listContainer.width
                    spacing: 2

                    Repeater {
                        model: root.displayedModels

                        delegate: Item {
                            id: modelOption

                            required property var modelData
                            required property int index
                            readonly property bool optionActive: modelData.name === AiEngine.currentModel && modelData.providerId === AiEngine.activeProvider
                            readonly property bool isHighlighted: index === root.highlightedIndex

                            width: modelsCol.width
                            height: 34

                            StyledRect {
                                anchors.fill: parent
                                radius: Tokens.rounding.medium
                                color: (!modelOption.isHighlighted && modelOption.optionActive)
                                    ? Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.14)
                                    : "transparent"
                            }

                            StateLayer {
                                id: optState
                                anchors.fill: parent
                                radius: Tokens.rounding.medium
                                color: modelOption.isHighlighted ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                onEntered: root.highlightedIndex = modelOption.index
                                onClicked: {
                                    AiEngine.setActiveModel(modelOption.modelData.providerId, modelOption.modelData.name);
                                    AiEngine.selectorOpen = false;
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.padding.small
                                anchors.rightMargin: Tokens.padding.small
                                spacing: Tokens.spacing.small

                                MaterialIcon {
                                    text: modelOption.optionActive ? "check_circle" : "smart_toy"
                                    fill: modelOption.optionActive ? 1 : 0
                                    fontStyle: Tokens.font.icon.small
                                    color: modelOption.optionActive
                                        ? Colours.palette.m3primary
                                        : (modelOption.isHighlighted ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant)
                                    Behavior on color { CAnim {} }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: {
                                        var m = modelOption.modelData.name || "";
                                        var slashIdx = m.indexOf("/");
                                        return slashIdx !== -1 ? m.substring(slashIdx + 1) : m;
                                    }
                                    font: Tokens.font.body.small
                                    color: modelOption.isHighlighted
                                        ? Colours.palette.m3onSecondaryContainer
                                        : (modelOption.optionActive ? Colours.palette.m3primary : Colours.palette.m3onSurface)
                                    elide: Text.ElideRight
                                    Behavior on color { CAnim {} }
                                }

                                StyledText {
                                    visible: {
                                        var m = modelOption.modelData.name || "";
                                        return m.indexOf("/") !== -1 || AiEngine.modelQuery.length > 0 || (root.activeSectionObj && root.activeSectionObj.id === "recent");
                                    }
                                    text: {
                                        var m = modelOption.modelData.name || "";
                                        var slashIdx = m.indexOf("/");
                                        return slashIdx !== -1 ? m.substring(0, slashIdx) : (modelOption.modelData.providerName || "");
                                    }
                                    font: Tokens.font.label.small
                                    color: modelOption.isHighlighted ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                                    opacity: 0.7
                                }
                            }
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: root.displayedModels.length === 0
                    text: qsTr("No configured models")
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }
    }
}

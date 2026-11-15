pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import M3Shapes
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import "../components"

Item {
    id: root

    required property var wallpaper
    property bool weActive: false
    property bool locked: true
    property string sizeMode: "2x1"
    property string surfaceStyle: ""
    property bool blurEnabled: Config.background.desktopWidgets.blur
    property real plateOpacity: Config.background.desktopWidgets.opacity
    property var widgetOptions: ({})

    readonly property real s: WidgetMetrics.scale
    property bool adding: false

    readonly property var sortedTodos: {
        void NotesStore.version;
        return NotesStore.getSortedTodos();
    }
    readonly property var doneTodos: sortedTodos.filter(t => t.done)
    readonly property int totalCount: sortedTodos.length
    readonly property int doneCount: doneTodos.length
    readonly property int openCount: Math.max(0, totalCount - doneCount)
    readonly property real completionRatio: totalCount > 0 ? (doneCount / totalCount) : 1.0

    function submitTodo(field: var): void {
        if (!field)
            return;
        const txt = field.text.trim();
        if (txt !== "") {
            NotesStore.addTodo(txt, "", "");
            field.text = "";
        }
        adding = false;
        Visibilities.desktopWidgetEditing = false;
    }

    function clearCompleted(): void {
        const ids = doneTodos.map(t => t.id);
        for (let i = 0; i < ids.length; i++)
            NotesStore.deleteTodo(ids[i]);
    }

    onLockedChanged: {
        if (!locked) {
            adding = false;
            Visibilities.desktopWidgetEditing = false;
        }
    }

    Component.onDestruction: Visibilities.desktopWidgetEditing = false

    implicitWidth: WidgetMetrics.widthFor(sizeMode, s)
    implicitHeight: WidgetMetrics.heightFor(sizeMode, "todo", s)

    Timer {
        id: addFocusTimer

        interval: 30
        onTriggered: {
            if (root.sizeMode === "2x3")
                panoInput.forceActiveFocus();
            else
                mainInput.forceActiveFocus();
        }
    }

    WidgetCardShell {
        id: shell

        anchors.fill: parent
        widgetType: "todo"
        sizeMode: root.sizeMode
        outerShape: root.widgetOptions?.outerShape ?? ""
        wallpaper: root.wallpaper
        weActive: root.weActive
        surfaceStyle: root.surfaceStyle
        blurEnabled: root.blurEnabled
        plateOpacity: root.plateOpacity
        scaleFactor: root.s

        // 1x1 Expressive Progress & Open Count Tile
        Item {
            anchors.fill: parent
            anchors.topMargin: shell.topPadding
            anchors.bottomMargin: shell.bottomPadding
            anchors.leftMargin: shell.sidePadding
            anchors.rightMargin: shell.sidePadding
            visible: root.sizeMode === "1x1"

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width
                spacing: Math.round(4 * root.s)

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.round((shell.isShaped ? 68 : 78) * root.s)
                    Layout.preferredHeight: Math.round((shell.isShaped ? 68 : 78) * root.s)

                    CircularProgress {
                        anchors.fill: parent
                        value: root.completionRatio
                        strokeWidth: Math.max(4, Math.round(6 * root.s))
                        fgColour: root.openCount === 0 ? Colours.palette.m3tertiary : Colours.palette.m3primary
                        bgColour: WidgetMetrics.trackSurface
                        implicitSize: width
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: root.totalCount === 0 ? "0" : String(root.openCount)
                        font: Tokens.font.clock.size(Math.round(28 * root.s)).weight(Font.Bold).build()
                        color: Colours.palette.m3onSurface
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.openCount === 0 && root.totalCount > 0 ? Tr.tr("All done") : Tr.tr("tasks left")
                    font: Tokens.font.label.builders.small.scale(Math.max(0.84, root.s * 0.9)).weight(Font.DemiBold).build()
                    color: root.openCount === 0 && root.totalCount > 0 ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }
        }

        // 1x2, 2x1, 2x2 Standard Interactive Task Cards
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "1x2" || root.sizeMode === "2x1" || root.sizeMode === "2x2"
            spacing: Math.round(Tokens.spacing.small * root.s)

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                WidgetHeader {
                    Layout.fillWidth: true
                    title: Tr.tr("Todo")
                    icon: "checklist"
                }

                StyledRect {
                    visible: root.totalCount > 0
                    Layout.preferredHeight: Math.round(22 * root.s)
                    Layout.preferredWidth: Math.round(cntText.implicitWidth + 14)
                    radius: Math.round(11 * root.s)
                    color: root.openCount === 0 ? Colours.palette.m3tertiaryContainer : Colours.palette.m3primaryContainer

                    StyledText {
                        id: cntText

                        anchors.centerIn: parent
                        text: root.doneCount + "/" + root.totalCount
                        font: Tokens.font.label.small
                        color: root.openCount === 0 ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onPrimaryContainer
                    }
                }

                IconButton {
                    visible: root.doneCount > 0
                    icon: "delete_sweep"
                    type: IconButton.Text
                    onClicked: root.clearCompleted()
                }

                IconButton {
                    icon: root.adding ? "close" : "add"
                    type: IconButton.Tonal
                    isRound: true
                    onClicked: {
                        root.adding = !root.adding;
                        if (root.adding)
                            addFocusTimer.restart();
                        else {
                            mainInput.text = "";
                            Visibilities.desktopWidgetEditing = false;
                        }
                    }
                }
            }

            StyledProgressBar {
                visible: root.sizeMode !== "1x2" && root.totalCount > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(8 * root.s)
                value: root.completionRatio
                fgColour: Colours.palette.m3primary
                bgColour: WidgetMetrics.trackSurface
            }

            StyledRect {
                visible: root.adding
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(34 * root.s)
                radius: Tokens.rounding.medium
                color: WidgetMetrics.innerSurfaceStrong
                border.width: mainInput.activeFocus ? 1.5 : 1
                border.color: mainInput.activeFocus ? Colours.palette.m3primary : Colours.palette.m3outlineVariant

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 6
                    spacing: 4

                    TextInput {
                        id: mainInput

                        Layout.fillWidth: true
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.small
                        verticalAlignment: TextInput.AlignVCenter
                        selectByMouse: true
                        onActiveFocusChanged: Visibilities.desktopWidgetEditing = activeFocus
                        Keys.onReturnPressed: root.submitTodo(mainInput)
                        Keys.onEnterPressed: root.submitTodo(mainInput)
                        Keys.onEscapePressed: {
                            text = "";
                            root.adding = false;
                            Visibilities.desktopWidgetEditing = false;
                        }

                        StyledText {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: Tr.tr("New task...")
                            font: Tokens.font.body.small
                            color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.65)
                            visible: mainInput.text === "" && !mainInput.activeFocus
                        }
                    }

                    IconButton {
                        icon: "check"
                        type: IconButton.Text
                        onClicked: root.submitTodo(mainInput)
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                StyledText {
                    anchors.centerIn: parent
                    visible: root.totalCount === 0
                    text: Tr.tr("No tasks yet")
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                ListView {
                    id: mainTodoList

                    anchors.fill: parent
                    visible: root.totalCount > 0
                    clip: true
                    spacing: Math.round(6 * root.s)
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.sortedTodos

                    delegate: StyledRect {
                        id: todoRow

                        required property var modelData
                        readonly property bool done: Boolean(modelData.done)

                        width: mainTodoList.width
                        height: Math.max(Math.round(34 * root.s), Math.round(todoText.implicitHeight + 14 * root.s))
                        radius: Tokens.rounding.medium
                        color: rowHover.hovered ? WidgetMetrics.innerSurfaceStrong : WidgetMetrics.innerSurface

                        HoverHandler {
                            id: rowHover
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Math.round(10 * root.s)
                            anchors.rightMargin: Math.round(6 * root.s)
                            anchors.topMargin: Math.round(6 * root.s)
                            anchors.bottomMargin: Math.round(6 * root.s)
                            spacing: Math.round(8 * root.s)

                            Item {
                                Layout.preferredWidth: Math.round(20 * root.s)
                                Layout.preferredHeight: Math.round(20 * root.s)
                                Layout.alignment: Qt.AlignVCenter

                                MaterialShape {
                                    anchors.fill: parent
                                    visible: todoRow.done
                                    shape: MaterialShape.Cookie7Sided
                                    color: Colours.palette.m3primary
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    visible: !todoRow.done
                                    radius: 5
                                    color: "transparent"
                                    border.width: 1.5
                                    border.color: Colours.palette.m3outline
                                }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    visible: todoRow.done
                                    text: "check"
                                    fontStyle: Tokens.font.icon.builders.small.scale(0.8).build()
                                    color: Colours.palette.m3onPrimary
                                }

                                StateLayer {
                                    enabled: root.locked
                                    radius: 10
                                    onClicked: NotesStore.toggleTodo(todoRow.modelData.id)
                                }
                            }

                            StyledText {
                                id: todoText

                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: todoRow.modelData.text ?? ""
                                font: Tokens.font.body.builders.small.scale(root.s).strikeout(todoRow.done).build()
                                color: todoRow.done ? Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.55) : Colours.palette.m3onSurface
                                wrapMode: Text.WordWrap
                            }

                            IconButton {
                                visible: rowHover.hovered
                                icon: "close"
                                type: IconButton.Text
                                onClicked: NotesStore.deleteTodo(todoRow.modelData.id)
                            }
                        }
                    }
                }
            }
        }

        // 2x3 Split Summary Hero + Generous Task List
        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "2x3"
            spacing: Math.round(Tokens.spacing.large * root.s)

            StyledRect {
                Layout.preferredWidth: Math.round(162 * root.s)
                Layout.fillHeight: true
                radius: Tokens.rounding.extraLarge
                color: WidgetMetrics.innerSurface
                border.width: 1
                border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.4)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Math.round(Tokens.padding.medium * root.s)
                    spacing: Math.round(Tokens.spacing.small * root.s)

                    WidgetHeader {
                        Layout.fillWidth: true
                        title: Tr.tr("Tasks")
                        icon: "checklist"
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(92 * root.s)

                        CircularProgress {
                            anchors.centerIn: parent
                            width: Math.round(86 * root.s)
                            height: Math.round(86 * root.s)
                            value: root.completionRatio
                            strokeWidth: Math.max(5, Math.round(7 * root.s))
                            fgColour: root.openCount === 0 ? Colours.palette.m3tertiary : Colours.palette.m3primary
                            bgColour: WidgetMetrics.trackSurface
                            implicitSize: width
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 0

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.openCount + ""
                                font: Tokens.font.clock.size(Math.round(24 * root.s)).weight(Font.Bold).build()
                                color: Colours.palette.m3onSurface
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Tr.tr("left")
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurfaceVariant
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Tr.tr("%1 / %2 done").arg(root.doneCount).arg(root.totalCount)
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    IconTextButton {
                        Layout.fillWidth: true
                        icon: root.adding ? "close" : "add"
                        text: root.adding ? Tr.tr("Cancel") : Tr.tr("Add task")
                        type: IconTextButton.Filled
                        isRound: true
                        onClicked: {
                            root.adding = !root.adding;
                            if (root.adding)
                                addFocusTimer.restart();
                            else {
                                panoInput.text = "";
                                Visibilities.desktopWidgetEditing = false;
                            }
                        }
                    }

                    IconTextButton {
                        visible: root.doneCount > 0
                        Layout.fillWidth: true
                        icon: "delete_sweep"
                        text: Tr.tr("Clear done")
                        type: IconTextButton.Tonal
                        isRound: true
                        onClicked: root.clearCompleted()
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Math.round(Tokens.spacing.small * root.s)

                StyledRect {
                    visible: root.adding
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(36 * root.s)
                    radius: Tokens.rounding.large
                    color: WidgetMetrics.innerSurfaceStrong
                    border.width: panoInput.activeFocus ? 1.5 : 1
                    border.color: panoInput.activeFocus ? Colours.palette.m3primary : Colours.palette.m3outlineVariant

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 6

                        TextInput {
                            id: panoInput

                            Layout.fillWidth: true
                            color: Colours.palette.m3onSurface
                            font: Tokens.font.body.small
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            onActiveFocusChanged: Visibilities.desktopWidgetEditing = activeFocus
                            Keys.onReturnPressed: root.submitTodo(panoInput)
                            Keys.onEnterPressed: root.submitTodo(panoInput)
                            Keys.onEscapePressed: {
                                text = "";
                                root.adding = false;
                                Visibilities.desktopWidgetEditing = false;
                            }

                            StyledText {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: Tr.tr("What needs to get done?")
                                font: Tokens.font.body.small
                                color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.65)
                                visible: panoInput.text === "" && !panoInput.activeFocus
                            }
                        }

                        IconButton {
                            icon: "check"
                            type: IconButton.Text
                            onClicked: root.submitTodo(panoInput)
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    StyledText {
                        anchors.centerIn: parent
                        visible: root.totalCount === 0
                        text: Tr.tr("No tasks yet")
                        font: Tokens.font.body.medium
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    ListView {
                        id: panoTodoList

                        anchors.fill: parent
                        visible: root.totalCount > 0
                        clip: true
                        spacing: Math.round(6 * root.s)
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.sortedTodos

                        delegate: StyledRect {
                            id: pRow

                            required property var modelData
                            readonly property bool done: Boolean(modelData.done)

                            width: panoTodoList.width
                            height: Math.max(Math.round(36 * root.s), Math.round(pTxt.implicitHeight + 16 * root.s))
                            radius: Tokens.rounding.large
                            color: pHover.hovered ? WidgetMetrics.innerSurfaceStrong : WidgetMetrics.innerSurface

                            HoverHandler {
                                id: pHover
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                anchors.topMargin: 7
                                anchors.bottomMargin: 7
                                spacing: 10

                                Item {
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20
                                    Layout.alignment: Qt.AlignVCenter

                                    MaterialShape {
                                        anchors.fill: parent
                                        visible: pRow.done
                                        shape: MaterialShape.Cookie7Sided
                                        color: Colours.palette.m3primary
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        visible: !pRow.done
                                        radius: 5
                                        color: "transparent"
                                        border.width: 1.5
                                        border.color: Colours.palette.m3outline
                                    }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        visible: pRow.done
                                        text: "check"
                                        fontStyle: Tokens.font.icon.builders.small.scale(0.8).build()
                                        color: Colours.palette.m3onPrimary
                                    }

                                    StateLayer {
                                        enabled: root.locked
                                        radius: 10
                                        onClicked: NotesStore.toggleTodo(pRow.modelData.id)
                                    }
                                }

                                StyledText {
                                    id: pTxt

                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    text: pRow.modelData.text ?? ""
                                    font: Tokens.font.body.builders.small.scale(root.s).strikeout(pRow.done).build()
                                    color: pRow.done ? Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.55) : Colours.palette.m3onSurface
                                    wrapMode: Text.WordWrap
                                }

                                IconButton {
                                    visible: pHover.hovered
                                    icon: "close"
                                    type: IconButton.Text
                                    onClicked: NotesStore.deleteTodo(pRow.modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

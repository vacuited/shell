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
    property real widgetScale: WidgetMetrics.scale
    property string surfaceStyle: ""
    property bool blurEnabled: Config.background.desktopWidgets.blur
    property real plateOpacity: Config.background.desktopWidgets.opacity
    property var widgetOptions: ({})

    readonly property real s: Math.max(0.55, Math.min(2.2, widgetScale > 0 ? widgetScale : WidgetMetrics.scale))
    readonly property string effectiveSize: WidgetMetrics.fallbackSizeFor("todo", sizeMode)
    property bool adding: false
    property bool _editingHeld: false

    readonly property var sortedTodos: {
        void NotesStore.version;
        const open = NotesStore.getSortedTodos();
        const done = (NotesStore.todos ?? []).filter(t => t && t.done)
            .slice()
            .sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0));
        return open.concat(done);
    }
    readonly property var doneTodos: sortedTodos.filter(t => t.done)
    readonly property int totalCount: sortedTodos.length
    readonly property int doneCount: doneTodos.length
    readonly property int openCount: Math.max(0, totalCount - doneCount)
    readonly property real completionRatio: totalCount > 0 ? (doneCount / totalCount) : 1.0

    function setEditingActive(active: bool): void {
        if (active === _editingHeld)
            return;
        _editingHeld = active;
        if (active)
            Visibilities.desktopWidgetEditingCount++;
        else
            Visibilities.desktopWidgetEditingCount = Math.max(0, Visibilities.desktopWidgetEditingCount - 1);
    }

    function submitTodo(field: var): void {
        if (!field)
            return;
        const txt = field.text.trim();
        if (txt !== "") {
            NotesStore.addTodo(txt, "", false);
            field.text = "";
        }
        adding = false;
    }

    function clearCompleted(): void {
        const ids = doneTodos.map(t => t.id);
        for (let i = 0; i < ids.length; i++)
            NotesStore.deleteTodo(ids[i]);
    }

    onAddingChanged: {
        setEditingActive(adding && locked);
        if (adding) {
            addFocusTimer.restart();
        } else if (layoutLoader.item?.inputField) {
            layoutLoader.item.inputField.text = "";
        }
    }

    onLockedChanged: {
        if (!locked)
            adding = false;
    }

    Component.onDestruction: setEditingActive(false)

    implicitWidth: WidgetMetrics.widthFor(effectiveSize, s)
    implicitHeight: WidgetMetrics.heightFor(effectiveSize, "todo", s)

    Timer {
        id: addFocusTimer

        interval: 30
        onTriggered: {
            if (layoutLoader.item?.inputField)
                layoutLoader.item.inputField.forceActiveFocus();
        }
    }

    WidgetCardShell {
        id: shell

        anchors.fill: parent
        widgetType: "todo"
        sizeMode: root.effectiveSize
        outerShape: root.widgetOptions?.outerShape ?? ""
        wallpaper: root.wallpaper
        weActive: root.weActive
        surfaceStyle: root.surfaceStyle
        blurEnabled: root.blurEnabled
        plateOpacity: root.plateOpacity
        scaleFactor: root.s

        Loader {
            id: layoutLoader

            anchors.fill: parent
            sourceComponent: root.effectiveSize === "1x1" ? layout1x1 : layoutStandard
        }
    }

    // 1x1 Expressive Progress & Open Count Tile
    Component {
        id: layout1x1

        Item {
            readonly property int ringSize: Math.max(36, Math.round(Math.min((shell.isShaped ? 64 : 74) * root.s, shell.safeInnerBox - Math.round(22 * root.s))))

            clip: true

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.max(24, parent.width - shell.sidePadding * 2)
                spacing: Math.max(2, Math.round(4 * root.s))

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: ringSize
                    Layout.preferredHeight: ringSize

                    CircularProgress {
                        anchors.fill: parent
                        value: root.completionRatio
                        strokeWidth: Math.max(4, Math.round(6 * root.s))
                        fgColour: root.openCount === 0 ? Colours.palette.m3tertiary : Colours.palette.m3primary
                        bgColour: shell.trackSurface
                        implicitSize: ringSize
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: root.totalCount === 0 ? "0" : String(root.openCount)
                        font: Tokens.font.clock.size(Math.max(12, Math.round(ringSize * 0.36))).weight(Font.Bold).build()
                        color: Colours.palette.m3onSurface
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    horizontalAlignment: Text.AlignHCenter
                    text: root.openCount === 0 && root.totalCount > 0 ? Tr.tr("All done") : Tr.tr("tasks left")
                    font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.88)).weight(Font.DemiBold).build()
                    color: root.openCount === 0 && root.totalCount > 0 ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }
        }
    }

    // 1x2, 2x1, 2x2 Standard Interactive Task Cards
    Component {
        id: layoutStandard

        ColumnLayout {
            property alias inputField: mainInput

            anchors.fill: parent
            anchors.margins: shell.contentPadding
            spacing: Math.max(4, Math.round(Tokens.spacing.small * root.s))

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Math.max(3, Math.round(6 * root.s))

                WidgetHeader {
                    Layout.fillWidth: true
                    title: Tr.tr("Todo")
                    icon: "checklist"
                    scaleFactor: root.s
                }

                StyledRect {
                    visible: root.totalCount > 0
                    Layout.fillWidth: false
                    Layout.preferredHeight: Math.round(22 * root.s)
                    Layout.preferredWidth: Math.round(cntText.implicitWidth + Math.round(12 * root.s))
                    radius: Math.round(11 * root.s)
                    color: root.openCount === 0 ? shell.tertiaryContainerTint : shell.primaryContainerTint

                    StyledText {
                        id: cntText

                        anchors.centerIn: parent
                        text: root.doneCount + "/" + root.totalCount
                        font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.9)).build()
                        color: root.openCount === 0 ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onPrimaryContainer
                    }
                }

                WidgetIconButton {
                    visible: root.doneCount > 0 && root.effectiveSize !== "2x1"
                    icon: "delete_sweep"
                    type: IconButton.Text
                    translucent: shell.isTranslucent
                    scaleFactor: root.s
                    onClicked: root.clearCompleted()
                }

                WidgetIconButton {
                    icon: root.adding ? "close" : "add"
                    type: IconButton.Tonal
                    isRound: true
                    translucent: shell.isTranslucent
                    scaleFactor: root.s
                    onClicked: root.adding = !root.adding
                }
            }

            StyledProgressBar {
                visible: root.effectiveSize !== "1x2" && root.totalCount > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(5, Math.round(8 * root.s))
                value: root.completionRatio
                fgColour: Colours.palette.m3primary
                bgColour: shell.trackSurface
            }

            StyledRect {
                visible: root.adding
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(32 * root.s)
                clip: true
                radius: Math.round(Tokens.rounding.medium * Math.min(1.2, Math.max(0.75, root.s)))
                color: shell.innerSurfaceStrong
                border.width: mainInput.activeFocus ? 1.5 : 1
                border.color: mainInput.activeFocus ? Colours.palette.m3primary : shell.innerBorder

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(10 * root.s)
                    anchors.rightMargin: Math.round(4 * root.s)
                    spacing: Math.max(2, Math.round(4 * root.s))

                    TextInput {
                        id: mainInput

                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).build()
                        verticalAlignment: TextInput.AlignVCenter
                        selectByMouse: true
                        clip: true
                        Keys.onReturnPressed: root.submitTodo(mainInput)
                        Keys.onEnterPressed: root.submitTodo(mainInput)
                        Keys.onEscapePressed: {
                            text = "";
                            root.adding = false;
                        }

                        StyledText {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: Tr.tr("New task...")
                            font: Tokens.font.body.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).build()
                            color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.65)
                            visible: mainInput.text === "" && !mainInput.activeFocus
                            elide: Text.ElideRight
                        }
                    }

                    WidgetIconButton {
                        icon: "check"
                        type: IconButton.Text
                        translucent: shell.isTranslucent
                        scaleFactor: root.s * 0.92
                        onClicked: root.submitTodo(mainInput)
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                StyledText {
                    anchors.centerIn: parent
                    width: Math.max(24, parent.width - Math.round(12 * root.s))
                    horizontalAlignment: Text.AlignHCenter
                    visible: root.totalCount === 0
                    text: Tr.tr("No tasks yet")
                    font: Tokens.font.body.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).build()
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }

                ListView {
                    id: mainTodoList

                    anchors.fill: parent
                    visible: root.totalCount > 0
                    clip: true
                    spacing: Math.max(3, Math.round(6 * root.s))
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.sortedTodos

                    delegate: StyledRect {
                        id: todoRow

                        required property var modelData
                        readonly property bool done: Boolean(modelData.done)

                        width: mainTodoList.width
                        height: Math.max(Math.round(32 * root.s), Math.round(todoText.implicitHeight + 12 * root.s))
                        clip: true
                        radius: Math.round(Tokens.rounding.medium * Math.min(1.2, Math.max(0.75, root.s)))
                        color: rowHover.hovered ? shell.innerSurfaceStrong : shell.innerSurface
                        border.width: 1
                        border.color: shell.innerBorder

                        HoverHandler {
                            id: rowHover
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Math.round(8 * root.s)
                            anchors.rightMargin: Math.round(6 * root.s)
                            anchors.topMargin: Math.round(5 * root.s)
                            anchors.bottomMargin: Math.round(5 * root.s)
                            spacing: Math.max(4, Math.round(8 * root.s))

                            Item {
                                Layout.fillWidth: false
                                Layout.preferredWidth: Math.round(18 * root.s)
                                Layout.preferredHeight: Math.round(18 * root.s)
                                Layout.alignment: Qt.AlignVCenter

                                MaterialShape {
                                    anchors.fill: parent
                                    implicitSize: Math.round(18 * root.s)
                                    visible: todoRow.done
                                    shape: MaterialShape.Cookie7Sided
                                    color: shell.primaryAccentTint
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    visible: !todoRow.done
                                    radius: Math.round(5 * root.s)
                                    color: "transparent"
                                    border.width: 1.5
                                    border.color: Colours.palette.m3outline
                                }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    visible: todoRow.done
                                    text: "check"
                                    fontStyle: Tokens.font.icon.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.78)).build()
                                    color: Colours.palette.m3onPrimary
                                }

                                StateLayer {
                                    enabled: root.locked
                                    radius: width / 2
                                    onClicked: NotesStore.toggleTodo(todoRow.modelData.id)
                                }
                            }

                            StyledText {
                                id: todoText

                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.alignment: Qt.AlignVCenter
                                text: todoRow.modelData.title ?? ""
                                font.family: Tokens.font.body.small.family
                                font.pointSize: Math.max(7, Tokens.font.body.small.pointSize * root.s)
                                font.weight: Tokens.font.body.small.weight
                                font.strikeout: todoRow.done
                                color: todoRow.done ? Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.55) : Colours.palette.m3onSurface
                                wrapMode: Text.WordWrap
                            }

                            WidgetIconButton {
                                visible: rowHover.hovered
                                icon: "close"
                                type: IconButton.Text
                                translucent: shell.isTranslucent
                                scaleFactor: root.s * 0.85
                                onClicked: NotesStore.deleteTodo(todoRow.modelData.id)
                            }
                        }
                    }
                }
            }

            // Compact footer action on narrow 2x1 column so header stays uncluttered
            StyledRect {
                visible: root.effectiveSize === "2x1" && root.doneCount > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(24 * root.s)
                clip: true
                radius: Math.round(12 * root.s)
                color: shell.innerSurfaceStrong
                border.width: 1
                border.color: shell.innerBorder

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Math.max(3, Math.round(4 * root.s))

                    MaterialIcon {
                        text: "delete_sweep"
                        fontStyle: Tokens.font.icon.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.84)).build()
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        text: Tr.tr("Clear done")
                        font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.86)).build()
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }

                StateLayer {
                    enabled: root.locked
                    radius: parent.radius
                    onClicked: root.clearCompleted()
                }
            }
        }
    }
}

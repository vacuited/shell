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

    readonly property real s: Math.max(0.7, Math.min(1.5, Config.background.desktopWidgets.scale ?? 1.0))
    property string selectedNoteId: widgetOptions?.noteId ?? ""
    property string mode: "view" // "view" | "edit"
    property bool _editingHeld: false
    readonly property var swatchKeys: ["none", "primary", "secondary", "tertiary", "pink"]

    readonly property var sortedNotes: {
        void NotesStore.version;
        const list = (NotesStore.notes ?? []).slice();
        list.sort((a, b) => {
            if (Boolean(a.pinned) !== Boolean(b.pinned))
                return a.pinned ? -1 : 1;
            return (b.updatedAt ?? 0) - (a.updatedAt ?? 0);
        });
        return list;
    }

    readonly property var activeNote: {
        if (sortedNotes.length === 0)
            return null;
        for (let i = 0; i < sortedNotes.length; i++) {
            if (sortedNotes[i].id === selectedNoteId)
                return sortedNotes[i];
        }
        return sortedNotes[0];
    }

    readonly property int activeIndex: {
        if (!activeNote)
            return -1;
        return sortedNotes.findIndex(n => n.id === activeNote.id);
    }

    readonly property string noteColorKey: activeNote?.color ?? "none"
    readonly property color accentColor: colorForKey(noteColorKey)

    signal optionsUpdated(var patch)

    function setEditingActive(active: bool): void {
        if (active === _editingHeld)
            return;
        _editingHeld = active;
        if (active)
            Visibilities.desktopWidgetEditingCount++;
        else
            Visibilities.desktopWidgetEditingCount = Math.max(0, Visibilities.desktopWidgetEditingCount - 1);
    }

    function colorForKey(key: string): color {
        if (key === "primary")
            return Colours.palette.m3primary;
        if (key === "secondary")
            return Colours.palette.m3secondary;
        if (key === "tertiary")
            return Colours.palette.m3tertiary;
        if (key === "pink")
            return Colours.palette.m3error;
        if (key && key.startsWith("#"))
            return key;
        return Colours.palette.m3primary;
    }

    function selectNote(id: string): void {
        if (mode === "edit" && activeNote && activeNote.id !== id)
            saveEdits();
        selectedNoteId = id;
        optionsUpdated({ noteId: id });
        mode = "view";
        setEditingActive(false);
    }

    function stepNote(delta: int): void {
        if (sortedNotes.length <= 1)
            return;
        const cur = Math.max(0, activeIndex);
        const next = (cur + delta + sortedNotes.length) % sortedNotes.length;
        selectNote(sortedNotes[next].id);
    }

    function createAndEditNote(): void {
        if (mode === "edit")
            saveEdits();
        const created = NotesStore.addNote("", "", false, "none", ({}));
        if (created && created.id) {
            selectedNoteId = created.id;
            optionsUpdated({ noteId: created.id });
        }
        enterEditMode();
    }

    function enterEditMode(): void {
        if (!activeNote)
            return;
        titleInput.text = activeNote.title ?? "";
        bodyEdit.text = activeNote.body ?? "";
        mode = "edit";
        setEditingActive(root.locked);
        editFocusTimer.restart();
    }

    function saveEdits(): void {
        const n = activeNote;
        if (n) {
            const tTrim = titleInput.text.trim();
            const bTrim = bodyEdit.text.trim();
            if (tTrim === "" && bTrim === "") {
                NotesStore.deleteNote(n.id);
            } else {
                const shapes = (n.listShapes && typeof n.listShapes === "object" && !Array.isArray(n.listShapes)) ? n.listShapes : ({});
                NotesStore.updateNote(n.id, titleInput.text, bodyEdit.text, Boolean(n.pinned), n.color ?? "none", shapes);
            }
        }
        mode = "view";
        setEditingActive(false);
    }

    function setNoteColor(key: string): void {
        const n = activeNote;
        if (n) {
            const shapes = (n.listShapes && typeof n.listShapes === "object" && !Array.isArray(n.listShapes)) ? n.listShapes : ({});
            const nextTitle = mode === "edit" ? titleInput.text : (n.title ?? "");
            const nextBody = mode === "edit" ? bodyEdit.text : (n.body ?? "");
            NotesStore.updateNote(n.id, nextTitle, nextBody, Boolean(n.pinned), key, shapes);
        }
    }

    implicitWidth: WidgetMetrics.widthFor(sizeMode, s)
    implicitHeight: WidgetMetrics.heightFor(sizeMode, "notes", s)

    onLockedChanged: {
        if (!locked && mode === "edit")
            saveEdits();
    }

    Component.onDestruction: setEditingActive(false)

    Timer {
        id: editFocusTimer

        interval: 30
        onTriggered: bodyEdit.forceActiveFocus()
    }

    WidgetCardShell {
        id: shell

        anchors.fill: parent
        widgetType: "notes"
        sizeMode: root.sizeMode
        outerShape: root.widgetOptions?.outerShape ?? ""
        wallpaper: root.wallpaper
        weActive: root.weActive
        surfaceStyle: root.surfaceStyle
        blurEnabled: root.blurEnabled
        plateOpacity: root.plateOpacity
        scaleFactor: root.s

        // 1x1 Expressive Sticky Note Snippet (tap to cycle notes)
        Item {
            anchors.fill: parent
            anchors.topMargin: shell.topPadding
            anchors.bottomMargin: shell.bottomPadding
            anchors.leftMargin: shell.sidePadding
            anchors.rightMargin: shell.sidePadding
            visible: root.sizeMode === "1x1"

            ColumnLayout {
                anchors.fill: parent
                spacing: Math.round(4 * root.s)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    MaterialShape {
                        Layout.preferredWidth: Math.round(14 * root.s)
                        Layout.preferredHeight: Math.round(14 * root.s)
                        implicitSize: Math.round(14 * root.s)
                        Layout.alignment: Qt.AlignVCenter
                        shape: MaterialShape.Cookie4Sided
                        color: root.accentColor
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.activeNote ? (root.activeNote.title || Tr.tr("Note")) : Tr.tr("Notes")
                        font: Tokens.font.label.builders.medium.weight(Font.Bold).build()
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    MaterialIcon {
                        visible: Boolean(root.activeNote?.pinned)
                        text: "push_pin"
                        fontStyle: Tokens.font.icon.builders.small.scale(0.8).build()
                        color: root.accentColor
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: root.activeNote ? (root.activeNote.body || Tr.tr("Empty note")) : Tr.tr("Tap + in larger view to write")
                    font: Tokens.font.body.builders.small.scale(Math.max(0.85, root.s * 0.92)).build()
                    color: root.activeNote?.body ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                }

                StyledText {
                    visible: root.sortedNotes.length > 1
                    Layout.alignment: Qt.AlignRight
                    text: (root.activeIndex + 1) + "/" + root.sortedNotes.length
                    font: Tokens.font.label.builders.small.scale(0.85).build()
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            StateLayer {
                enabled: root.locked && root.sortedNotes.length > 1
                radius: shell.isShaped ? width / 2 : shell.radius
                onClicked: root.stepNote(1)
            }
        }

        // Standard / Split Note Workspace (1x2, 2x1, 2x2, 2x3)
        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode !== "1x1"
            spacing: Math.round(Tokens.spacing.medium * root.s)

            // 2x3 Left Note Switcher Sidebar
            StyledRect {
                visible: root.sizeMode === "2x3"
                Layout.preferredWidth: Math.round(158 * root.s)
                Layout.fillHeight: true
                radius: Tokens.rounding.extraLarge
                color: WidgetMetrics.innerSurface
                border.width: 1
                border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.4)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Math.round(Tokens.padding.small * root.s)
                    spacing: Math.round(6 * root.s)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        StyledText {
                            Layout.fillWidth: true
                            text: Tr.tr("All Notes (%1)").arg(root.sortedNotes.length)
                            font: Tokens.font.label.builders.small.weight(Font.Bold).build()
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        IconButton {
                            icon: "add"
                            type: IconButton.Tonal
                            isRound: true
                            onClicked: root.createAndEditNote()
                        }
                    }

                    ListView {
                        id: sidebarNotesList

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 4
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.sortedNotes

                        delegate: StyledRect {
                            id: sbRow

                            required property var modelData
                            readonly property bool selected: root.activeNote?.id === modelData.id

                            width: sidebarNotesList.width
                            height: Math.round(44 * root.s)
                            radius: Tokens.rounding.medium
                            color: selected
                                ? Colours.palette.m3primaryContainer
                                : (sbHover.hovered ? WidgetMetrics.innerSurfaceStrong : WidgetMetrics.innerSurface)

                            HoverHandler {
                                id: sbHover
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 6

                                MaterialShape {
                                    Layout.preferredWidth: 10
                                    Layout.preferredHeight: 10
                                    implicitSize: 10
                                    Layout.alignment: Qt.AlignVCenter
                                    shape: MaterialShape.Cookie4Sided
                                    color: root.colorForKey(sbRow.modelData.color ?? "none")
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: (sbRow.modelData.title && sbRow.modelData.title.trim() !== "") ? sbRow.modelData.title : Tr.tr("Untitled")
                                        font: Tokens.font.label.builders.small.weight(sbRow.selected ? Font.Bold : Font.Medium).build()
                                        color: sbRow.selected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: (sbRow.modelData.body ?? "").replace(/\n/g, " ") || Tr.tr("Empty")
                                        font: Tokens.font.label.builders.small.scale(0.82).build()
                                        color: sbRow.selected ? Qt.alpha(Colours.palette.m3onPrimaryContainer, 0.78) : Colours.palette.m3onSurfaceVariant
                                        elide: Text.ElideRight
                                    }
                                }

                                MaterialIcon {
                                    visible: Boolean(sbRow.modelData.pinned)
                                    text: "push_pin"
                                    fontStyle: Tokens.font.icon.builders.small.scale(0.8).build()
                                    color: sbRow.selected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3primary
                                }
                            }

                            StateLayer {
                                enabled: root.locked
                                radius: parent.radius
                                onClicked: root.selectNote(sbRow.modelData.id)
                            }
                        }
                    }
                }
            }

            // Active Note Editor / Viewer Pane
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Math.round(root.sizeMode === "1x2" ? 4 : Tokens.spacing.small * root.s)

                // Compact Action Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    MaterialShape {
                        Layout.preferredWidth: Math.round(14 * root.s)
                        Layout.preferredHeight: Math.round(14 * root.s)
                        implicitSize: Math.round(14 * root.s)
                        Layout.alignment: Qt.AlignVCenter
                        shape: MaterialShape.Cookie4Sided
                        color: root.accentColor
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        text: root.activeNote ? ((root.activeNote.title && root.activeNote.title.trim() !== "") ? root.activeNote.title : Tr.tr("Untitled Note")) : Tr.tr("Notes")
                        visible: root.mode === "view"
                        font: Tokens.font.title.builders.small.scale(root.s).weight(Font.Bold).build()
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    StyledRect {
                        visible: root.mode === "edit"
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        Layout.preferredHeight: Math.round(28 * root.s)
                        radius: Tokens.rounding.small
                        color: WidgetMetrics.innerSurfaceStrong

                        TextInput {
                            id: titleInput

                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            color: Colours.palette.m3onSurface
                            font: Tokens.font.label.builders.medium.weight(Font.Bold).build()
                            selectByMouse: true

                            StyledText {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: Tr.tr("Title...")
                                font: Tokens.font.label.medium
                                color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.6)
                                visible: titleInput.text === "" && !titleInput.activeFocus
                            }
                        }
                    }

                    IconButton {
                        visible: root.sizeMode !== "2x3" && root.sortedNotes.length > 1 && root.mode === "view"
                        icon: "chevron_left"
                        type: IconButton.Text
                        onClicked: root.stepNote(-1)
                    }

                    IconButton {
                        visible: root.sizeMode !== "2x3" && root.sortedNotes.length > 1 && root.mode === "view"
                        icon: "chevron_right"
                        type: IconButton.Text
                        onClicked: root.stepNote(1)
                    }

                    IconButton {
                        visible: root.activeNote !== null && root.mode === "view"
                        icon: "push_pin"
                        type: IconButton.Text
                        isToggle: true
                        checked: Boolean(root.activeNote?.pinned)
                        onClicked: if (root.activeNote) NotesStore.togglePin(root.activeNote.id)
                    }

                    IconButton {
                        visible: root.activeNote !== null
                        icon: root.mode === "edit" ? "check" : "edit"
                        type: root.mode === "edit" ? IconButton.Filled : IconButton.Tonal
                        isRound: true
                        onClicked: {
                            if (root.mode === "edit")
                                root.saveEdits();
                            else
                                root.enterEditMode();
                        }
                    }

                    IconButton {
                        visible: root.sizeMode !== "2x3" && root.mode === "view"
                        icon: "add"
                        type: IconButton.Text
                        onClicked: root.createAndEditNote()
                    }

                    IconButton {
                        visible: root.activeNote !== null && root.mode === "edit"
                        icon: "delete"
                        type: IconButton.Text
                        onClicked: {
                            if (root.activeNote) {
                                const delId = root.activeNote.id;
                                root.mode = "view";
                                root.setEditingActive(false);
                                NotesStore.deleteNote(delId);
                            }
                        }
                    }
                }

                // Color swatch bar when editing (hidden only on cramped 1x2 unless taller)
                RowLayout {
                    visible: root.mode === "edit" && root.activeNote !== null && root.sizeMode !== "1x2"
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: root.swatchKeys

                        delegate: StyledRect {
                            id: swChip

                            required property string modelData
                            readonly property bool selected: root.noteColorKey === modelData

                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            radius: 10
                            color: modelData === "none" ? WidgetMetrics.innerSurfaceStrong : root.colorForKey(modelData)
                            border.width: selected ? 2 : 0
                            border.color: Colours.palette.m3onSurface

                            StateLayer {
                                enabled: root.locked
                                radius: 10
                                onClicked: root.setNoteColor(swChip.modelData)
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                // View Body
                Flickable {
                    visible: root.mode === "view"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 40
                    contentWidth: width
                    contentHeight: viewBodyText.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    StyledText {
                        id: viewBodyText

                        width: parent.width
                        text: root.activeNote
                            ? (root.activeNote.body || Tr.tr("Double-click or press Edit to write..."))
                            : Tr.tr("Tap + to create a note")
                        font: Tokens.font.body.builders.small.scale(root.s).build()
                        color: root.activeNote?.body ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.WordWrap
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.locked
                        onDoubleClicked: {
                            if (root.activeNote)
                                root.enterEditMode();
                            else
                                root.createAndEditNote();
                        }
                    }
                }

                // Edit Body (minimumHeight prevents collapse on 1x2)
                StyledRect {
                    visible: root.mode === "edit"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 48
                    radius: Tokens.rounding.medium
                    color: WidgetMetrics.innerSurfaceStrong
                    border.width: bodyEdit.activeFocus ? 1.5 : 1
                    border.color: bodyEdit.activeFocus ? root.accentColor : Colours.palette.m3outlineVariant

                    Flickable {
                        id: editFlick

                        anchors.fill: parent
                        anchors.margins: 8
                        contentWidth: width
                        contentHeight: Math.max(height, bodyEdit.implicitHeight)
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        TextEdit {
                            id: bodyEdit

                            width: editFlick.width
                            height: Math.max(editFlick.height, implicitHeight)
                            color: Colours.palette.m3onSurface
                            font: Tokens.font.body.builders.small.scale(root.s).build()
                            wrapMode: TextEdit.WordWrap
                            selectByMouse: true
                            Keys.onEscapePressed: root.saveEdits()

                            StyledText {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                text: Tr.tr("Start typing...")
                                font: Tokens.font.body.small
                                color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.55)
                                visible: bodyEdit.text === "" && !bodyEdit.activeFocus
                            }
                        }
                    }
                }
            }
        }
    }
}

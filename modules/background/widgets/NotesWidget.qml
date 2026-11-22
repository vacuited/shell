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
    readonly property string effectiveSize: WidgetMetrics.fallbackSizeFor("notes", sizeMode)
    property string selectedNoteId: widgetOptions?.noteId ?? ""
    property string mode: "view" // "view" | "edit"
    property string draftTitle: ""
    property string draftBody: ""
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
        draftTitle = activeNote.title ?? "";
        draftBody = activeNote.body ?? "";
        mode = "edit";
        layoutLoader.item?.syncDraftFields?.();
        setEditingActive(root.locked);
        editFocusTimer.restart();
    }

    function saveEdits(): void {
        const n = activeNote;
        if (n) {
            const tTrim = draftTitle.trim();
            const bTrim = draftBody.trim();
            if (tTrim === "" && bTrim === "") {
                NotesStore.deleteNote(n.id);
            } else {
                const shapes = (n.listShapes && typeof n.listShapes === "object" && !Array.isArray(n.listShapes)) ? n.listShapes : ({});
                NotesStore.updateNote(n.id, draftTitle, draftBody, Boolean(n.pinned), n.color ?? "none", shapes);
            }
        }
        mode = "view";
        setEditingActive(false);
    }

    function setNoteColor(key: string): void {
        const n = activeNote;
        if (n) {
            const shapes = (n.listShapes && typeof n.listShapes === "object" && !Array.isArray(n.listShapes)) ? n.listShapes : ({});
            const nextTitle = mode === "edit" ? draftTitle : (n.title ?? "");
            const nextBody = mode === "edit" ? draftBody : (n.body ?? "");
            NotesStore.updateNote(n.id, nextTitle, nextBody, Boolean(n.pinned), key, shapes);
        }
    }

    function deleteActiveNote(): void {
        if (!activeNote)
            return;
        const delId = activeNote.id;
        mode = "view";
        setEditingActive(false);
        NotesStore.deleteNote(delId);
    }

    implicitWidth: WidgetMetrics.widthFor(effectiveSize, s)
    implicitHeight: WidgetMetrics.heightFor(effectiveSize, "notes", s)

    onLockedChanged: {
        if (!locked && mode === "edit")
            saveEdits();
    }

    Component.onDestruction: setEditingActive(false)

    Timer {
        id: editFocusTimer

        interval: 30
        onTriggered: {
            if (layoutLoader.item?.bodyField)
                layoutLoader.item.bodyField.forceActiveFocus();
        }
    }

    WidgetCardShell {
        id: shell

        anchors.fill: parent
        widgetType: "notes"
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
            sourceComponent: root.effectiveSize === "1x1" ? layout1x1 : layoutWorkspace
        }
    }

    // 1x1 Expressive Sticky Note Snippet (tap to cycle notes)
    Component {
        id: layout1x1

        Item {
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: shell.topPadding
                anchors.bottomMargin: shell.bottomPadding
                anchors.leftMargin: shell.sidePadding
                anchors.rightMargin: shell.sidePadding
                spacing: Math.max(2, Math.round(4 * root.s))

                RowLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: Math.max(3, Math.round(4 * root.s))

                    MaterialShape {
                        Layout.fillWidth: false
                        Layout.preferredWidth: Math.round(13 * root.s)
                        Layout.preferredHeight: Math.round(13 * root.s)
                        implicitSize: Math.round(13 * root.s)
                        Layout.alignment: Qt.AlignVCenter
                        shape: MaterialShape.Cookie4Sided
                        color: root.accentColor
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: root.activeNote ? (root.activeNote.title || Tr.tr("Note")) : Tr.tr("Notes")
                        font: Tokens.font.label.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).weight(Font.Bold).build()
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    MaterialIcon {
                        visible: Boolean(root.activeNote?.pinned)
                        text: "push_pin"
                        fontStyle: Tokens.font.icon.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.8)).build()
                        color: root.accentColor
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 0
                    text: root.activeNote ? (root.activeNote.body || Tr.tr("Empty note")) : Tr.tr("Tap + in larger view")
                    font: Tokens.font.body.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.9)).build()
                    color: root.activeNote?.body ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                }

                StyledText {
                    visible: root.sortedNotes.length > 1
                    Layout.alignment: Qt.AlignRight
                    text: (root.activeIndex + 1) + "/" + root.sortedNotes.length
                    font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.82)).build()
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            StateLayer {
                anchors.fill: parent
                anchors.topMargin: shell.topPadding
                anchors.bottomMargin: shell.bottomPadding
                anchors.leftMargin: shell.sidePadding
                anchors.rightMargin: shell.sidePadding
                enabled: root.locked && root.sortedNotes.length > 1
                radius: shell.isShaped ? width / 2 : shell.radius
                onClicked: root.stepNote(1)
            }
        }
    }

    // 1x2, 2x1, 2x2 Note Workspace
    Component {
        id: layoutWorkspace

        ColumnLayout {
            id: wsRoot

            property alias bodyField: bodyEdit
            readonly property bool narrowCard: root.effectiveSize === "2x1"

            function syncDraftFields(): void {
                if (titleInput.text !== root.draftTitle)
                    titleInput.text = root.draftTitle;
                if (bodyEdit.text !== root.draftBody)
                    bodyEdit.text = root.draftBody;
            }

            Component.onCompleted: syncDraftFields()

            anchors.fill: parent
            anchors.margins: shell.contentPadding
            spacing: Math.max(3, Math.round((root.effectiveSize === "1x2" ? 4 : Tokens.spacing.small) * root.s))

            // Compact Action Header
            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Math.max(2, Math.round(3 * root.s))

                MaterialShape {
                    Layout.fillWidth: false
                    Layout.preferredWidth: Math.round(14 * root.s)
                    Layout.preferredHeight: Math.round(14 * root.s)
                    implicitSize: Math.round(14 * root.s)
                    Layout.alignment: Qt.AlignVCenter
                    shape: MaterialShape.Cookie4Sided
                    color: root.accentColor
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.leftMargin: Math.round(4 * root.s)
                    text: root.activeNote ? ((root.activeNote.title && root.activeNote.title.trim() !== "") ? root.activeNote.title : Tr.tr("Untitled Note")) : Tr.tr("Notes")
                    visible: root.mode === "view"
                    font: Tokens.font.title.builders.small.scale(WidgetMetrics.safeFontScale(root.s, wsRoot.narrowCard ? 0.9 : 0.96)).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledRect {
                    visible: root.mode === "edit"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.leftMargin: Math.round(4 * root.s)
                    Layout.preferredHeight: Math.round(28 * root.s)
                    clip: true
                    radius: Math.round(Tokens.rounding.small * Math.min(1.2, Math.max(0.75, root.s)))
                    color: shell.innerSurfaceStrong
                    border.width: 1
                    border.color: shell.innerBorder

                    TextInput {
                        id: titleInput

                        anchors.fill: parent
                        anchors.leftMargin: Math.round(8 * root.s)
                        anchors.rightMargin: Math.round(8 * root.s)
                        verticalAlignment: TextInput.AlignVCenter
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.label.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).weight(Font.Bold).build()
                        selectByMouse: true
                        clip: true
                        onTextEdited: root.draftTitle = text

                        StyledText {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: Tr.tr("Title...")
                            font: Tokens.font.label.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).build()
                            color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.6)
                            visible: titleInput.text === "" && !titleInput.activeFocus
                            elide: Text.ElideRight
                        }
                    }
                }

                WidgetIconButton {
                    visible: !wsRoot.narrowCard && root.sortedNotes.length > 1 && root.mode === "view"
                    icon: "chevron_left"
                    type: IconButton.Text
                    translucent: shell.isTranslucent
                    scaleFactor: root.s * 0.9
                    onClicked: root.stepNote(-1)
                }

                WidgetIconButton {
                    visible: !wsRoot.narrowCard && root.sortedNotes.length > 1 && root.mode === "view"
                    icon: "chevron_right"
                    type: IconButton.Text
                    translucent: shell.isTranslucent
                    scaleFactor: root.s * 0.9
                    onClicked: root.stepNote(1)
                }

                WidgetIconButton {
                    visible: !wsRoot.narrowCard && root.activeNote !== null && root.mode === "view"
                    icon: "push_pin"
                    type: IconButton.Text
                    isToggle: true
                    checked: Boolean(root.activeNote?.pinned)
                    translucent: shell.isTranslucent
                    scaleFactor: root.s * 0.9
                    onClicked: if (root.activeNote) NotesStore.togglePin(root.activeNote.id)
                }

                WidgetIconButton {
                    visible: root.activeNote !== null
                    icon: root.mode === "edit" ? "check" : "edit"
                    type: root.mode === "edit" ? IconButton.Filled : IconButton.Tonal
                    isRound: true
                    translucent: shell.isTranslucent
                    scaleFactor: root.s * 0.92
                    onClicked: {
                        if (root.mode === "edit")
                            root.saveEdits();
                        else
                            root.enterEditMode();
                    }
                }

                WidgetIconButton {
                    visible: !wsRoot.narrowCard && root.mode === "view"
                    icon: "add"
                    type: IconButton.Text
                    translucent: shell.isTranslucent
                    scaleFactor: root.s * 0.92
                    onClicked: root.createAndEditNote()
                }

                WidgetIconButton {
                    visible: !wsRoot.narrowCard && root.activeNote !== null && root.mode === "edit"
                    icon: "delete"
                    type: IconButton.Text
                    translucent: shell.isTranslucent
                    scaleFactor: root.s * 0.92
                    onClicked: root.deleteActiveNote()
                }
            }

            // Color swatch bar when editing (hidden on compact 1x2)
            RowLayout {
                visible: root.mode === "edit" && root.activeNote !== null && root.effectiveSize !== "1x2"
                Layout.fillWidth: true
                spacing: Math.max(4, Math.round(6 * root.s))

                Repeater {
                    model: root.swatchKeys

                    delegate: StyledRect {
                        id: swChip

                        required property string modelData
                        readonly property bool selected: root.noteColorKey === modelData

                        Layout.fillWidth: false
                        Layout.preferredWidth: Math.round(20 * root.s)
                        Layout.preferredHeight: Math.round(20 * root.s)
                        radius: Math.round(10 * root.s)
                        color: modelData === "none" ? shell.innerSurfaceStrong : root.colorForKey(modelData)
                        border.width: selected ? 2 : 0
                        border.color: Colours.palette.m3onSurface

                        StateLayer {
                            enabled: root.locked
                            radius: parent.radius
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
                Layout.minimumHeight: Math.round(36 * root.s)
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
                    font: Tokens.font.body.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).build()
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

            // Edit Body
            StyledRect {
                visible: root.mode === "edit"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Math.round(44 * root.s)
                clip: true
                radius: Math.round(Tokens.rounding.medium * Math.min(1.2, Math.max(0.75, root.s)))
                color: shell.innerSurfaceStrong
                border.width: bodyEdit.activeFocus ? 1.5 : 1
                border.color: bodyEdit.activeFocus ? root.accentColor : shell.innerBorder

                Flickable {
                    id: editFlick

                    anchors.fill: parent
                    anchors.margins: Math.round(8 * root.s)
                    contentWidth: width
                    contentHeight: Math.max(height, bodyEdit.implicitHeight)
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    TextEdit {
                        id: bodyEdit

                        width: editFlick.width
                        height: Math.max(editFlick.height, implicitHeight)
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).build()
                        wrapMode: TextEdit.WordWrap
                        selectByMouse: true
                        onTextChanged: if (root.mode === "edit") root.draftBody = text
                        Keys.onEscapePressed: root.saveEdits()

                        StyledText {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            text: Tr.tr("Start typing...")
                            font: Tokens.font.body.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).build()
                            color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.55)
                            visible: bodyEdit.text === "" && !bodyEdit.activeFocus
                        }
                    }
                }
            }

            // Bottom toolbar on narrow 2x1 column so controls fit cleanly
            RowLayout {
                visible: wsRoot.narrowCard
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Math.max(2, Math.round(2 * root.s))

                WidgetIconButton {
                    visible: root.sortedNotes.length > 1 && root.mode === "view"
                    icon: "chevron_left"
                    type: IconButton.Text
                    translucent: shell.isTranslucent
                    scaleFactor: root.s * 0.85
                    onClicked: root.stepNote(-1)
                }

                StyledText {
                    visible: root.sortedNotes.length > 1 && root.mode === "view"
                    text: (root.activeIndex + 1) + "/" + root.sortedNotes.length
                    font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.84)).build()
                    color: Colours.palette.m3onSurfaceVariant
                }

                WidgetIconButton {
                    visible: root.sortedNotes.length > 1 && root.mode === "view"
                    icon: "chevron_right"
                    type: IconButton.Text
                    translucent: shell.isTranslucent
                    scaleFactor: root.s * 0.85
                    onClicked: root.stepNote(1)
                }

                Item {
                    Layout.fillWidth: true
                }

                WidgetIconButton {
                    visible: root.activeNote !== null && root.mode === "view"
                    icon: "push_pin"
                    type: IconButton.Text
                    isToggle: true
                    checked: Boolean(root.activeNote?.pinned)
                    translucent: shell.isTranslucent
                    scaleFactor: root.s * 0.85
                    onClicked: if (root.activeNote) NotesStore.togglePin(root.activeNote.id)
                }

                WidgetIconButton {
                    visible: root.mode === "view"
                    icon: "add"
                    type: IconButton.Text
                    translucent: shell.isTranslucent
                    scaleFactor: root.s * 0.88
                    onClicked: root.createAndEditNote()
                }

                WidgetIconButton {
                    visible: root.activeNote !== null && root.mode === "edit"
                    icon: "delete"
                    type: IconButton.Text
                    translucent: shell.isTranslucent
                    scaleFactor: root.s * 0.88
                    onClicked: root.deleteActiveNote()
                }
            }
        }
    }
}

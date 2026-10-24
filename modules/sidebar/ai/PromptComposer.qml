pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import M3Shapes

ColumnLayout {
    id: root

    signal openModelPickerRequested()
    signal openHistoryRequested()
    signal openToolsSettingsRequested()

    readonly property bool hasText: inputArea.text.trim().length > 0 || AiEngine.attachedImageBase64.length > 0
    readonly property bool toolsEnabled: GlobalConfig.ai.enableCelestialMode !== false

    spacing: Tokens.spacing.small

    Connections {
        target: AiEngine
        function onSelectorOpenChanged() {
            if (!AiEngine.selectorOpen) {
                Qt.callLater(() => inputArea.forceActiveFocus());
            }
        }
    }

    function focusInput() {
        inputArea.forceActiveFocus();
    }

    function setPromptText(txt, autoSend = false) {
        inputArea.text = txt;
        if (autoSend) {
            submitPrompt();
        } else {
            inputArea.forceActiveFocus();
            inputArea.cursorPosition = inputArea.text.length;
        }
    }

    function executeSlashCommand(cmdId) {
        inputArea.clear();
        if (cmdId === "new") {
            AiEngine.createNewChat();
        } else if (cmdId === "reset" || cmdId === "clear") {
            AiEngine.clearCurrentChat();
        } else if (cmdId === "history") {
            root.openHistoryRequested();
        } else if (cmdId === "model") {
            root.openModelPickerRequested();
        } else if (cmdId === "tools") {
            root.openToolsSettingsRequested();
        }
    }

    function submitPrompt() {
        var trimmed = inputArea.text.trim();
        if (slashMenu.isOpen && trimmed.indexOf("/") === 0 && trimmed.indexOf(" ") === -1) {
            if (slashMenu.acceptCurrent()) return;
        }
        if (AiEngine.isTyping) {
            AiEngine.abortGeneration();
            return;
        }
        if (!trimmed && !AiEngine.attachedImageBase64) return;
        inputArea.clear();
        AiEngine.sendPrompt(trimmed, false, "");
    }

    // Attached Screenshot Preview Pill (if present)
    StyledRect {
        Layout.fillWidth: true
        visible: AiEngine.attachedImageBase64.length > 0 || AiEngine.isCapturingScreenshot
        implicitHeight: visible ? 34 : 0
        radius: Tokens.rounding.medium
        color: Colours.tPalette.m3secondaryContainer

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.medium
            anchors.rightMargin: Tokens.padding.small
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: AiEngine.isCapturingScreenshot ? "hourglass_top" : "screenshot_monitor"
                fontStyle: Tokens.font.icon.small
                color: Colours.palette.m3onSecondaryContainer
            }

            StyledText {
                Layout.fillWidth: true
                text: AiEngine.isCapturingScreenshot
                    ? qsTr("Capturing display screenshot...")
                    : qsTr("Display screenshot attached")
                font: Tokens.font.label.small
                color: Colours.palette.m3onSecondaryContainer
                elide: Text.ElideRight
            }

            Item {
                implicitWidth: 22
                implicitHeight: 22
                visible: !AiEngine.isCapturingScreenshot

                StateLayer {
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3onSecondaryContainer
                    onClicked: AiEngine.clearScreenshotAttachment()
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "close"
                    fontStyle: Tokens.font.icon.small
                    color: Colours.palette.m3onSecondaryContainer
                }
            }
        }
    }

    // Unified Two-Tier Docked Composer Container (Top Shelf + In-Drawer Menus + Bottom Recessed Input Well)
    StyledRect {
        id: composerDock
        Layout.fillWidth: true
        implicitHeight: dockCol.implicitHeight + 8
        radius: 24
        color: Colours.tPalette.m3surfaceContainer
        clip: true

        ColumnLayout {
            id: dockCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 4
            spacing: 4

            // Tier 1: Connected Top Control Shelf (Model Selector + Tools Toggle + Vision Screenshot)
            RowLayout {
                id: topShelf
                Layout.fillWidth: true
                Layout.leftMargin: 6
                Layout.rightMargin: 6
                Layout.topMargin: 2
                spacing: 6

                // Model Selector Pill Chip
                StyledRect {
                    id: modelChip
                    implicitWidth: Math.min(modelChipRow.implicitWidth + 20, 240)
                    implicitHeight: 26
                    radius: 13
                    color: AiEngine.selectorOpen
                        ? Colours.palette.m3secondaryContainer
                        : (modelChipState.containsMouse ? Colours.tPalette.m3surfaceContainerHighest : Colours.tPalette.m3surfaceContainerHigh)

                    Behavior on color { CAnim {} }
                    Behavior on implicitWidth { Anim { type: Anim.Standard } }

                    StateLayer {
                        id: modelChipState
                        radius: 13
                        color: AiEngine.selectorOpen ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        onClicked: root.openModelPickerRequested()
                    }

                    Row {
                        id: modelChipRow
                        anchors.centerIn: parent
                        spacing: 5

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: AiEngine.activeProviderIcon
                            fontStyle: Tokens.font.icon.small
                            color: AiEngine.selectorOpen ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3primary
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                var m = AiEngine.currentModel || "auto";
                                var slashIdx = m.lastIndexOf("/");
                                return slashIdx !== -1 ? m.substring(slashIdx + 1) : m;
                            }
                            font: Tokens.font.label.small
                            color: AiEngine.selectorOpen ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                            width: Math.min(implicitWidth, 175)
                            elide: Text.ElideRight
                        }

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "expand_less"
                            fontStyle: Tokens.font.icon.small
                            color: AiEngine.selectorOpen ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            rotation: AiEngine.selectorOpen ? 180 : 0
                            Behavior on rotation { Anim { type: Anim.Standard } }
                        }
                    }
                }

                // System Tools Toggle Chip
                StyledRect {
                    id: toolsChip
                    implicitWidth: toolsChipRow.implicitWidth + 18
                    implicitHeight: 26
                    radius: 13
                    color: root.toolsEnabled
                        ? Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.16)
                        : Colours.tPalette.m3surfaceContainerHigh

                    Behavior on color { CAnim {} }

                    StateLayer {
                        radius: 13
                        color: root.toolsEnabled ? Colours.palette.m3primary : Colours.palette.m3onSurface
                        onClicked: GlobalConfig.ai.enableCelestialMode = !root.toolsEnabled
                    }

                    Row {
                        id: toolsChipRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "handyman"
                            fontStyle: Tokens.font.icon.small
                            fill: root.toolsEnabled ? 1 : 0
                            color: root.toolsEnabled ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            Behavior on color { CAnim {} }
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Tools")
                            font: Tokens.font.label.small
                            color: root.toolsEnabled ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            Behavior on color { CAnim {} }
                        }
                    }
                }

                // Vision Screenshot Capture Chip (only visible when model supports vision)
                StyledRect {
                    id: visionChip
                    visible: AiEngine.isCurrentModelVisionCapable
                    implicitWidth: 26
                    implicitHeight: 26
                    radius: 13
                    color: AiEngine.attachedImageBase64.length > 0
                        ? Colours.palette.m3secondaryContainer
                        : Colours.tPalette.m3surfaceContainerHigh

                    Behavior on color { CAnim {} }

                    StateLayer {
                        radius: 13
                        color: Colours.palette.m3onSurface
                        onClicked: AiEngine.captureScreenshotAttachment()
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "add_a_photo"
                        fontStyle: Tokens.font.icon.small
                        color: AiEngine.attachedImageBase64.length > 0
                            ? Colours.palette.m3onSecondaryContainer
                            : Colours.palette.m3onSurfaceVariant
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // Inline Expanding Model Picker Drawer (Pushes Top Shelf Upward)
            ModelPickerModal {
                id: inlineModelPicker
                Layout.fillWidth: true
            }

            // Inline Expanding Slash Command Drawer (Pushes Top Shelf Upward when typing '/')
            SlashMenu {
                id: slashMenu
                Layout.fillWidth: true
                filterText: inputArea.text
                onIsOpenChanged: {
                    if (isOpen && AiEngine.selectorOpen) {
                        AiEngine.selectorOpen = false;
                    }
                }
                onCommandTriggered: cmdId => root.executeSlashCommand(cmdId)
            }

            // Tier 2: Full-Width Recessed Input Well + Morphing MaterialShape Button
            StyledRect {
                id: inputWell
                Layout.fillWidth: true
                implicitHeight: Math.max(44, Math.min(inputArea.implicitHeight + Tokens.padding.small * 2 + 4, 132))
                radius: 20
                color: Colours.tPalette.m3surfaceContainerHigh

                StateLayer {
                    id: inputStateLayer
                    anchors.fill: parent
                    radius: 20
                    hoverEnabled: false
                    cursorShape: Qt.IBeamCursor
                    onClicked: inputArea.forceActiveFocus()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.medium
                    anchors.rightMargin: 6
                    spacing: Tokens.spacing.small

                    ScrollView {
                        id: inputScroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        TextArea {
                            id: inputArea
                            verticalAlignment: TextInput.AlignVCenter
                            placeholderText: qsTr("Ask Lilith... (/ for commands)")
                            color: Colours.palette.m3onSurface
                            placeholderTextColor: Colours.palette.m3outline
                            font: Tokens.font.body.small
                            wrapMode: Text.Wrap
                            selectByMouse: true
                            background: null

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.IBeamCursor
                                propagateComposedEvents: true
                                onPressed: mouse => {
                                    var mapped = mapToItem(inputStateLayer, mouse.x, mouse.y);
                                    inputStateLayer.press(mapped.x, mapped.y);
                                    mouse.accepted = false;
                                }
                            }

                            Keys.onPressed: event => {
                                if (AiEngine.selectorOpen) {
                                    if (event.key === Qt.Key_Up) {
                                        inlineModelPicker.moveUp();
                                        event.accepted = true;
                                        return;
                                    }
                                    if (event.key === Qt.Key_Down) {
                                        inlineModelPicker.moveDown();
                                        event.accepted = true;
                                        return;
                                    }
                                    if (event.key === Qt.Key_Left) {
                                        inlineModelPicker.prevProvider();
                                        event.accepted = true;
                                        return;
                                    }
                                    if (event.key === Qt.Key_Right) {
                                        inlineModelPicker.nextProvider();
                                        event.accepted = true;
                                        return;
                                    }
                                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Tab) {
                                        inlineModelPicker.acceptCurrent();
                                        event.accepted = true;
                                        return;
                                    }
                                    if (event.key === Qt.Key_Escape) {
                                        AiEngine.selectorOpen = false;
                                        event.accepted = true;
                                        return;
                                    }
                                }
                                if (slashMenu.isOpen) {
                                    if (event.key === Qt.Key_Up) {
                                        slashMenu.moveUp();
                                        event.accepted = true;
                                        return;
                                    }
                                    if (event.key === Qt.Key_Down) {
                                        slashMenu.moveDown();
                                        event.accepted = true;
                                        return;
                                    }
                                    if (event.key === Qt.Key_Tab) {
                                        slashMenu.acceptCurrent();
                                        event.accepted = true;
                                        return;
                                    }
                                    if (event.key === Qt.Key_Escape) {
                                        inputArea.clear();
                                        event.accepted = true;
                                        return;
                                    }
                                }
                                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                                    event.accepted = true;
                                    root.submitPrompt();
                                }
                            }
                        }
                    }

                    // 3-State Morphing MaterialShape Send / Abort Button
                    Item {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        Layout.alignment: Qt.AlignVCenter

                        MaterialShape {
                            id: sendShape
                            anchors.fill: parent
                            shape: AiEngine.isTyping
                                ? MaterialShape.Cookie4Sided
                                : (root.hasText ? MaterialShape.Arrow : MaterialShape.SoftBurst)
                            color: AiEngine.isTyping
                                ? Colours.palette.m3error
                                : (root.hasText ? Colours.palette.m3primary : Colours.layer(Colours.tPalette.m3surfaceContainerHighest, 2))
                            scale: sendMouse.pressed
                                ? 0.62
                                : (AiEngine.isTyping
                                    ? (sendMouse.containsMouse ? 0.86 : 0.78)
                                    : (root.hasText ? (sendMouse.containsMouse ? 0.88 : 0.8) : 0.64))
                            rotation: AiEngine.isTyping ? 0 : (root.hasText ? 0 : -45)

                            Behavior on scale { Anim { type: Anim.DefaultSpatial } }
                            Behavior on rotation { Anim { type: Anim.DefaultSpatial } }
                            Behavior on color { CAnim {} }

                            RotationAnimator on rotation {
                                from: 0
                                to: 360
                                duration: 2400
                                loops: Animation.Infinite
                                running: AiEngine.isTyping
                            }

                            MouseArea {
                                id: sendMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: (root.hasText || AiEngine.isTyping) ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.submitPrompt()
                            }
                        }
                    }
                }
            }
        }
    }
}

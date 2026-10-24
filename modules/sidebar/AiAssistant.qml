pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.sidebar.ai
import qs.modules.nexus

Item {
    id: root

    readonly property bool isStreaming: AiEngine.isStreaming

    Connections {
        target: Visibilities
        function onRequestAiFocus() {
            Qt.callLater(() => composer.focusInput());
        }
        function onRequestNewChat() {
            Visibilities.pendingNewChat = false;
            AiEngine.createNewChat();
            Qt.callLater(() => composer.focusInput());
        }
    }

    Component.onCompleted: {
        if (Visibilities.pendingNewChat) {
            Visibilities.pendingNewChat = false;
            AiEngine.createNewChat();
        }
    }

    Item {
        id: mainWrapper
        anchors.fill: parent
        anchors.margins: Tokens.padding.medium

        // Chat View + Morphing Docked Composer
        Item {
            anchors.fill: parent
            opacity: !AiEngine.isHistoryOpen ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.InOutQuad } }

            ChatView {
                id: chatView
                anchors.top: parent.top
                anchors.bottom: composer.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottomMargin: Tokens.spacing.small
                onSuggestionSelected: promptText => composer.setPromptText(promptText, false)
            }

            // Click-outside scrim when model selector drawer is expanded inside composer
            MouseArea {
                anchors.top: parent.top
                anchors.bottom: composer.top
                anchors.left: parent.left
                anchors.right: parent.right
                enabled: AiEngine.selectorOpen
                visible: enabled
                z: 9
                onClicked: AiEngine.selectorOpen = false
            }

            PromptComposer {
                id: composer
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                z: 10

                onOpenModelPickerRequested: AiEngine.selectorOpen = !AiEngine.selectorOpen
                onOpenHistoryRequested: AiEngine.isHistoryOpen = !AiEngine.isHistoryOpen
                onOpenToolsSettingsRequested: WindowFactory.create(null, {})
            }
        }

        // History Grid View
        HistorySheet {
            anchors.fill: parent
            opacity: AiEngine.isHistoryOpen ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.InOutQuad } }
        }
    }
}

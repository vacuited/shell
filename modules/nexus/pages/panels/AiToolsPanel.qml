pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("AI Tools")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        SectionHeader {
            first: true
            text: qsTr("General")
        }

        ToggleRow {
            first: true
            last: true
            text: qsTr("Enabled")
            subtext: qsTr("Allow the assistant to use desktop and external tools")
            configNode: root.targetConfig.ai
            propertyName: "enableCelestialMode"
            checked: root.targetConfig.ai.enableCelestialMode
            onToggled: {
                root.targetConfig.ai.enableCelestialMode = checked;
                root.targetConfig.save();
            }
        }

        SectionHeader {
            text: qsTr("Web Search")
        }

        ToggleRow {
            first: true
            text: qsTr("Web Search")
            subtext: qsTr("Search the web via Tavily Search API")
            configNode: root.targetConfig.ai
            propertyName: "enableWebSearch"
            checked: root.targetConfig.ai.enableWebSearch !== false
            onToggled: {
                root.targetConfig.ai.enableWebSearch = checked;
                root.targetConfig.save();
            }
        }

        TextFieldRow {
            last: true
            label: qsTr("Tavily API Key")
            subtext: qsTr("Free 1,000 searches/month from tavily.com")
            value: root.targetConfig.ai.tavilyApiKey || ""
            placeholderText: "tvly-..."
            onEditingFinished: value => {
                root.targetConfig.ai.tavilyApiKey = value;
                root.targetConfig.save();
            }
        }

        SectionHeader {
            text: qsTr("Spotify & Media")
        }

        ToggleRow {
            first: true
            text: qsTr("Spotify Integration")
            subtext: qsTr("Enable Spotify library search, playlists & queue control")
            configNode: root.targetConfig.ai
            propertyName: "enableSpotify"
            checked: root.targetConfig.ai.enableSpotify || false
            onToggled: {
                root.targetConfig.ai.enableSpotify = checked;
                root.targetConfig.save();
            }
        }

        TextFieldRow {
            label: qsTr("Client ID")
            subtext: qsTr("Spotify Developer App Client ID")
            value: root.targetConfig.ai.spotifyClientId || ""
            placeholderText: "Client ID..."
            onEditingFinished: value => {
                root.targetConfig.ai.spotifyClientId = value;
                root.targetConfig.save();
            }
        }

        TextFieldRow {
            last: true
            label: qsTr("Client Secret")
            subtext: qsTr("Spotify Developer App Client Secret")
            value: root.targetConfig.ai.spotifyClientSecret || ""
            placeholderText: "Client Secret..."
            onEditingFinished: value => {
                root.targetConfig.ai.spotifyClientSecret = value;
                root.targetConfig.save();
            }
        }

        SectionHeader {
            text: qsTr("Desktop & Vision")
        }

        ToggleRow {
            first: true
            text: qsTr("Screen Vision (grim)")
            subtext: qsTr("Capture focused monitor/window for vision models (e.g. MiMo)")
            configNode: root.targetConfig.ai
            propertyName: "enableVision"
            checked: root.targetConfig.ai.enableVision !== false
            onToggled: {
                root.targetConfig.ai.enableVision = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            last: true
            text: qsTr("Clipboard Access")
            subtext: qsTr("Allow assistant to read (wl-paste) and copy text (wl-copy)")
            configNode: root.targetConfig.ai
            propertyName: "enableClipboard"
            checked: root.targetConfig.ai.enableClipboard !== false
            onToggled: {
                root.targetConfig.ai.enableClipboard = checked;
                root.targetConfig.save();
            }
        }

        SectionHeader {
            text: qsTr("System & Memory")
        }

        ToggleRow {
            first: true
            text: qsTr("System & Caelestia Control")
            subtext: qsTr("Allow media control (playerctl) and caelestia shell CLI execution")
            configNode: root.targetConfig.ai
            propertyName: "enableSystemControl"
            checked: root.targetConfig.ai.enableSystemControl !== false
            onToggled: {
                root.targetConfig.ai.enableSystemControl = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            last: true
            text: qsTr("Persistent Memory")
            subtext: qsTr("Store explicit facts and notes in ai_memory.json")
            configNode: root.targetConfig.ai
            propertyName: "enableMemory"
            checked: root.targetConfig.ai.enableMemory !== false
            onToggled: {
                root.targetConfig.ai.enableMemory = checked;
                root.targetConfig.save();
            }
        }
    }
}

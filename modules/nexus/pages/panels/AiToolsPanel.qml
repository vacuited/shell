pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
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
            checked: GlobalConfig.ai.enableCelestialMode
            onToggled: {
                GlobalConfig.ai.enableCelestialMode = checked;
                GlobalConfig.save();
            }
        }

        SectionHeader {
            text: qsTr("Reminders & Notifications")
        }

        ToggleRow {
            first: true
            last: true
            text: qsTr("Reminders & Notifications")
            subtext: qsTr("Schedule timed reminders and send instant desktop notifications")
            checked: AiTools.enableReminders
            onToggled: {
                AiTools.enableReminders = checked;
                AiTools.save();
            }
        }

        SectionHeader {
            text: qsTr("Web Search")
        }

        ToggleRow {
            first: true
            text: qsTr("Web Search")
            subtext: qsTr("Search the web via Tavily Search API or DuckDuckGo")
            checked: AiTools.enableWebSearch
            onToggled: {
                AiTools.enableWebSearch = checked;
                AiTools.save();
            }
        }

        TextFieldRow {
            last: true
            label: qsTr("Tavily API Key")
            subtext: qsTr("Free 1,000 searches/month from tavily.com")
            value: AiTools.tavilyApiKey || ""
            placeholderText: "tvly-..."
            onEditingFinished: value => {
                AiTools.tavilyApiKey = value;
                AiTools.save();
            }
        }

        SectionHeader {
            text: qsTr("Spotify & Media")
        }

        ToggleRow {
            first: true
            text: qsTr("Spotify Integration")
            subtext: qsTr("Enable Spotify library search, playlists & queue control")
            checked: AiTools.enableSpotify
            onToggled: {
                AiTools.enableSpotify = checked;
                AiTools.save();
            }
        }

        TextFieldRow {
            label: qsTr("Client ID")
            subtext: qsTr("Spotify Developer App Client ID")
            value: AiTools.spotifyClientId || ""
            placeholderText: "Client ID..."
            onEditingFinished: value => {
                AiTools.spotifyClientId = value;
                AiTools.save();
            }
        }

        TextFieldRow {
            last: true
            label: qsTr("Client Secret")
            subtext: qsTr("Spotify Developer App Client Secret")
            value: AiTools.spotifyClientSecret || ""
            placeholderText: "Client Secret..."
            onEditingFinished: value => {
                AiTools.spotifyClientSecret = value;
                AiTools.save();
            }
        }

        SectionHeader {
            text: qsTr("Desktop & Vision")
        }

        ToggleRow {
            first: true
            text: qsTr("Screen Vision (grim)")
            subtext: qsTr("Capture focused monitor/window for vision models (e.g. MiMo)")
            checked: AiTools.enableVision
            onToggled: {
                AiTools.enableVision = checked;
                AiTools.save();
            }
        }

        ToggleRow {
            last: true
            text: qsTr("Clipboard Access")
            subtext: qsTr("Allow assistant to read (wl-paste) and copy text (wl-copy)")
            checked: AiTools.enableClipboard
            onToggled: {
                AiTools.enableClipboard = checked;
                AiTools.save();
            }
        }

        SectionHeader {
            text: qsTr("System & Memory")
        }

        ToggleRow {
            first: true
            text: qsTr("System & Caelestia Control")
            subtext: qsTr("Allow media control (playerctl) and caelestia shell CLI execution")
            checked: AiTools.enableSystemControl
            onToggled: {
                AiTools.enableSystemControl = checked;
                AiTools.save();
            }
        }

        ToggleRow {
            last: true
            text: qsTr("Persistent Memory")
            subtext: qsTr("Store explicit facts and notes in ai_memory.json")
            checked: AiTools.enableMemory
            onToggled: {
                AiTools.enableMemory = checked;
                AiTools.save();
            }
        }
    }
}

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config

Singleton {
    id: root

    readonly property string configPath: `${Quickshell.env("HOME")}/.config/caelestia/ai_tools.json`

    property bool enableReminders: true
    property bool enableWebSearch: true
    property string tavilyApiKey: ""
    property bool enableSpotify: false
    property string spotifyClientId: ""
    property string spotifyClientSecret: ""
    property bool enableVision: true
    property bool enableClipboard: true
    property bool enableSystemControl: true
    property bool enableMemory: true
    property bool loaded: false

    readonly property FileView configFile: FileView {
        path: root.configPath
        watchChanges: true
        printErrors: false
        onLoaded: root.loadConfig(text())
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.initDefaults();
            }
        }
    }

    Timer {
        id: saveDebounceTimer
        interval: 300
        repeat: false
        onTriggered: root.flushSave()
    }

    function initDefaults() {
        root.enableReminders = true;
        root.enableWebSearch = true;
        root.tavilyApiKey = "";
        root.enableSpotify = false;
        root.spotifyClientId = "";
        root.spotifyClientSecret = "";
        root.enableVision = true;
        root.enableClipboard = true;
        root.enableSystemControl = true;
        root.enableMemory = true;
        root.loaded = true;
        root.requestSave();
    }

    function loadConfig(content) {
        var rawText = content !== undefined ? content : (configFile ? configFile.text() : "");
        if (!rawText || rawText.trim().length === 0) {
            initDefaults();
            return;
        }

        try {
            var data = JSON.parse(rawText);
            if (data.enableReminders !== undefined) root.enableReminders = data.enableReminders;
            if (data.enableWebSearch !== undefined) root.enableWebSearch = data.enableWebSearch;
            if (data.tavilyApiKey !== undefined) root.tavilyApiKey = data.tavilyApiKey;
            if (data.enableSpotify !== undefined) root.enableSpotify = data.enableSpotify;
            if (data.spotifyClientId !== undefined) root.spotifyClientId = data.spotifyClientId;
            if (data.spotifyClientSecret !== undefined) root.spotifyClientSecret = data.spotifyClientSecret;
            if (data.enableVision !== undefined) root.enableVision = data.enableVision;
            if (data.enableClipboard !== undefined) root.enableClipboard = data.enableClipboard;
            if (data.enableSystemControl !== undefined) root.enableSystemControl = data.enableSystemControl;
            if (data.enableMemory !== undefined) root.enableMemory = data.enableMemory;
        } catch (e) {
            console.warn("Failed to parse ai_tools.json:", e);
        }

        root.loaded = true;
    }

    function requestSave() {
        if (saveDebounceTimer.running) saveDebounceTimer.restart();
        else saveDebounceTimer.start();
    }

    function save() {
        requestSave();
    }

    function flushSave() {
        if (!configFile) return;
        saveDebounceTimer.stop();

        var payload = {
            "version": 1,
            "enableReminders": root.enableReminders,
            "enableWebSearch": root.enableWebSearch,
            "tavilyApiKey": root.tavilyApiKey,
            "enableSpotify": root.enableSpotify,
            "spotifyClientId": root.spotifyClientId,
            "spotifyClientSecret": root.spotifyClientSecret,
            "enableVision": root.enableVision,
            "enableClipboard": root.enableClipboard,
            "enableSystemControl": root.enableSystemControl,
            "enableMemory": root.enableMemory
        };
        configFile.setText(JSON.stringify(payload, null, 2));
    }
}

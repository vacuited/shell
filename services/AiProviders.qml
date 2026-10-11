pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config

Singleton {
    id: root

    readonly property string configPath: `${Quickshell.env("HOME")}/.config/caelestia/ai_providers.json`

    property var providers: []
    property string activeProviderId: "openrouter"
    property string activeModel: "openrouter/auto"
    property var modelsByProvider: ({})
    property var modelFetchState: ({})
    property var recentModels: []
    property bool loaded: false

    readonly property var activeProvider: {
        for (var i = 0; i < providers.length; i++) {
            if (providers[i].id === activeProviderId)
                return providers[i];
        }
        return providers.length > 0 ? providers[0] : null;
    }

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
        var defaultApiKey = GlobalConfig.ai.openRouterApiKey || "";
        var defaultModel = GlobalConfig.ai.openRouterModel || "openrouter/auto";
        var defaultUrl = GlobalConfig.ai.openRouterUrl || "https://openrouter.ai/api/v1";

        root.providers = [
            {
                "id": "openrouter",
                "name": "OpenRouter",
                "baseUrl": defaultUrl,
                "apiKey": defaultApiKey,
                "models": [
                    defaultModel,
                    "openai/gpt-4o-mini",
                    "anthropic/claude-3.5-haiku",
                    "google/gemini-2.0-flash-001",
                    "deepseek/deepseek-chat"
                ]
            }
        ];
        root.activeProviderId = "openrouter";
        root.activeModel = defaultModel;
        root.loadRecentFromConfig();
        root.loaded = true;
        root.requestSave();
        root.fetchAllModels();
    }

    function loadConfig(content) {
        var rawText = content !== undefined ? content : (configFile ? configFile.text() : "");
        if (!rawText || rawText.trim().length === 0) {
            initDefaults();
            return;
        }

        try {
            var data = JSON.parse(rawText);
            var list = [];
            if (Array.isArray(data)) {
                list = data;
            } else if (data && Array.isArray(data.providers)) {
                list = data.providers;
                if (data.activeProviderId) root.activeProviderId = data.activeProviderId;
                if (data.activeModel) root.activeModel = data.activeModel;
            }

            if (list.length === 0) {
                initDefaults();
                return;
            }

            root.providers = list;
            var found = false;
            for (var p = 0; p < list.length; p++) {
                if (list[p].id === root.activeProviderId) {
                    found = true;
                    break;
                }
            }
            if (!found) root.activeProviderId = list[0].id;

            if (!root.activeModel && root.activeProvider) {
                root.activeModel = (root.activeProvider.models && root.activeProvider.models.length > 0)
                    ? root.activeProvider.models[0]
                    : "openrouter/auto";
            }
        } catch (e) {
            console.log("Error parsing ai_providers.json: " + e.message);
            if (root.providers.length === 0) initDefaults();
        }

        root.loadRecentFromConfig();
        root.loaded = true;
        root.fetchAllModels();
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
            "activeProviderId": root.activeProviderId,
            "activeModel": root.activeModel,
            "providers": root.providers
        };
        configFile.setText(JSON.stringify(payload, null, 2));

        if (root.activeProvider) {
            GlobalConfig.ai.activeProvider = "openrouter";
            GlobalConfig.ai.openRouterUrl = root.activeProvider.baseUrl;
            GlobalConfig.ai.openRouterApiKey = root.activeProvider.apiKey;
            GlobalConfig.ai.openRouterModel = root.activeModel;
            GlobalConfig.save();
        }
    }

    function selectModel(providerId, model) {
        root.activeProviderId = providerId;
        root.activeModel = model;
        pushRecentModel(providerId, model);
        save();
    }

    function pushRecentModel(providerId, model) {
        if (!providerId || !model) return;
        var entryStr = providerId + "|" + model;
        var currentRecents = (GlobalConfig.ai.recentModels || []).slice();
        var idx = currentRecents.indexOf(entryStr);
        if (idx !== -1) currentRecents.splice(idx, 1);
        currentRecents.unshift(entryStr);
        if (currentRecents.length > 8) currentRecents = currentRecents.slice(0, 8);
        GlobalConfig.ai.recentModels = currentRecents;
        GlobalConfig.save();

        loadRecentFromConfig();
    }

    function loadRecentFromConfig() {
        var raw = GlobalConfig.ai.recentModels || [];
        var out = [];
        for (var i = 0; i < raw.length && out.length < 5; i++) {
            var sep = raw[i].indexOf("|");
            if (sep === -1) continue;
            var pid = raw[i].substring(0, sep);
            var mname = raw[i].substring(sep + 1);

            var pName = "";
            for (var p = 0; p < root.providers.length; p++) {
                if (root.providers[p].id === pid) {
                    pName = root.providers[p].name;
                    break;
                }
            }
            if (!pName) continue;

            out.push({
                "providerId": pid,
                "providerName": pName,
                "model": mname,
                "name": mname,
                "lower": mname.toLowerCase()
            });
        }
        root.recentModels = out;
    }

    function addProvider(name, baseUrl, apiKey, models) {
        var id = "p_" + Date.now();
        var modelList = [];
        if (Array.isArray(models)) {
            modelList = models;
        } else if (typeof models === "string" && models.trim().length > 0) {
            modelList = models.split(",").map(m => m.trim()).filter(m => m.length > 0);
        } else {
            modelList = ["default"];
        }

        var newP = {
            "id": id,
            "name": name || "New Provider",
            "baseUrl": baseUrl || "https://api.openai.com/v1",
            "apiKey": apiKey || "",
            "models": modelList
        };

        var list = root.providers.slice();
        list.push(newP);
        root.providers = list;
        save();
        fetchProviderModels(id);
        return id;
    }

    function updateProvider(id, changes) {
        var list = root.providers.slice();
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === id) {
                list[i] = Object.assign({}, list[i], changes);
                break;
            }
        }
        root.providers = list;
        save();
        if (changes.baseUrl !== undefined || changes.apiKey !== undefined) {
            fetchProviderModels(id);
        }
    }

    function removeProvider(id) {
        if (root.providers.length <= 1) return;
        var list = root.providers.filter(p => p.id !== id);
        root.providers = list;
        if (root.activeProviderId === id) {
            root.activeProviderId = list[0].id;
            root.activeModel = (list[0].models && list[0].models.length > 0) ? list[0].models[0] : "";
        }
        save();
        loadRecentFromConfig();
    }

    function fetchProviderModels(providerId) {
        var p = null;
        for (var i = 0; i < root.providers.length; i++) {
            if (root.providers[i].id === providerId) {
                p = root.providers[i];
                break;
            }
        }
        if (!p || !p.baseUrl) return;
        if (root.modelFetchState[providerId] === "loading") return;

        var stateCopy = Object.assign({}, root.modelFetchState);
        stateCopy[providerId] = "loading";
        root.modelFetchState = stateCopy;

        var cleanUrl = p.baseUrl.replace(/\/+$/, "");
        var requestUrl = cleanUrl + "/models";
        var xhr = new XMLHttpRequest();
        xhr.open("GET", requestUrl, true);
        if (p.apiKey) {
            xhr.setRequestHeader("Authorization", "Bearer " + p.apiKey);
            xhr.setRequestHeader("HTTP-Referer", "https://github.com/dim-ghub/midnight-shell");
            xhr.setRequestHeader("X-Title", "midnight-shell");
        }

        xhr.onreadystatechange = () => {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var fetched = [];
                if (xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText);
                        if (res.data && Array.isArray(res.data)) {
                            for (var j = 0; j < res.data.length; j++) {
                                if (res.data[j].id) fetched.push(res.data[j].id);
                            }
                            fetched.sort();
                        } else if (res.models && Array.isArray(res.models)) {
                            for (var k = 0; k < res.models.length; k++) {
                                if (res.models[k].name) fetched.push(res.models[k].name);
                            }
                            fetched.sort();
                        }
                    } catch (e) {
                        console.log("Error parsing models for provider " + providerId + ": " + e.message);
                    }
                }

                var baseList = p.models || [];
                var combined = [];
                for (var b = 0; b < baseList.length; b++) {
                    if (combined.indexOf(baseList[b]) === -1) combined.push(baseList[b]);
                }
                for (var f = 0; f < fetched.length; f++) {
                    if (combined.indexOf(fetched[f]) === -1) combined.push(fetched[f]);
                }

                var modelsCopy = Object.assign({}, root.modelsByProvider);
                modelsCopy[providerId] = combined;
                root.modelsByProvider = modelsCopy;

                var stateCopyDone = Object.assign({}, root.modelFetchState);
                stateCopyDone[providerId] = (xhr.status === 200 && fetched.length > 0) ? "done" : "failed";
                root.modelFetchState = stateCopyDone;
            }
        };

        xhr.send();
    }

    function fetchAllModels() {
        for (var i = 0; i < root.providers.length; i++) {
            fetchProviderModels(root.providers[i].id);
        }
    }
}

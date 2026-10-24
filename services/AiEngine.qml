pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config

Singleton {
    id: root

    // --- State Models ---
    ListModel { id: chatHistory }
    ListModel { id: historySessionsModel }

    readonly property alias chatHistory: chatHistory
    readonly property alias historySessionsModel: historySessionsModel

    // --- Execution & Session State ---
    property string currentChatId: ""
    property string lastChatId: ""
    property var currentRequest: null
    property bool isStreaming: false
    property bool isTyping: false
    property bool isThinking: false
    property bool inAgentLoop: false
    property string currentActionText: "Thinking..."
    property string currentThoughtText: ""
    property bool isThoughtExpanded: false

    // --- UI Coordinator Flags (shared across sidebar lifecycle) ---
    property bool isHistoryOpen: false
    property bool selectorOpen: false
    property string modelQuery: ""
    property var expandedSections: ({})

    // --- Vision / Screenshot Attachment State ---
    property string attachedImageBase64: ""
    property string attachedImagePreviewPath: ""
    property bool isCapturingScreenshot: false
    property string lastCapturedImageBase64: ""

    // --- Tool Loop State ---
    property int runningToolsCount: 0
    property int agentRounds: 0
    readonly property int maxAgentRounds: 4
    property var toolResultMap: ({})
    property var toolResultOrder: []
    property var pendingToolCalls: null
    property string pendingAssistantContent: ""
    property var activeToolCalls: []
    property var currentTurnToolMessages: []
    property string currentTurnAttachedImage: ""

    // --- Persistence State ---
    property bool storeReady: false
    property bool isInitializing: true
    property var allChatSessions: []
    readonly property string storePath: `${Quickshell.env("HOME")}/.config/caelestia/ai_chats.json`

    // --- Provider & Model Bindings ---
    readonly property string activeProvider: AiProviders.activeProviderId
    readonly property string currentModel: AiProviders.activeModel || "openrouter/auto"
    readonly property string providerLabel: AiProviders.activeProvider ? AiProviders.activeProvider.name : "AI"
    readonly property var providerList: AiProviders.providers
    readonly property string activeProviderIcon: "auto_awesome"

    function isVisionCapable(modelName) {
        var m = (modelName || "").toLowerCase();
        if (!m) return false;
        return m.indexOf("vision") !== -1 ||
               m.indexOf("minimax") !== -1 ||
               m.indexOf("kimi") !== -1 ||
               m.indexOf("step") !== -1 ||
               m.indexOf("glm") !== -1 ||
               m.indexOf("qwen3.8") !== -1 ||
               m.indexOf("qwen-vl") !== -1 ||
               m.indexOf("qwen2.5-vl") !== -1 ||
               m.indexOf("qvq") !== -1 ||
               m.indexOf("internvl") !== -1 ||
               m.indexOf("mimo") !== -1 ||
               m.indexOf("vl") !== -1 ||
               m.indexOf("4o") !== -1 ||
               m.indexOf("omni") !== -1 ||
               m.indexOf("gemini") !== -1 ||
               m.indexOf("claude-3") !== -1 ||
               m.indexOf("claude-") !== -1 ||
               m.indexOf("pixtral") !== -1 ||
               m.indexOf("minicpm") !== -1 ||
               m.indexOf("llava") !== -1 ||
               m.indexOf("cogvlm") !== -1 ||
               m.indexOf("gemma-3") !== -1 ||
               m.indexOf("gpt-4-turbo") !== -1;
    }

    readonly property bool isCurrentModelVisionCapable: isVisionCapable(currentModel)

    readonly property bool modelsLoading: {
        for (var key in AiProviders.modelFetchState) {
            if (AiProviders.modelFetchState[key] === "loading") return true;
        }
        return false;
    }

    readonly property var orderedSections: {
        var secs = [];
        var recents = AiProviders.recentModels;
        if (recents && recents.length > 0) {
            var recentEntriesList = [];
            for (var r = 0; r < recents.length; r++) {
                recentEntriesList.push({
                    "name": recents[r].model,
                    "lower": (recents[r].model || "").toLowerCase(),
                    "providerId": recents[r].providerId,
                    "providerName": recents[r].providerName
                });
            }
            secs.push({ "id": "recent", "label": qsTr("Recent"), "icon": "history", "models": recentEntriesList });
        }

        var providers = AiProviders.providers;
        for (var i = 0; i < providers.length; i++) {
            var prov = providers[i];
            var models = prov.models || [];
            var entries = [];
            for (var m = 0; m < models.length; m++) {
                entries.push({
                    "name": models[m],
                    "lower": (models[m] || "").toLowerCase(),
                    "providerId": prov.id,
                    "providerName": prov.name
                });
            }
            secs.push({
                "id": prov.id,
                "label": prov.name,
                "icon": "auto_awesome",
                "models": entries
            });
        }
        return secs;
    }

    readonly property var visibleSections: {
        var query = modelQuery.toLowerCase();
        var secs = [];
        for (var s = 0; s < orderedSections.length; s++) {
            var srcSec = orderedSections[s];
            var rows;
            if (!query) {
                rows = srcSec.models;
            } else {
                rows = [];
                for (var m = 0; m < srcSec.models.length; m++) {
                    if (srcSec.models[m].lower.indexOf(query) !== -1)
                        rows.push(srcSec.models[m]);
                }
            }
            secs.push({ "id": srcSec.id, "label": srcSec.label, "icon": srcSec.icon, "models": rows });
        }
        return secs;
    }

    readonly property int searchResultCount: {
        var n = 0;
        for (var s = 0; s < visibleSections.length; s++)
            n += visibleSections[s].models.length;
        return n;
    }

    readonly property int totalModelCount: {
        var n = 0;
        for (var s = 0; s < orderedSections.length; s++) {
            if (orderedSections[s].id === "recent") continue;
            n += orderedSections[s].models.length;
        }
        return n;
    }

    signal scrollToBottomRequested()

    function isSectionExpanded(sec) {
        if (modelQuery.length > 0) return sec.models.length > 0;
        if (expandedSections[sec.id] !== undefined)
            return expandedSections[sec.id];
        return sec.id === AiProviders.activeProviderId || sec.id === "recent";
    }

    function toggleSection(secId) {
        var current = isSectionExpanded({ id: secId, models: [] });
        expandedSections = Object.assign({}, expandedSections, { [secId]: !current });
    }

    function providerIconForId(providerId) {
        if (providerId === "recent") return "history";
        return "auto_awesome";
    }

    function setActiveModel(providerId, model) {
        if (!model) return;
        AiProviders.selectModel(providerId, model);
    }

    function fetchModels() {
        AiProviders.fetchAllModels();
    }

    function fetchProviderModels(providerId) {
        AiProviders.fetchProviderModels(providerId);
    }

    // --- FileView Storage ---
    FileView {
        id: chatStore
        path: root.storePath
        printErrors: false

        onLoaded: {
            var raw = text();
            var data = null;
            if (raw && raw.trim().length > 0) {
                try {
                    data = JSON.parse(raw);
                } catch (e) {
                    console.warn("[AiEngine] Failed to parse ai_chats.json:", e);
                    data = null;
                }
            }
            if (data !== null) {
                root.applyStoreData(data);
            } else {
                root.migrateLegacyHistory();
            }
        }

        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.migrateLegacyHistory();
            } else {
                root.applyStoreData([]);
            }
        }
    }

    Timer {
        id: historySaveTimer
        interval: 400
        repeat: false
        onTriggered: root.flushHistory()
    }

    property string _pendingToolPrompt: ""
    property string _pendingToolName: ""

    Timer {
        id: toolFollowupTimer
        interval: 1500
        repeat: false
        onTriggered: {
            var p = root._pendingToolPrompt;
            var n = root._pendingToolName;
            root._pendingToolPrompt = "";
            root._pendingToolName = "";
            if (p) {
                root.sendPrompt(p, true, n);
            }
        }
    }

    property var _retryCallback: null
    property var _retryPayload: null
    property string _retryUrl: ""
    property int _retryCount: 0
    readonly property int _maxRetries: 3

    Timer {
        id: retryTimer
        interval: 3000
        repeat: false
        onTriggered: {
            var cb = root._retryCallback;
            root._retryCallback = null;
            if (cb) cb();
        }
    }

    Connections {
        target: Visibilities
        function onRequestNewChat() {
            Visibilities.pendingNewChat = false;
            root.createNewChat();
        }
    }

    Component.onDestruction: {
        if (root.storeReady && chatHistory.count > 0) {
            root.saveHistory(true);
        } else {
            root.flushHistory();
        }
    }

    // --- Subprocess Runner ---
    function runAgentCommand(cmd, type) {
        var processQml = "import QtQuick\n" +
                         "import Quickshell.Io\n" +
                         "Process {\n" +
                         "    id: proc\n" +
                         "    command: [\"sh\", \"-c\", " + JSON.stringify(cmd) + "]\n" +
                         "    property string outStr: \"\"\n" +
                         "    property string errStr: \"\"\n" +
                         "    property bool hasExited: false\n" +
                         "    property int exitCode: 0\n" +
                         "    property bool outFinished: false\n" +
                         "    property bool errFinished: false\n" +
                         "    function checkDone() {\n" +
                         "        if (hasExited && outFinished && errFinished) {\n" +
                         "            root.handleAgentProcessResult(" + JSON.stringify(type) + ", proc.outStr, proc.errStr, " + JSON.stringify(cmd) + ", proc.exitCode);\n" +
                         "            proc.destroy();\n" +
                         "        }\n" +
                         "    }\n" +
                         "    stdout: StdioCollector { onStreamFinished: { proc.outStr = text || \"\"; proc.outFinished = true; proc.checkDone(); } }\n" +
                         "    stderr: StdioCollector { onStreamFinished: { proc.errStr = text || \"\"; proc.errFinished = true; proc.checkDone(); } }\n" +
                         "    onExited: code => { proc.exitCode = code; proc.hasExited = true; proc.checkDone(); }\n" +
                         "}";
        var obj = Qt.createQmlObject(processQml, root, "agentProcess");
        obj.running = true;
    }

    function captureScreenshotAttachment() {
        if (isCapturingScreenshot) return;
        isCapturingScreenshot = true;
        var scriptPath = Quickshell.shellDir + "/assets/scripts/ai_tools.py";
        var cmd = 'python3 "' + scriptPath + '" --tool take_screenshot --args \'{}\'';
        runAgentCommand(cmd, "attach_screenshot");
    }

    function clearScreenshotAttachment() {
        attachedImageBase64 = "";
        attachedImagePreviewPath = "";
    }

    function recordToolResult(toolName, text) {
        var map = Object.assign({}, toolResultMap);
        map[toolName] = (map[toolName] ? map[toolName] + "\n\n" : "") + text;
        toolResultMap = map;
        if (toolResultOrder.indexOf(toolName) === -1)
            toolResultOrder = toolResultOrder.concat([toolName]);

        // Update activeToolCalls status for UI display
        var updated = activeToolCalls.slice();
        for (var i = 0; i < updated.length; i++) {
            if (updated[i].name === toolName && updated[i].status === "running") {
                updated[i] = Object.assign({}, updated[i], {
                    "status": "done",
                    "result": text.substring(0, 600)
                });
                break;
            }
        }
        activeToolCalls = updated;
        if (chatHistory.count > 0) {
            chatHistory.setProperty(chatHistory.count - 1, "toolCallsJson", JSON.stringify(activeToolCalls));
        }
    }

    function isVisionCapableModel() {
        return isVisionCapable(AiProviders.activeModel || currentModel);
    }

    function handleAgentProcessResult(type, stdout, stderr, cmd, exitCode = 0) {
        if (type === "attach_screenshot") {
            isCapturingScreenshot = false;
            try {
                var parsedShot = JSON.parse(stdout.trim());
                if (parsedShot && parsedShot.image_base64) {
                    attachedImageBase64 = parsedShot.image_base64;
                }
            } catch (e) {
                console.warn("[AiEngine] Screenshot attachment failed:", e);
            }
            return;
        }

        if (type.startsWith("exec_")) {
            var toolName = type.substring(5);
            var outText = stdout.trim();
            var errText = stderr.trim();
            var resultText = "";

            var parsed = null;
            try {
                parsed = JSON.parse(outText);
            } catch (e) {}

            if (parsed && parsed.result !== undefined) {
                resultText = parsed.result;
                if (parsed.image_base64) {
                    lastCapturedImageBase64 = parsed.image_base64;
                }
            } else if (exitCode !== 0) {
                resultText = "Tool failed with exit code " + exitCode + ": " + (outText || errText);
            } else {
                resultText = outText || errText || "(Tool executed successfully with no output)";
            }

            recordToolResult(toolName, resultText);
            runningToolsCount--;
            checkToolsFinished();
        }
    }

    function checkToolsFinished() {
        if (runningToolsCount <= 0) {
            var combined = "";
            for (var i = 0; i < toolResultOrder.length; i++) {
                var tn = toolResultOrder[i];
                combined += "Tool: " + tn + "\nResult: " + toolResultMap[tn] + "\n\n";
            }
            currentActionText = "Processing results...";
            _pendingToolPrompt = combined.trim();
            _pendingToolName = "multi_tool";
            toolFollowupTimer.restart();
        }
    }

    // --- Session & History Management ---
    function abortGeneration() {
        toolFollowupTimer.stop();
        retryTimer.stop();
        _retryCallback = null;
        _pendingToolPrompt = "";
        _pendingToolName = "";
        _retryPayload = null;
        _retryCount = 0;
        _retryUrl = "";
        if (currentRequest) {
            currentRequest.abort();
            currentRequest = null;
        }
        isTyping = false;
        isThinking = false;
        inAgentLoop = false;
        isStreaming = false;
        agentRounds = 0;
        currentTurnToolMessages = [];
        currentTurnAttachedImage = "";
        if (chatHistory.count > 0) {
            chatHistory.setProperty(chatHistory.count - 1, "isFinished", true);
            saveHistory(true);
        }
    }

    function createNewChat() {
        toolFollowupTimer.stop();
        retryTimer.stop();
        _retryCallback = null;
        _pendingToolPrompt = "";
        _pendingToolName = "";
        _retryPayload = null;
        _retryCount = 0;
        _retryUrl = "";
        if (storeReady && chatHistory.count > 0) {
            saveHistory(true);
        }
        if (currentRequest) {
            currentRequest.abort();
            currentRequest = null;
        }
        isTyping = false;
        isThinking = false;
        inAgentLoop = false;
        isStreaming = false;
        pendingToolCalls = null;
        pendingAssistantContent = "";
        activeToolCalls = [];
        agentRounds = 0;
        currentTurnToolMessages = [];
        currentTurnAttachedImage = "";
        currentChatId = "chat_" + Date.now();
        lastChatId = currentChatId;
        chatHistory.clear();
        isHistoryOpen = false;
        if (!isInitializing)
            flushHistory();
    }

    function clearCurrentChat() {
        toolFollowupTimer.stop();
        retryTimer.stop();
        _retryCallback = null;
        _pendingToolPrompt = "";
        _pendingToolName = "";
        _retryPayload = null;
        _retryCount = 0;
        _retryUrl = "";
        if (currentRequest) {
            currentRequest.abort();
            currentRequest = null;
        }
        isTyping = false;
        isThinking = false;
        inAgentLoop = false;
        isStreaming = false;
        pendingToolCalls = null;
        pendingAssistantContent = "";
        activeToolCalls = [];
        agentRounds = 0;
        currentTurnToolMessages = [];
        currentTurnAttachedImage = "";
        chatHistory.clear();
        if (currentChatId) {
            for (var i = 0; i < allChatSessions.length; i++) {
                if (allChatSessions[i].id === currentChatId) {
                    allChatSessions.splice(i, 1);
                    break;
                }
            }
        }
        currentChatId = "chat_" + Date.now();
        lastChatId = currentChatId;
        syncHistoryModel();
        flushHistory();
    }

    function loadChat(id) {
        if (id === currentChatId && chatHistory.count > 0) {
            isHistoryOpen = false;
            return;
        }
        toolFollowupTimer.stop();
        retryTimer.stop();
        _retryCallback = null;
        _pendingToolPrompt = "";
        _pendingToolName = "";
        _retryPayload = null;
        _retryCount = 0;
        _retryUrl = "";
        if (storeReady && chatHistory.count > 0) {
            saveHistory(true);
        }
        if (currentRequest) {
            currentRequest.abort();
            currentRequest = null;
        }
        isTyping = false;
        isThinking = false;
        inAgentLoop = false;
        isStreaming = false;
        activeToolCalls = [];
        agentRounds = 0;
        currentTurnToolMessages = [];
        currentTurnAttachedImage = "";
        currentChatId = id;
        lastChatId = id;
        chatHistory.clear();
        var found = false;
        var targetSess = null;
        for (var i = 0; i < allChatSessions.length; i++) {
            if (allChatSessions[i].id === id) {
                targetSess = allChatSessions[i];
                var msgs = targetSess.messages || [];
                for (var j = 0; j < msgs.length; j++) {
                    chatHistory.append({
                        "isUser": msgs[j].isUser === true,
                        "text": msgs[j].text || "",
                        "isFinished": msgs[j].isFinished !== false,
                        "thoughtText": msgs[j].thoughtText || "",
                        "toolCallsJson": msgs[j].toolCallsJson || "[]"
                    });
                }
                found = true;
                break;
            }
        }
        if (found && targetSess)
            restoreSessionProvider(targetSess);
        else
            createNewChat();
        isHistoryOpen = false;
        if (!isInitializing)
            flushHistory();
        scrollToBottomRequested();
    }

    function relativeTime(ts) {
        if (!ts) return "";
        var diff = Date.now() - ts;
        if (diff < 0) diff = 0;
        var mins = Math.floor(diff / 60000);
        if (mins < 1) return "Just now";
        if (mins < 60) return mins + "m ago";
        var hours = Math.floor(mins / 60);
        if (hours < 24) return hours + "h ago";
        var days = Math.floor(hours / 24);
        if (days === 1) return "Yesterday";
        if (days < 7) return days + "d ago";
        return Qt.formatDate(new Date(ts), "MMM d");
    }

    function syncHistoryModel() {
        historySessionsModel.clear();
        for (var i = 0; i < allChatSessions.length; i++) {
            var s = allChatSessions[i];
            var msgs = Array.isArray(s.messages) ? s.messages : [];
            var preview = "";
            for (var m = msgs.length - 1; m >= 0; m--) {
                var t = (msgs[m].text || "").replace(/\s+/g, " ").trim();
                if (t) { preview = t; break; }
            }
            if (!preview) {
                for (var n = 0; n < msgs.length; n++) {
                    var th = (msgs[n].thoughtText || "").replace(/\s+/g, " ").trim();
                    if (th) { preview = "…" + th.substring(0, 60); break; }
                }
            }
            if (preview.length > 90)
                preview = preview.substring(0, 90) + "…";
            historySessionsModel.append({
                "id": s.id || "",
                "title": s.title || "New Chat",
                "preview": preview,
                "updated": relativeTime(s.updatedAt || s.createdAt || 0),
                "providerIcon": providerIconForId(s.provider || "")
            });
        }
    }

    function restoreSessionProvider(sess) {
        if (!sess) return;
        if (sess.provider)
            AiProviders.activeProviderId = sess.provider;
        if (sess.model)
            AiProviders.activeModel = sess.model;
    }

    function applyStoreData(data) {
        var chats = Array.isArray(data) ? data : (data && Array.isArray(data.chats) ? data.chats : []);
        lastChatId = (!Array.isArray(data) && data && data.lastChatId) ? String(data.lastChatId) : "";

        allChatSessions = chats.filter(s => s !== null && s.id).map(s => {
            var created = typeof s.createdAt === "number" ? s.createdAt : 0;
            return {
                "id": String(s.id),
                "title": s.title || "New Chat",
                "messages": Array.isArray(s.messages) ? s.messages : [],
                "createdAt": created,
                "updatedAt": typeof s.updatedAt === "number" ? s.updatedAt : created,
                "provider": s.provider || AiProviders.activeProviderId,
                "model": s.model || ""
            };
        });

        allChatSessions.sort((a, b) => b.updatedAt - a.updatedAt);

        syncHistoryModel();
        storeReady = true;

        if (Visibilities.pendingNewChat) {
            Visibilities.pendingNewChat = false;
            createNewChat();
        } else {
            var targetId = "";
            if (lastChatId) {
                for (var i = 0; i < allChatSessions.length; i++) {
                    if (allChatSessions[i].id === lastChatId) {
                        targetId = lastChatId;
                        break;
                    }
                }
            }
            if (!targetId && allChatSessions.length > 0)
                targetId = allChatSessions[0].id;

            if (targetId)
                loadChat(targetId);
            else
                createNewChat();
        }

        Qt.callLater(() => {
            root.isInitializing = false;
        });
    }

    function migrateLegacyHistory() {
        var legacy = [];
        try {
            var jsonStr = GlobalConfig.ai.ollamaHistoryJson;
            if (jsonStr && jsonStr !== "[]") legacy = JSON.parse(jsonStr);
        } catch (e) {
            legacy = [];
        }
        if (!Array.isArray(legacy))
            legacy = [];

        applyStoreData(legacy);
        if (legacy.length > 0) {
            Qt.callLater(() => root.flushHistory());
        }
    }

    function flushHistory() {
        historySaveTimer.stop();
        if (!storeReady) return;
        var payload = {
            "version": 2,
            "lastChatId": currentChatId || lastChatId,
            "chats": allChatSessions
        };
        chatStore.setText(JSON.stringify(payload, null, 2));
    }

    function saveHistory(immediate = false) {
        var msgs = [];
        for (var i = 0; i < chatHistory.count; i++) {
            var msg = chatHistory.get(i);
            msgs.push({
                "isUser": msg.isUser === true,
                "text": msg.text || "",
                "isFinished": msg.isFinished !== false,
                "thoughtText": (msg.thoughtText || "").substring(0, 12000),
                "toolCallsJson": msg.toolCallsJson || "[]"
            });
        }

        if (msgs.length === 0) return;

        var now = Date.now();
        if (!currentChatId) {
            currentChatId = "chat_" + now;
        }

        var found = false;
        for (var j = 0; j < allChatSessions.length; j++) {
            if (allChatSessions[j].id === currentChatId) {
                var sess = allChatSessions[j];
                sess.messages = msgs;
                sess.updatedAt = now;
                sess.provider = activeProvider;
                sess.model = currentModel;
                if (!sess.createdAt) sess.createdAt = now;

                allChatSessions.splice(j, 1);
                allChatSessions.unshift(sess);

                if (!root.isStreaming && !root.isTyping && msgs.length > 1 && !sess.titleGenerating && (sess.title === "Legacy Chat" || sess.title === "New Chat" || sess.title.indexOf("New Chat") === 0 || !sess.title)) {
                    var firstUser = null;
                    for (var k = 0; k < msgs.length; k++) {
                        if (msgs[k].isUser) { firstUser = msgs[k]; break; }
                    }
                    if (firstUser) {
                        sess.titleGenerating = true;
                        generateChatTitleAsync(currentChatId, firstUser.text);
                    }
                }
                found = true;
                break;
            }
        }

        if (!found) {
            var firstUserMsg = null;
            for (var m = 0; m < msgs.length; m++) {
                if (msgs[m].isUser) { firstUserMsg = msgs[m]; break; }
            }

            var newSess = {
                "id": currentChatId,
                "title": "New Chat",
                "messages": msgs,
                "createdAt": now,
                "updatedAt": now,
                "provider": activeProvider,
                "model": currentModel,
                "titleGenerating": false
            };

            if (firstUserMsg && !root.isStreaming && !root.isTyping) {
                newSess.titleGenerating = true;
                generateChatTitleAsync(currentChatId, firstUserMsg.text);
            }

            allChatSessions.unshift(newSess);
        }

        while (allChatSessions.length > 100) {
            if (allChatSessions[allChatSessions.length - 1].id === currentChatId) break;
            allChatSessions.pop();
        }

        syncHistoryModel();
        if (immediate) {
            flushHistory();
        } else {
            historySaveTimer.restart();
        }
    }

    function deleteChat(id) {
        var idx = -1;
        for (var i = 0; i < allChatSessions.length; i++) {
            if (allChatSessions[i].id === id) {
                idx = i;
                break;
            }
        }
        if (idx === -1) return;

        allChatSessions.splice(idx, 1);
        syncHistoryModel();
        flushHistory();

        if (currentChatId === id) {
            chatHistory.clear();
            if (allChatSessions.length > 0) {
                loadChat(allChatSessions[0].id);
            } else {
                createNewChat();
            }
        }
    }

    function clearAllHistory() {
        allChatSessions = [];
        syncHistoryModel();
        flushHistory();
        createNewChat();
    }

    function generateChatTitleAsync(chatId, firstMessage) {
        if (!firstMessage) return;
        var p = AiProviders.activeProvider;
        if (!p || !p.baseUrl) return;

        var xhr = new XMLHttpRequest();
        var url = p.baseUrl.replace(/\/+$/, "") + "/chat/completions";
        xhr.open("POST", url, true);
        xhr.setRequestHeader("Content-Type", "application/json");

        if (p.apiKey) {
            xhr.setRequestHeader("Authorization", "Bearer " + p.apiKey);
            xhr.setRequestHeader("HTTP-Referer", "https://github.com/dim-ghub/midnight-shell");
            xhr.setRequestHeader("X-Title", "midnight-shell");
        }

        xhr.onreadystatechange = () => {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var parsed = JSON.parse(xhr.responseText);
                        var content = "";
                        if (parsed.choices && parsed.choices.length > 0 && parsed.choices[0].message) {
                            content = parsed.choices[0].message.content || "";
                        }
                        var title = content.trim().replace(/^"|"$/g, '').replace(/\n/g, ' ');
                        if (title.length > 40) title = title.substring(0, 40) + "...";
                        if (title.length > 0) {
                            updateChatTitle(chatId, title);
                            return;
                        }
                    } catch (e) {}
                }
                for (var i = 0; i < root.allChatSessions.length; i++) {
                    if (root.allChatSessions[i].id === chatId) {
                        root.allChatSessions[i].titleGenerating = false;
                        break;
                    }
                }
            }
        };

        var safeMsg = firstMessage.substring(0, 200);
        var body = {
            model: AiProviders.activeModel || "openrouter/auto",
            messages: [
                {
                    role: "system",
                    content: "You are a title generator. Output ONLY a 2-4 word title representing the user's message. NO quotes, NO explanation."
                },
                {
                    role: "user",
                    content: "Message: " + safeMsg + "\nTitle:"
                }
            ],
            stream: false
        };
        xhr.send(JSON.stringify(body));
    }

    function updateChatTitle(chatId, title) {
        if (!title || !chatId) return;
        for (var i = 0; i < allChatSessions.length; i++) {
            if (allChatSessions[i].id === chatId) {
                allChatSessions[i].title = title;
                allChatSessions[i].titleGenerating = false;
                break;
            }
        }
        syncHistoryModel();
        flushHistory();
    }

    function addAiMessage(message) {
        chatHistory.append({
            "isUser": false,
            "text": message || "",
            "isFinished": true,
            "thoughtText": "",
            "toolCallsJson": "[]"
        });
        scrollToBottomRequested();
        saveHistory(true);
    }

    // --- Streaming & Tool Loop Execution ---
    function sendPrompt(promptText, isSystemToolResult = false, toolName = "") {
        if (!promptText.trim() && !attachedImageBase64) return;
        retryTimer.stop();
        _retryCallback = null;
        _retryCount = 0;

        var userAttachedImage = "";
        if (!isSystemToolResult) {
            userAttachedImage = attachedImageBase64;
            currentTurnAttachedImage = userAttachedImage;
            attachedImageBase64 = "";
            attachedImagePreviewPath = "";

            pendingToolCalls = null;
            pendingAssistantContent = "";
            activeToolCalls = [];
            currentTurnToolMessages = [];
            agentRounds = 0;

            for (var i = chatHistory.count - 1; i >= 0; i--) {
                var m = chatHistory.get(i);
                if (!m.isUser && !m.isFinished && m.text === "" && (!m.toolCallsJson || m.toolCallsJson === "[]")) {
                    chatHistory.remove(i);
                }
            }

            chatHistory.append({
                "isUser": true,
                "text": promptText || (userAttachedImage ? "[Screenshot Attached]" : ""),
                "isFinished": true,
                "thoughtText": "",
                "toolCallsJson": "[]"
            });

            chatHistory.append({
                "isUser": false,
                "text": "",
                "isFinished": false,
                "thoughtText": "",
                "toolCallsJson": "[]"
            });

            scrollToBottomRequested();
            saveHistory(true);
        } else {
            if (chatHistory.count > 0) {
                chatHistory.setProperty(chatHistory.count - 1, "isFinished", false);
            }
        }

        isTyping = true;
        isThinking = true;
        inAgentLoop = true;
        currentThoughtText = "";
        isThoughtExpanded = false;

        if (isSystemToolResult) {
            if (toolName === "web_search" || toolName === "read_webpage") {
                currentActionText = "Reading results...";
            } else if (toolName === "get_weather") {
                currentActionText = "Analyzing weather...";
            } else if (toolName === "take_screenshot") {
                currentActionText = "Inspecting screenshot...";
            } else {
                currentActionText = "Thinking...";
            }
        } else {
            currentActionText = "Thinking...";
        }

        scrollToBottomRequested();

        var messages = [];
        var enableTools = GlobalConfig.ai.enableCelestialMode;
        var sysPrompt = "You are Lilith, a helpful, sharp, and expressive AI assistant integrated into the Caelestia desktop shell. You can use tools to assist the user.";
        if (enableTools) {
            sysPrompt += "\nCRITICAL RULES:\n1. You CAN browse the web using the web_search tool.\n2. DO NOT apologize for errors, simply explain what happened.\n3. When using tools, you don't need to explain that you are using a tool, just do it and respond to the user smoothly.\n4. If a tool call fails or returns an error, do NOT retry it and do NOT try workarounds with other tools. Briefly tell the user what failed and answer from your own knowledge if you can.\n5. After tools give you their results, answer the user directly; only call more tools when the request truly needs them.\n6. You CAN schedule timed reminders with set_reminder or send immediate desktop popups with notify. When the user asks to be reminded or set an alarm/reminder, call set_reminder. When the user asks to send an alert or notification, call notify.\n7. You HAVE Spotify tools: spotify_search (search tracks, albums, artists, playlists), spotify_play (play tracks/albums/playlists via query or URI), and spotify_status (check current player state). Use them whenever the user asks about music, songs, artists, or Spotify playback.";
        }

        messages.push({
            "role": "system",
            "content": sysPrompt
        });

        var historyLimit = (chatHistory.count > 0 && !chatHistory.get(chatHistory.count - 1).isUser)
            ? chatHistory.count - 1
            : chatHistory.count;

        for (var mIdx = 0; mIdx < historyLimit; mIdx++) {
            var msg = chatHistory.get(mIdx);
            if (!msg.isUser && (!msg.text || msg.text.length === 0))
                continue;
            if (mIdx === historyLimit - 1 && msg.isUser && currentTurnAttachedImage && isVisionCapableModel()) {
                messages.push({
                    "role": "user",
                    "content": [
                        { "type": "text", "text": msg.text || "Analyze this screenshot." },
                        { "type": "image_url", "image_url": { "url": "data:image/jpeg;base64," + currentTurnAttachedImage } }
                    ]
                });
            } else {
                messages.push({
                    "role": msg.isUser ? "user" : "assistant",
                    "content": msg.text || ""
                });
            }
        }

        if (isSystemToolResult) {
            if (pendingToolCalls && pendingToolCalls.length > 0) {
                var tcArr = [];
                for (var pIdx = 0; pIdx < pendingToolCalls.length; pIdx++) {
                    tcArr.push({
                        "id": pendingToolCalls[pIdx].id,
                        "type": "function",
                        "function": {
                            "name": pendingToolCalls[pIdx].name,
                            "arguments": JSON.stringify(pendingToolCalls[pIdx].args || {})
                        }
                    });
                }
                currentTurnToolMessages.push({
                    "role": "assistant",
                    "content": pendingAssistantContent || null,
                    "tool_calls": tcArr
                });

                for (var q = 0; q < pendingToolCalls.length; q++) {
                    var pcName = pendingToolCalls[q].name;
                    currentTurnToolMessages.push({
                        "role": "tool",
                        "tool_call_id": pendingToolCalls[q].id,
                        "content": toolResultMap[pcName] || "(no output)"
                    });
                }

                if (lastCapturedImageBase64) {
                    currentTurnToolMessages.push({
                        "role": "user",
                        "content": [
                            { "type": "text", "text": "Screenshot captured from active display:" },
                            { "type": "image_url", "image_url": { "url": "data:image/jpeg;base64," + lastCapturedImageBase64 } }
                        ]
                    });
                    lastCapturedImageBase64 = "";
                }
            } else if (promptText) {
                var toolMsg = {
                    "role": "user",
                    "content": promptText
                };
                if (lastCapturedImageBase64) {
                    toolMsg.content = [
                        { "type": "text", "text": promptText },
                        { "type": "image_url", "image_url": { "url": "data:image/jpeg;base64," + lastCapturedImageBase64 } }
                    ];
                    lastCapturedImageBase64 = "";
                }
                currentTurnToolMessages.push(toolMsg);
            }
            pendingToolCalls = null;
            pendingAssistantContent = "";

            for (var tIdx = 0; tIdx < currentTurnToolMessages.length; tIdx++) {
                messages.push(currentTurnToolMessages[tIdx]);
            }
        }

        var requestBody = {
            "model": currentModel,
            "messages": messages,
            "stream": true
        };

        if (enableTools) {
            var toolsList = [];

            var enableWeb = (typeof AiTools !== "undefined") ? AiTools.enableWebSearch : true;
            var enableVis = (typeof AiTools !== "undefined") ? AiTools.enableVision : true;
            var enableClip = (typeof AiTools !== "undefined") ? AiTools.enableClipboard : true;
            var enableSys = (typeof AiTools !== "undefined") ? AiTools.enableSystemControl : true;
            var enableMem = (typeof AiTools !== "undefined") ? AiTools.enableMemory : true;
            var enableRem = (typeof AiTools !== "undefined") ? AiTools.enableReminders : true;
            var enableSp = (typeof AiTools !== "undefined") ? AiTools.enableSpotify : true;

            if (enableWeb) {
                toolsList.push({
                    "type": "function",
                    "function": {
                        "name": "web_search",
                        "description": "Searches the web via Tavily Search API. Returns the top 5 results with titles, URLs, and snippets.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "query": { "type": "string", "description": "The search query" }
                            },
                            "required": ["query"]
                        }
                    }
                });
                toolsList.push({
                    "type": "function",
                    "function": {
                        "name": "read_webpage",
                        "description": "Navigates to a specific URL and returns the main text content of the page.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "url": { "type": "string", "description": "The absolute URL to read" }
                            },
                            "required": ["url"]
                        }
                    }
                });
            }

            if (enableVis && isVisionCapableModel()) {
                toolsList.push({
                    "type": "function",
                    "function": {
                        "name": "take_screenshot",
                        "description": "Takes a screenshot of the user's active/focused screen and provides it for visual analysis.",
                        "parameters": { "type": "object", "properties": {} }
                    }
                });
            }

            if (enableClip) {
                toolsList.push({
                    "type": "function",
                    "function": {
                        "name": "get_clipboard",
                        "description": "Reads the current text from the user's system clipboard.",
                        "parameters": { "type": "object", "properties": {} }
                    }
                });
                toolsList.push({
                    "type": "function",
                    "function": {
                        "name": "set_clipboard",
                        "description": "Copies text to the user's system clipboard.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "text": { "type": "string", "description": "Text to copy to the clipboard" }
                            },
                            "required": ["text"]
                        }
                    }
                });
            }

            if (enableSys) {
                toolsList.push({
                    "type": "function",
                    "function": {
                        "name": "media_control",
                        "description": "Controls desktop media playback via playerctl. Valid actions: play, pause, play-pause, next, prev, status.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "action": { "type": "string", "description": "Action to perform: play, pause, play-pause, next, prev, or status" }
                            },
                            "required": ["action"]
                        }
                    }
                });
                toolsList.push({
                    "type": "function",
                    "function": {
                        "name": "caelestia_command",
                        "description": "Execute a caelestia CLI command to manage the system. Valid subcommands: shell, toggle, scheme, search, screenshot, record, clipboard, emoji, wallpaper, resizer, install, update.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "subcommand": { "type": "string", "description": "The subcommand to run (e.g., scheme, wallpaper, toggle, record)" },
                                "args": { "type": "string", "description": "Additional arguments to pass to the subcommand" }
                            },
                            "required": ["subcommand"]
                        }
                    }
                });
                toolsList.push({
                    "type": "function",
                    "function": {
                        "name": "get_weather",
                        "description": "Gets current weather for a specific city or location.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "location": { "type": "string", "description": "City or location name" }
                            },
                            "required": ["location"]
                        }
                    }
                });
                toolsList.push({
                    "type": "function",
                    "function": {
                        "name": "get_system_info",
                        "description": "Returns current CPU utilization, RAM memory usage, and root disk capacity.",
                        "parameters": { "type": "object", "properties": {} }
                    }
                });
            }

            if (enableMem) {
                toolsList.push({
                    "type": "function",
                    "function": {
                        "name": "save_memory",
                        "description": "Saves an explicit fact, preference, or note into long-term persistent memory.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "content": { "type": "string", "description": "The fact or note to remember" },
                                "category": { "type": "string", "description": "Category for the memory (e.g. preference, work, personal)" }
                            },
                            "required": ["content"]
                        }
                    }
                });
                toolsList.push({
                    "type": "function",
                    "function": {
                        "name": "list_memories",
                        "description": "Retrieves saved facts and notes from long-term memory.",
                        "parameters": { "type": "object", "properties": {} }
                    }
                });
            }

            if (enableRem) {
                toolsList.push({
                    "type": "function",
                    "function": {
                        "name": "notify",
                        "description": "Sends an instant desktop notification popup to the user.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "title": { "type": "string", "description": "Title of the notification" },
                                "message": { "type": "string", "description": "Message body to display" }
                            },
                            "required": ["message"]
                        }
                    }
                });
                toolsList.push({
                    "type": "function",
                    "function": {
                        "name": "set_reminder",
                        "description": "Sets a scheduled reminder that triggers a desktop notification after a given delay or at a specific time.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "message": { "type": "string", "description": "Reminder text" },
                                "delay_seconds": { "type": "number", "description": "Delay in seconds from now (e.g. 60 for 1 min, 3600 for 1 hr)" },
                                "at_time": { "type": "string", "description": "Target time formatted like '15:30' or '2026-10-11T16:00:00'" }
                            },
                            "required": ["message"]
                        }
                    }
                });
                toolsList.push({
                    "type": "function",
                    "function": {
                        "name": "list_reminders",
                        "description": "Lists all active upcoming reminders.",
                        "parameters": { "type": "object", "properties": {} }
                    }
                });
                toolsList.push({
                    "type": "function",
                    "function": {
                        "name": "cancel_reminder",
                        "description": "Cancels an active reminder by ID.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "id": { "type": "string", "description": "ID of the reminder to cancel" }
                            },
                            "required": ["id"]
                        }
                    }
                });
            }

            if (enableSp) {
                toolsList.push({
                    "type": "function",
                    "function": {
                        "name": "spotify_search",
                        "description": "Searches Spotify for tracks, albums, artists, or playlists using the Spotify Web API. Returns titles, artists, album names, duration, and Spotify URIs.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "query": { "type": "string", "description": "Search term (e.g. song name, artist, album)" },
                                "type": { "type": "string", "enum": ["track", "album", "artist", "playlist"], "description": "Type of item to search for (default: track)" },
                                "limit": { "type": "integer", "description": "Number of results to return (1-20, default: 5)" }
                            },
                            "required": ["query"]
                        }
                    }
                });
                toolsList.push({
                    "type": "function",
                    "function": {
                        "name": "spotify_play",
                        "description": "Plays a track, album, or playlist in the local Spotify client. Takes an exact Spotify URI or a search query to play automatically.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "query": { "type": "string", "description": "Song, album, or artist to search and play automatically" },
                                "uri": { "type": "string", "description": "Exact Spotify URI to open and play (e.g. spotify:track:...)" }
                            }
                        }
                    }
                });
                toolsList.push({
                    "type": "function",
                    "function": {
                        "name": "spotify_status",
                        "description": "Gets the currently playing track, artist, album, and playback status from the local Spotify player.",
                        "parameters": { "type": "object", "properties": {} }
                    }
                });
            }

            if (toolsList.length > 0) {
                requestBody["tools"] = toolsList;
            }
        }

        var p = AiProviders.activeProvider;
        var requestUrl = (p && p.baseUrl ? p.baseUrl.replace(/\/+$/, "") : "https://openrouter.ai/api/v1") + "/chat/completions";
        var processedTextLength = 0;
        var accumulatedThoughtText = "";
        var accumulatedContentText = "";
        var finalToolCalls = null;
        var openAiToolAccum = {};

        function processStreamLine(rawLine) {
            var line = rawLine.trim();
            if (!line) return true;

            if (line.indexOf("data:") === 0) {
                line = line.substring(5).trim();
                if (!line || line === "[DONE]") return true;
            } else if (line.indexOf("event:") === 0 || line.indexOf("id:") === 0 || line.indexOf(":") === 0) {
                return true;
            }

            var parsed;
            try {
                parsed = JSON.parse(line);
            } catch (e) {
                return false;
            }

            if (parsed.error) {
                var streamErrMsg = parsed.error.message || (typeof parsed.error === "string" ? parsed.error : JSON.stringify(parsed.error));
                accumulatedContentText += (accumulatedContentText ? "\n\n" : "") + "*[" + streamErrMsg + "]*";
                return true;
            }

            if (parsed.message) {
                var chunkReasoning = parsed.message.thinking || parsed.message.reasoning || parsed.message.reasoning_content || "";
                if (chunkReasoning) accumulatedThoughtText += chunkReasoning;

                var chunkContent = parsed.message.content || "";
                if (chunkContent) accumulatedContentText += chunkContent;

                if (parsed.message.tool_calls) {
                    finalToolCalls = parsed.message.tool_calls;
                }
            } else if (parsed.choices && parsed.choices.length > 0) {
                var choice = parsed.choices[0];
                var delta = choice.delta || choice.message || {};

                var chunkReasoning2 = delta.reasoning || delta.reasoning_content || "";
                if (chunkReasoning2) accumulatedThoughtText += chunkReasoning2;

                var chunkContent2 = delta.content || "";
                if (chunkContent2) accumulatedContentText += chunkContent2;

                if (delta.tool_calls) {
                    for (var t = 0; t < delta.tool_calls.length; t++) {
                        var tc = delta.tool_calls[t];
                        var tcIdx = (tc.index !== undefined) ? tc.index : 0;
                        if (!openAiToolAccum[tcIdx]) {
                            openAiToolAccum[tcIdx] = { "id": tc.id || "", "name": "", "args": "" };
                        } else if (tc.id && !openAiToolAccum[tcIdx].id) {
                            openAiToolAccum[tcIdx].id = tc.id;
                        }
                        if (tc.function) {
                            if (tc.function.name) openAiToolAccum[tcIdx].name += tc.function.name;
                            if (tc.function.arguments) openAiToolAccum[tcIdx].args += tc.function.arguments;
                        }
                    }
                }
            }
            return true;
        }

        function finalizeToolCalls() {
            if (finalToolCalls === null && Object.keys(openAiToolAccum).length > 0) {
                var calls = [];
                var keys = Object.keys(openAiToolAccum).sort();
                for (var k = 0; k < keys.length; k++) {
                    var entry = openAiToolAccum[keys[k]];
                    if (!entry.name || !entry.name.trim())
                        continue;
                    var argsObj = {};
                    if (entry.args) {
                        try {
                            argsObj = JSON.parse(entry.args);
                        } catch (e) {
                            argsObj = {};
                        }
                    }
                    calls.push({
                        "id": entry.id || ("call_" + keys[k]),
                        "type": "function",
                        "function": {
                            "name": entry.name.trim(),
                            "arguments": argsObj
                        }
                    });
                }
                if (calls.length > 0)
                    finalToolCalls = calls;
            }
        }

        function updateChatDisplay() {
            var displayContent = accumulatedContentText;
            var displayThought = accumulatedThoughtText;

            if (accumulatedThoughtText === "") {
                var openThinkIdx = displayContent.indexOf("<think>");
                var closeThinkIdx = displayContent.indexOf("</think>");

                if (openThinkIdx !== -1) {
                    if (closeThinkIdx !== -1) {
                        displayThought = displayContent.substring(openThinkIdx + 7, closeThinkIdx).trim();
                        displayContent = displayContent.substring(0, openThinkIdx) + displayContent.substring(closeThinkIdx + 8);
                    } else {
                        displayThought = displayContent.substring(openThinkIdx + 7).trim();
                        displayContent = displayContent.substring(0, openThinkIdx);
                    }
                }
            }

            root.currentThoughtText = displayThought.trim();

            if (displayContent.trim() !== "") {
                if (isThinking) isThinking = false;
            }

            if (chatHistory.count > 0) {
                chatHistory.setProperty(chatHistory.count - 1, "thoughtText", displayThought.trim());
                chatHistory.setProperty(chatHistory.count - 1, "text", displayContent.trim());
            }
            scrollToBottomRequested();
        }

        function fireRequest(attempt) {
            processedTextLength = 0;
            accumulatedThoughtText = "";
            accumulatedContentText = "";
            finalToolCalls = null;
            openAiToolAccum = {};

            var xhr = new XMLHttpRequest();
            root.currentRequest = xhr;

            xhr.onreadystatechange = () => {
                if (xhr.readyState === 3 || xhr.readyState === XMLHttpRequest.DONE) {
                    if (xhr.status === 200) {
                        var currentText = xhr.responseText;
                        var unparsed = currentText.substring(processedTextLength);
                        var lines = unparsed.split('\n');

                        var linesToProcess = (xhr.readyState === XMLHttpRequest.DONE) ? lines.length : lines.length - 1;

                        for (var i = 0; i < linesToProcess; i++) {
                            var line = lines[i].trim();
                            if (line === "") {
                                processedTextLength += lines[i].length + 1;
                                continue;
                            }

                            if (!processStreamLine(lines[i])) {
                                break;
                            }
                            processedTextLength += lines[i].length + 1;
                            updateChatDisplay();
                        }
                    }

                    if (xhr.readyState === XMLHttpRequest.DONE) {
                        if (xhr.status === 200) {
                            finalizeToolCalls();
                            if (chatHistory.count > 0) {
                                chatHistory.setProperty(chatHistory.count - 1, "isFinished", true);
                            }

                            if (finalToolCalls && finalToolCalls.length > 0) {
                                var enableTools = GlobalConfig.ai.enableCelestialMode;
                                if (enableTools) {
                                    currentActionText = "Using tools...";
                                    toolResultMap = {};
                                    toolResultOrder = [];
                                    runningToolsCount = 0;

                                    var calls = [];
                                    var uiToolList = activeToolCalls.slice();
                                    for (var c = 0; c < finalToolCalls.length; c++) {
                                        var fc = finalToolCalls[c];
                                        var fcName = (fc.function && fc.function.name) ? fc.function.name.trim() : "";
                                        if (!fcName)
                                            continue;
                                        var fcArgs = fc.function ? fc.function.arguments : {};
                                        if (typeof fcArgs === "string") {
                                            try {
                                                fcArgs = JSON.parse(fcArgs || "{}");
                                            } catch (e) {
                                                fcArgs = {};
                                            }
                                        }
                                        calls.push({
                                            "id": fc.id || ("call_" + c),
                                            "name": fcName,
                                            "args": fcArgs || {}
                                        });
                                        uiToolList.push({
                                            "id": fc.id || ("call_" + c),
                                            "name": fcName,
                                            "args": JSON.stringify(fcArgs || {}),
                                            "status": "running",
                                            "result": ""
                                        });
                                    }
                                    activeToolCalls = uiToolList;
                                    if (chatHistory.count > 0) {
                                        chatHistory.setProperty(chatHistory.count - 1, "toolCallsJson", JSON.stringify(activeToolCalls));
                                    }
                                    saveHistory(true);

                                    pendingToolCalls = calls;
                                    pendingAssistantContent = accumulatedContentText;
                                    agentRounds++;

                                    if (agentRounds > maxAgentRounds * 2) {
                                        if (chatHistory.count > 0) {
                                            chatHistory.setProperty(chatHistory.count - 1, "text", "Stopped after " + agentRounds + " tool rounds without a final answer.");
                                            chatHistory.setProperty(chatHistory.count - 1, "isFinished", true);
                                        }
                                        isTyping = false;
                                        isThinking = false;
                                        inAgentLoop = false;
                                        agentRounds = 0;
                                        currentTurnToolMessages = [];
                                        currentTurnAttachedImage = "";
                                        isStreaming = false;
                                        saveHistory(true);
                                        return;
                                    }

                                    if (agentRounds > maxAgentRounds) {
                                        for (var f = 0; f < calls.length; f++)
                                            recordToolResult(calls[f].name, "Tool use limit reached. Do not call any more tools; answer the user directly now with the information you have.");
                                        checkToolsFinished();
                                        return;
                                    }

                                    for (var t = 0; t < calls.length; t++) {
                                        var tName = calls[t].name;
                                        var args = calls[t].args || {};

                                        runningToolsCount++;
                                        currentActionText = "Using " + tName.replace(/_/g, " ") + "...";

                                        var scriptPath = Quickshell.shellDir + "/assets/scripts/ai_tools.py";
                                        var safeArgs = JSON.stringify(args).replace(/'/g, "'\\''");
                                        var toolCmd = 'python3 "' + scriptPath + '" --tool ' + tName + " --args '" + safeArgs + "'";

                                        var tavilyKey = (typeof AiTools !== "undefined" ? AiTools.tavilyApiKey : "") || "";
                                        if (tavilyKey) toolCmd += " --tavily-key '" + tavilyKey + "'";
                                        var spId = (typeof AiTools !== "undefined" ? AiTools.spotifyClientId : "") || "";
                                        if (spId) toolCmd += " --spotify-id '" + spId + "'";
                                        var spSec = (typeof AiTools !== "undefined" ? AiTools.spotifyClientSecret : "") || "";
                                        if (spSec) toolCmd += " --spotify-secret '" + spSec + "'";

                                        runAgentCommand(toolCmd, "exec_" + tName);
                                    }

                                    if (runningToolsCount === 0) {
                                        if (toolResultOrder.length > 0) {
                                            checkToolsFinished();
                                        } else {
                                            currentActionText = "Thinking...";
                                            isTyping = false;
                                            isThinking = false;
                                            inAgentLoop = false;
                                            agentRounds = 0;
                                            currentTurnToolMessages = [];
                                            currentTurnAttachedImage = "";
                                            isStreaming = false;
                                            saveHistory(true);
                                        }
                                    }
                                } else {
                                    currentActionText = "Thinking...";
                                    isTyping = false;
                                    isThinking = false;
                                    inAgentLoop = false;
                                    agentRounds = 0;
                                    currentTurnToolMessages = [];
                                    currentTurnAttachedImage = "";
                                    isStreaming = false;
                                    saveHistory(true);
                                }
                            } else {
                                currentActionText = "Thinking...";
                                isTyping = false;
                                isThinking = false;
                                inAgentLoop = false;
                                agentRounds = 0;
                                currentTurnToolMessages = [];
                                currentTurnAttachedImage = "";
                                isStreaming = false;
                                saveHistory(true);
                            }
                        } else {
                            if (xhr.status === 429 && attempt < root._maxRetries) {
                                var nextAttempt = attempt + 1;
                                var delayMs = (nextAttempt === 1) ? 3000 : ((nextAttempt === 2) ? 6000 : 10000);
                                root.currentActionText = "Rate limited, retrying in " + (delayMs / 1000) + "s...";
                                root.isThinking = true;
                                root._retryCount = nextAttempt;
                                root._retryUrl = requestUrl;
                                root._retryPayload = requestBody;
                                root._retryCallback = () => fireRequest(nextAttempt);
                                retryTimer.interval = delayMs;
                                retryTimer.restart();
                                return;
                            }

                            var errMsg = (xhr.status === 0) ? "Generation cancelled" : root.providerLabel + " request failed (status " + xhr.status + ").";
                            if (xhr.status !== 0) {
                                try {
                                    var errParsed = JSON.parse(xhr.responseText);
                                    if (errParsed.error) {
                                        var errDetail = errParsed.error.message || (typeof errParsed.error === "string" ? errParsed.error : "");
                                        if (errDetail) errMsg += " " + errDetail;
                                    }
                                } catch (e) {}
                            }
                            if (chatHistory.count > 0) {
                                var currentTxt = chatHistory.get(chatHistory.count - 1).text;
                                if (currentTxt.trim() === "") {
                                    chatHistory.setProperty(chatHistory.count - 1, "text", errMsg);
                                } else {
                                    chatHistory.setProperty(chatHistory.count - 1, "text", currentTxt + "\n\n*[" + errMsg + "]*");
                                }
                                chatHistory.setProperty(chatHistory.count - 1, "isFinished", true);
                            }
                            isTyping = false;
                            isThinking = false;
                            inAgentLoop = false;
                            agentRounds = 0;
                            currentTurnToolMessages = [];
                            currentTurnAttachedImage = "";
                            isStreaming = false;
                            saveHistory(true);
                        }
                    }
                }
            };

            xhr.open("POST", requestUrl, true);
            xhr.setRequestHeader("Content-Type", "application/json");

            if (p && p.apiKey) {
                xhr.setRequestHeader("Authorization", "Bearer " + p.apiKey);
                xhr.setRequestHeader("HTTP-Referer", "https://github.com/dim-ghub/midnight-shell");
                xhr.setRequestHeader("X-Title", "midnight-shell");
            }

            isStreaming = true;
            xhr.send(JSON.stringify(requestBody));
        }

        fireRequest(0);
    }
}

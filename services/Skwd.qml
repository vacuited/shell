pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Caelestia
import Caelestia.Config
import qs.services
import qs.utils

Singleton {
    id: root

    readonly property string helperScript: Quickshell.shellPath("assets/scripts/skwd_helper.py")
    readonly property string wallpaperStateDir: `${Paths.state}/wallpaper`
    readonly property string statePath: `${root.wallpaperStateDir}/wallpaper-engine.json`
    readonly property string posterCacheDir: `${Paths.cache}/we-posters`

    // Persistent settings (backed by wallpaper-engine.json; watchChanges: false prevents write loops)
    property alias volume: weAdapter.volume
    property alias silent: weAdapter.silent
    property alias muteBehindWindows: weAdapter.muteBehindWindows
    property alias muteOnOtherAudio: weAdapter.muteOnOtherAudio
    property alias workshopDir: weAdapter.workshopDir
    property alias gpuMode: weAdapter.gpuMode
    property alias fps: weAdapter.fps
    property alias disableParticles: weAdapter.disableParticles
    property alias sceneQuality: weAdapter.sceneQuality
    property alias reduceEffects: weAdapter.reduceEffects
    property alias compositorBlur: weAdapter.compositorBlur
    property alias transitionEffect: weAdapter.transitionEffect
    property alias sceneProperties: weAdapter.sceneProperties

    property bool adapterReady: false

    // Runtime & capability state
    property bool probeCompleted: false
    property bool paperAvailable: false
    property bool helmAvailable: false
    property bool surfaceReady: false
    property bool engineFailed: false
    property string lastError: ""
    property int applyNonce: 0
    property bool usedTransitionFrom: false

    property var availableGpus: []
    property bool hasSafeDiscrete: false
    property bool hasOffloadDiscrete: false
    property bool hasSafeIntegrated: true
    readonly property bool hasAnyDiscrete: root.hasSafeDiscrete || root.hasOffloadDiscrete
    property string compositorGpuName: ""
    property string discreteGpuName: ""
    property string integratedGpuName: ""
    property var availableTransitions: [
        { "id": "fade", "label": "Fade", "duration_ms": 500 }
    ]
    property string resolvedWorkshopDir: ""
    property var weInstalledItems: []
    property var posterMap: ({})
    property int posterRevision: 0

    // Steam Workshop state
    property bool steamAvailable: false
    property bool steamConnected: false
    property string steamError: ""
    property var steamInstalledMap: ({})
    property var steamSubscribedIds: []
    property var workshopResults: []
    property bool workshopSearching: false
    property string workshopError: ""
    property var workshopDownloads: ({})

    // Active scene tracking
    readonly property string desiredWeDir: Wallpapers.committedWeDir
    readonly property string activeWeDir: desiredWeDir
    readonly property string activeWeId: extractWeId(activeWeDir)
    readonly property var activeSceneSchema: {
        const id = root.activeWeId;
        if (!id || !root.weInstalledItems)
            return [];
        for (let i = 0; i < root.weInstalledItems.length; i++) {
            const item = root.weInstalledItems[i];
            if (item && String(item.id) === id) {
                return Array.isArray(item.properties) ? item.properties : [];
            }
        }
        return [];
    }

    readonly property bool shouldBeRunning: adapterReady && probeCompleted && paperAvailable && desiredWeDir !== "" && GlobalConfig.background.wallpaperEnabled && !GameMode.enabled

    readonly property string effectiveGpu: {
        const mode = weAdapter.gpuMode || "auto";
        if (mode === "dgpu" && root.hasAnyDiscrete)
            return "discrete";
        if (mode === "ac_dgpu" && !UPower.onBattery && root.hasAnyDiscrete)
            return "discrete";
        if (mode === "igpu" && root.hasSafeIntegrated)
            return "integrated";
        return "auto";
    }

    readonly property bool usingDiscreteForScenes: root.effectiveGpu === "discrete" || (root.effectiveGpu === "auto" && root.hasSafeDiscrete)

    readonly property int effectiveFps: {
        const f = weAdapter.fps;
        if (f > 0)
            return Math.round(f);
        let maxHz = 0;
        const mons = Hypr.monitors?.values ?? [];
        for (let i = 0; i < mons.length; i++) {
            const hz = Number(mons[i]?.lastIpcObject?.refreshRate ?? 0);
            if (hz > maxHz)
                maxHz = hz;
        }
        const nativeHz = maxHz > 0 ? Math.round(maxHz) : 60;
        return UPower.onBattery ? Math.min(nativeHz, 60) : nativeHz;
    }

    readonly property int effectiveVideoFps: UPower.onBattery ? 60 : 0

    readonly property int effectiveMaxDim: {
        const nativeDim = root.activeDisplayMaxDim;
        const q = weAdapter.sceneQuality || "auto";
        let dim = nativeDim;
        if (q === "performance")
            dim = Math.round(nativeDim * 0.5);
        else if (q === "balanced")
            dim = Math.round(nativeDim * 0.67);
        else if (q === "high")
            dim = Math.round(nativeDim * 0.85);
        else if (q === "native")
            dim = nativeDim;
        else
            dim = root.usingDiscreteForScenes ? nativeDim : Math.min(1280, nativeDim);
        return Math.max(256, Math.min(16384, Math.round(dim)));
    }

    readonly property int effectiveMaxEffectChains: weAdapter.reduceEffects ? 4 : 0
    readonly property int effectiveMaxEffectPasses: weAdapter.reduceEffects ? 4 : 0

    readonly property int activeDisplayMaxDim: {
        let maxDim = 0;
        const mons = Hypr.monitors?.values ?? [];
        for (let i = 0; i < mons.length; i++) {
            const m = mons[i];
            const w = Number(m?.width) || 0;
            const h = Number(m?.height) || 0;
            if (w > maxDim)
                maxDim = w;
            if (h > maxDim)
                maxDim = h;
        }
        if (maxDim <= 0) {
            const scr = Screens.screens.length > 0 ? Screens.screens : Quickshell.screens;
            for (let i = 0; i < scr.length; i++) {
                const s = scr[i];
                const scale = Number(s?.devicePixelRatio) || 1;
                const w = Math.round((Number(s?.width) || 0) * scale);
                const h = Math.round((Number(s?.height) || 0) * scale);
                if (w > maxDim)
                    maxDim = w;
                if (h > maxDim)
                    maxDim = h;
            }
        }
        if (maxDim <= 0)
            return 1920;
        return Math.max(256, Math.min(16384, Math.round(maxDim)));
    }

    readonly property bool otherAudioPlaying: Boolean(Players.active?.isPlaying) || (Players.list ? Players.list.some(p => p && p.isPlaying) : false)
    readonly property bool effectiveMuted: weAdapter.silent || (weAdapter.muteBehindWindows && WallpaperPauser.paused) || ((weAdapter.muteOnOtherAudio || GlobalConfig.background.videoWallpaperMuteOnMedia) && otherAudioPlaying)

    // Internal coordination state
    property string _prevDesiredWeDir: ""
    property string _pendingStaticFrom: ""
    property string _appliedWeDir: ""
    property bool _pendingReapply: false
    property bool _pendingForceRestart: false
    property bool _pendingStop: false
    property bool _remotePaused: false
    property int _pauseRetryCount: 0
    property bool _lastSentMuted: false
    property real _lastSentVolume: -1.0
    property int _audioRetryCount: 0
    property var _posterQueue: []
    property var _subQueue: []
    property var _dlPending: ({})
    property var _pendingSearch: null

    function extractWeId(weDir: string): string {
        if (!weDir)
            return "";
        let clean = String(weDir).trim().replace(/\/+$/, "");
        if (!clean)
            return "";
        const idx = clean.lastIndexOf("/");
        return idx >= 0 ? clean.slice(idx + 1) : clean;
    }

    function persist(): void {
        if (root.adapterReady) {
            weStore.writeAdapter();
        }
    }

    function isStaticImagePath(path: string): bool {
        if (!path)
            return false;
        const lower = String(path).trim().toLowerCase();
        if (!lower || lower.endsWith(".gif") || Wallpapers.isVideo(lower))
            return false;
        return CUtils.fileExists(path);
    }

    function getCachedPosterPath(weDir: string): string {
        void root.posterRevision;
        const id = extractWeId(weDir);
        if (!id)
            return "";
        const mapped = root.posterMap[id];
        if (mapped && CUtils.fileExists(mapped))
            return mapped;
        const cached = `${root.posterCacheDir}/${id}.png`;
        if (CUtils.fileExists(cached))
            return cached;
        return "";
    }

    function getPosterPath(weDir: string): string {
        void root.posterRevision;
        const id = extractWeId(weDir);
        if (!id)
            return "";

        const cached = getCachedPosterPath(weDir);
        if (cached)
            return cached;

        const cleanDir = String(weDir || "").trim().replace(/\/+$/, "");
        if (root.weInstalledItems) {
            for (let i = 0; i < root.weInstalledItems.length; i++) {
                const item = root.weInstalledItems[i];
                if (item && (String(item.id) === id || item.path === cleanDir)) {
                    if (item.poster && !String(item.poster).toLowerCase().endsWith(".gif") && CUtils.fileExists(item.poster))
                        return item.poster;
                    if (item.preview && !String(item.preview).toLowerCase().endsWith(".gif") && CUtils.fileExists(item.preview))
                        return item.preview;
                }
            }
        }

        if (cleanDir && CUtils.fileExists(cleanDir + "/project.json")) {
            try {
                const json = JSON.parse(CUtils.readFile(cleanDir + "/project.json"));
                if (json.preview && typeof json.preview === "string" && !json.preview.includes("..") && !json.preview.startsWith("/")) {
                    const candidate = cleanDir + "/" + json.preview;
                    if (!candidate.toLowerCase().endsWith(".gif") && CUtils.fileExists(candidate))
                        return candidate;
                }
            } catch (e) {}

            const staticCandidates = ["preview.png", "preview.jpg", "preview.jpeg", "preview.webp"];
            for (let i = 0; i < staticCandidates.length; i++) {
                const candidate = cleanDir + "/" + staticCandidates[i];
                if (CUtils.fileExists(candidate))
                    return candidate;
            }
        }

        return "";
    }

    function buildPropertiesJson(weId: string): string {
        if (!weId)
            return "";
        const overrides = (weAdapter.sceneProperties && weAdapter.sceneProperties[weId]) ? weAdapter.sceneProperties[weId] : null;
        if (!overrides || typeof overrides !== "object")
            return "";
        let filtered = {};
        for (const k in overrides) {
            if (k && k.length <= 64 && overrides[k] !== undefined && overrides[k] !== null)
                filtered[k] = overrides[k];
        }
        return Object.keys(filtered).length > 0 ? JSON.stringify(filtered) : "";
    }

    // Setters
    function setVolume(v: real): void {
        const clamped = Math.max(0.0, Math.min(1.0, Number(v) || 0));
        if (Math.abs(weAdapter.volume - clamped) < 0.0001)
            return;
        weAdapter.volume = clamped;
        persist();
    }

    function setSilent(b: bool): void {
        const val = Boolean(b);
        if (weAdapter.silent === val)
            return;
        weAdapter.silent = val;
        persist();
    }

    function setMuteBehindWindows(b: bool): void {
        const val = Boolean(b);
        if (weAdapter.muteBehindWindows === val)
            return;
        weAdapter.muteBehindWindows = val;
        persist();
    }

    function setMuteOnOtherAudio(b: bool): void {
        const val = Boolean(b);
        if (weAdapter.muteOnOtherAudio === val)
            return;
        weAdapter.muteOnOtherAudio = val;
        persist();
    }

    function setWorkshopDir(v: string): void {
        const cleaned = String(v || "").trim();
        if (weAdapter.workshopDir === cleaned)
            return;
        weAdapter.workshopDir = cleaned;
        persist();
        runProbe();
        refreshWeInstalled();
    }

    function sanitizeGpuMode(saveIfChanged: bool): void {
        const cur = String(weAdapter.gpuMode || "auto");
        let next = cur;
        if (cur !== "auto" && cur !== "ac_dgpu" && cur !== "igpu" && cur !== "dgpu") {
            next = "auto";
        } else if (root.probeCompleted) {
            if ((cur === "ac_dgpu" || cur === "dgpu") && !root.hasAnyDiscrete)
                next = "auto";
            else if (cur === "igpu" && !root.hasSafeIntegrated)
                next = "auto";
        }
        if (next !== cur) {
            weAdapter.gpuMode = next;
            if (saveIfChanged)
                persist();
        }
    }

    function setGpuMode(v: string): void {
        let val = v || "auto";
        if (val !== "auto" && val !== "ac_dgpu" && val !== "igpu" && val !== "dgpu")
            val = "auto";
        if (root.probeCompleted) {
            if ((val === "ac_dgpu" || val === "dgpu") && !root.hasAnyDiscrete)
                val = "auto";
            else if (val === "igpu" && !root.hasSafeIntegrated)
                val = "auto";
        }
        if (weAdapter.gpuMode === val)
            return;
        weAdapter.gpuMode = val;
        persist();
    }

    function setFps(v: int): void {
        const val = Math.max(0, Math.round(Number(v) || 0));
        if (weAdapter.fps === val)
            return;
        weAdapter.fps = val;
        persist();
    }

    function setDisableParticles(b: bool): void {
        const val = Boolean(b);
        if (weAdapter.disableParticles === val)
            return;
        weAdapter.disableParticles = val;
        persist();
        if (root.shouldBeRunning && !root.engineFailed)
            requestApply(false);
    }

    function setSceneQuality(v: string): void {
        const val = (v === "performance" || v === "balanced" || v === "high" || v === "native" || v === "auto") ? v : "auto";
        if (weAdapter.sceneQuality === val)
            return;
        weAdapter.sceneQuality = val;
        persist();
    }

    function setReduceEffects(b: bool): void {
        const val = Boolean(b);
        if (weAdapter.reduceEffects === val)
            return;
        weAdapter.reduceEffects = val;
        persist();
    }

    function setCompositorBlur(b: bool): void {
        const val = Boolean(b);
        if (weAdapter.compositorBlur === val)
            return;
        weAdapter.compositorBlur = val;
        persist();
        syncCompositorBlur();
    }

    function syncCompositorBlur(): void {
        if (!root.probeCompleted || !root.paperAvailable)
            return;
        if (blurProc.running) {
            blurProc.pendingResync = true;
            return;
        }
        blurProc.pendingResync = false;
        blurProc.command = ["python3", root.helperScript, "set-blur", "--enabled", weAdapter.compositorBlur ? "1" : "0"];
        blurProc.running = true;
    }

    function setTransitionEffect(v: string): void {
        const val = v || "fade";
        if (weAdapter.transitionEffect === val)
            return;
        weAdapter.transitionEffect = val;
        persist();
    }

    function setSceneProperty(weId: string, key: string, val: var): void {
        if (!weId || !key)
            return;
        const allProps = Object.assign({}, weAdapter.sceneProperties || {});
        const sceneMap = Object.assign({}, allProps[weId] || {});
        sceneMap[key] = val;
        allProps[weId] = sceneMap;
        weAdapter.sceneProperties = allProps;
        persist();
        if (root.shouldBeRunning && !root.engineFailed && weId === root.activeWeId)
            propReapplyTimer.restart();
    }

    function resetSceneProperties(weId: string): void {
        if (!weId)
            return;
        const allProps = Object.assign({}, weAdapter.sceneProperties || {});
        if (allProps[weId] !== undefined) {
            delete allProps[weId];
            weAdapter.sceneProperties = allProps;
            persist();
        }
        if (root.shouldBeRunning && !root.engineFailed && weId === root.activeWeId)
            propReapplyTimer.restart();
    }

    function retryCurrent(): void {
        root.engineFailed = false;
        root.lastError = "";
        if (root.probeCompleted && !root.paperAvailable && root.desiredWeDir !== "") {
            root.engineFailed = true;
            root.lastError = "skwd-paper-v2 is not available";
            return;
        }
        if (root.shouldBeRunning)
            requestApply(true);
    }

    // Lifecycle & Process Orchestration
    function evaluateLifecycle(): void {
        if (!root.adapterReady || !root.probeCompleted)
            return;

        if (!root.paperAvailable && root.desiredWeDir !== "" && GlobalConfig.background.wallpaperEnabled && !GameMode.enabled) {
            if (!root.engineFailed) {
                root.surfaceReady = false;
                root.usedTransitionFrom = false;
                root.engineFailed = true;
                root.lastError = "skwd-paper-v2 is not installed. Run ./install.sh --with-wallpaper-engine (Arch AUR: skwd-paper-bin) or install from github.com/liixini/skwd-wall";
                Toaster.toast("Wallpaper Engine", root.lastError, "error", Toast.Error);
            }
            return;
        }

        if (root.shouldBeRunning) {
            if (!root.engineFailed) {
                if (root._appliedWeDir !== root.desiredWeDir || !root.surfaceReady)
                    requestApply(false);
            }
        } else {
            requestStop();
        }
    }

    function requestApply(forceRestart: bool): void {
        if (!root.shouldBeRunning || root.engineFailed)
            return;

        root.applyNonce++;
        root._pendingStop = false;

        if (stopProc.running || applyProc.running) {
            root._pendingReapply = true;
            root._pendingForceRestart = root._pendingForceRestart || forceRestart;
            return;
        }

        const targetPath = root.desiredWeDir;
        if (!targetPath)
            return;

        const targetId = extractWeId(targetPath);
        const effGpu = root.effectiveGpu;
        const effFps = root.effectiveFps;
        const propsJson = buildPropertiesJson(targetId);

        let cmd = [
            "python3", root.helperScript, "apply",
            "--output", "ALL",
            "--path", targetPath,
            "--gpu", effGpu,
            "--fps", String(effFps),
            "--video-fps", String(root.effectiveVideoFps),
            "--disable-particles", weAdapter.disableParticles ? "1" : "0",
            "--max-dim", String(root.effectiveMaxDim),
            "--max-effect-chains", String(root.effectiveMaxEffectChains),
            "--max-effect-passes", String(root.effectiveMaxEffectPasses),
            "--compositor-blur", weAdapter.compositorBlur ? "1" : "0",
            "--mute", root.effectiveMuted ? "1" : "0",
            "--volume", Number(weAdapter.volume).toFixed(3),
            "--force-restart", forceRestart ? "1" : "0"
        ];

        const isHotSwap = (targetPath === root._appliedWeDir && !forceRestart);
        let usedStaticFrom = false;
        if (Wallpapers.enableAnimation && !isHotSwap) {
            cmd.push("--transition", weAdapter.transitionEffect || "fade");
            if (!root.surfaceReady && root._pendingStaticFrom !== "" && isStaticImagePath(root._pendingStaticFrom)) {
                cmd.push("--transition-from", root._pendingStaticFrom);
                usedStaticFrom = true;
            }
        } else {
            cmd.push("--transition", "none");
        }
        root._pendingStaticFrom = "";

        if (propsJson !== "") {
            cmd.push("--properties", propsJson);
        }

        applyProc.targetPath = targetPath;
        applyProc.targetId = targetId;
        applyProc.usedTransitionFromArg = usedStaticFrom;
        applyProc.sentMuted = root.effectiveMuted;
        applyProc.sentVolume = weAdapter.volume;
        applyProc.stdoutText = "";
        applyProc.stderrText = "";
        applyProc.exited = false;
        applyProc.stdoutDone = false;
        applyProc.stderrDone = false;
        applyProc.lastExitCode = 0;
        applyProc.command = cmd;
        applyProc.running = true;
    }

    function requestStop(): void {
        root._pendingReapply = false;
        root._pendingForceRestart = false;

        // Paint QML poster immediately before stopping the Vulkan surface
        root.surfaceReady = false;
        root.usedTransitionFrom = false;
        root._remotePaused = false;
        root._pauseRetryCount = 0;
        root._audioRetryCount = 0;
        root._appliedWeDir = "";
        pauseRetryTimer.stop();
        audioDebounceTimer.stop();

        if (applyProc.running) {
            root._pendingStop = true;
            return;
        }
        if (stopProc.running)
            return;

        if (!root.probeCompleted || !root.paperAvailable)
            return;

        stopProc.command = ["python3", root.helperScript, "stop", "--unload"];
        stopProc.running = true;
    }

    function syncPauseState(): void {
        if (!root.shouldBeRunning || !root.surfaceReady)
            return;
        const targetPaused = Boolean(WallpaperPauser.paused);
        if (targetPaused === root._remotePaused)
            return;
        if (pauseProc.running)
            return;

        pauseProc.targetState = targetPaused;
        pauseProc.stdoutText = "";
        pauseProc.exited = false;
        pauseProc.stdoutDone = false;
        pauseProc.lastExitCode = 0;
        pauseProc.command = ["python3", root.helperScript, targetPaused ? "pause" : "resume"];
        pauseProc.running = true;
    }

    function syncAudioState(): void {
        if (!root.shouldBeRunning || !root.surfaceReady)
            return;
        const m = root.effectiveMuted;
        const v = Number(weAdapter.volume);
        if (m === root._lastSentMuted && Math.abs(v - root._lastSentVolume) < 0.001)
            return;
        if (audioProc.running)
            return;

        audioProc.pendingMuted = m;
        audioProc.pendingVolume = v;
        audioProc.stdoutText = "";
        audioProc.exited = false;
        audioProc.stdoutDone = false;
        audioProc.lastExitCode = 0;
        audioProc.command = [
            "python3", root.helperScript, "audio",
            "--mute", m ? "1" : "0",
            "--volume", v.toFixed(3)
        ];
        audioProc.running = true;
    }

    function queuePosterCapture(weDir: string): void {
        const id = extractWeId(weDir);
        if (!id || !weDir)
            return;
        if (getCachedPosterPath(weDir) !== "")
            return;
        if (root._posterQueue.some(entry => entry.id === id))
            return;
        if (posterProc.running && posterProc.currentId === id)
            return;

        root._posterQueue = root._posterQueue.concat([{ id: id, weDir: weDir }]);
        processNextPoster();
    }

    function processNextPoster(): void {
        if (posterProc.running || root._posterQueue.length === 0)
            return;

        const next = root._posterQueue[0];
        root._posterQueue = root._posterQueue.slice(1);

        const s = Screens.screens.length > 0 ? Screens.screens[0] : (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null);
        const w = (s && s.width > 0) ? Math.round(s.width) : 1920;
        const h = (s && s.height > 0) ? Math.round(s.height) : 1080;
        const dest = `${root.posterCacheDir}/${next.id}.png`;

        CUtils.mkdirp(root.posterCacheDir);
        posterProc.currentId = next.id;
        posterProc.destPath = dest;
        posterProc.stdoutText = "";
        posterProc.exited = false;
        posterProc.stdoutDone = false;
        posterProc.lastExitCode = 0;
        posterProc.command = [
            "python3", root.helperScript, "capture-poster",
            "--source", next.weDir,
            "--dest", dest,
            "--width", String(w),
            "--height", String(h)
        ];
        posterProc.running = true;
    }

    function runProbe(): void {
        if (probeProc.running)
            return;
        let cmd = [
            "python3", root.helperScript, "probe",
            "--compositor-blur", weAdapter.compositorBlur ? "1" : "0"
        ];
        if (weAdapter.workshopDir) {
            cmd.push("--workshop-dir", weAdapter.workshopDir);
        }
        probeProc.stdoutText = "";
        probeProc.exited = false;
        probeProc.stdoutDone = false;
        probeProc.lastExitCode = 0;
        probeProc.command = cmd;
        probeProc.running = true;
    }

    function refreshWeInstalled(): void {
        if (listWeProc.running) {
            listWeProc.pendingRerun = true;
            return;
        }
        let cmd = ["python3", root.helperScript, "list-we"];
        if (weAdapter.workshopDir) {
            cmd.push("--workshop-dir", weAdapter.workshopDir);
        }
        listWeProc.stdoutText = "";
        listWeProc.exited = false;
        listWeProc.stdoutDone = false;
        listWeProc.lastExitCode = 0;
        listWeProc.command = cmd;
        listWeProc.running = true;
    }

    function refreshSteamInventory(): void {
        if (!root.steamAvailable)
            return;
        if (steamInvProc.running) {
            steamInvProc.pendingRerun = true;
            return;
        }
        steamInvProc.stdoutText = "";
        steamInvProc.exited = false;
        steamInvProc.stdoutDone = false;
        steamInvProc.lastExitCode = 0;
        steamInvProc.command = ["python3", root.helperScript, "steam-inventory"];
        steamInvProc.running = true;
    }

    function searchWorkshop(query: string, sortType: int, page: int): void {
        if (!root.steamAvailable)
            return;
        const payload = JSON.stringify({
            "query": String(query || ""),
            "query_type": Math.round(Number(sortType) || 0),
            "page": Math.max(1, Math.round(Number(page) || 1))
        });

        root.workshopSearching = true;
        root.workshopError = "";

        if (steamSearchProc.running) {
            root._pendingSearch = payload;
            return;
        }

        steamSearchProc.stdoutText = "";
        steamSearchProc.exited = false;
        steamSearchProc.stdoutDone = false;
        steamSearchProc.lastExitCode = 0;
        steamSearchProc.command = ["python3", root.helperScript, "steam-search", payload];
        steamSearchProc.running = true;
    }

    function subscribeWorkshopItem(idStr: string): void {
        const sId = String(idStr || "").trim();
        if (!sId || !root.steamAvailable)
            return;

        const nextDl = Object.assign({}, root.workshopDownloads || {});
        nextDl[sId] = { "id": sId, "status": "starting", "progress": 0.0, "message": "Queued..." };
        root.workshopDownloads = nextDl;

        if ((steamSubProc.running && steamSubProc.currentId === sId) || root._subQueue.includes(sId))
            return;

        root._subQueue = root._subQueue.concat([sId]);
        processNextSub();
    }

    function processNextSub(): void {
        if (steamSubProc.running || root._subQueue.length === 0)
            return;

        const nextId = root._subQueue[0];
        root._subQueue = root._subQueue.slice(1);

        steamSubProc.currentId = nextId;
        steamSubProc.command = ["python3", root.helperScript, "steam-sub", nextId];
        steamSubProc.running = true;
    }

    function handleSubProgressLine(line: string): void {
        const raw = String(line || "").trim();
        if (!raw)
            return;
        try {
            const obj = JSON.parse(raw);
            const sId = String(obj.id || steamSubProc.currentId || "");
            if (!sId)
                return;
            root._dlPending[sId] = obj;
            const st = String(obj.status || "");
            if (st === "complete" || st === "completed" || st === "done" || st === "installed" || st === "error" || st === "failed" || st === "cancelled") {
                dlFlushTimer.stop();
                flushDownloadProgress();
            } else if (!dlFlushTimer.running) {
                dlFlushTimer.start();
            }
        } catch (e) {}
    }

    function flushDownloadProgress(): void {
        const keys = Object.keys(root._dlPending);
        if (keys.length === 0)
            return;
        const next = Object.assign({}, root.workshopDownloads || {}, root._dlPending);
        root._dlPending = ({});
        root.workshopDownloads = next;
    }

    function unsubscribeWorkshopItem(idStr: string): void {
        const sId = String(idStr || "").trim();
        if (!sId || !root.steamAvailable)
            return;
        if (steamUnsubProc.running)
            return;

        steamUnsubProc.targetId = sId;
        steamUnsubProc.stdoutText = "";
        steamUnsubProc.exited = false;
        steamUnsubProc.stdoutDone = false;
        steamUnsubProc.lastExitCode = 0;
        steamUnsubProc.command = ["python3", root.helperScript, "steam-unsub", sId];
        steamUnsubProc.running = true;
    }

    // Reactive watchers
    onDesiredWeDirChanged: {
        const prev = root._prevDesiredWeDir;
        root._prevDesiredWeDir = root.desiredWeDir;

        if (prev === "" && root.desiredWeDir !== "") {
            root._pendingStaticFrom = Wallpapers.lastStaticHoldPath || "";
        } else if (root.desiredWeDir === "") {
            root._pendingStaticFrom = "";
        } else {
            // WE -> WE direct GPU transition
            root._pendingStaticFrom = "";
        }

        root.engineFailed = false;
        root.lastError = "";
        evaluateLifecycle();
    }

    onShouldBeRunningChanged: evaluateLifecycle()

    onEffectiveGpuChanged: {
        if (root.shouldBeRunning && !root.engineFailed && (root.surfaceReady || applyProc.running))
            requestApply(true);
    }

    onEffectiveFpsChanged: {
        if (root.shouldBeRunning && !root.engineFailed && (root.surfaceReady || applyProc.running))
            requestApply(false);
    }

    onEffectiveVideoFpsChanged: {
        if (root.shouldBeRunning && !root.engineFailed && (root.surfaceReady || applyProc.running))
            requestApply(false);
    }

    onEffectiveMaxDimChanged: {
        if (root.shouldBeRunning && !root.engineFailed && (root.surfaceReady || applyProc.running))
            requestApply(false);
    }

    onEffectiveMaxEffectChainsChanged: {
        if (root.shouldBeRunning && !root.engineFailed && (root.surfaceReady || applyProc.running))
            requestApply(false);
    }

    onEffectiveMutedChanged: {
        if (root.shouldBeRunning && root.surfaceReady) {
            root._audioRetryCount = 0;
            audioDebounceTimer.interval = 100;
            audioDebounceTimer.restart();
        }
    }

    onVolumeChanged: {
        if (root.shouldBeRunning && root.surfaceReady) {
            root._audioRetryCount = 0;
            audioDebounceTimer.interval = 100;
            audioDebounceTimer.restart();
        }
    }

    Connections {
        target: WallpaperPauser
        function onPausedChanged(): void {
            root._pauseRetryCount = 0;
            pauseRetryTimer.stop();
            root.syncPauseState();
        }
    }

    Connections {
        target: Wallpapers
        function onSelectNonceChanged(): void {
            if (root.engineFailed && root.desiredWeDir !== "")
                root.retryCurrent();
        }
    }

    // Timers
    Timer {
        id: pauseRetryTimer
        interval: 250
        repeat: false
        onTriggered: root.syncPauseState()
    }

    Timer {
        id: audioDebounceTimer
        interval: 100
        repeat: false
        onTriggered: root.syncAudioState()
    }

    Timer {
        id: propReapplyTimer
        interval: 200
        repeat: false
        onTriggered: {
            if (root.shouldBeRunning && !root.engineFailed)
                root.requestApply(false);
        }
    }

    Timer {
        id: dlFlushTimer
        interval: 100
        repeat: false
        onTriggered: root.flushDownloadProgress()
    }

    // Persistent config store
    FileView {
        id: weStore

        path: root.statePath
        printErrors: false
        watchChanges: false

        onLoaded: {
            root.adapterReady = true;
            root.sanitizeGpuMode(true);
            root.runProbe();
            transitionsProc.running = true;
        }
        onLoadFailed: {
            root.adapterReady = true;
            root.sanitizeGpuMode(false);
            root.runProbe();
            transitionsProc.running = true;
        }

        JsonAdapter {
            id: weAdapter

            property real volume: 0.15
            property bool silent: false
            property bool muteBehindWindows: false
            property bool muteOnOtherAudio: false
            property string workshopDir: ""
            property string gpuMode: "ac_dgpu"
            property int fps: 60
            property bool disableParticles: false
            property string sceneQuality: "auto"
            property bool reduceEffects: false
            property bool compositorBlur: false
            property string transitionEffect: "fade"
            property var sceneProperties: ({})
        }
    }

    // Helper Processes
    Process {
        id: probeProc
        property string stdoutText: ""
        property bool exited: false
        property bool stdoutDone: false
        property int lastExitCode: 0

        function tryFinish(): void {
            if (!exited || !stdoutDone)
                return;
            if (lastExitCode === 0 && stdoutText) {
                try {
                    const res = JSON.parse(stdoutText);
                    if (res && res.ok) {
                        root.paperAvailable = Boolean(res.paperAvailable);
                        root.steamAvailable = Boolean(res.steamAvailable);
                        root.helmAvailable = Boolean(res.helmAvailable);
                        root.resolvedWorkshopDir = String(res.resolvedWorkshopDir || "");
                        root.availableGpus = Array.isArray(res.gpus) ? res.gpus : [];
                        root.hasSafeDiscrete = Boolean(res.hasSafeDiscrete);
                        root.hasOffloadDiscrete = Boolean(res.hasOffloadDiscrete);
                        root.hasSafeIntegrated = res.hasSafeIntegrated !== undefined ? Boolean(res.hasSafeIntegrated) : true;
                        root.compositorGpuName = String(res.compositorGpu || "");
                        root.discreteGpuName = String(res.discreteGpuName || "");
                        root.integratedGpuName = String(res.integratedGpuName || "");
                    }
                } catch (e) {}
            }
            root.probeCompleted = true;
            root.sanitizeGpuMode(true);
            root.refreshWeInstalled();
            if (root.steamAvailable)
                root.refreshSteamInventory();
            root.evaluateLifecycle();
        }

        stdout: StdioCollector {
            onStreamFinished: {
                probeProc.stdoutText = text ? text.trim() : "";
                probeProc.stdoutDone = true;
                probeProc.tryFinish();
            }
        }
        onExited: (exitCode, exitStatus) => {
            probeProc.lastExitCode = exitCode;
            probeProc.exited = true;
            probeProc.tryFinish();
        }
    }

    Process {
        id: transitionsProc
        command: ["python3", root.helperScript, "transitions"]
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text ? text.trim() : "";
                try {
                    const res = JSON.parse(raw);
                    if (res && res.ok && Array.isArray(res.transitions) && res.transitions.length > 0)
                        root.availableTransitions = res.transitions;
                } catch (e) {}
            }
        }
    }

    Process {
        id: listWeProc
        property bool pendingRerun: false
        property string stdoutText: ""
        property bool exited: false
        property bool stdoutDone: false
        property int lastExitCode: 0

        function tryFinish(): void {
            if (!exited || !stdoutDone)
                return;
            if (lastExitCode === 0 && stdoutText) {
                try {
                    const res = JSON.parse(stdoutText);
                    if (res && res.ok) {
                        if (res.resolvedWorkshopDir)
                            root.resolvedWorkshopDir = String(res.resolvedWorkshopDir);
                        const items = Array.isArray(res.items) ? res.items : [];
                        root.weInstalledItems = items;

                        const nextMap = Object.assign({}, root.posterMap || {});
                        let changed = false;
                        for (let i = 0; i < items.length; i++) {
                            const it = items[i];
                            if (!it || !it.id)
                                continue;
                            const id = String(it.id);
                            const cached = `${root.posterCacheDir}/${id}.png`;
                            if (!nextMap[id] && CUtils.fileExists(cached)) {
                                nextMap[id] = cached;
                                changed = true;
                            }
                        }
                        if (changed) {
                            root.posterMap = nextMap;
                            root.posterRevision++;
                        }
                    }
                } catch (e) {}
            }
            if (listWeProc.pendingRerun) {
                listWeProc.pendingRerun = false;
                root.refreshWeInstalled();
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                listWeProc.stdoutText = text ? text.trim() : "";
                listWeProc.stdoutDone = true;
                listWeProc.tryFinish();
            }
        }
        onExited: (exitCode, exitStatus) => {
            listWeProc.lastExitCode = exitCode;
            listWeProc.exited = true;
            listWeProc.tryFinish();
        }
    }

    Process {
        id: applyProc
        property string targetPath: ""
        property string targetId: ""
        property bool usedTransitionFromArg: false
        property bool sentMuted: false
        property real sentVolume: 0.15
        property string stdoutText: ""
        property string stderrText: ""
        property bool exited: false
        property bool stdoutDone: false
        property bool stderrDone: false
        property int lastExitCode: 0

        function tryFinish(): void {
            if (!exited || !stdoutDone || !stderrDone)
                return;
            if (root._pendingStop) {
                root._pendingStop = false;
                root.requestStop();
                return;
            }

            if (root._pendingReapply) {
                const force = root._pendingForceRestart;
                root._pendingReapply = false;
                root._pendingForceRestart = false;
                if (root.shouldBeRunning && !root.engineFailed) {
                    root.requestApply(force);
                    return;
                }
            }

            let res = null;
            try {
                if (applyProc.stdoutText)
                    res = JSON.parse(applyProc.stdoutText);
            } catch (e) {}

            const succeeded = (applyProc.lastExitCode === 0 && res && res.ok);
            if (succeeded) {
                root._appliedWeDir = applyProc.targetPath;
            }

            if (!root.shouldBeRunning || applyProc.targetPath !== root.desiredWeDir) {
                root.evaluateLifecycle();
                return;
            }

            if (succeeded) {
                root.engineFailed = false;
                root.lastError = "";
                root._lastSentMuted = applyProc.sentMuted;
                root._lastSentVolume = applyProc.sentVolume;
                root.usedTransitionFrom = applyProc.usedTransitionFromArg;
                root.surfaceReady = true;
                root._remotePaused = false;
                root._pauseRetryCount = 0;
                root._audioRetryCount = 0;
                pauseRetryTimer.stop();

                root.syncPauseState();
                root.syncAudioState();
                root.queuePosterCapture(applyProc.targetPath);
            } else {
                const errMsg = (res && res.error) ? String(res.error) : (applyProc.stderrText || ("Wallpaper Engine exited with code " + applyProc.lastExitCode));
                root.engineFailed = true;
                root.lastError = errMsg;
                root.requestStop();
                Toaster.toast("Wallpaper Engine", errMsg, "error", Toast.Error);
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                applyProc.stdoutText = text ? text.trim() : "";
                applyProc.stdoutDone = true;
                applyProc.tryFinish();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                applyProc.stderrText = text ? text.trim() : "";
                applyProc.stderrDone = true;
                applyProc.tryFinish();
            }
        }
        onExited: (exitCode, exitStatus) => {
            applyProc.lastExitCode = exitCode;
            applyProc.exited = true;
            applyProc.tryFinish();
        }
    }

    Process {
        id: stopProc
        onExited: {
            if (root._pendingReapply && root.shouldBeRunning && !root.engineFailed) {
                const force = root._pendingForceRestart;
                root._pendingReapply = false;
                root._pendingForceRestart = false;
                root.requestApply(force);
            }
        }
    }

    Process {
        id: blurProc
        property bool pendingResync: false
        onExited: {
            if (blurProc.pendingResync) {
                blurProc.pendingResync = false;
                root.syncCompositorBlur();
            }
        }
    }

    Process {
        id: pauseProc
        property bool targetState: false
        property string stdoutText: ""
        property bool exited: false
        property bool stdoutDone: false
        property int lastExitCode: 0

        function tryFinish(): void {
            if (!exited || !stdoutDone)
                return;
            let res = null;
            try {
                if (stdoutText)
                    res = JSON.parse(stdoutText);
            } catch (e) {}

            if (lastExitCode === 0 && res && res.ok === true) {
                root._remotePaused = pauseProc.targetState;
                root._pauseRetryCount = 0;
                pauseRetryTimer.stop();
                if (root.shouldBeRunning && root.surfaceReady && Boolean(WallpaperPauser.paused) !== root._remotePaused)
                    root.syncPauseState();
            } else if (root.shouldBeRunning && root.surfaceReady && Boolean(WallpaperPauser.paused) !== root._remotePaused) {
                root._pauseRetryCount++;
                if (root._pauseRetryCount <= 4) {
                    pauseRetryTimer.interval = 250 * Math.pow(2, root._pauseRetryCount - 1);
                    pauseRetryTimer.restart();
                }
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                pauseProc.stdoutText = text ? text.trim() : "";
                pauseProc.stdoutDone = true;
                pauseProc.tryFinish();
            }
        }
        onExited: (exitCode, exitStatus) => {
            pauseProc.lastExitCode = exitCode;
            pauseProc.exited = true;
            pauseProc.tryFinish();
        }
    }

    Process {
        id: audioProc
        property bool pendingMuted: false
        property real pendingVolume: 0.15
        property string stdoutText: ""
        property bool exited: false
        property bool stdoutDone: false
        property int lastExitCode: 0

        function tryFinish(): void {
            if (!exited || !stdoutDone)
                return;
            let res = null;
            try {
                if (stdoutText)
                    res = JSON.parse(stdoutText);
            } catch (e) {}

            if (lastExitCode === 0 && res && res.ok === true) {
                root._lastSentMuted = audioProc.pendingMuted;
                root._lastSentVolume = audioProc.pendingVolume;
                root._audioRetryCount = 0;
                if (root.shouldBeRunning && root.surfaceReady) {
                    if (root.effectiveMuted !== root._lastSentMuted || Math.abs(weAdapter.volume - root._lastSentVolume) >= 0.001) {
                        audioDebounceTimer.interval = 100;
                        audioDebounceTimer.restart();
                    }
                }
            } else if (root.shouldBeRunning && root.surfaceReady) {
                if (root.effectiveMuted !== root._lastSentMuted || Math.abs(weAdapter.volume - root._lastSentVolume) >= 0.001) {
                    root._audioRetryCount++;
                    if (root._audioRetryCount <= 4) {
                        audioDebounceTimer.interval = 250 * Math.pow(2, root._audioRetryCount - 1);
                        audioDebounceTimer.restart();
                    }
                }
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                audioProc.stdoutText = text ? text.trim() : "";
                audioProc.stdoutDone = true;
                audioProc.tryFinish();
            }
        }
        onExited: (exitCode, exitStatus) => {
            audioProc.lastExitCode = exitCode;
            audioProc.exited = true;
            audioProc.tryFinish();
        }
    }

    Process {
        id: posterProc
        property string currentId: ""
        property string destPath: ""
        property string stdoutText: ""
        property bool exited: false
        property bool stdoutDone: false
        property int lastExitCode: 0

        function tryFinish(): void {
            if (!exited || !stdoutDone)
                return;
            try {
                const res = posterProc.stdoutText ? JSON.parse(posterProc.stdoutText) : null;
                if (posterProc.lastExitCode === 0 && res && res.ok) {
                    const outPath = String(res.poster || posterProc.destPath);
                    if (outPath && CUtils.fileExists(outPath)) {
                        const nextMap = Object.assign({}, root.posterMap || {});
                        nextMap[posterProc.currentId] = outPath;
                        root.posterMap = nextMap;
                        root.posterRevision++;
                    }
                }
            } catch (e) {}
            posterProc.currentId = "";
            root.processNextPoster();
        }

        stdout: StdioCollector {
            onStreamFinished: {
                posterProc.stdoutText = text ? text.trim() : "";
                posterProc.stdoutDone = true;
                posterProc.tryFinish();
            }
        }
        onExited: (exitCode, exitStatus) => {
            posterProc.lastExitCode = exitCode;
            posterProc.exited = true;
            posterProc.tryFinish();
        }
    }

    Process {
        id: steamInvProc
        property bool pendingRerun: false
        property string stdoutText: ""
        property bool exited: false
        property bool stdoutDone: false
        property int lastExitCode: 0

        function tryFinish(): void {
            if (!exited || !stdoutDone)
                return;
            try {
                const res = steamInvProc.stdoutText ? JSON.parse(steamInvProc.stdoutText) : null;
                if (lastExitCode === 0 && res && res.ok) {
                    root.steamConnected = true;
                    root.steamError = "";
                    root.steamSubscribedIds = Array.isArray(res.subscribed) ? res.subscribed.map(x => String(x)) : [];
                    const inst = res.installed || {};
                    const norm = {};
                    for (const k in inst) {
                        const val = inst[k];
                        norm[String(k)] = {
                            "id": String(k),
                            "folder": typeof val === "string" ? val : String(val?.folder || "")
                        };
                    }
                    root.steamInstalledMap = norm;
                } else {
                    root.steamConnected = false;
                    root.steamError = (res && res.error) ? String(res.error) : "Steam inventory unavailable";
                }
            } catch (e) {
                root.steamConnected = false;
                root.steamError = "Failed to parse Steam inventory";
            }
            if (steamInvProc.pendingRerun) {
                steamInvProc.pendingRerun = false;
                root.refreshSteamInventory();
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                steamInvProc.stdoutText = text ? text.trim() : "";
                steamInvProc.stdoutDone = true;
                steamInvProc.tryFinish();
            }
        }
        onExited: (exitCode, exitStatus) => {
            steamInvProc.lastExitCode = exitCode;
            steamInvProc.exited = true;
            steamInvProc.tryFinish();
        }
    }

    Process {
        id: steamSearchProc
        property string stdoutText: ""
        property bool exited: false
        property bool stdoutDone: false
        property int lastExitCode: 0

        function tryFinish(): void {
            if (!exited || !stdoutDone)
                return;
            try {
                const res = steamSearchProc.stdoutText ? JSON.parse(steamSearchProc.stdoutText) : null;
                if (lastExitCode === 0 && res && res.ok) {
                    root.workshopResults = Array.isArray(res.results) ? res.results : [];
                    root.workshopError = "";
                } else {
                    root.workshopError = (res && res.error) ? String(res.error) : "Workshop search failed";
                }
            } catch (e) {
                root.workshopError = "Failed to parse Workshop search response";
            }

            if (root._pendingSearch !== null) {
                const nextPayload = root._pendingSearch;
                root._pendingSearch = null;
                steamSearchProc.stdoutText = "";
                steamSearchProc.exited = false;
                steamSearchProc.stdoutDone = false;
                steamSearchProc.lastExitCode = 0;
                steamSearchProc.command = ["python3", root.helperScript, "steam-search", nextPayload];
                steamSearchProc.running = true;
            } else {
                root.workshopSearching = false;
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                steamSearchProc.stdoutText = text ? text.trim() : "";
                steamSearchProc.stdoutDone = true;
                steamSearchProc.tryFinish();
            }
        }
        onExited: (exitCode, exitStatus) => {
            steamSearchProc.lastExitCode = exitCode;
            steamSearchProc.exited = true;
            steamSearchProc.tryFinish();
        }
    }

    Process {
        id: steamSubProc
        property string currentId: ""
        stdout: SplitParser {
            onRead: data => root.handleSubProgressLine(data)
        }
        onExited: (exitCode, exitStatus) => {
            dlFlushTimer.stop();
            root.flushDownloadProgress();
            const sId = steamSubProc.currentId;
            if (sId) {
                const cur = root.workshopDownloads ? root.workshopDownloads[sId] : null;
                if (exitCode !== 0 && (!cur || cur.status === "starting" || cur.status === "downloading")) {
                    const next = Object.assign({}, root.workshopDownloads || {});
                    next[sId] = { "id": sId, "status": "error", "progress": 0.0, "message": "Download failed" };
                    root.workshopDownloads = next;
                } else if (cur && cur.status === "downloading") {
                    const next = Object.assign({}, root.workshopDownloads || {});
                    next[sId] = { "id": sId, "status": "complete", "progress": 1.0, "message": cur.message || "Done" };
                    root.workshopDownloads = next;
                }
            }
            steamSubProc.currentId = "";
            root.refreshWeInstalled();
            root.refreshSteamInventory();
            root.processNextSub();
        }
    }

    Process {
        id: steamUnsubProc
        property string targetId: ""
        property string stdoutText: ""
        property bool exited: false
        property bool stdoutDone: false
        property int lastExitCode: 0

        function tryFinish(): void {
            if (!exited || !stdoutDone)
                return;
            try {
                const res = steamUnsubProc.stdoutText ? JSON.parse(steamUnsubProc.stdoutText) : null;
                if (lastExitCode === 0 && res && res.ok) {
                    const sId = steamUnsubProc.targetId;
                    root.steamSubscribedIds = (root.steamSubscribedIds || []).filter(x => String(x) !== sId);
                    const nextMap = Object.assign({}, root.steamInstalledMap || {});
                    delete nextMap[sId];
                    root.steamInstalledMap = nextMap;
                    root.refreshWeInstalled();
                    root.refreshSteamInventory();
                } else if (res && res.error) {
                    root.workshopError = String(res.error);
                }
            } catch (e) {}
            steamUnsubProc.targetId = "";
        }

        stdout: StdioCollector {
            onStreamFinished: {
                steamUnsubProc.stdoutText = text ? text.trim() : "";
                steamUnsubProc.stdoutDone = true;
                steamUnsubProc.tryFinish();
            }
        }
        onExited: (exitCode, exitStatus) => {
            steamUnsubProc.lastExitCode = exitCode;
            steamUnsubProc.exited = true;
            steamUnsubProc.tryFinish();
        }
    }

    Component.onCompleted: {
        CUtils.mkdirp(root.wallpaperStateDir);
        CUtils.mkdirp(root.posterCacheDir);
    }

    Component.onDestruction: {
        if (root.probeCompleted && root.paperAvailable) {
            Quickshell.execDetached(["python3", root.helperScript, "stop", "--unload"]);
        }
    }
}

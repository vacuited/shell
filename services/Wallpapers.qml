pragma Singleton

import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.Models
import qs.services
import qs.utils

Searcher {
    id: root

    readonly property string currentNamePath: `${Paths.state}/wallpaper/path.txt`
    readonly property list<string> smartArg: GlobalConfig.services.smartScheme ? [] : ["--no-smart"]
    readonly property string fallback: Quickshell.shellPath("assets/wallpapers/Material-Wave.png")

    property bool showPreview: false
    property bool enableAnimation: true
    readonly property string current: (showPreview && previewWeDir === "") ? previewPath : actualCurrent
    property string previewPath
    property string actualCurrent
    property bool previewColourLock
    property bool pendingPreviewClear

    readonly property list<string> validVideoExtensions: ["mp4", "webm", "mkv"]
    property string wallpaperMode: "static"
    property string cacheBuster: ""
    property string rollbackPath: ""
    property string rollbackMode: ""
    property bool isTrackingRollback: false
    
    // Track and restore the last used wallpaper per mode using low-overhead execution
    property string lastStatic: ""
    property string lastAnimated: ""

    property string committedWeDir: ""
    property string previewWeDir: ""
    property string storedWeDir: ""
    property string storedTarget: ""
    property bool weDirLoaded: false
    property bool pathLoaded: false
    property bool _selfSet: false
    property int selectNonce: 0
    property var _thumbCache: ({})

    function cleanPath(raw: string): string {
        if (!raw) return "";
        let s = String(raw).trim();
        if (s.indexOf("file://") === 0) {
            s = s.substring(7).split(/[?#]/)[0];
            try {
                s = decodeURIComponent(s);
            } catch (e) {}
        }
        return s;
    }

    function deriveWeDir(path: string): string {
        let clean = cleanPath(path);
        if (!clean) return "";
        if (clean.endsWith("/project.json")) {
            return clean.substring(0, clean.length - 13);
        }
        if (CUtils.fileExists(clean + "/project.json")) {
            return clean;
        }
        let dir = clean.substring(0, clean.lastIndexOf('/'));
        if (dir && CUtils.fileExists(dir + "/project.json")) {
            return dir;
        }
        let parentDir = dir ? dir.substring(0, dir.lastIndexOf('/')) : "";
        if (parentDir && CUtils.fileExists(parentDir + "/project.json")) {
            try {
                let json = JSON.parse(CUtils.readFile(parentDir + "/project.json"));
                if (json.preview && typeof json.preview === "string") {
                    let expected = parentDir + "/" + json.preview;
                    if (expected === clean) {
                        return parentDir;
                    }
                }
            } catch (e) {}
        }
        return "";
    }

    function isCurrent(path: string): bool {
        if (!path) return false;
        let clean = cleanPath(path);
        if (!clean) return false;
        let currentClean = cleanPath(actualCurrent);
        if (clean === currentClean) return true;
        let currentWe = committedWeDir || deriveWeDir(currentClean);
        if (currentWe) {
            let we = deriveWeDir(clean);
            if (we && we === currentWe) return true;
        }
        return false;
    }

    function syncWeDir(allowDiskWrite: bool): void {
        if (_selfSet || !pathLoaded || !weDirLoaded || !actualCurrent) return;

        if (actualCurrent === storedTarget) {
            committedWeDir = storedWeDir;
            return;
        }

        let derived = deriveWeDir(actualCurrent);
        committedWeDir = derived;
        storedWeDir = derived;
        storedTarget = actualCurrent;

        if (allowDiskWrite) {
            Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && printf "%s\t%s\n" "$2" "$3" > "$1/$4"', "sh", Paths.state + "/wallpaper", derived, actualCurrent, "we_dir.txt"]);
        }
    }

    function resolveWallpaperPath(path: string): string {
        let clean = cleanPath(path);
        if (!clean) return "";
        if (CUtils.fileExists(clean + "/project.json")) {
            clean = clean + "/project.json";
        }
        if (!clean.endsWith("/project.json")) {
            return clean;
        }

        if (_thumbCache[clean] !== undefined) {
            return _thumbCache[clean];
        }

        let target = "";
        let dir = clean.substring(0, clean.length - 13);
        try {
            let content = CUtils.readFile(clean);
            let json = JSON.parse(content);
            if (json.preview && typeof json.preview === "string") {
                if (!json.preview.includes("..") && !json.preview.startsWith("/")) {
                    let candidate = dir + "/" + json.preview;
                    if (CUtils.fileExists(candidate)) {
                        target = candidate;
                    }
                }
            }
        } catch (e) {
            console.warn("Failed to parse project.json:", e);
        }

        if (!target) {
            const candidates = ["preview.png", "preview.jpg", "preview.gif", "preview.webp"];
            for (let i = 0; i < candidates.length; i++) {
                let candidate = dir + "/" + candidates[i];
                if (CUtils.fileExists(candidate)) {
                    target = candidate;
                    break;
                }
            }
        }

        if (target) {
            _thumbCache[clean] = target;
            return target;
        }

        return root.fallback;
    }

    property var _hashCache: ({})

    Timer {
        id: setWallpaperCliTimer
        interval: 250
        repeat: false
        property string pendingTarget: ""
        onTriggered: {
            if (pendingTarget) {
                Quickshell.execDetached(["caelestia", "wallpaper", "-f", pendingTarget, ...root.smartArg]);
            }
        }
    }

    Timer {
        id: colorReleaseTimer
        interval: 180 
        repeat: false
        onTriggered: {
            // Safety check: only clear the preview if no new lock has been engaged
            if (!previewColourLock && pendingPreviewClear) {
                Colours.showPreview = false;
                pendingPreviewClear = false;
            }
        }
    }

    function djb2_hash(s) {
        if (!s) return "0";
        if (_hashCache[s] !== undefined) return _hashCache[s];

        let h = 5381;
        for (let i = 0; i < s.length; i++) {
            h = ((h << 5) + h) + s.charCodeAt(i);
            h |= 0;
        }
        const res = (h >>> 0).toString(10);
        _hashCache[s] = res;
        return res;
    }

    function getWallpaperThumb(path, buster) {
        let clean = String(path || "").split(/[?#]/)[0];
        if (clean.indexOf("file://") === 0) clean = clean.substring(7);
        let b = buster !== undefined ? buster : cacheBuster;
        return Paths.cache + "/videothumbs/" + djb2_hash(clean) + ".jpg" + (b ? "?v=" + b : "");
    }

    function isVideo(path: string): bool {
        if (!path) return false;
        const clean = String(path).split(/[?#]/)[0].toLowerCase();
        const index = clean.lastIndexOf(".");
        const ext = index >= 0 ? clean.slice(index + 1) : "";
        return validVideoExtensions.includes(ext);
    }

    readonly property var categories: {
        let dummy = root.list;
        const baseDir = Paths.wallsdir;
        let cats = [];
        for (let i = 0; i < root.list.length; i++) {
            let p = root.list[i].parentDir;
            if (p.includes("steamapps/workshop/content/431960")) {
                let cat = "Wallpaper Engine";
                if (!cats.includes(cat)) cats.push(cat);
                continue;
            }
            if (p !== baseDir) {
                let cat = p.slice(baseDir.length + 1);
                if (cat.includes("/")) cat = cat.slice(0, cat.indexOf("/"));
                if (!cats.includes(cat)) cats.push(cat);
            }
        }
        return ["Main"].concat(cats.sort());
    }

    readonly property var grouped: {
        let dummy = root.list;
        const baseDir = Paths.wallsdir;
        let grp = { "Main": [] };
        for (let i = 0; i < root.list.length; i++) {
            let w = root.list[i];
            let p = w.parentDir;
            if (p.includes("steamapps/workshop/content/431960")) {
                let cat = "Wallpaper Engine";
                if (!grp[cat]) grp[cat] = [];
                grp[cat].push(w);
                continue;
            }
            if (p === baseDir) {
                grp["Main"].push(w);
            } else {
                let cat = p.slice(baseDir.length + 1);
                if (cat.includes("/")) cat = cat.slice(0, cat.indexOf("/"));
                if (!grp[cat]) grp[cat] = [];
                grp[cat].push(w);
            }
        }
        return grp;
    }

    function getCategoryFor(w: FileSystemEntry): string {
        if (w.parentDir.includes("steamapps/workshop/content/431960")) {
            return "Wallpaper Engine";
        }
        let category = w.parentDir.slice(Paths.wallsdir.length + 1);
        if (category.includes("/"))
            category = category.slice(0, category.indexOf("/"));
        return category;
    }

    function setWallpaperMode(mode) {
        wallpaperMode = mode;
    }

    function captureRollbackState() {
        if (!isTrackingRollback) {
            rollbackPath = actualCurrent;
            rollbackMode = wallpaperMode;
            isTrackingRollback = true;
        }
    }

    onWallpaperModeChanged: {
        captureRollbackState();
        
        const target = wallpaperMode === "animated" ? lastAnimated : lastStatic;

        if (target !== "") {
            actualCurrent = target;
            if (showPreview) {
                previewPath = target;
                if (String(Colours.scheme).startsWith("dynamic")) {
                    if (!getPreviewColoursProc.running) {
                        getPreviewColoursProc.startFor(target);
                    }
                }
            } else {
                Quickshell.execDetached(["caelestia", "wallpaper", "-f", target, ...smartArg]);
            }
        }
    }

    onEnableAnimationChanged: {
        Quickshell.execDetached(["sh", "-c", "mkdir -p '" + Paths.state + "/wallpaper' && echo '" + (enableAnimation ? "1" : "0") + "' > '" + Paths.state + "/wallpaper/enable_animation.txt'"]);
    }

    function setRandom(): void {
        Quickshell.execDetached(["caelestia", "wallpaper", "-r", ...smartArg]);
    }

    function setWallpaper(path: string): void {
        let clean = cleanPath(path);
        if (!clean) return;

        let wePath = deriveWeDir(clean);
        let targetPath = resolveWallpaperPath(clean);

        _selfSet = true;
        committedWeDir = wePath;
        storedWeDir = wePath;
        storedTarget = targetPath;
        actualCurrent = targetPath;
        _selfSet = false;

        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && printf "%s\t%s\n" "$2" "$3" > "$1/$4"', "sh", Paths.state + "/wallpaper", wePath, targetPath, "we_dir.txt"]);

        isTrackingRollback = false;
        previewColourLock = true;
        pendingPreviewClear = false;

        if (isVideo(targetPath)) {
            lastAnimated = targetPath;
            wallpaperMode = "animated";
            Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && printf "%s\n" "$2" > "$1/$3"', "sh", Paths.state + "/wallpaper", targetPath, "last_animated.txt"]);
        } else {
            lastStatic = targetPath;
            wallpaperMode = "static";
            Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && printf "%s\n" "$2" > "$1/$3"', "sh", Paths.state + "/wallpaper", targetPath, "last_static.txt"]);
        }

        stopPreview();

        setWallpaperCliTimer.pendingTarget = targetPath;
        setWallpaperCliTimer.restart();

        selectNonce++;
    }

    function preview(path: string): void {
        captureRollbackState();

        let clean = cleanPath(path);
        if (!clean) return;

        let weDir = deriveWeDir(clean);
        previewWeDir = weDir;

        let targetPath = resolveWallpaperPath(clean);

        if (previewPath === targetPath && showPreview) return;

        previewPath = targetPath;
        showPreview = true;

        if (String(Colours.scheme).startsWith("dynamic")) {
            if (!getPreviewColoursProc.running) {
                getPreviewColoursProc.startFor(targetPath);
            }
        }
    }

    function stopPreview(): void {
        showPreview = false;
        previewWeDir = "";
        
        if (getPreviewColoursProc.running) {
            getPreviewColoursProc.running = false;
        }

        if (isTrackingRollback) {
            wallpaperMode = rollbackMode;
            _selfSet = true;
            actualCurrent = rollbackPath;
            _selfSet = false;
            isTrackingRollback = false;
            
            Quickshell.execDetached(["caelestia", "wallpaper", "-f", rollbackPath, ...smartArg]);
        }

        if (previewColourLock) {
            pendingPreviewClear = true;
        } else {
            Colours.showPreview = false;
            pendingPreviewClear = false;
        }
    }

    function getThumbnailPath(path: string): string {
        let clean = cleanPath(path);
        if (clean.endsWith("/project.json")) {
            return resolveWallpaperPath(clean);
        }
        if (isVideo(clean)) {
            return getWallpaperThumb(clean);
        }
        return clean;
    }

    onPreviewColourLockChanged: {
        if (!previewColourLock && pendingPreviewClear) {
            colorReleaseTimer.restart();
        }
    }

    list: wallpapers.entries
    key: "relativePath"
    useFuzzy: GlobalConfig.launcher.useFuzzy.wallpapers
    extraOpts: useFuzzy ? ({}) : ({
            forward: false
        })

    IpcHandler {
        function get(): string {
            return root.actualCurrent;
        }

        function set(path: string): void {
            root.setWallpaper(path);
        }

        function list(): string {
            return root.list.map(w => w.path).join("\n");
        }

        function preview(path: string): void {
            root.preview(path);
        }

        function stopPreview(): void {
            root.stopPreview();
        }

        function setMode(mode: string): void {
            root.setWallpaperMode(mode);
        }

        target: "wallpaper"
    }

    FileView {
        path: `${Paths.state}/wallpaper/enable_animation.txt`
        printErrors: false
        onLoaded: {
            const val = text().trim();
            if (val === "0") root.enableAnimation = false;
            else if (val === "1") root.enableAnimation = true;
        }
    }

    FileView {
        path: `${Paths.state}/wallpaper/we_dir.txt`
        printErrors: false
        onLoaded: {
            let raw = text().replace(/\r?\n$/, "");
            let parts = raw.split("\t");
            root.storedWeDir = parts[0] || "";
            root.storedTarget = parts[1] || "";
            root.weDirLoaded = true;
            if (root.pathLoaded) {
                root.syncWeDir(false);
            }
        }
        onLoadFailed: {
            root.weDirLoaded = true;
            if (root.pathLoaded) {
                root.syncWeDir(false);
            }
        }
    }

    onActualCurrentChanged: {
        if (!root._selfSet && root.weDirLoaded && root.pathLoaded) {
            root.syncWeDir(true);
        }
    }

    FileView {
        path: root.currentNamePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            let wall = text().trim();
            if (!wall) {
                wall = root.fallback;
                Quickshell.execDetached(["caelestia", "wallpaper", "-f", root.fallback, ...root.smartArg]);
            }
            let isExternal = (root.pathLoaded && root.storedTarget !== wall);
            root._selfSet = true;
            root.actualCurrent = wall;
            root._selfSet = false;
            root.pathLoaded = true;
            root.previewColourLock = false;

            if (root.isVideo(root.actualCurrent)) {
                wallpaperMode = "animated";
                if (!root.lastAnimated) root.lastAnimated = wall;
            } else {
                wallpaperMode = "static";
                if (!root.lastStatic) root.lastStatic = wall;
            }

            if (root.weDirLoaded) {
                root.syncWeDir(isExternal);
            }
        }
        onLoadFailed: {
            root._selfSet = true;
            root.actualCurrent = root.fallback;
            root._selfSet = false;
            root.pathLoaded = true;
            root.previewColourLock = false;
            Quickshell.execDetached(["caelestia", "wallpaper", "-f", root.fallback, ...root.smartArg]);
            if (root.weDirLoaded) {
                root.syncWeDir(false);
            }
        }
    }

    FileView {
        path: `${Paths.state}/wallpaper/last_static.txt`
        printErrors: false
        onLoaded: {
            const val = text().trim();
            if (val) root.lastStatic = val;
        }
    }

    FileView {
        path: `${Paths.state}/wallpaper/last_animated.txt`
        printErrors: false
        onLoaded: {
            const val = text().trim();
            if (val) root.lastAnimated = val;
        }
    }

    function updateCombinedList() {
        let arr = [];
        for (let i = 0; i < wallpapers.entries.length; i++) {
            arr.push(wallpapers.entries[i]);
        }
        for (let i = 0; i < weWallpapers.entries.length; i++) {
            arr.push(weWallpapers.entries[i]);
        }
        root.list = arr;
    }

    property alias weVolume: weAdapter.volume
    property alias weSilent: weAdapter.silent
    onWeVolumeChanged: weStore.writeAdapter()
    onWeSilentChanged: weStore.writeAdapter()
    
    Component.onCompleted: CUtils.mkdirp(Paths.state + "/wallpaper")

    FileView {
        id: weStore

        path: `${Paths.state}/wallpaper/wallpaper-engine.json`
        printErrors: false
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: weAdapter

            property real volume: 0.15
            property bool silent: false
        }
    }

    FileSystemModel {
        id: wallpapers
        recursive: true
        path: Paths.wallsdir
        filter: FileSystemModel.Files
        nameFilters: Array.from(Images.validImageExtensions).concat(Array.from(Images.validVideoExtensions)).map(e => `*.${e}`).concat(["project.json"])
        onEntriesChanged: root.updateCombinedList()
    }

    FileSystemModel {
        id: weWallpapers
        recursive: true
        path: Quickshell.env("HOME") + "/.local/share/Steam/steamapps/workshop/content/431960"
        filter: FileSystemModel.Files
        nameFilters: ["project.json"]
        onEntriesChanged: root.updateCombinedList()
    }

    Process {
        id: getPreviewColoursProc

        property string currentProcessingPath: ""

        command: ["caelestia", "wallpaper", "-p", currentProcessingPath, ...root.smartArg]

        function startFor(path) {
            if (!path) return;
            currentProcessingPath = path;
            running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.showPreview) return;

                const raw = text ? text.trim() : "";
                if (raw) {
                    try {
                        JSON.parse(raw);
                        Colours.load(raw, true);
                        Colours.showPreview = true;
                    } catch (e) {
                        // Ignore incomplete or invalid output
                    }
                }

                if (root.showPreview && root.previewPath !== "" && root.previewPath !== getPreviewColoursProc.currentProcessingPath) {
                    getPreviewColoursProc.startFor(root.previewPath);
                }
            }
        }
    }

    property bool _refreshing: false
    property bool restoreWallpaperMode: false
    property var itemBusters: ({})

    FileView {
        path: "/tmp/caelestia_thumb_ready.txt"
        watchChanges: true
        printErrors: false
        onLoaded: {
            const raw = text().trim();
            if (!raw) return;
            
            const lines = raw.split("\n");
            let busters = Object.assign({}, root.itemBusters);
            let changed = false;
            const now = Date.now().toString();

            for (let i = 0; i < lines.length; i++) {
                let line = lines[i].trim();
                if (line.indexOf("file://") === 0) line = line.substring(7);
                if (line && !busters[line]) {
                    busters[line] = now;
                    busters["file://" + line] = now;
                    changed = true;
                }
            }
            if (changed) {
                root.itemBusters = busters;
            }
        }
    }

    function refreshAnimatedThumbs() {
        if (_refreshing) return;
        itemBusters = {};
        _refreshing = true;
        _extractThumbsProc.running = true;
    }

    Process {
        id: _extractThumbsProc

        command: ["caelestia", "wallpaper", "--extract-thumbs"]
        onExited: (exitCode, exitStatus) => {
            root._refreshing = false;
            root.cacheBuster = Date.now().toString();
            root.restoreWallpaperMode = true;
        }
    }

    Component.onDestruction: {
        if (setWallpaperCliTimer.running && setWallpaperCliTimer.pendingTarget) {
            Quickshell.execDetached(["caelestia", "wallpaper", "-f", setWallpaperCliTimer.pendingTarget, ...root.smartArg]);
        }
    }
}

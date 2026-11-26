pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.State
import qs.services
import qs.utils

Singleton {
    id: root

    readonly property string scriptPath: Quickshell.shellPath("assets/scripts/vacuited_updater.py")
    readonly property var _defaultComp: ({
            installedCommit: "",
            installedShort: "",
            pluginCommit: "",
            pluginShort: "",
            version: "",
            installedAt: "",
            remoteCommit: "",
            remoteShort: "",
            baselineMissing: true,
            hasUpdate: false,
            aheadBy: 0,
            commits: [],
            compareUrl: "",
            needsPluginRebuild: false,
            touchesHardwareHelper: false,
            touchesShaders: false,
            touchesDeps: false,
            rateLimited: false,
            checkError: ""
        })

    // User preferences (stored in ~/.config/caelestia/updater.json; never touches shell.json)
    property alias autoCheck: prefsAdapter.autoCheck
    property alias checkIntervalHours: prefsAdapter.checkIntervalHours
    property alias notifyOnUpdate: prefsAdapter.notifyOnUpdate
    property alias lastNotifiedSha: prefsAdapter.lastNotifiedSha
    property alias lastCheckedIso: prefsAdapter.lastCheckedIso
    property bool adapterReady: false

    // Runtime state
    property bool statusLoaded: false
    property bool checking: false
    property bool updating: false
    property bool canceling: false
    property string activeTarget: ""
    property string phase: ""
    property real progress: 0.0
    property var logLines: []
    property string lastError: ""
    property bool canTerminalFallback: false
    property string terminalFallbackCmd: ""

    property var shellInfo: _defaultComp
    property var cliInfo: _defaultComp
    property var backups: []
    property var tools: ({})
    property var systemSync: ({
            needed: false,
            reasons: []
        })

    readonly property bool shellHasUpdate: Boolean(shellInfo?.hasUpdate)
    readonly property bool cliHasUpdate: Boolean(cliInfo?.hasUpdate)
    readonly property bool hasAnyUpdate: shellHasUpdate || cliHasUpdate
    readonly property bool baselineMissing: Boolean(shellInfo?.baselineMissing) || Boolean(cliInfo?.baselineMissing)
    readonly property bool systemSyncNeeded: Boolean(systemSync?.needed)
    readonly property var systemSyncReasons: Array.isArray(systemSync?.reasons) ? systemSync.reasons : []
    readonly property int totalUpdateCommits: (shellHasUpdate ? (Number(shellInfo?.aheadBy) || (shellInfo?.commits?.length ?? 0)) : 0)
        + (cliHasUpdate ? (Number(cliInfo?.aheadBy) || (cliInfo?.commits?.length ?? 0)) : 0)
    readonly property string combinedRemoteSha: hasAnyUpdate
        ? `${shellHasUpdate ? (shellInfo?.remoteCommit ?? "") : ""}:${cliHasUpdate ? (cliInfo?.remoteCommit ?? "") : ""}`
        : ""

    function savePrefs(): void {
        saveTimer.restart();
    }

    function _flushPrefs(): void {
        CUtils.mkdirp(Paths.config);
        prefsStore.writeAdapter();
    }

    function _appendLog(line: string, level: string): void {
        const text = String(line ?? "").trimEnd();
        if (!text)
            return;
        const next = root.logLines.slice();
        next.push({
            line: text,
            level: level || "info"
        });
        if (next.length > 300)
            next.splice(0, next.length - 300);
        root.logLines = next;
    }

    function _applyPayload(data: var): void {
        if (!data || typeof data !== "object")
            return;
        if (data.shell)
            root.shellInfo = data.shell;
        if (data.cli)
            root.cliInfo = data.cli;
        if (Array.isArray(data.backups))
            root.backups = data.backups;
        if (data.tools && typeof data.tools === "object")
            root.tools = data.tools;
        if (data.systemSync && typeof data.systemSync === "object")
            root.systemSync = data.systemSync;
        if (data.meta?.lastCheckedAt)
            prefsAdapter.lastCheckedIso = String(data.meta.lastCheckedAt);
    }

    function _maybeNotifyAvailable(): void {
        if (!prefsAdapter.notifyOnUpdate || !root.hasAnyUpdate)
            return;
        const sha = root.combinedRemoteSha;
        if (!sha || sha === prefsAdapter.lastNotifiedSha)
            return;
        if (GameMode.enabled || PersistentState.doNotDisturb || Notifs.hasFullscreen())
            return;

        prefsAdapter.lastNotifiedSha = sha;
        root.savePrefs();

        const parts = [];
        if (root.shellHasUpdate) {
            const count = Number(root.shellInfo?.aheadBy) || (root.shellInfo?.commits?.length ?? 0);
            parts.push(count > 0 ? qsTr("Shell (%1 commit%2)").arg(count).arg(count === 1 ? "" : "s") : qsTr("Shell"));
        }
        if (root.cliHasUpdate) {
            const count = Number(root.cliInfo?.aheadBy) || (root.cliInfo?.commits?.length ?? 0);
            parts.push(count > 0 ? qsTr("CLI (%1 commit%2)").arg(count).arg(count === 1 ? "" : "s") : qsTr("CLI"));
        }
        Toaster.toast(
            qsTr("Vacuited update available"),
            qsTr("%1 ready in Nexus > Updates").arg(parts.join(" · ")),
            "system_update",
            Toast.Info,
            6000
        );
    }

    function _handleJustUpdated(justUpdated: var): void {
        if (!justUpdated || typeof justUpdated !== "object")
            return;
        if (!clearJustUpdatedProc.running)
            clearJustUpdatedProc.running = true;

        if (justUpdated.rolledBack) {
            const shortCommit = justUpdated.shellShort ? ` (${justUpdated.shellShort})` : "";
            Toaster.toast(
                qsTr("Vacuited rolled back"),
                qsTr("Restored %1%2").arg(justUpdated.backupName || qsTr("snapshot")).arg(shortCommit),
                "history",
                Toast.Success,
                6000
            );
            return;
        }

        const parts = [];
        if (Array.isArray(justUpdated.components)) {
            if (justUpdated.components.includes("shell"))
                parts.push(justUpdated.shellShort ? `Shell ${justUpdated.shellShort}` : "Shell");
            if (justUpdated.components.includes("cli"))
                parts.push(justUpdated.cliShort ? `CLI ${justUpdated.cliShort}` : "CLI");
        }
        const baseSummary = parts.length > 0 ? parts.join(" · ") : qsTr("Updated to latest");
        const summary = root.systemSyncNeeded
            ? qsTr("%1 · Open Nexus > Updates to sync system hooks").arg(baseSummary)
            : baseSummary;
        Toaster.toast(qsTr("Vacuited updated"), summary, "check_circle", Toast.Success, root.systemSyncNeeded ? 8000 : 6000);
    }

    function _handleStreamLine(raw: string): void {
        const line = String(raw ?? "").trim();
        if (!line)
            return;

        let msg = null;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            root._appendLog(line, "info");
            return;
        }

        if (!msg || typeof msg !== "object")
            return;

        if (msg.type === "progress") {
            root.phase = String(msg.phase || "");
            root.progress = Math.max(0, Math.min(1, Number(msg.percent || 0) / 100));
        } else if (msg.type === "log") {
            root._appendLog(String(msg.line || ""), String(msg.level || "info"));
        } else if (msg.type === "done") {
            updateProc.receivedTerminalEvent = true;
            root.progress = 1.0;
            root.phase = msg.restarting ? qsTr("Restarting shell...") : (msg.summary || qsTr("Update complete"));
            if (Array.isArray(msg.backups))
                root.backups = msg.backups;
            if (msg.systemSync && typeof msg.systemSync === "object")
                root.systemSync = msg.systemSync;
            if (!msg.restarting) {
                root.loadStatus();
                Toaster.toast(
                    qsTr("Vacuited updated"),
                    String(msg.summary || qsTr("Updated to latest")),
                    "check_circle",
                    Toast.Success,
                    5000
                );
            }
        } else if (msg.type === "cancelled") {
            updateProc.receivedTerminalEvent = true;
            root.canceling = false;
            root.phase = qsTr("Update canceled");
            root.lastError = "";
            root._appendLog(String(msg.message || qsTr("Update canceled.")), "warn");
            Toaster.toast(
                qsTr("Update canceled"),
                qsTr("No shell files were changed."),
                "cancel",
                Toast.Info,
                4000
            );
        } else if (msg.type === "error") {
            updateProc.receivedTerminalEvent = true;
            root.lastError = String(msg.message || qsTr("Update failed"));
            root.canTerminalFallback = Boolean(msg.canTerminalFallback);
            root.terminalFallbackCmd = String(msg.terminalCommand || "");
            root._appendLog(root.lastError, "error");
        }
    }

    function loadStatus(): void {
        if (statusProc.running)
            return;
        statusProc.stdoutText = "";
        statusProc.exited = false;
        statusProc.stdoutDone = false;
        statusProc.lastExitCode = 0;
        statusProc.running = true;
    }

    function checkForUpdates(force = false, manual = true): void {
        if (root.checking || root.updating)
            return;
        root.checking = true;
        if (manual)
            root.lastError = "";
        checkProc.isManual = manual;
        checkProc.stdoutText = "";
        checkProc.exited = false;
        checkProc.stdoutDone = false;
        checkProc.lastExitCode = 0;
        checkProc.command = force
            ? ["python3", root.scriptPath, "check", "--force"]
            : ["python3", root.scriptPath, "check"];
        checkProc.running = true;
    }

    function updateComponent(target = "all", forceRebuild = false): void {
        if (root.updating || root.checking)
            return;
        root.updating = true;
        root.canceling = false;
        root.activeTarget = target;
        root.phase = qsTr("Preparing update...");
        root.progress = 0.02;
        root.logLines = [];
        root.lastError = "";
        root.canTerminalFallback = false;
        root.terminalFallbackCmd = "";
        updateProc.receivedTerminalEvent = false;

        const cmd = ["python3", root.scriptPath, "update", "--target", target];
        if (forceRebuild)
            cmd.push("--force-rebuild");
        updateProc.command = cmd;
        updateProc.running = true;
    }

    function syncSystem(): void {
        if (root.updating || root.checking)
            return;
        root.updating = true;
        root.canceling = false;
        root.activeTarget = "system";
        root.phase = qsTr("Syncing system hooks...");
        root.progress = 0.05;
        root.logLines = [];
        root.lastError = "";
        root.canTerminalFallback = false;
        root.terminalFallbackCmd = "";
        updateProc.receivedTerminalEvent = false;
        updateProc.command = ["python3", root.scriptPath, "sync-system"];
        updateProc.running = true;
    }

    function rollback(backupName: string): void {
        if (root.updating || root.checking || !backupName)
            return;
        root.updating = true;
        root.canceling = false;
        root.activeTarget = "rollback";
        root.phase = qsTr("Restoring backup...");
        root.progress = 0.05;
        root.logLines = [];
        root.lastError = "";
        root.canTerminalFallback = false;
        root.terminalFallbackCmd = "";
        updateProc.receivedTerminalEvent = false;
        updateProc.command = ["python3", root.scriptPath, "rollback", backupName];
        updateProc.running = true;
    }

    function cancelUpdate(): void {
        if (!root.updating || root.canceling)
            return;
        root.canceling = true;
        root.phase = qsTr("Canceling...");
        root._appendLog(qsTr("Canceling update..."), "warn");
        cancelProc.running = true;
        cancelFallbackTimer.restart();
    }

    function deleteBackup(backupName: string): void {
        if (!backupName || deleteBackupProc.running)
            return;
        deleteBackupProc.stdoutText = "";
        deleteBackupProc.exited = false;
        deleteBackupProc.stdoutDone = false;
        deleteBackupProc.lastExitCode = 0;
        deleteBackupProc.command = ["python3", root.scriptPath, "delete-backup", backupName];
        deleteBackupProc.running = true;
    }

    function markSynced(component = "all"): void {
        if (markSyncedProc.running || root.updating)
            return;
        root.checking = true;
        root.lastError = "";
        markSyncedProc.stdoutText = "";
        markSyncedProc.exited = false;
        markSyncedProc.stdoutDone = false;
        markSyncedProc.lastExitCode = 0;
        markSyncedProc.command = ["python3", root.scriptPath, "mark-synced", "--component", component];
        markSyncedProc.running = true;
    }

    function runTerminalFallback(): void {
        if (!root.terminalFallbackCmd)
            return;
        const term = (GlobalConfig.general.apps.terminal && GlobalConfig.general.apps.terminal.length > 0)
            ? [...GlobalConfig.general.apps.terminal]
            : ["kitty"];
        const shellCmd = `${root.terminalFallbackCmd}; echo; printf 'Done. Press Enter to close...'; read -r _`;
        Quickshell.execDetached([...term, "sh", "-c", shellCmd]);
    }

    Component.onCompleted: loadStatus()

    Component.onDestruction: {
        if (saveTimer.running) {
            saveTimer.stop();
            root._flushPrefs();
        }
    }

    Timer {
        id: saveTimer
        interval: 200
        repeat: false
        onTriggered: root._flushPrefs()
    }

    Timer {
        id: startupCheckTimer
        interval: 60000
        repeat: false
        running: root.adapterReady && prefsAdapter.autoCheck && prefsAdapter.checkIntervalHours > 0
        onTriggered: {
            if (!root.adapterReady || !prefsAdapter.autoCheck || prefsAdapter.checkIntervalHours <= 0)
                return;
            const lastMs = prefsAdapter.lastCheckedIso ? Date.parse(prefsAdapter.lastCheckedIso) : NaN;
            if (!isNaN(lastMs) && (Date.now() - lastMs) < 15 * 60 * 1000)
                return;
            root.checkForUpdates(false, false);
        }
    }

    Timer {
        id: periodicTimer
        interval: Math.max(1, prefsAdapter.checkIntervalHours) * 3600000
        repeat: true
        running: root.adapterReady && prefsAdapter.autoCheck && prefsAdapter.checkIntervalHours > 0
        onTriggered: root.checkForUpdates(false, false)
    }

    FileView {
        id: prefsStore

        path: `${Paths.config}/updater.json`
        preload: true
        printErrors: false
        watchChanges: false

        onLoaded: root.adapterReady = true
        onLoadFailed: root.adapterReady = true

        JsonAdapter {
            id: prefsAdapter

            property bool autoCheck: false
            property int checkIntervalHours: 6
            property bool notifyOnUpdate: false
            property string lastNotifiedSha: ""
            property string lastCheckedIso: ""
        }
    }

    Process {
        id: statusProc

        property string stdoutText: ""
        property bool exited: false
        property bool stdoutDone: false
        property int lastExitCode: 0

        command: ["python3", root.scriptPath, "status"]

        function tryFinish(): void {
            if (!exited || !stdoutDone)
                return;
            if (lastExitCode === 0 && stdoutText) {
                try {
                    const data = JSON.parse(stdoutText);
                    if (data && data.ok) {
                        root._applyPayload(data);
                        root.statusLoaded = true;
                        if (data.justUpdated)
                            root._handleJustUpdated(data.justUpdated);
                    }
                } catch (e) {}
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                statusProc.stdoutText = text ? text.trim() : "";
                statusProc.stdoutDone = true;
                statusProc.tryFinish();
            }
        }

        onExited: exitCode => { // qmllint disable signal-handler-parameters
            statusProc.lastExitCode = exitCode;
            statusProc.exited = true;
            statusProc.tryFinish();
        }
    }

    Process {
        id: clearJustUpdatedProc
        command: ["python3", root.scriptPath, "clear-just-updated"]
    }

    Process {
        id: checkProc

        property bool isManual: true
        property string stdoutText: ""
        property bool exited: false
        property bool stdoutDone: false
        property int lastExitCode: 0

        function tryFinish(): void {
            if (!exited || !stdoutDone)
                return;
            root.checking = false;
            try {
                const data = stdoutText ? JSON.parse(stdoutText) : null;
                if (lastExitCode === 0 && data && data.ok) {
                    root._applyPayload(data);
                    root.statusLoaded = true;
                    root.savePrefs();
                    if (!isManual)
                        root._maybeNotifyAvailable();
                } else {
                    const err = (data && data.error) ? String(data.error) : qsTr("Failed to check for updates.");
                    if (isManual)
                        root.lastError = err;
                }
            } catch (e) {
                if (isManual)
                    root.lastError = qsTr("Failed to parse update check output.");
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                checkProc.stdoutText = text ? text.trim() : "";
                checkProc.stdoutDone = true;
                checkProc.tryFinish();
            }
        }

        onExited: exitCode => { // qmllint disable signal-handler-parameters
            checkProc.lastExitCode = exitCode;
            checkProc.exited = true;
            checkProc.tryFinish();
        }
    }

    Process {
        id: markSyncedProc

        property string stdoutText: ""
        property bool exited: false
        property bool stdoutDone: false
        property int lastExitCode: 0

        function tryFinish(): void {
            if (!exited || !stdoutDone)
                return;
            root.checking = false;
            try {
                const data = stdoutText ? JSON.parse(stdoutText) : null;
                if (lastExitCode === 0 && data && data.ok) {
                    root._applyPayload(data);
                    root.statusLoaded = true;
                    Toaster.toast(qsTr("Baseline synced"), qsTr("Current install marked as up to date"), "check_circle", Toast.Success);
                } else {
                    root.lastError = (data && data.error) ? String(data.error) : qsTr("Failed to mark current install as synced.");
                }
            } catch (e) {
                root.lastError = qsTr("Failed to mark current install as synced.");
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                markSyncedProc.stdoutText = text ? text.trim() : "";
                markSyncedProc.stdoutDone = true;
                markSyncedProc.tryFinish();
            }
        }

        onExited: exitCode => { // qmllint disable signal-handler-parameters
            markSyncedProc.lastExitCode = exitCode;
            markSyncedProc.exited = true;
            markSyncedProc.tryFinish();
        }
    }

    Process {
        id: deleteBackupProc

        property string stdoutText: ""
        property bool exited: false
        property bool stdoutDone: false
        property int lastExitCode: 0

        function tryFinish(): void {
            if (!exited || !stdoutDone)
                return;
            try {
                const data = stdoutText ? JSON.parse(stdoutText) : null;
                if (lastExitCode === 0 && data && data.ok && Array.isArray(data.backups)) {
                    root.backups = data.backups;
                    Toaster.toast(qsTr("Backup deleted"), qsTr("Snapshot removed from disk"), "delete", Toast.Info);
                } else if (data && data.error) {
                    Toaster.toast(qsTr("Delete failed"), String(data.error), "error", Toast.Error);
                }
            } catch (e) {}
        }

        stdout: StdioCollector {
            onStreamFinished: {
                deleteBackupProc.stdoutText = text ? text.trim() : "";
                deleteBackupProc.stdoutDone = true;
                deleteBackupProc.tryFinish();
            }
        }

        onExited: exitCode => { // qmllint disable signal-handler-parameters
            deleteBackupProc.lastExitCode = exitCode;
            deleteBackupProc.exited = true;
            deleteBackupProc.tryFinish();
        }
    }

    Timer {
        id: cancelFallbackTimer
        interval: 2500
        repeat: false
        onTriggered: {
            if (updateProc.running) {
                updateProc.receivedTerminalEvent = true;
                updateProc.running = false;
                root.canceling = false;
                root.updating = false;
                root.activeTarget = "";
                root.phase = qsTr("Update canceled");
                Toaster.toast(qsTr("Update canceled"), qsTr("No shell files were changed."), "cancel", Toast.Info, 4000);
            }
        }
    }

    Process {
        id: cancelProc
        command: ["python3", root.scriptPath, "cancel"]
    }

    Process {
        id: updateProc

        property bool receivedTerminalEvent: false

        stdout: SplitParser {
            onRead: data => root._handleStreamLine(data)
        }

        stderr: SplitParser {
            onRead: data => root._appendLog(data, "warn")
        }

        onExited: exitCode => { // qmllint disable signal-handler-parameters
            cancelFallbackTimer.stop();
            root.updating = false;
            root.canceling = false;
            root.activeTarget = "";
            if (exitCode !== 0 && !updateProc.receivedTerminalEvent) {
                root.lastError = qsTr("Process exited unexpectedly (code %1)").arg(exitCode);
                root._appendLog(root.lastError, "error");
            }
        }
    }

    IpcHandler {
        function check(): void {
            root.checkForUpdates(true, true);
        }

        function cancel(): void {
            root.cancelUpdate();
        }

        function status(): string {
            return JSON.stringify({
                checking: root.checking,
                updating: root.updating,
                hasAnyUpdate: root.hasAnyUpdate,
                shellHasUpdate: root.shellHasUpdate,
                cliHasUpdate: root.cliHasUpdate,
                baselineMissing: root.baselineMissing,
                systemSyncNeeded: root.systemSyncNeeded,
                systemSync: root.systemSync,
                shell: root.shellInfo,
                cli: root.cliInfo,
                backups: root.backups
            });
        }

        target: "updates"
    }
}

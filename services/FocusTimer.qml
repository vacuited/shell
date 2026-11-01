pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import Caelestia.State
import qs.services
import qs.utils

Singleton {
    id: root

    function clamp(val: real, minVal: real, maxVal: real): real {
        return Math.max(minVal, Math.min(maxVal, val));
    }

    // config-backed, clamped, read-only
    readonly property int focusMins: clamp(GlobalConfig.focus.focusMins, 5, 180)
    readonly property int shortBreakMins: clamp(GlobalConfig.focus.shortBreakMins, 1, 60)
    readonly property int longBreakMins: clamp(GlobalConfig.focus.longBreakMins, 5, 180)
    readonly property int cyclesBeforeLongBreak: clamp(GlobalConfig.focus.cyclesBeforeLongBreak, 2, 8)

    property string mode: "timer"          // "timer" | "stopwatch"
    property string phase: "focus"         // "focus" | "shortBreak" | "longBreak"
    property string subject: ""            // "" = untagged
    property int remaining: 0              // countdown seconds
    property int elapsed: 0                // stopwatch seconds
    property int phaseTotal: 0             // countdown length incl. +5m extensions
    property int phaseTickSecs: 0          // seconds actually ticked in this phase
    property int cycleCount: 0             // credited focus sessions since last Big Break
    property bool running: false
    property bool sessionActive: false
    property bool dndEngaged: false
    property int distractionSecs: 0

    readonly property bool isStopwatch: mode === "stopwatch" && phase === "focus"
    readonly property int baseSecs: (phase === "shortBreak" ? shortBreakMins : phase === "longBreak" ? longBreakMins : focusMins) * 60
    readonly property int durationSecs: baseSecs
    readonly property bool active: sessionActive
    readonly property int completedSessions: FocusLedger.todaySessions
    readonly property int totalFocusedSecsToday: FocusLedger.todaySecs
    readonly property bool canSwitchMode: !running && phaseTickSecs === 0

    readonly property real progress: {
        if (isStopwatch) {
            let fSecs = focusMins * 60;
            return fSecs > 0 ? (elapsed % fSecs) / fSecs : 0;
        }
        return phaseTotal > 0 ? clamp(1.0 - (remaining / phaseTotal), 0.0, 1.0) : 0;
    }

    readonly property string display: {
        let v = isStopwatch ? elapsed : Math.max(0, remaining);
        let h = Math.floor(v / 3600);
        let m = Math.floor((v % 3600) / 60);
        let s = v % 60;
        let mm = m.toString().padStart(2, "0");
        let ss = s.toString().padStart(2, "0");
        if (h > 0) {
            return `${h}:${mm}:${ss}`;
        }
        return `${mm}:${ss}`;
    }

    readonly property string phaseLabel: {
        let fresh = phaseTickSecs === 0 && !running;
        if (phase === "focus") {
            if (mode === "stopwatch") {
                if (running) return Tr.tr("Flowing");
                return fresh ? Tr.tr("Ready to flow") : Tr.tr("Flow paused");
            } else {
                if (running) return Tr.tr("Focusing");
                return fresh ? Tr.tr("Ready to focus") : Tr.tr("Focus paused");
            }
        } else if (phase === "shortBreak") {
            if (running) return Tr.tr("Short break");
            return fresh ? Tr.tr("Break ready") : Tr.tr("Break paused");
        } else if (phase === "longBreak") {
            if (running) return Tr.tr("Big break");
            return fresh ? Tr.tr("Big break ready") : Tr.tr("Break paused");
        }
        return "";
    }

    readonly property string phaseIcon: phase === "focus" ? "timer" : "coffee"

    signal phaseEvent()

    readonly property FileView sessionFile: FileView {
        path: `${Paths.state}/focus_session.json`
        preload: true
        watchChanges: false
        printErrors: false

        onLoaded: root.restoreSnapshot(text())
        onLoadFailed: err => {}
    }

    function enterPhase(newPhase: string, autoRun: bool): void {
        phase = newPhase;
        phaseTickSecs = 0;
        elapsed = 0;
        distractionSecs = 0;
        phaseTotal = baseSecs;
        remaining = baseSecs;
        running = autoRun;
        if (autoRun)
            sessionActive = true;
        syncDnd();
        phaseEvent();
        saveSnapshot();
    }

    function creditFocus(): bool {
        let credited = phaseTickSecs >= (0.5 * focusMins * 60);
        if (credited) {
            cycleCount++;
            FocusLedger.addSession();
        }
        return credited;
    }

    function nextBreak(): string {
        return cycleCount >= cyclesBeforeLongBreak ? "longBreak" : "shortBreak";
    }

    function completePhase(): void {
        if (phase === "focus") {
            creditFocus();
            Audio.playFocusEnd();
            Toaster.toast(Tr.tr("Study session complete"), Tr.tr("Time for a break."), "task_alt", Toast.Info);
            enterPhase(nextBreak(), GlobalConfig.focus.autoPlay);
        } else {
            if (phase === "longBreak")
                cycleCount = 0;
            Audio.playBreakEnd();
            Toaster.toast(Tr.tr("Break finished"), Tr.tr("Ready for your next focus session."), "timer", Toast.Info);
            enterPhase("focus", GlobalConfig.focus.autoPlay);
        }
    }

    function skipPhase(): void {
        if (!sessionActive)
            return;
        if (phase === "focus") {
            creditFocus();
            enterPhase(nextBreak(), true);
        } else {
            if (phase === "longBreak")
                cycleCount = 0;
            enterPhase("focus", true);
        }
    }

    function toggle(): void {
        if (!running && !isStopwatch && remaining <= 0)
            remaining = phaseTotal;
        running = !running;
        if (running)
            sessionActive = true;
        syncDnd();
        phaseEvent();
        saveSnapshot();
    }

    function reset(): void {
        running = false;
        sessionActive = false;
        phase = "focus";
        cycleCount = 0;
        phaseTickSecs = 0;
        elapsed = 0;
        distractionSecs = 0;
        let fSecs = focusMins * 60;
        phaseTotal = fSecs;
        remaining = fSecs;
        syncDnd();
        saveSnapshot();
    }

    function setPhase(p: string): void {
        enterPhase(p, false);
    }

    function setMode(m: string): void {
        if (!canSwitchMode || m === mode)
            return;
        mode = m;
        syncIdle();
        saveSnapshot();
    }

    function setSubject(name: string): void {
        subject = (subject === name) ? "" : name;
        saveSnapshot();
    }

    function extend(): void {
        if (!sessionActive || isStopwatch)
            return;
        remaining += 300;
        phaseTotal += 300;
        saveSnapshot();
    }

    function reduce(): void {
        if (!sessionActive || isStopwatch)
            return;
        remaining = Math.max(60, remaining - 300);
        phaseTotal = Math.max(remaining, phaseTotal - 300);
        saveSnapshot();
    }

    function recordDistractionSecond(appClass: string): void {
        if (running && phase === "focus")
            distractionSecs++;
    }

    function adjust(mins: int): void {
        if (running)
            return;
        if (phase === "shortBreak") {
            GlobalConfig.focus.shortBreakMins = clamp(shortBreakMins + mins, 1, 60);
        } else if (phase === "longBreak") {
            GlobalConfig.focus.longBreakMins = clamp(longBreakMins + mins, 5, 180);
        } else {
            GlobalConfig.focus.focusMins = clamp(focusMins + mins, 5, 180);
        }
        GlobalConfig.save();
        syncIdle();
    }

    function syncIdle(): void {
        if (!running && phaseTickSecs === 0) {
            phaseTotal = baseSecs;
            remaining = baseSecs;
        }
    }

    onFocusMinsChanged: syncIdle()
    onShortBreakMinsChanged: syncIdle()
    onLongBreakMinsChanged: syncIdle()

    function syncDnd(): void {
        if (!GlobalConfig.focus.autoDnd || !sessionActive) {
            releaseDnd();
            return;
        }
        if (running && phase === "focus") {
            PersistentState.doNotDisturb = true;
            dndEngaged = true;
        } else if (dndEngaged) {
            PersistentState.doNotDisturb = false;
            dndEngaged = false;
        }
    }

    function releaseDnd(): void {
        if (dndEngaged) {
            PersistentState.doNotDisturb = false;
            dndEngaged = false;
        }
    }

    onRunningChanged: syncDnd()
    onPhaseChanged: syncDnd()
    onSessionActiveChanged: syncDnd()

    function saveSnapshot(): void {
        let snap = {
            version: 1,
            sessionActive: root.sessionActive,
            running: root.running,
            mode: root.mode,
            phase: root.phase,
            remaining: root.remaining,
            elapsed: root.elapsed,
            distractionSecs: root.distractionSecs,
            phaseTotal: root.phaseTotal,
            phaseTickSecs: root.phaseTickSecs,
            cycleCount: root.cycleCount,
            subject: root.subject,
            dndEngaged: root.dndEngaged,
            savedAt: Date.now()
        };
        sessionFile.setText(JSON.stringify(snap, null, 2));
    }

    function restoreSnapshot(rawText: string): void {
        try {
            if (!rawText || rawText.trim() === "")
                return;
            let snap = JSON.parse(rawText);
            if (typeof snap !== "object" || snap === null)
                return;
            if (snap.version !== 1 || !snap.sessionActive)
                return;
            if (["focus", "shortBreak", "longBreak"].indexOf(snap.phase) === -1)
                return;
            if (["timer", "stopwatch"].indexOf(snap.mode) === -1)
                return;
            if (typeof snap.remaining !== "number" || !isFinite(snap.remaining) || snap.remaining < 0 || snap.remaining > 36000)
                return;

            mode = snap.mode;
            phase = snap.phase;
            remaining = snap.remaining;
            elapsed = snap.elapsed || 0;
            distractionSecs = snap.distractionSecs || 0;
            phaseTotal = snap.phaseTotal || baseSecs;
            phaseTickSecs = snap.phaseTickSecs || 0;
            cycleCount = snap.cycleCount || 0;
            subject = snap.subject || "";
            sessionActive = true;
            dndEngaged = snap.dndEngaged || false;
            running = !!snap.running;

            if (dndEngaged && !(running && phase === "focus")) {
                PersistentState.doNotDisturb = false;
                dndEngaged = false;
            } else {
                syncDnd();
            }

            Toaster.toast(Tr.tr("Focus session restored"), Tr.tr("Resumed previous focus state."), "history", Toast.Info);
        } catch (e) {}
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.running
        onTriggered: {
            if (root.isStopwatch)
                root.elapsed++;
            else
                root.remaining--;
            root.phaseTickSecs++;
            if (root.phase === "focus")
                FocusLedger.addFocusSecs(root.subject, 1);
            if (!root.isStopwatch && root.remaining <= 0)
                root.completePhase();
        }
    }

    Timer {
        id: persistTimer
        interval: 5000
        repeat: true
        running: root.running
        onTriggered: {
            root.saveSnapshot();
            FocusLedger.flush();
        }
    }

    Component.onCompleted: {
        phaseTotal = baseSecs;
        remaining = baseSecs;
    }

    Component.onDestruction: {
        saveSnapshot();
        FocusLedger.flush();
    }

    IpcHandler {
        target: "pomodoro"

        function toggle(): void {
            root.toggle();
        }
        function reset(): void {
            root.reset();
        }
        function skip(): void {
            root.skipPhase();
        }
        function extend(): void {
            root.extend();
        }
        function reduce(): void {
            root.reduce();
        }
        function setMode(m: string): void {
            root.setMode(m);
        }
        function setSubject(s: string): void {
            root.setSubject(s);
        }
        function status(): string {
            return JSON.stringify({
                phase: root.phase,
                mode: root.mode,
                running: root.running,
                remaining: root.remaining,
                elapsed: root.elapsed,
                display: root.display,
                subject: root.subject,
                cycleCount: root.cycleCount,
                completedSessions: root.completedSessions,
                distractionSecs: root.distractionSecs,
                studiedTodaySecs: FocusLedger.todaySecs
            });
        }
    }
}

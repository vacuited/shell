pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.I18n

Singleton {
    id: root

    // Phases: "focus", "shortBreak", "longBreak"
    property string phase: "focus"
    property int focusMins: 25
    property int shortBreakMins: 5
    property int longBreakMins: 15
    property int cyclesBeforeLongBreak: 4

    property int completedSessions: 0
    property int totalFocusedSecsToday: 0
    property bool autoAdvance: false

    readonly property int durationSecs: {
        if (phase === "shortBreak")
            return shortBreakMins * 60;
        if (phase === "longBreak")
            return longBreakMins * 60;
        return focusMins * 60;
    }

    property int remaining: durationSecs
    property bool running: false
    property bool sessionActive: false

    // True only when a Pomodoro session has been explicitly started (and not reset)
    readonly property bool active: sessionActive

    readonly property real progress: durationSecs > 0 ? Math.max(0, Math.min(1, 1 - remaining / durationSecs)) : 0

    readonly property string display: {
        const m = Math.floor(remaining / 60);
        const s = remaining % 60;
        return `${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
    }

    readonly property string phaseLabel: {
        if (remaining <= 0)
            return Tr.tr("Session complete");
        if (phase === "shortBreak")
            return running ? Tr.tr("Short break") : Tr.tr("Break paused");
        if (phase === "longBreak")
            return running ? Tr.tr("Long break") : Tr.tr("Break paused");
        return running ? Tr.tr("Focusing") : (remaining < durationSecs ? Tr.tr("Focus paused") : Tr.tr("Ready to focus"));
    }

    readonly property string phaseIcon: phase === "focus" ? "timer" : "coffee"

    signal phaseEvent()

    function setPhase(newPhase: string): void {
        running = false;
        phase = newPhase;
        remaining = durationSecs;
        if (sessionActive)
            phaseEvent();
    }

    function toggle(): void {
        if (remaining <= 0)
            remaining = durationSecs;
        running = !running;
        if (running)
            sessionActive = true;
        phaseEvent();
    }

    function reset(): void {
        running = false;
        sessionActive = false;
        phase = "focus";
        remaining = durationSecs;
    }

    function skipPhase(): void {
        advancePhase(false);
    }

    function adjust(mins: int): void {
        if (running)
            return;
        if (phase === "shortBreak")
            shortBreakMins = Math.max(1, Math.min(60, shortBreakMins + mins));
        else if (phase === "longBreak")
            longBreakMins = Math.max(1, Math.min(90, longBreakMins + mins));
        else
            focusMins = Math.max(5, Math.min(180, focusMins + mins));
        remaining = durationSecs;
    }

    function advancePhase(completedNaturally: bool): void {
        running = false;
        if (phase === "focus") {
            if (completedNaturally) {
                completedSessions++;
                Toaster.toast(
                    Tr.tr("Focus session complete!"),
                    Tr.tr("Completed %1 focus session(s). Time for a break.").arg(completedSessions),
                    "task_alt",
                    Toast.Info
                );
            }
            if (completedSessions > 0 && completedSessions % cyclesBeforeLongBreak === 0)
                phase = "longBreak";
            else
                phase = "shortBreak";
        } else {
            if (completedNaturally) {
                Toaster.toast(
                    Tr.tr("Break finished"),
                    Tr.tr("Ready for your next focus session."),
                    "timer",
                    Toast.Info
                );
            }
            phase = "focus";
        }
        remaining = durationSecs;
        if (completedNaturally && autoAdvance)
            running = true;
        phaseEvent();
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.running
        onTriggered: {
            if (root.phase === "focus")
                root.totalFocusedSecsToday++;
            root.remaining--;
            if (root.remaining <= 0)
                root.advancePhase(true);
        }
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
        function status(): string {
            return JSON.stringify({
                phase: root.phase,
                running: root.running,
                remaining: root.remaining,
                display: root.display,
                completedSessions: root.completedSessions
            });
        }
    }
}

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import qs.utils

// Architecture:
//   - daemonProc: long-running "hyprsunset -t <K>" process that holds gamma control
//   - ipcProc:    short-lived "hyprctl hyprsunset temperature <K>" for LIVE updates
//   - sunsetStore: persistent FileView + JsonAdapter saving temperature & active to state
//
// When temperature changes while active, we send via IPC (no restart → no flicker).
// The daemon is only restarted when toggling on/off.
Singleton {
    id: root

    readonly property alias temperature: sunsetAdapter.temperature
    readonly property alias active: sunsetAdapter.active
    property bool available: true

    property int _pending: -1  // queued temperature for when ipcProc is busy

    function start(temp): void {
        if (temp !== undefined && temp !== null)
            sunsetAdapter.temperature = temp;
        sunsetAdapter.active = true;
        _save();
        if (daemonProc.running) {
            // Daemon already up — just update temperature via IPC (no flicker)
            _sendIpc(sunsetAdapter.temperature);
        } else {
            // Start daemon with correct temperature baked in
            daemonProc.command = ["hyprsunset", "-t", sunsetAdapter.temperature.toString()];
            daemonProc.running = true;
        }
    }

    function stop(): void {
        sunsetAdapter.active = false;
        sunsetStore.writeAdapter();
        _pending = -1;
        ipcProc.running = false;
        daemonProc.running = false;  // killing daemon resets gamma to identity automatically
    }

    function toggle(temp): void {
        if (sunsetAdapter.active)
            stop();
        else
            start(temp);
    }

    // IPC: queue-based so we never miss the latest value during rapid slider moves
    function _sendIpc(temp: int): void {
        if (ipcProc.running) {
            _pending = temp;   // hyprctl busy → overwrite pending (only latest matters)
        } else {
            _pending = -1;
            ipcProc.command = ["hyprctl", "hyprsunset", "temperature", temp.toString()];
            ipcProc.running = true;
        }
    }

    function _syncDaemon(): void {
        if (!root.available || !sunsetAdapter.active)
            return;
        if (daemonProc.running) {
            _sendIpc(sunsetAdapter.temperature);
        } else {
            daemonProc.command = ["hyprsunset", "-t", sunsetAdapter.temperature.toString()];
            daemonProc.running = true;
        }
    }

    function _save(): void {
        saveTimer.restart();
    }

    Timer {
        id: saveTimer
        interval: 200
        repeat: false
        onTriggered: sunsetStore.writeAdapter()
    }

    FileView {
        id: sunsetStore

        path: `${Paths.state}/sunset.json`
        printErrors: false
        onLoaded: root._syncDaemon()

        JsonAdapter {
            id: sunsetAdapter

            property int temperature: 6000
            property bool active: false
        }
    }

    Component.onCompleted: {
        checkAvailProc.running = true;
    }

    Component.onDestruction: {
        if (saveTimer.running) {
            saveTimer.stop();
            sunsetStore.writeAdapter();
        }
    }

    Process {
        id: checkAvailProc
        command: ["sh", "-c", "command -v hyprsunset >/dev/null 2>&1"]
        onExited: code => { // qmllint disable signal-handler-parameters
            root.available = (code === 0);
            root._syncDaemon();
        }
    }

    // Long-running daemon — holds gamma control for the session
    Process {
        id: daemonProc
        stdout: StdioCollector {}
        stderr: StdioCollector { id: daemonErr }

        onExited: code => { // qmllint disable signal-handler-parameters
            if (code !== 0 && sunsetAdapter.active) {
                console.error("[HyprSunset] daemon crashed: " + daemonErr.text);
                sunsetAdapter.active = false;
                sunsetStore.writeAdapter();
            }
        }
    }

    // Short-lived hyprctl IPC — updates temperature without restarting daemon
    Process {
        id: ipcProc
        stdout: StdioCollector {}
        stderr: StdioCollector { id: ipcErr }

        onExited: code => { // qmllint disable signal-handler-parameters
            if (code !== 0)
                console.error("[HyprSunset] IPC failed: " + ipcErr.text);

            // Flush queued temperature (latest value from rapid slider moves)
            if (root._pending >= 0) {
                const t = root._pending;
                root._pending = -1;
                ipcProc.command = ["hyprctl", "hyprsunset", "temperature", t.toString()];
                ipcProc.running = true;
            }
        }
    }
}

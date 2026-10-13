pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config

Singleton {
    id: root

    property string profile: "quiet" // "quiet" | "cool" | "balanced" | "performance"
    property string fanMode: "auto"  // "auto" | "max"
    property int fan1Rpm: 0
    property int fan2Rpm: 0
    property int refreshRate: 60    // 60 | 144
    property int cpuTemp: 0
    property int gpuTemp: 0
    property real gpuPower: 0.0
    property string gpuState: "D3 Sleep"
    property bool turbo: true
    property bool isBusy: false

    function refreshStatus(): void {
        if (!statusProc.running) {
            statusProc.running = true;
        }
    }

    function setProfile(newProfile: string): void {
        if (!newProfile || newProfile === "") return;
        profile = newProfile;
        writeProc.command = ["caelestia", "hardware", "profile", newProfile];
        writeProc.running = true;
    }

    function setFanMode(newMode: string): void {
        if (!newMode || newMode === "") return;
        fanMode = newMode;
        writeProc.command = ["caelestia", "hardware", "fan", newMode];
        writeProc.running = true;
    }

    function setRefreshRate(hz: int): void {
        if (hz !== 60 && hz !== 144) return;
        refreshRate = hz;
        refreshProc.command = ["caelestia", "hardware", "refresh", hz.toString()];
        refreshProc.running = true;
    }

    function setTurbo(enabled: bool): void {
        turbo = enabled;
        writeProc.command = ["caelestia", "hardware", "turbo", enabled ? "on" : "off"];
        writeProc.running = true;
    }

    Process {
        id: statusProc
        command: ["caelestia", "hardware", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    if (!writeProc.running) {
                        if (data.profile) root.profile = data.profile;
                        if (data.fanMode) root.fanMode = data.fanMode;
                        if (data.turbo !== undefined) root.turbo = Boolean(data.turbo);
                    }
                    if (data.fan1Rpm !== undefined) root.fan1Rpm = Number(data.fan1Rpm);
                    if (data.fan2Rpm !== undefined) root.fan2Rpm = Number(data.fan2Rpm);
                    if (data.cpuTemp !== undefined) root.cpuTemp = Math.round(Number(data.cpuTemp));
                    if (data.gpuTemp !== undefined) root.gpuTemp = Math.round(Number(data.gpuTemp));
                    if (data.gpuPower !== undefined) root.gpuPower = Number(data.gpuPower);
                    if (data.gpuState !== undefined) root.gpuState = String(data.gpuState);
                    if (!refreshProc.running && data.refreshRate !== undefined) {
                        root.refreshRate = Math.round(Number(data.refreshRate));
                    }
                } catch (e) {
                    // Ignore parse error during transitions
                }
            }
        }
    }

    Process {
        id: writeProc
        onExited: (exitCode) => {
            root.isBusy = false;
            refreshTimer.restart();
        }
        onStarted: {
            root.isBusy = true;
        }
    }

    Process {
        id: refreshProc
        onExited: (exitCode) => {
            refreshTimer.restart();
        }
    }

    Timer {
        id: refreshTimer
        interval: 300
        repeat: false
        onTriggered: root.refreshStatus()
    }

    Timer {
        id: pollTimer
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.refreshStatus()
    }

    Component.onCompleted: {
        root.refreshStatus();
    }
}

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
    property bool isBusy: false

    readonly property string helperPath: {
        return "/usr/local/bin/caelestia-hardware-helper";
    }

    readonly property string fallbackHelperPath: {
        return Quickshell.env("HOME") + "/retroistickx/projects/vacuited-shell/scripts/caelestia-hardware-helper";
    }

    function refreshStatus(): void {
        if (!statusProc.running) {
            statusProc.running = true;
        }
    }

    function setProfile(newProfile: string): void {
        if (!newProfile || newProfile === "") return;
        profile = newProfile;
        writeProc.command = ["pkexec", helperPath, "set-profile", newProfile];
        writeProc.running = true;
    }

    function setFanMode(newMode: string): void {
        if (!newMode || newMode === "") return;
        fanMode = newMode;
        writeProc.command = ["pkexec", helperPath, "set-fan", newMode];
        writeProc.running = true;
    }

    function setRefreshRate(hz: int): void {
        if (hz !== 60 && hz !== 144) return;
        refreshRate = hz;
        const script = "output=\"eDP-1\"; " +
            "if command -v wlr-randr >/dev/null 2>&1; then " +
                "wlr_out=$(wlr-randr 2>/dev/null | awk '/^([a-zA-Z0-9_-]+) \"/ {print $1; exit}'); " +
                "[ -n \"$wlr_out\" ] && output=\"$wlr_out\"; " +
            "fi; " +
            "if [ \"" + hz + "\" = \"144\" ]; then " +
                "mode=$(wlr-randr --output \"$output\" 2>/dev/null | awk '$0 ~ \"144\\\\.\" {gsub(\" px,\", \"\", $1); print $1 \"@\" $3 \"Hz\"; exit}'); " +
                "if [ -n \"$mode\" ]; then wlr-randr --output \"$output\" --mode \"$mode\" 2>/dev/null || true; else wlr-randr --output \"$output\" --preferred 2>/dev/null || true; fi; " +
            "else " +
                "mode=$(wlr-randr --output \"$output\" 2>/dev/null | awk '$0 ~ \"60\\\\.\" {gsub(\" px,\", \"\", $1); print $1 \"@\" $3 \"Hz\"; exit}'); " +
                "if [ -n \"$mode\" ]; then wlr-randr --output \"$output\" --mode \"$mode\" 2>/dev/null || true; fi; " +
            "fi; " +
            "cava_conf=\"$HOME/.config/cava/config\"; " +
            "if [ -f \"$cava_conf\" ]; then sed -i \"s/^framerate = .*/framerate = " + hz + "/\" \"$cava_conf\" 2>/dev/null || true; pkill -USR2 cava 2>/dev/null || true; fi";

        refreshProc.command = ["sh", "-c", script];
        refreshProc.running = true;
    }

    Process {
        id: statusProc
        command: ["sh", "-c", "hp_data=$(\"$HOME/retroistickx/projects/vacuited-shell/scripts/caelestia-hardware-helper\" status 2>/dev/null || true); hz_raw=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0].refreshRate // 60' 2>/dev/null || echo 60); hz=$(printf \"%.0f\" \"$hz_raw\" 2>/dev/null || echo 60); echo \"$hp_data\" | jq --argjson hz \"$hz\" '. + {refreshRate: $hz}' 2>/dev/null || echo \"$hp_data\""]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    if (!writeProc.running) {
                        if (data.profile) root.profile = data.profile;
                        if (data.fanMode) root.fanMode = data.fanMode;
                    }
                    if (data.fan1Rpm !== undefined) root.fan1Rpm = Number(data.fan1Rpm);
                    if (data.fan2Rpm !== undefined) root.fan2Rpm = Number(data.fan2Rpm);
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

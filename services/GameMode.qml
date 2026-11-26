pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import Caelestia.State
import qs.services
import qs.utils

Singleton {
    id: root

    property bool enabled: RuntimeState.gameMode

    onEnabledChanged: {
        if (RuntimeState.gameMode !== enabled)
            RuntimeState.gameMode = enabled;
    }

    property bool _autoEnabled: false
    readonly property bool _autoWatchActive: GlobalConfig.utilities.gameMode.autoEnable && GlobalConfig.utilities.gameMode.autoEnableRegexes.length > 0

    function evaluateAutoEnable(): void {
        const regexes = GlobalConfig.utilities.gameMode.autoEnableRegexes;
        if (!GlobalConfig.utilities.gameMode.autoEnable || regexes.length === 0) {
            if (_autoEnabled) {
                _autoEnabled = false;
                RuntimeState.gameMode = false;
            }
            return;
        }

        let isRunning = false;
        for (const toplevel of Hyprland.toplevels.values) {
            if (toplevel.lastIpcObject && Strings.testRegexList(regexes, toplevel.lastIpcObject.class)) {
                isRunning = true;
                break;
            }
        }

        if (_autoEnabled !== isRunning) {
            _autoEnabled = isRunning;
            RuntimeState.gameMode = isRunning;
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: root._autoWatchActive
        onTriggered: root.evaluateAutoEnable()
    }

    Connections {
        target: Hyprland.toplevels
        enabled: root._autoWatchActive
        function onValuesChanged(): void { root.evaluateAutoEnable(); }
    }

    Connections {
        target: GlobalConfig.utilities.gameMode
        function onAutoEnableChanged(): void { root.evaluateAutoEnable(); }
        function onAutoEnableRegexesChanged(): void { root.evaluateAutoEnable(); }
    }

    function applyGameMode(): void {
        const gameModeConfig = GlobalConfig.utilities.gameMode;
        const baseOpts = gameModeConfig.options || {};
        let options = Object.assign({}, baseOpts);
        if (!gameModeConfig.disableHyprlandAnimations)
            delete options["animations:enabled"];
        else if (options["animations:enabled"] === undefined)
            options["animations:enabled"] = 0;

        if (!gameModeConfig.disableHyprlandShadows)
            delete options["decoration:shadow:enabled"];
        else if (options["decoration:shadow:enabled"] === undefined)
            options["decoration:shadow:enabled"] = 0;

        if (!gameModeConfig.disableHyprlandBlur)
            delete options["decoration:blur:enabled"];
        else if (options["decoration:blur:enabled"] === undefined)
            options["decoration:blur:enabled"] = 0;

        if (!gameModeConfig.disableHyprlandGaps) {
            delete options["general:gaps_in"];
            delete options["general:gaps_out"];
            delete options["general:border_size"];
            delete options["decoration:rounding"];
        } else {
            if (options["general:gaps_in"] === undefined) options["general:gaps_in"] = 0;
            if (options["general:gaps_out"] === undefined) options["general:gaps_out"] = 0;
            if (options["general:border_size"] === undefined) options["general:border_size"] = 1;
            if (options["decoration:rounding"] === undefined) options["decoration:rounding"] = 0;
        }
        if (options["general:allow_tearing"] === undefined)
            options["general:allow_tearing"] = 1;

        if (gameModeConfig.disableWindowTransparency) {
            options["decoration:active_opacity"] = 1;
            options["decoration:inactive_opacity"] = 1;
            options["decoration:fullscreen_opacity"] = 1;
        }

        Hypr.extras.applyOptions(options);

        if (gameModeConfig.disableWindowTransparency) {
            if (Hypr.usingLua) {
                Hypr.extras.batchMessage([`eval hl.window_rule({ match = { class = ".*" }, opaque = true })`]);
            } else {
                Hypr.extras.batchMessage([`keyword windowrule opaque on, match:class .*`]);
            }
        }
    }

    function syncState(enableDisable: bool): void {
        if (RuntimeState.gameMode) {
            root.applyGameMode();
            if (GlobalConfig.utilities.toasts.gameModeChanged)
                Toaster.toast(Tr.tr("Game mode enabled"), Tr.tr("Disabled Hyprland animations, blur, gaps and shadows"), "gamepad");
        } else if (enableDisable) {
            Hypr.extras.message("reload");
            if (GlobalConfig.utilities.toasts.gameModeChanged)
                Toaster.toast(Tr.tr("Game mode disabled"), Tr.tr("Hyprland settings restored"), "gamepad");
        }
    }

    Component.onCompleted: syncState(false)

    Connections {
        function onGameModeChanged(): void {
            if (root.enabled !== RuntimeState.gameMode)
                root.enabled = RuntimeState.gameMode;
            root.syncState(true);
        }

        target: RuntimeState
    }

    Connections {
        function onConfigReloaded(): void {
            if (RuntimeState.gameMode)
                root.applyGameMode();
        }

        target: Hypr
    }

    IpcHandler {
        function isEnabled(): bool {
            return RuntimeState.gameMode;
        }

        function toggle(): void {
            RuntimeState.gameMode = !RuntimeState.gameMode;
        }

        function enable(): void {
            RuntimeState.gameMode = true;
        }

        function disable(): void {
            RuntimeState.gameMode = false;
        }

        target: "gameMode"
    }
}

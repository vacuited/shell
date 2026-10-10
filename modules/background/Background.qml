pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import qs.utils

Variants {
    model: Screens.screens.filter(s => GlobalConfig.forScreen(s.name).background.enabled)

    StyledWindow {
        id: win

        required property ShellScreen modelData
        readonly property alias wallpaperLoader: wallpaper

        screen: modelData
        name: "background"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: (contentItem.Config.background.wallpaperEnabled && !(wallpaper.item && wallpaper.item.weRunning)) ? WlrLayer.Background : WlrLayer.Bottom
        color: contentItem.Config.background.wallpaperEnabled && !(wallpaper.item && wallpaper.item.weRunning) ? "black" : "transparent"
        surfaceFormat.opaque: false

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        ShellState.ComponentRef {
            screen: win.screen
            slot: "background"
            component: win
        }

        property bool cleanupDone: false

        Process {
            id: cleanupProc
            command: [
                "sh", "-c",
                'PIDFILE="$1/engine_$2.pid"; if [ -f "$PIDFILE" ]; then OLD_PID=$(cat "$PIDFILE" 2>/dev/null); rm -f "$PIDFILE"; if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then CMD=$(tr "\\0" " " < "/proc/$OLD_PID/cmdline" 2>/dev/null || true); if echo "$CMD" | grep -q "linux-wallpaperengine" && echo "$CMD" | grep -q -- "--layer" && echo "$CMD" | grep -q -- "$2"; then kill "$OLD_PID" 2>/dev/null || true; fi; fi; fi',
                "sh",
                Paths.state + "/wallpaper",
                win.modelData.name
            ]
            running: true
            onRunningChanged: {
                if (!running) cleanupDone = true;
            }
            onExited: {
                cleanupDone = true;
            }
        }

        Item {
            id: behindClock

            anchors.fill: parent

            Loader {
                id: wallpaper

                asynchronous: true

                anchors.fill: parent
                active: Config.background.wallpaperEnabled
                opacity: (item && item.weSurfaceVisible) ? 0 : 1

                sourceComponent: Wallpaper {
                    screen: win.modelData
                    weEngineReady: weProc.engineReady
                    weFailed: weProc.weFailed
                }
            }

            Timer {
                id: engineReadyTimer
                interval: weProc.engineReadyDelayMs
                repeat: false
                onTriggered: {
                    if (weProc.alive) {
                        weProc.engineReady = true;
                    }
                }
            }

            Timer {
                id: watchdogTimer
                interval: 2000
                repeat: false
                onTriggered: {
                    if (weProc.stopping && weProc.alive) {
                        console.warn("linux-wallpaperengine stop timed out, sending SIGKILL");
                        weProc.signal(9);
                    }
                }
            }

            Process {
                id: weProc
                property string weDir: Wallpapers.committedWeDir
                property bool weRunning: wallpaper.item ? wallpaper.item.weRunning : false
                property bool weFailed: false
                property bool stopping: false
                property bool alive: false
                property bool gotExit: false
                property bool engineReady: false
                property int engineReadyDelayMs: 1200
                property int lastPid: 0
                property bool isProcessPaused: false

                function updatePauseState(): void {
                    if (!alive || lastPid <= 0 || stopping || !engineReady)
                        return;

                    let shouldPause = WallpaperPauser.paused && !weFailed;
                    if (shouldPause && !isProcessPaused) {
                        isProcessPaused = true;
                        Quickshell.execDetached(["kill", "-STOP", lastPid.toString()]);
                    } else if (!shouldPause && isProcessPaused) {
                        isProcessPaused = false;
                        Quickshell.execDetached(["kill", "-CONT", lastPid.toString()]);
                    }
                }

                onEngineReadyChanged: {
                    if (engineReady) {
                        updatePauseState();
                    }
                }

                onStoppingChanged: {
                    if (stopping && isProcessPaused && lastPid > 0) {
                        isProcessPaused = false;
                        Quickshell.execDetached(["kill", "-CONT", lastPid.toString()]);
                    }
                }

                readonly property bool desiredRun: cleanupDone && weRunning && weDir !== "" && contentItem.Config.background.wallpaperEnabled && !weFailed
                readonly property bool shouldRun: desiredRun && !stopping

                onShouldRunChanged: {
                    if (shouldRun) {
                        gotExit = false;
                    }
                }

                onDesiredRunChanged: {
                    if (!desiredRun && (weProc.running || alive)) {
                        stopping = true;
                        watchdogTimer.restart();
                    }
                }

                command: {
                    let bin = Quickshell.env("CAELESTIA_WE_BIN") || "linux-wallpaperengine";
                    let cmd = [bin, "--screen-root", win.modelData.name, "--layer", "background"];
                    if (Wallpapers.weSilent) {
                        cmd.push("--silent");
                    } else {
                        cmd.push("--volume", Math.round(Wallpapers.weVolume * 100).toString());
                    }
                    cmd.push(weDir);
                    return cmd;
                }

                running: shouldRun

                property int lastNonce: Wallpapers.selectNonce
                onLastNonceChanged: {
                    weFailed = false;
                }

                onWeFailedChanged: {
                    if (weFailed && isProcessPaused && lastPid > 0) {
                        isProcessPaused = false;
                        Quickshell.execDetached(["kill", "-CONT", lastPid.toString()]);
                    }
                }

                onWeDirChanged: {
                    weFailed = false;
                    engineReady = false;
                    engineReadyTimer.stop();
                    if (weProc.running || alive) {
                        stopping = true;
                        watchdogTimer.restart();
                    }
                }

                onStarted: {
                    alive = true;
                    gotExit = false;
                    engineReady = false;
                    engineReadyTimer.restart();
                    if (processId) {
                        lastPid = processId;
                        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && printf "%s\\n" "$2" > "$1/engine_$3.pid"', "sh", Paths.state + "/wallpaper", lastPid.toString(), win.modelData.name]);
                    }
                }

                onProcessIdChanged: {
                    if (processId && running && lastPid !== processId) {
                        lastPid = processId;
                        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && printf "%s\\n" "$2" > "$1/engine_$3.pid"', "sh", Paths.state + "/wallpaper", lastPid.toString(), win.modelData.name]);
                    }
                }

                onRunningChanged: {
                    if (!running) {
                        engineReadyTimer.stop();
                        engineReady = false;
                        if (!gotExit) {
                            console.warn("linux-wallpaperengine failed to start");
                            weFailed = true;
                            stopping = false;
                        }
                    }
                }

                onExited: (exitCode, exitStatus) => {
                    isProcessPaused = false;
                    alive = false;
                    gotExit = true;
                    watchdogTimer.stop();
                    engineReadyTimer.stop();
                    engineReady = false;
                    const exitedPid = lastPid;
                    lastPid = 0;

                    if (stopping) {
                        Qt.callLater(() => {
                            stopping = false;
                        });
                    } else if (weRunning && contentItem.Config.background.wallpaperEnabled) {
                        console.warn("linux-wallpaperengine exited unexpectedly. Code:", exitCode, "Status:", exitStatus);
                        weFailed = true;
                    }

                    if (exitedPid > 0 && (!desiredRun || !weRunning || weFailed)) {
                        Quickshell.execDetached(["sh", "-c", 'PIDFILE="$1/engine_$2.pid"; if [ -f "$PIDFILE" ] && [ "$(cat "$PIDFILE" 2>/dev/null)" = "$3" ]; then rm -f "$PIDFILE"; fi', "sh", Paths.state + "/wallpaper", win.modelData.name, exitedPid.toString()]);
                    }
                }

            }

            Connections {
                target: WallpaperPauser
                function onPausedChanged() {
                    weProc.updatePauseState();
                }
            }


            Visualiser {
                anchors.fill: parent
                screen: win.modelData
                wallpaper: wallpaper
                z: 2
            }
        }

        Loader {
            id: clockLoader

            readonly property int clockBarZone: Visibilities.bars.get(win.modelData.name)?.exclusiveZone ?? (Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.small, Config.border.thickness))
            readonly property int clockBaseMargin: Tokens.padding.extraLargeIncreased

            asynchronous: true
            active: Config.background.desktopClock.enabled

            anchors.margins: clockBaseMargin
            anchors.leftMargin: Config.bar.position === "left" ? clockBaseMargin + clockBarZone : clockBaseMargin
            anchors.rightMargin: Config.bar.position === "right" ? clockBaseMargin + clockBarZone : clockBaseMargin
            anchors.topMargin: Config.bar.position === "top" ? clockBaseMargin + clockBarZone : clockBaseMargin
            anchors.bottomMargin: Config.bar.position === "bottom" ? clockBaseMargin + clockBarZone : clockBaseMargin

            anchors.horizontalCenterOffset: {
                if (Config.bar.position === "left") return clockBarZone / 2;
                if (Config.bar.position === "right") return -clockBarZone / 2;
                return 0;
            }
            anchors.verticalCenterOffset: {
                if (Config.bar.position === "top") return clockBarZone / 2;
                if (Config.bar.position === "bottom") return -clockBarZone / 2;
                return 0;
            }

            state: Config.background.desktopClock.position
            states: [
                State {
                    name: "top-left"

                    AnchorChanges {
                        target: clockLoader
                        anchors.top: parent.top
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "top-center"

                    AnchorChanges {
                        target: clockLoader
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "top-right"

                    AnchorChanges {
                        target: clockLoader
                        anchors.top: parent.top
                        anchors.right: parent.right
                    }
                },
                State {
                    name: "middle-left"

                    AnchorChanges {
                        target: clockLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "middle-center"

                    AnchorChanges {
                        target: clockLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "middle-right"

                    AnchorChanges {
                        target: clockLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                    }
                },
                State {
                    name: "bottom-left"

                    AnchorChanges {
                        target: clockLoader
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "bottom-center"

                    AnchorChanges {
                        target: clockLoader
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "bottom-right"

                    AnchorChanges {
                        target: clockLoader
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                    }
                }
            ]

            transitions: Transition {
                AnchorAnim {}
            }

            sourceComponent: DesktopClock {
                wallpaper: behindClock
                absX: clockLoader.x
                absY: clockLoader.y
            }
        }

        Loader {
            id: lyricsLoader

            readonly property int lyricsBarZone: Visibilities.bars.get(win.modelData.name)?.exclusiveZone ?? (Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.small, Config.border.thickness))
            readonly property int lyricsBaseMargin: Tokens.padding.large * 2

            asynchronous: true
            active: Config.background.desktopLyrics.enabled && !Config.background.desktopLyrics.overlay && !(GameMode.enabled && GlobalConfig.utilities.gameMode.disableDesktopLyrics)

            anchors.margins: lyricsBaseMargin
            anchors.leftMargin: Config.bar.position === "left" ? lyricsBaseMargin + lyricsBarZone : lyricsBaseMargin
            anchors.rightMargin: Config.bar.position === "right" ? lyricsBaseMargin + lyricsBarZone : lyricsBaseMargin
            anchors.topMargin: Config.bar.position === "top" ? lyricsBaseMargin + lyricsBarZone : lyricsBaseMargin
            anchors.bottomMargin: Config.bar.position === "bottom" ? lyricsBaseMargin + lyricsBarZone : lyricsBaseMargin

            anchors.horizontalCenterOffset: {
                if (Config.bar.position === "left") return lyricsBarZone / 2;
                if (Config.bar.position === "right") return -lyricsBarZone / 2;
                return 0;
            }
            anchors.verticalCenterOffset: {
                if (Config.bar.position === "top") return lyricsBarZone / 2;
                if (Config.bar.position === "bottom") return -lyricsBarZone / 2;
                return 0;
            }

            state: Config.background.desktopLyrics.position
            states: [
                State {
                    name: "top-left"

                    AnchorChanges {
                        target: lyricsLoader
                        anchors.top: parent.top
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "top-center"

                    AnchorChanges {
                        target: lyricsLoader
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "top-right"

                    AnchorChanges {
                        target: lyricsLoader
                        anchors.top: parent.top
                        anchors.right: parent.right
                    }
                },
                State {
                    name: "middle-left"

                    AnchorChanges {
                        target: lyricsLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "middle-center"

                    AnchorChanges {
                        target: lyricsLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "middle-right"

                    AnchorChanges {
                        target: lyricsLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                    }
                },
                State {
                    name: "bottom-left"

                    AnchorChanges {
                        target: lyricsLoader
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "bottom-center"

                    AnchorChanges {
                        target: lyricsLoader
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "bottom-right"

                    AnchorChanges {
                        target: lyricsLoader
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                    }
                }
            ]

            transitions: Transition {
                AnchorAnim {}
            }

            sourceComponent: DesktopLyrics {
                screen: modelData
                wallpaper: behindClock
                absX: lyricsLoader.x
                absY: lyricsLoader.y
            }
        }
    }
}

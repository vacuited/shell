pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Column {
    id: root

    required property ScreenState screenState

    readonly property string defaultSessionGif: GlobalConfig.paths.descriptorFor("sessionGif")?.defaultValue ?? "root:/assets/kurukuru.gif"
    readonly property string rawSessionGif: (Config.paths.sessionGif || "").trim()
    readonly property bool useVacuitedLogo: rawSessionGif === "" || rawSessionGif === "vacuited" || rawSessionGif === "root:/assets/logo.svg" || rawSessionGif === defaultSessionGif
    readonly property string mascotPath: useVacuitedLogo ? "" : Paths.absolutePath(rawSessionGif)

    padding: Tokens.padding.large
    rightPadding: CUtils.clamp(padding - Config.border.thickness, 0, padding)
    spacing: Tokens.spacing.large

    Repeater {
        id: topButtonsRepeater

        model: Config.session.buttons.slice(0, Math.min(2, Config.session.buttons.length))

        SessionButton {
            id: topBtn

            required property var modelData
            required property int index

            icon: modelData.icon
            command: modelData.command

            Component.onCompleted: {
                if (index === 0)
                    topBtn.forceActiveFocus();
            }

            Connections {
                function onLauncherChanged(): void {
                    if (index === 0 && !root.screenState.launcher)
                        topBtn.forceActiveFocus();
                }

                target: root.screenState
            }

            KeyNavigation.up: index > 0 ? topButtonsRepeater.itemAt(index - 1) : null
            KeyNavigation.down: index < topButtonsRepeater.count - 1
                ? topButtonsRepeater.itemAt(index + 1)
                : (bottomButtonsRepeater.count > 0 ? bottomButtonsRepeater.itemAt(0) : null)
        }
    }

    Loader {
        active: root.useVacuitedLogo || root.mascotPath !== ""
        sourceComponent: root.useVacuitedLogo
            ? vacuitedEmblemComp
            : (/\.(gif|webp|apng)(\?.*)?$/i.test(root.mascotPath) ? animatedEmblemComp : staticEmblemComp)

        Component {
            id: vacuitedEmblemComp

            Logo {
                implicitWidth: Tokens.sizes.session.button
                implicitHeight: Tokens.sizes.session.button
            }
        }

        Component {
            id: animatedEmblemComp

            AnimatedImage {
                width: Tokens.sizes.session.button
                height: Tokens.sizes.session.button
                sourceSize.width: width * ((QsWindow.window as QsWindow)?.devicePixelRatio ?? 1)
                playing: visible
                asynchronous: true
                speed: Config.general.sessionGifSpeed
                source: "file://" + root.mascotPath
                fillMode: AnimatedImage.PreserveAspectFit
            }
        }

        Component {
            id: staticEmblemComp

            Image {
                width: Tokens.sizes.session.button
                height: Tokens.sizes.session.button
                sourceSize.width: width * ((QsWindow.window as QsWindow)?.devicePixelRatio ?? 1)
                sourceSize.height: height * ((QsWindow.window as QsWindow)?.devicePixelRatio ?? 1)
                asynchronous: true
                smooth: true
                mipmap: true
                source: "file://" + root.mascotPath
                fillMode: Image.PreserveAspectFit
            }
        }
    }

    Repeater {
        id: bottomButtonsRepeater

        model: Config.session.buttons.length > 2 ? Config.session.buttons.slice(2) : []

        SessionButton {
            required property var modelData
            required property int index

            icon: modelData.icon
            command: modelData.command

            KeyNavigation.up: index === 0
                ? (topButtonsRepeater.count > 0 ? topButtonsRepeater.itemAt(topButtonsRepeater.count - 1) : null)
                : bottomButtonsRepeater.itemAt(index - 1)
            KeyNavigation.down: index < bottomButtonsRepeater.count - 1
                ? bottomButtonsRepeater.itemAt(index + 1)
                : null
        }
    }

    component SessionButton: IconButton {
        id: button

        required property list<string> command

        function exec(): void {
            root.screenState.session = false;
            if (!SessionManager.exec(command)) {
                if (command.length > 0) {
                    const exe = String(command[0]);
                    if (exe === "hyprshutdown" || exe.endsWith("/hyprshutdown")) {
                        const postIdx = command.indexOf("--post-cmd");
                        const fallbackCmd = (postIdx !== -1 && postIdx + 1 < command.length) ? command[postIdx + 1] : "hyprctl dispatch exit";
                        Quickshell.execDetached([
                            "sh", "-c",
                            'if [ -x "$1" ] || command -v "$1" >/dev/null 2>&1; then exec "$@"; elif command -v hyprshutdown >/dev/null 2>&1; then shift; exec hyprshutdown "$@"; else eval "$CAELESTIA_FALLBACK"; fi',
                            "sh", ...command
                        ], {
                            environment: { "CAELESTIA_FALLBACK": fallbackCmd }
                        });
                        return;
                    }
                    const hasShellOp = command.some(arg => arg === "&&" || arg === "||" || arg === ";" || arg === "|" || arg === ">" || arg === "<");
                    if (hasShellOp || command.length === 1) {
                        Quickshell.execDetached(["sh", "-c", command.join(" ")]);
                    } else {
                        Quickshell.execDetached(command);
                    }
                }
            }
        }

        implicitWidth: Tokens.sizes.session.button
        implicitHeight: Tokens.sizes.session.button

        inactiveColour: activeFocus ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer
        inactiveOnColour: activeFocus ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
        radius: pressed ? Tokens.rounding.medium : activeFocus ? Tokens.rounding.extraLarge : Tokens.rounding.largeIncreased
        font: Tokens.font.icon.builders.large.scale(1.3).build()
        onClicked: exec()

        Keys.onEnterPressed: exec()
        Keys.onReturnPressed: exec()
        Keys.onEscapePressed: root.screenState.session = false
        Keys.onPressed: event => {
            if (!Config.session.vimKeybinds)
                return;

            if (event.modifiers & Qt.ControlModifier) {
                if ((event.key === Qt.Key_J || event.key === Qt.Key_N) && KeyNavigation.down) {
                    KeyNavigation.down.focus = true;
                    event.accepted = true;
                } else if ((event.key === Qt.Key_K || event.key === Qt.Key_P) && KeyNavigation.up) {
                    KeyNavigation.up.focus = true;
                    event.accepted = true;
                }
            } else if (event.key === Qt.Key_Tab && KeyNavigation.down) {
                KeyNavigation.down.focus = true;
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                if (KeyNavigation.up) {
                    KeyNavigation.up.focus = true;
                    event.accepted = true;
                }
            }
        }
    }
}

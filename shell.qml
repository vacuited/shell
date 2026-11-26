pragma ComponentBehavior: Bound

//@ pragma Env QS_CRASHREPORT_URL=https://github.com/vacuited/shell/issues/new?template=crash.yml
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import QtQml
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Caelestia.Config
import qs.components.containers
import qs.daemons
import qs.modules
import qs.modules.areapicker
import qs.modules.background
import qs.modules.drawers
import qs.modules.lock
import qs.modules.shimeji
import qs.services
import qs.utils

ShellRoot {
    id: root

    settings.watchFiles: false

    Component.onCompleted: {
        // Force certain singletons to load on shell init instead of lazily
        IdleInhibitor;
        GameMode;
        Notifs;
        Players;
        Brightness;
        HyprSunset;
        ScreenTime;
        Updates;

        if (GlobalConfig.utilities.vpn.enabled)
            VPN;
        if (GlobalConfig.services.arpcEnabled)
            DiscordRPC;

        Qt.callLater(() => {
            Weather.reload();
        });
    }

    FontLoader {
        source: Quickshell.shellPath("assets/google-sans-flex/GoogleSansFlex-VariableFont_GRAD,ROND,opsz,slnt,wdth,wght.ttf")
    }

    Binding {
        target: ShellState
        property: "shellRoot"
        value: root
    }

    // Modules
    Background {}
    DesktopLyricsOverlay {}
    BadAppleOverlay {}

    Drawers {}
    AreaPicker {}
    Lock {
        id: lock
    }

    property QtObject _polkitInstance: null

    Process {
        id: polkitCheckProc

        running: true
        command: [
            "sh",
            "-c",
            "if pgrep -u \"$(id -u)\" -f '([h]yprpolkitagent|[p]olkit-kde-authentication-agent-1|[p]olkit-gnome-authentication-agent-1|[l]xpolkit|[l]xqt-policykit-agent|[m]ate-polkit|[x]fce-polkit|[s]oteria|[p]antheon-agent-polkit|[p]olkit-dumb-agent)' >/dev/null 2>&1; then exit 1; fi; dirs=\"/usr/lib/qt6/qml:/usr/lib64/qt6/qml:${QML_IMPORT_PATH:-}:${QML2_IMPORT_PATH:-}\"; for qp in qtpaths6 qtpaths-qt6 /usr/lib/qt6/bin/qtpaths6 /usr/lib64/qt6/bin/qtpaths6; do if command -v \"$qp\" >/dev/null 2>&1 || [ -x \"$qp\" ]; then qdir=\"$(\"$qp\" --query QT_INSTALL_QML 2>/dev/null || true)\"; [ -n \"$qdir\" ] && dirs=\"$dirs:$qdir\"; break; fi; done; oldifs=\"$IFS\"; IFS=:; for d in $dirs; do [ -n \"$d\" ] && [ -f \"$d/Quickshell/Services/Polkit/qmldir\" ] && exit 0; done; IFS=\"$oldifs\"; [ -e /etc/NIXOS ] && exit 0; exit 2"
        ]

        onExited: code => {
            if (code === 0) {
                const comp = Qt.createComponent(Qt.resolvedUrl("modules/polkit/PolkitModule.qml"), Component.PreferSynchronous);
                if (comp.status === Component.Ready) {
                    root._polkitInstance = comp.createObject(root);
                    if (!root._polkitInstance)
                        console.warn("[Polkit] Failed to instantiate PolkitModule");
                } else {
                    console.warn("[Polkit] Skipping built-in polkit agent:", comp.errorString().trim());
                }
            } else if (code === 1) {
                console.info("[Polkit] External polkit agent detected; disabling built-in agent");
            } else {
                console.info("[Polkit] Quickshell.Services.Polkit unavailable; disabling built-in agent");
            }
        }
    }

    Variants {
        model: Quickshell.screens.filter(s => (GlobalConfig.shimeji?.enabled ?? false) && (GlobalConfig.shimeji?.path?.length ?? 0) > 0 && !Strings.testRegexList(GlobalConfig.shimeji?.excludedScreens ?? [], s.name))

        Shimeji {
            shimejiCount: GlobalConfig.shimeji?.count ?? 1
        }
    }

    // Daemons
    Shortcuts {}
    BatteryMonitor {}
    IdleMonitors {
        lock: lock
    }
    BluetoothReconnect {}

    // Force service initialization
    property var _gameModeInit: GameMode
    property var _pipInit: PipManager
    property var _systemTrayInit: SystemTray

    Connections {
        target: GlobalConfig.services
        function onArpcEnabledChanged(): void {
            if (GlobalConfig.services.arpcEnabled)
                DiscordRPC;
        }
    }
}

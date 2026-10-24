pragma ComponentBehavior: Bound

//@ pragma Env QS_CRASHREPORT_URL=https://github.com/caelestia-dots/shell/issues/new?template=crash.yml
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import QtQml
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Caelestia.Config
import qs.components.containers
import qs.daemons
import qs.modules
import qs.modules.areapicker
import qs.modules.background
import qs.modules.drawers
import qs.modules.lock
import qs.modules.polkit
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
        AiProviders;
        AiTools;
        AiEngine;

        if (GlobalConfig.utilities.vpn.enabled)
            VPN;

        Qt.callLater(() => {
            Weather.reload();
            PastafarianCalendar.reload();
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
    PolkitModule {}

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
    property var _arpcInit: DiscordRPC
    property var _gameModeInit: GameMode
    property var _pipInit: PipManager
    property var _systemTrayInit: SystemTray
}

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.services
import qs.utils
import qs.modules.bar.components as BarComponents
import "Dial.js" as Dial

Item {
    id: root

    required property ScreenState screenState
    required property ShellScreen screen
    required property var bar

    Config.screen: screen.name
    Tokens.screen: screen.name

    readonly property bool hubEnabled: Config.session.powerHub === true
    readonly property bool opened: hubEnabled && screenState.session && Config.session.enabled
    property bool prepared: false
    property bool presenting: false
    property bool cursorReady: false
    property point openingPointer: Qt.point(0, 0)
    property int openGeneration: 0
    property int queryGeneration: -1
    readonly property real reveal: motion.panelReveal
    property string pendingAction: ""

    readonly property var actions: Dial.buildActions(Config.session.buttons)
    readonly property var barContent: bar?.barContent ?? null
    readonly property Item logoSource: barContent ? CUtils.findChild(barContent, "taskbarLogo") : null
    readonly property Item titleSource: barContent ? CUtils.findChild(barContent, "taskbarActiveWindow") : null
    readonly property Item powerSource: barContent ? CUtils.findChild(barContent, "taskbarPowerButton") : null
    readonly property Item powerGlyph: powerSource?.glyph ?? null
    readonly property string actionTitle: (view.item as PowerView)?.action?.title ?? Tr.tr("Session")
    readonly property string actionIcon: (view.item as PowerView)?.action?.icon ?? "power_settings_new"
    readonly property color actionColour: (view.item as PowerView)?.accent ?? Colours.palette.m3primary

    readonly property string barPosition: Config.bar.position
    readonly property bool horizontalBar: barPosition === "top" || barPosition === "bottom"
    readonly property bool flipDialX: barPosition === "right" || barPosition === "top" || barPosition === "bottom"
    readonly property bool flipDialY: barPosition === "top"
    readonly property real railWidth: horizontalBar
        ? Math.max(bar?.height ?? 0, bar?.contentWidth ?? 56)
        : Math.max(bar?.width ?? 0, bar?.contentWidth ?? 56)
    readonly property var menuBar: barContent ?? ({
        isHorizontal: horizontalBar,
        width: horizontalBar ? width : railWidth,
        height: horizontalBar ? railWidth : height,
        spacing: Tokens.spacing.medium,
        popouts: null,
        sections: horizontalBar
            ? [{ x: 0, y: 0, width: 100, height: railWidth }, {}, { x: width - 100, y: 0, width: 100, height: railWidth }]
            : [{ x: 0, y: 0, width: railWidth, height: 100 }, {}, { x: 0, y: height - 100, width: railWidth, height: 100 }]
    })

    // Shell assets resolution: defaults to Vacuited Logo; respects custom user asset when set.
    readonly property string defaultSessionGif: GlobalConfig.paths.descriptorFor("sessionGif")?.defaultValue ?? "root:/assets/kurukuru.gif"
    readonly property string rawSessionGif: (Config.paths.sessionGif || "").trim()
    readonly property bool useVacuitedLogo: rawSessionGif === "" || rawSessionGif === "vacuited" || rawSessionGif === "root:/assets/logo.svg" || rawSessionGif === defaultSessionGif
    readonly property string mascotPath: useVacuitedLogo ? "" : Paths.absolutePath(rawSessionGif)
    property int mascotRevision: 0

    property int geometryRevision: 0
    readonly property rect logoGeometry: sourceGeometry(logoSource, defaultLogoFallback())
    readonly property rect titleGeometry: sourceGeometry(titleSource, defaultTitleFallback())
    readonly property rect powerGeometry: sourceGeometry(powerSource, defaultPowerFallback())
    readonly property point powerOrigin: Qt.point(powerGeometry.x + powerGeometry.width / 2, powerGeometry.y + powerGeometry.height / 2)

    function defaultLogoFallback(): rect {
        if (barPosition === "right")
            return Qt.rect(width - railWidth, Tokens.padding.large, railWidth, 32);
        if (barPosition === "top")
            return Qt.rect(Tokens.padding.large, 0, 32, railWidth);
        if (barPosition === "bottom")
            return Qt.rect(Tokens.padding.large, height - railWidth, 32, railWidth);
        return Qt.rect(0, Tokens.padding.large, railWidth, 32);
    }

    function defaultTitleFallback(): rect {
        if (barPosition === "right")
            return Qt.rect(width - railWidth, height / 2 - 16, railWidth, 32);
        if (barPosition === "top")
            return Qt.rect(width / 2 - 40, 0, 80, railWidth);
        if (barPosition === "bottom")
            return Qt.rect(width / 2 - 40, height - railWidth, 80, railWidth);
        return Qt.rect(0, height / 2 - 16, railWidth, 32);
    }

    function defaultPowerFallback(): rect {
        const u = Math.max(0.25, Math.min(width / 1920, height / 1200));
        if (barPosition === "right")
            return Qt.rect(width - railWidth, height - 32 * u, railWidth, 24);
        if (barPosition === "top")
            return Qt.rect(width - 32 * u, 0, 24, railWidth);
        if (barPosition === "bottom")
            return Qt.rect(width - 32 * u, height - railWidth, 24, railWidth);
        return Qt.rect(0, height - 32 * u, railWidth, 24);
    }

    function sourceGeometry(source: Item, fallback: rect): rect {
        const revision = geometryRevision;
        if (!source || !source.visible || source.width <= 0 || source.height <= 0)
            return fallback;
        const position = source.mapToItem(root, 0, 0);
        return Qt.rect(position.x, position.y, source.width, source.height);
    }

    function refreshGeometry(): void {
        geometryRevision++;
        if (opened && cursorReady && !prepared)
            Qt.callLater(preparePointer);
    }

    function requestCursor(): void {
        if (!opened || cursorQuery.running)
            return;
        queryGeneration = openGeneration;
        cursorQuery.running = true;
    }

    function preparePointer(): void {
        if (!opened || prepared || !cursorReady)
            return;
        const content = view.item as PowerView;
        if (!content || content.width <= 0 || content.height <= 0)
            return;
        refreshGeometry();
        content.initializePointer(openingPointer.x, openingPointer.y);
        prepared = true;
        presentDelay.restart();
    }

    function runSessionCommand(command: var): void {
        if (!command || command.length === 0)
            return;
        if (SessionManager.exec(command))
            return;

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
        if (hasShellOp || command.length === 1)
            Quickshell.execDetached(["sh", "-c", command.join(" ")]);
        else
            Quickshell.execDetached(command);
    }

    onWidthChanged: Qt.callLater(refreshGeometry)
    onHeightChanged: Qt.callLater(refreshGeometry)
    onBarContentChanged: Qt.callLater(refreshGeometry)
    onPowerSourceChanged: Qt.callLater(refreshGeometry)
    onBarPositionChanged: Qt.callLater(refreshGeometry)

    Connections {
        target: root.bar
        function onWidthChanged(): void { Qt.callLater(root.refreshGeometry); }
        function onHeightChanged(): void { Qt.callLater(root.refreshGeometry); }
    }

    function dismiss(): void {
        screenState.session = false;
    }

    function activate(action: string): void {
        if (!opened || !prepared || motion.animating || pendingAction !== "")
            return;
        pendingAction = action;
        dismiss();
    }

    visible: prepared || motion.active

    Timer {
        id: presentDelay

        interval: 36
        onTriggered: if (root.opened && root.prepared) root.presenting = true
    }

    // Hide the underlying bar power icon while the morphed badge renders above it.
    Binding {
        target: root.powerGlyph
        property: "opacity"
        value: 0
        when: root.visible && root.powerGlyph !== null
        restoreMode: Binding.RestoreBindingOrValue
    }

    // Crossfade bar content away early so translucent menu surfaces do not show ghosted tray/workspace icons.
    Binding {
        target: root.barContent
        property: "opacity"
        value: Math.max(0, 1 - root.reveal * 2.6)
        when: root.visible && root.barContent !== null
        restoreMode: Binding.RestoreBindingOrValue
    }

    MenuMotion {
        id: motion

        opened: root.presenting
        onClosed: {
            if (root.pendingAction !== "")
                executeAfterClose.restart();
            gcTimer.restart();
        }
    }

    Timer {
        id: gcTimer

        interval: 600
        onTriggered: {
            if (!root.opened && !root.visible)
                gc();
        }
    }

    onOpenedChanged: {
        openGeneration++;
        prepared = false;
        cursorReady = false;
        presentDelay.stop();
        if (!opened) {
            presenting = false;
            return;
        }
        gcTimer.stop();
        if (!useVacuitedLogo)
            mascotRevision++;
        refreshGeometry();
        Qt.callLater(refreshGeometry);
        screenState.launcher = false;
        screenState.sidebar = false;
        screenState.dashboard = false;
        screenState.workspaceDrawer = false;
        executeAfterClose.stop();
        pendingAction = "";
        requestCursor();
    }

    Process {
        id: cursorQuery

        command: ["hyprctl", "cursorpos", "-j"]
        stdout: StdioCollector { id: cursorOutput }
        onExited: code => {
            if (!root.opened)
                return;
            if (root.queryGeneration !== root.openGeneration) {
                Qt.callLater(root.requestCursor);
                return;
            }
            try {
                const position = JSON.parse(cursorOutput.text);
                if (code !== 0 || !Number.isFinite(position.x) || !Number.isFinite(position.y))
                    throw new Error("Invalid cursor position");
                root.openingPointer = Qt.point(position.x - root.screen.x, position.y - root.screen.y);
            } catch (error) {
                const area = ShellState.componentsFor(root.screen)?.interactionWrapper;
                root.openingPointer = area ? area.mapToItem(root, area.mouseX, area.mouseY) : root.powerOrigin;
            }
            root.cursorReady = true;
            root.preparePointer();
        }
    }

    Loader {
        id: view

        anchors.fill: parent
        active: root.opened || root.visible
        asynchronous: true
        onLoaded: Qt.callLater(root.preparePointer)

        sourceComponent: PowerView {
            colours: Colours.palette
            actions: root.actions
            fontFamily: Tokens.font.body.large.family || "GoogleSansFlex"
            iconFontFamily: Tokens.font.icon.large.family || "Material Symbols Rounded"

            twelveHourClock: Units.twelveHourClock
            timeHours: Time.hourStr
            timeMinutes: Time.minuteStr
            timeAmPm: Time.amPmStr
            dateWeekday: Time.format("dddd")
            dateMonthDay: Time.format("MMMM d")
            dateFormatted: Time.format("dddd • d MMM")
            idleHeroShape: GlobalConfig.lock.profilePicShape
            facePath: Paths.home + "/.face"
            dialStyle: Config.session.powerHubDialStyle || "rim"

            barPosition: root.barPosition
            borderThickness: Config.border.thickness
            borderRounding: Config.border.rounding
            transparentMode: Colours.transparency.enabled
            lightSurface: Colours.light

            useVacuitedLogo: root.useVacuitedLogo
            mascotPath: root.mascotPath
            mascotSpeed: Config.general.sessionGifSpeed
            mascotRevision: root.mascotRevision

            baseColour: GlobalConfig.appearance.pitchBlack
                ? "#000000"
                : (Colours.transparency.enabled
                    ? Qt.alpha(Colours.palette.m3surface, Math.max(0.42, Colours.transparency.base + 0.04))
                    : Colours.palette.m3surface)
            panelColour: Colours.transparency.enabled
                ? Qt.alpha(Colours.palette.m3surfaceContainerLow, Math.max(0.56, Colours.transparency.base + 0.18))
                : Colours.palette.m3surfaceContainerLow
            panelEdgeColour: Colours.transparency.enabled
                ? Qt.alpha(Colours.palette.m3surfaceContainerHigh, Math.max(0.64, Colours.transparency.base + 0.26))
                : Colours.palette.m3surfaceContainerHigh
            optionColour: Colours.tPalette.m3surfaceContainerHigh

            railWidth: root.railWidth
            horizontalBar: root.horizontalBar
            flipDialX: root.flipDialX
            flipDialY: root.flipDialY
            dialOrigin: root.powerOrigin
            dialExpansion: motion.expansion
            handleMorph: motion.expansion
            normalPowerFont: root.powerGlyph?.font ?? Tokens.font.icon.small
            normalPowerColour: root.powerGlyph?.color ?? Colours.palette.m3error
            reveal: root.reveal
            backdropReveal: motion.backdropReveal
            contentReveal: motion.contentReveal
            clockReveal: motion.clockReveal
            detailsReveal: motion.detailsReveal
            dialReveal: motion.dialReveal
            cornerReveal: motion.cornerReveal
            acceptingInput: root.opened && root.prepared && motion.expansion === 1 && !motion.animating
            trackingPointer: root.opened
            confirmDangerous: Config.session.powerHubConfirmDangerous !== false
            statusChipsEnabled: Config.session.powerHubStatusChips !== false
            recordingActive: Recorder.running
            keepAwakeActive: IdleInhibitor.active
            onSelectionTicked: {
                if (Config.session.powerHubTickSound === true)
                    Audio.playEffectTick();
            }
            onDismissed: root.dismiss()
            onActionRequested: action => root.activate(action)
        }
    }

    Loader {
        id: osIconLoader

        active: root.opened || root.visible
        asynchronous: true
        opacity: Math.max(0, (motion.panelReveal - 0.15) / 0.85)
        x: root.logoGeometry.x + (root.logoGeometry.width - width) / 2
        y: root.logoGeometry.y + (root.logoGeometry.height - height) / 2

        sourceComponent: BarComponents.OsIcon {
            enabled: false
            width: root.logoSource?.width ?? implicitWidth
            height: root.logoSource?.height ?? implicitHeight
        }
    }

    Loader {
        id: activeWindowLoader

        active: root.opened || root.visible
        asynchronous: true
        opacity: Math.max(0, (motion.panelReveal - 0.15) / 0.85)
        x: root.titleGeometry.x + (root.titleGeometry.width - (item?.implicitWidth ?? 0)) / 2
        y: root.titleGeometry.y + (root.titleGeometry.height - (item?.implicitHeight ?? 0)) / 2

        sourceComponent: BarComponents.ActiveWindow {
            enabled: false
            bar: root.menuBar
            monitor: Brightness.getMonitorForScreen(root.screen)
            titleOverride: root.actionTitle
            iconOverride: root.actionIcon
            colour: root.actionColour
        }
    }

    Timer {
        id: executeAfterClose

        interval: 16
        onTriggered: {
            const actionId = root.pendingAction;
            root.pendingAction = "";
            if (Quickshell.env("CAELESTIA_POWER_DRY_RUN") === "1") {
                console.info("Power menu dry run:", actionId);
                return;
            }
            const entry = root.actions.find(a => a.id === actionId);
            const command = entry?.command ?? (actionId === "shutdown" ? ["poweroff"] : [actionId]);
            root.runSessionCommand(command);
        }
    }
}

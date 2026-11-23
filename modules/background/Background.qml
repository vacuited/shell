pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import qs.utils
import qs.modules.nexus
import "components"

Variants {
    model: Screens.screens.filter(s => GlobalConfig.forScreen(s.name).background.enabled)

    Scope {
        id: scope

        required property ShellScreen modelData
        readonly property bool weRunning: !!(win.wallpaperLoader.item && win.wallpaperLoader.item.weRunning)
        property bool winBottomDeferred: false

        function syncBottomOrder(): void {
            if (weRunning) {
                if (!winBottomDeferred)
                    bottomLayerTimer.restart();
            } else {
                bottomLayerTimer.stop();
                winBottomDeferred = false;
            }
        }

        onWeRunningChanged: syncBottomOrder()
        Component.onCompleted: syncBottomOrder()

        Timer {
            id: bottomLayerTimer

            interval: 40
            onTriggered: scope.winBottomDeferred = scope.weRunning
        }

        // Dedicated non-blurred bottom surface for Visualiser during Wallpaper Engine
        // playback so caelestia-background's Hyprland blur rule does not carve wavy
        // ignore_alpha cutouts into live Wallpaper Engine scenes.
        StyledWindow {
            id: visWin

            screen: scope.modelData
            name: "visualiser"
            visible: scope.weRunning
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}
            color: "transparent"
            surfaceFormat.opaque: false

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Loader {
                anchors.fill: parent
                active: scope.weRunning

                sourceComponent: Visualiser {
                    screen: scope.modelData
                    wallpaper: win.wallpaperLoader
                }
            }
        }

        StyledWindow {
            id: win

            readonly property ShellScreen modelData: scope.modelData
            readonly property alias wallpaperLoader: wallpaper
            readonly property var monitor: Hypr.monitorFor(win.modelData)
            readonly property bool workspaceOccupied: !(monitor?.activeWorkspace?.toplevels?.values.every(t => t.lastIpcObject?.floating) ?? true)

            screen: modelData
            name: "background"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: (contentItem.Config.background.wallpaperEnabled && !scope.winBottomDeferred) ? WlrLayer.Background : WlrLayer.Bottom
            WlrLayershell.keyboardFocus: (Visibilities.desktopWidgetsUnlocked || Visibilities.desktopWidgetEditing) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            color: contentItem.Config.background.wallpaperEnabled && !scope.weRunning ? "black" : "transparent"
            surfaceFormat.opaque: false

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

        Shortcut {
            sequence: "Escape"
            enabled: Visibilities.desktopWidgetsUnlocked
            onActivated: {
                if (desktopCanvas.clockEditing)
                    desktopCanvas.closeClockPopover();
                else if (desktopCanvas.lyricsEditing)
                    desktopCanvas.closeLyricsPopover();
                else if ((widgetsLoader.item?.editingWidgetId ?? "") !== "")
                    widgetsLoader.item.closeQuickPopover();
                else
                    Visibilities.desktopWidgetsUnlocked = false;
            }
        }

        ShellState.ComponentRef {
            screen: win.screen
            slot: "background"
            component: win
        }

        Item {
            id: behindClock

            readonly property bool weSurfaceActive: wallpaper.item?.weSurfaceVisible ?? false

            anchors.fill: parent

            Loader {
                id: wallpaper

                asynchronous: true

                anchors.fill: parent
                active: Config.background.wallpaperEnabled
                opacity: (item && item.weSurfaceVisible && item.weRevealOpacity <= 0.001) ? 0 : 1

                sourceComponent: Wallpaper {
                    screen: win.modelData
                    weEngineReady: Skwd.surfaceReady
                    weFailed: Skwd.engineFailed
                }
            }

            Loader {
                id: visualiserLoader

                anchors.fill: parent
                active: !scope.weRunning
                z: 2

                sourceComponent: Visualiser {
                    screen: win.modelData
                    wallpaper: wallpaper
                }
            }
        }

        Item {
            id: desktopCanvas

            readonly property bool isWidgetCanvas: true
            readonly property int barExclusiveZone: Visibilities.bars.get(win.modelData.name)?.exclusiveZone ?? (Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.small, Config.border.thickness))
            readonly property int edgeBorderInset: Config.border.clampedThickness
            readonly property int safeGap: Tokens.spacing.medium
            readonly property real safeLeft: Math.round((Config.bar.position === "left" ? barExclusiveZone : edgeBorderInset) + safeGap)
            readonly property real safeTop: Math.round((Config.bar.position === "top" ? barExclusiveZone : edgeBorderInset) + safeGap)
            readonly property real safeRight: Math.max(safeLeft + 64, Math.round(width - (Config.bar.position === "right" ? barExclusiveZone : edgeBorderInset) - safeGap))
            readonly property real safeBottom: Math.max(safeTop + 64, Math.round(height - (Config.bar.position === "bottom" ? barExclusiveZone : edgeBorderInset) - safeGap))
            readonly property real safeWidth: Math.max(64, safeRight - safeLeft)
            readonly property real safeHeight: Math.max(64, safeBottom - safeTop)
            readonly property real workCenterX: Math.round((safeLeft + safeRight) / 2)
            readonly property real workCenterY: Math.round((safeTop + safeBottom) / 2)
            property bool dragging: false
            property bool resizing: false
            property bool centerXActive: false
            property bool centerYActive: false
            property var guideLines: []
            property var registeredItems: []
            property bool clockEditing: false
            property bool lyricsEditing: false

            function clockTargetFor(propKey: string, subGroup: string): var {
                const scr = Config.forScreen(win.modelData.name);
                if (!scr)
                    return GlobalConfig;
                let node = scr.background.desktopClock;
                if (subGroup === "background")
                    node = node.background;
                else if (subGroup === "shadow")
                    node = node.shadow;
                return node.isOverride(propKey) ? scr : GlobalConfig;
            }

            function clockPositionTarget(): var {
                const scr = Config.forScreen(win.modelData.name);
                if (!scr)
                    return GlobalConfig;
                const hasScreenOverride = scr.background.desktopClock.isOverride("x")
                    || scr.background.desktopClock.isOverride("y");
                return hasScreenOverride ? scr : GlobalConfig;
            }

            function openClockPopover(): void {
                closeLyricsPopover();
                if (widgetsLoader.item?.closeQuickPopover)
                    widgetsLoader.item.closeQuickPopover();
                clockEditing = true;
            }

            function closeClockPopover(): void {
                clockEditing = false;
            }

            function toggleClockPopover(): void {
                if (clockEditing)
                    closeClockPopover();
                else
                    openClockPopover();
            }

            function lyricsTargetFor(propKey: string, subGroup: string): var {
                const scr = Config.forScreen(win.modelData.name);
                if (!scr)
                    return GlobalConfig;
                let node = scr.background.desktopLyrics;
                if (subGroup === "background")
                    node = node.background;
                else if (subGroup === "shadow")
                    node = node.shadow;
                return node.isOverride(propKey) ? scr : GlobalConfig;
            }

            function lyricsPositionTarget(): var {
                const scr = Config.forScreen(win.modelData.name);
                if (!scr)
                    return GlobalConfig;
                const hasScreenOverride = scr.background.desktopLyrics.isOverride("x")
                    || scr.background.desktopLyrics.isOverride("y");
                return hasScreenOverride ? scr : GlobalConfig;
            }

            function openLyricsPopover(): void {
                closeClockPopover();
                if (widgetsLoader.item?.closeQuickPopover)
                    widgetsLoader.item.closeQuickPopover();
                lyricsEditing = true;
            }

            function closeLyricsPopover(): void {
                lyricsEditing = false;
            }

            function toggleLyricsPopover(): void {
                if (lyricsEditing)
                    closeLyricsPopover();
                else
                    openLyricsPopover();
            }

            function patchLyricsOptions(patch: var, save: bool): void {
                const target = lyricsTargetFor("options", "");
                const next = Object.assign({}, Config.background.desktopLyrics.options || ({}), patch);
                target.background.desktopLyrics.options = next;
                if (save)
                    target.save();
            }

            function patchClockOptions(patch: var, save: bool): void {
                const target = clockTargetFor("options", "");
                const next = Object.assign({}, Config.background.desktopClock.options || ({}), patch);
                target.background.desktopClock.options = next;
                if (save)
                    target.save();
            }

            function setUnifiedCardBackground(enabled: bool): void {
                const bgTarget = clockTargetFor("enabled", "background");
                bgTarget.background.desktopClock.background.enabled = enabled;
                bgTarget.save();
                const curOpts = Config.background.desktopClock.options || ({});
                if (curOpts.showBackground !== undefined) {
                    const nextOpts = Object.assign({}, curOpts);
                    delete nextOpts.showBackground;
                    const optTarget = clockTargetFor("options", "");
                    optTarget.background.desktopClock.options = nextOpts;
                    optTarget.save();
                }
            }

            function setClockSurfaceStyle(style: string): void {
                const target = clockTargetFor("surfaceStyle", "");
                target.background.desktopClock.surfaceStyle = style;
                target.save();
                const curOpts = Config.background.desktopClock.options || ({});
                if (curOpts.surfaceStyle !== undefined || curOpts.style !== undefined) {
                    const nextOpts = Object.assign({}, curOpts);
                    delete nextOpts.surfaceStyle;
                    delete nextOpts.style;
                    const optTarget = clockTargetFor("options", "");
                    optTarget.background.desktopClock.options = nextOpts;
                    optTarget.save();
                }
            }

            function setDragging(active: bool): void {
                dragging = active;
                if (!active && !resizing)
                    guideLines = [];
            }

            function setResizing(active: bool): void {
                resizing = active;
                if (!active && !dragging)
                    guideLines = [];
            }

            function setCenterActive(xActive: bool, yActive: bool): void {
                centerXActive = xActive;
                centerYActive = yActive;
            }

            function setGuideLines(lines: var): void {
                guideLines = lines ?? [];
            }

            function registerItem(item: Item): void {
                if (!item || registeredItems.indexOf(item) >= 0)
                    return;
                const next = registeredItems.slice();
                next.push(item);
                registeredItems = next;
            }

            function unregisterItem(item: Item): void {
                const idx = registeredItems.indexOf(item);
                if (idx < 0)
                    return;
                const next = registeredItems.slice();
                next.splice(idx, 1);
                registeredItems = next;
            }

            function siblingRects(excludeItem: Item): var {
                const out = [];
                for (let i = 0; i < registeredItems.length; i++) {
                    const it = registeredItems[i];
                    if (!it || it === excludeItem || !it.visible || it.width <= 0 || it.height <= 0)
                        continue;
                    const pt = it.mapToItem(desktopCanvas, 0, 0);
                    out.push({
                        x: pt.x,
                        y: pt.y,
                        width: it.width,
                        height: it.height
                    });
                }
                return out;
            }

            anchors.fill: parent

            Connections {
                target: Visibilities
                function onDesktopWidgetsUnlockedChanged(): void {
                    if (!Visibilities.desktopWidgetsUnlocked) {
                        desktopCanvas.closeClockPopover();
                        desktopCanvas.closeLyricsPopover();
                    }
                }
            }

            Connections {
                target: Config.background.desktopClock
                function onEnabledChanged(): void {
                    if (!Config.background.desktopClock.enabled)
                        desktopCanvas.closeClockPopover();
                }
            }

            Connections {
                target: Config.background.desktopLyrics
                function onEnabledChanged(): void {
                    if (!Config.background.desktopLyrics.enabled)
                        desktopCanvas.closeLyricsPopover();
                }
                function onOverlayChanged(): void {
                    if (Config.background.desktopLyrics.overlay)
                        desktopCanvas.closeLyricsPopover();
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: Visibilities.desktopWidgetsUnlocked = !Visibilities.desktopWidgetsUnlocked
            }

            Loader {
                id: gridLinesLoader

                anchors.fill: parent
                z: 50
                active: Visibilities.desktopWidgetsUnlocked && (desktopCanvas.dragging || desktopCanvas.resizing)

                sourceComponent: WidgetGridLines {
                    safeLeft: desktopCanvas.safeLeft
                    safeTop: desktopCanvas.safeTop
                    safeRight: desktopCanvas.safeRight
                    safeBottom: desktopCanvas.safeBottom
                    workCenterX: desktopCanvas.workCenterX
                    workCenterY: desktopCanvas.workCenterY
                    centerXActive: desktopCanvas.centerXActive
                    centerYActive: desktopCanvas.centerYActive
                    guideLines: desktopCanvas.guideLines
                }
            }

            WidgetWrapper {
                id: clockWrapper

                readonly property int clockBarZone: Visibilities.bars.get(win.modelData.name)?.exclusiveZone ?? (Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.small, Config.border.thickness))
                readonly property int clockBaseMargin: Tokens.padding.extraLargeIncreased
                readonly property int leftMargin: Config.bar.position === "left" ? clockBaseMargin + clockBarZone : clockBaseMargin
                readonly property int rightMargin: Config.bar.position === "right" ? clockBaseMargin + clockBarZone : clockBaseMargin
                readonly property int topMargin: Config.bar.position === "top" ? clockBaseMargin + clockBarZone : clockBaseMargin
                readonly property int bottomMargin: Config.bar.position === "bottom" ? clockBaseMargin + clockBarZone : clockBaseMargin
                readonly property bool hasCustomPos: Config.background.desktopClock.x >= 0 && Config.background.desktopClock.y >= 0
                property real occupiedProg: win.workspaceOccupied ? 1 : 0
                readonly property bool hideWithWindows: Boolean(Config.background.desktopClock.options?.hideWithWindows ?? false)
                readonly property real reveal: (hideWithWindows && !Visibilities.desktopWidgetsUnlocked) ? (1 - occupiedProg) : 1

                Behavior on occupiedProg {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                readonly property int anchorX: {
                    const pos = Config.background.desktopClock.position;
                    if (pos.endsWith("-left"))
                        return leftMargin;
                    if (pos.endsWith("-right"))
                        return Math.round(desktopCanvas.width - rightMargin - width);
                    const barOff = Config.bar.position === "left" ? clockBarZone / 2 : (Config.bar.position === "right" ? -clockBarZone / 2 : 0);
                    return Math.round((desktopCanvas.width - width) / 2 + barOff);
                }

                readonly property int anchorY: {
                    const pos = Config.background.desktopClock.position;
                    if (pos.startsWith("top-"))
                        return topMargin;
                    if (pos.startsWith("bottom-"))
                        return Math.round(desktopCanvas.height - bottomMargin - height);
                    const barOff = Config.bar.position === "top" ? clockBarZone / 2 : (Config.bar.position === "bottom" ? -clockBarZone / 2 : 0);
                    return Math.round((desktopCanvas.height - height) / 2 + barOff);
                }

                canvas: desktopCanvas
                visible: Config.background.desktopClock.enabled && reveal > 0.01
                opacity: reveal
                resizable: true
                resizeMode: "diagonal"
                showSettingsHandle: true
                settingsActive: desktopCanvas.clockEditing
                outlineShape: Config.background.desktopClock.style === "cookie"
                    ? WidgetMetrics.resolveShapeEnum(String(Config.background.desktopClock.options?.shape ?? "Cookie9Sided"), "Cookie9Sided")
                    : -1
                outlineScale: clockLoader.item?.visualScale ?? 1.0
                outlineRotation: clockLoader.item?.visualRotation ?? 0.0
                minWidth: Math.max(80, Math.round((clockLoader.item?.unscaledWidth ?? 230) * 0.5))
                minHeight: Math.max(56, Math.round((clockLoader.item?.unscaledHeight ?? 230) * 0.5))
                maxWidth: Math.round((clockLoader.item?.unscaledWidth ?? 230) * 3.0)
                maxHeight: Math.round((clockLoader.item?.unscaledHeight ?? 230) * 3.0)
                customResizeBadge: {
                    const baseW = Math.max(1, clockLoader.item?.unscaledWidth ?? 230);
                    const sc = Math.max(0.5, Math.min(3.0, Math.round((clockWrapper.ghostWidth / baseW) * 20) / 20));
                    return sc.toFixed(2) + "×";
                }
                implicitWidth: clockLoader.implicitWidth
                implicitHeight: clockLoader.implicitHeight
                width: implicitWidth
                height: implicitHeight
                initialX: hasCustomPos ? Config.background.desktopClock.x : anchorX
                initialY: hasCustomPos ? Config.background.desktopClock.y : anchorY
                onPositionCommitted: (newX, newY) => {
                    const target = desktopCanvas.clockPositionTarget();
                    target.background.desktopClock.x = Math.round(newX);
                    target.background.desktopClock.y = Math.round(newY);
                    target.save();
                }
                onResizeFinished: finalWidth => {
                    const baseW = Math.max(1, clockLoader.item?.unscaledWidth ?? 230);
                    const nextScale = Math.max(0.5, Math.min(3.0, Math.round((finalWidth / baseW) * 20) / 20));
                    const target = desktopCanvas.clockTargetFor("scale", "");
                    target.background.desktopClock.scale = nextScale;
                    target.save();
                }
                onSettingsRequested: desktopCanvas.toggleClockPopover()

                Loader {
                    id: clockLoader

                    asynchronous: true
                    active: Config.background.desktopClock.enabled
                    scale: 0.97 + 0.03 * clockWrapper.reveal

                    sourceComponent: DesktopClock {
                        wallpaper: behindClock
                        absX: clockWrapper.x
                        absY: clockWrapper.y
                        desktopOccluded: win.workspaceOccupied
                    }
                }
            }

            ClockQuickPopover {
                id: clockPopover

                open: desktopCanvas.clockEditing && Visibilities.desktopWidgetsUnlocked && Config.background.desktopClock.enabled
                clockStyle: Config.background.desktopClock.style || "classic"
                surfaceStyle: clockLoader.item?.surfaceStyle ?? (Config.background.desktopClock.surfaceStyle || "glass")
                clockScale: Config.background.desktopClock.scale
                cardBackground: clockLoader.item?.cardBackground ?? Config.background.desktopClock.background.enabled
                bgBlur: Config.background.desktopClock.background.blur
                bgOpacity: Config.background.desktopClock.background.opacity
                shadowEnabled: Config.background.desktopClock.shadow.enabled
                invertColors: Config.background.desktopClock.invertColors
                hasCustomPos: clockWrapper.hasCustomPos
                clockOptions: Config.background.desktopClock.options || ({})
                anchorX: clockWrapper.x
                anchorY: clockWrapper.y
                anchorWidth: clockWrapper.width
                anchorHeight: clockWrapper.height
                safeLeft: desktopCanvas.safeLeft
                safeTop: desktopCanvas.safeTop
                safeRight: desktopCanvas.safeRight
                safeBottom: desktopCanvas.safeBottom

                onClosed: desktopCanvas.closeClockPopover()
                onStyleSelected: style => {
                    const target = desktopCanvas.clockTargetFor("style", "");
                    target.background.desktopClock.style = style;
                    target.save();
                }
                onSurfaceStyleSelected: style => desktopCanvas.setClockSurfaceStyle(style)
                onCardBackgroundToggled: enabled => desktopCanvas.setUnifiedCardBackground(enabled)
                onToggleGlassBlur: {
                    const target = desktopCanvas.clockTargetFor("blur", "background");
                    target.background.desktopClock.background.blur = !Config.background.desktopClock.background.blur;
                    target.save();
                }
                onOpacityChangedLive: (nextOpacity, save) => {
                    const target = desktopCanvas.clockTargetFor("opacity", "background");
                    target.background.desktopClock.background.opacity = nextOpacity;
                    if (save)
                        target.save();
                }
                onScaleChangedLive: (nextScale, save) => {
                    const target = desktopCanvas.clockTargetFor("scale", "");
                    target.background.desktopClock.scale = nextScale;
                    if (save)
                        target.save();
                }
                onShadowToggled: enabled => {
                    const target = desktopCanvas.clockTargetFor("enabled", "shadow");
                    target.background.desktopClock.shadow.enabled = enabled;
                    target.save();
                }
                onInvertColorsToggled: enabled => {
                    const target = desktopCanvas.clockTargetFor("invertColors", "");
                    target.background.desktopClock.invertColors = enabled;
                    target.save();
                }
                onOptionPatched: patch => desktopCanvas.patchClockOptions(patch, true)
                onCenterRequested: {
                    const target = desktopCanvas.clockPositionTarget();
                    const cx = Math.round(desktopCanvas.workCenterX - clockWrapper.width / 2);
                    const cy = Math.round(desktopCanvas.workCenterY - clockWrapper.height / 2);
                    target.background.desktopClock.x = Math.round(clockWrapper.clampX(cx, clockWrapper.width));
                    target.background.desktopClock.y = Math.round(clockWrapper.clampY(cy, clockWrapper.height));
                    target.save();
                }
                onResetPositionRequested: {
                    const target = desktopCanvas.clockPositionTarget();
                    target.background.desktopClock.x = -1;
                    target.background.desktopClock.y = -1;
                    target.save();
                }
                onHideClockRequested: {
                    const target = desktopCanvas.clockTargetFor("enabled", "");
                    target.background.desktopClock.enabled = false;
                    target.save();
                }
                onOpenNexusRequested: WindowFactory.openPage(PageRegistry.indexOfKey("background"), 1)
            }

            WidgetWrapper {
                id: lyricsWrapper

                readonly property int lyricsBarZone: Visibilities.bars.get(win.modelData.name)?.exclusiveZone ?? (Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.small, Config.border.thickness))
                readonly property int lyricsBaseMargin: Tokens.padding.large * 2
                readonly property int leftMargin: Config.bar.position === "left" ? lyricsBaseMargin + lyricsBarZone : lyricsBaseMargin
                readonly property int rightMargin: Config.bar.position === "right" ? lyricsBaseMargin + lyricsBarZone : lyricsBaseMargin
                readonly property int topMargin: Config.bar.position === "top" ? lyricsBaseMargin + lyricsBarZone : lyricsBaseMargin
                readonly property int bottomMargin: Config.bar.position === "bottom" ? lyricsBaseMargin + lyricsBarZone : lyricsBaseMargin
                readonly property bool hasCustomPos: Config.background.desktopLyrics.x >= 0 && Config.background.desktopLyrics.y >= 0
                readonly property bool lyricsEnabledOnCanvas: Config.background.desktopLyrics.enabled
                    && !Config.background.desktopLyrics.overlay
                    && !(GameMode.enabled && GlobalConfig.utilities.gameMode.disableDesktopLyrics)

                readonly property int anchorX: {
                    const pos = Config.background.desktopLyrics.position;
                    if (pos.endsWith("-left"))
                        return leftMargin;
                    if (pos.endsWith("-right"))
                        return Math.round(desktopCanvas.width - rightMargin - width);
                    const barOff = Config.bar.position === "left" ? lyricsBarZone / 2 : (Config.bar.position === "right" ? -lyricsBarZone / 2 : 0);
                    return Math.round((desktopCanvas.width - width) / 2 + barOff);
                }

                readonly property int anchorY: {
                    const pos = Config.background.desktopLyrics.position;
                    if (pos.startsWith("top-"))
                        return topMargin;
                    if (pos.startsWith("bottom-"))
                        return Math.round(desktopCanvas.height - bottomMargin - height);
                    const barOff = Config.bar.position === "top" ? lyricsBarZone / 2 : (Config.bar.position === "bottom" ? -lyricsBarZone / 2 : 0);
                    return Math.round((desktopCanvas.height - height) / 2 + barOff);
                }

                canvas: desktopCanvas
                visible: lyricsEnabledOnCanvas && (Visibilities.desktopWidgetsUnlocked || (lyricsLoader.item?.shouldDisplay ?? false) || ((lyricsLoader.item?.opacity ?? 0) > 0.001))
                resizable: true
                resizeMode: "horizontal"
                showSettingsHandle: true
                settingsActive: desktopCanvas.lyricsEditing
                minWidth: 260
                maxWidth: 1100
                customResizeBadge: Math.round(lyricsWrapper.ghostWidth) + " px"
                implicitWidth: lyricsLoader.implicitWidth
                implicitHeight: lyricsLoader.implicitHeight
                width: implicitWidth
                height: implicitHeight
                initialX: hasCustomPos ? Config.background.desktopLyrics.x : anchorX
                initialY: hasCustomPos ? Config.background.desktopLyrics.y : anchorY
                onPositionCommitted: (newX, newY) => {
                    const target = desktopCanvas.lyricsPositionTarget();
                    target.background.desktopLyrics.x = Math.round(newX);
                    target.background.desktopLyrics.y = Math.round(newY);
                    target.save();
                }
                onResizeFinished: finalWidth => {
                    const nextWidth = Math.max(260, Math.min(1100, Math.round(finalWidth)));
                    const target = desktopCanvas.lyricsTargetFor("width", "");
                    target.background.desktopLyrics.width = nextWidth;
                    target.save();
                }
                onSettingsRequested: desktopCanvas.toggleLyricsPopover()

                Loader {
                    id: lyricsLoader

                    asynchronous: true
                    active: lyricsWrapper.lyricsEnabledOnCanvas

                    sourceComponent: DesktopLyrics {
                        screen: win.modelData
                        wallpaper: behindClock
                        absX: lyricsWrapper.x
                        absY: lyricsWrapper.y
                        editUnlocked: Visibilities.desktopWidgetsUnlocked
                        popoverOpen: desktopCanvas.lyricsEditing
                        customWidth: lyricsWrapper.resizing ? Math.round(lyricsWrapper.ghostWidth) : Config.background.desktopLyrics.width
                    }
                }
            }

            LyricsQuickPopover {
                id: lyricsPopover

                open: desktopCanvas.lyricsEditing && Visibilities.desktopWidgetsUnlocked && lyricsWrapper.lyricsEnabledOnCanvas
                lyricsStyle: Config.background.desktopLyrics.style || "apple"
                surfaceStyle: Config.background.desktopLyrics.surfaceStyle || "glass"
                lyricsScale: Config.background.desktopLyrics.scale
                lyricsWidth: Config.background.desktopLyrics.width
                alignment: Config.background.desktopLyrics.alignment
                cardBackground: Config.background.desktopLyrics.background.enabled
                bgBlur: Config.background.desktopLyrics.background.blur
                bgOpacity: Config.background.desktopLyrics.background.opacity
                shadowEnabled: Config.background.desktopLyrics.shadow.enabled
                invertColors: Config.background.desktopLyrics.invertColors
                hasCustomPos: lyricsWrapper.hasCustomPos
                positionPreset: Config.background.desktopLyrics.position
                lyricsOptions: Config.background.desktopLyrics.options || ({})
                anchorX: lyricsWrapper.x
                anchorY: lyricsWrapper.y
                anchorWidth: lyricsWrapper.width
                anchorHeight: lyricsWrapper.height
                safeLeft: desktopCanvas.safeLeft
                safeTop: desktopCanvas.safeTop
                safeRight: desktopCanvas.safeRight
                safeBottom: desktopCanvas.safeBottom

                onClosed: desktopCanvas.closeLyricsPopover()
                onStyleSelected: style => {
                    const target = desktopCanvas.lyricsTargetFor("style", "");
                    target.background.desktopLyrics.style = style;
                    target.save();
                }
                onSurfaceStyleSelected: style => {
                    const target = desktopCanvas.lyricsTargetFor("surfaceStyle", "");
                    target.background.desktopLyrics.surfaceStyle = style;
                    target.save();
                }
                onAlignmentSelected: align => {
                    const target = desktopCanvas.lyricsTargetFor("alignment", "");
                    target.background.desktopLyrics.alignment = align;
                    target.save();
                }
                onPositionPresetSelected: pos => {
                    const posTarget = desktopCanvas.lyricsTargetFor("position", "");
                    const xyTarget = desktopCanvas.lyricsPositionTarget();
                    posTarget.background.desktopLyrics.position = pos;
                    xyTarget.background.desktopLyrics.x = -1;
                    xyTarget.background.desktopLyrics.y = -1;
                    posTarget.save();
                    if (xyTarget !== posTarget)
                        xyTarget.save();
                }
                onCardBackgroundToggled: enabled => {
                    const target = desktopCanvas.lyricsTargetFor("enabled", "background");
                    target.background.desktopLyrics.background.enabled = enabled;
                    target.save();
                }
                onToggleGlassBlur: {
                    const target = desktopCanvas.lyricsTargetFor("blur", "background");
                    target.background.desktopLyrics.background.blur = !Config.background.desktopLyrics.background.blur;
                    target.save();
                }
                onOpacityChangedLive: (nextOpacity, save) => {
                    const target = desktopCanvas.lyricsTargetFor("opacity", "background");
                    target.background.desktopLyrics.background.opacity = nextOpacity;
                    if (save)
                        target.save();
                }
                onScaleChangedLive: (nextScale, save) => {
                    const target = desktopCanvas.lyricsTargetFor("scale", "");
                    target.background.desktopLyrics.scale = nextScale;
                    if (save)
                        target.save();
                }
                onWidthChangedLive: (nextWidth, save) => {
                    const target = desktopCanvas.lyricsTargetFor("width", "");
                    target.background.desktopLyrics.width = Math.max(260, Math.min(1100, Math.round(nextWidth)));
                    if (save)
                        target.save();
                }
                onShadowToggled: enabled => {
                    const target = desktopCanvas.lyricsTargetFor("enabled", "shadow");
                    target.background.desktopLyrics.shadow.enabled = enabled;
                    target.save();
                }
                onInvertColorsToggled: enabled => {
                    const target = desktopCanvas.lyricsTargetFor("invertColors", "");
                    target.background.desktopLyrics.invertColors = enabled;
                    target.save();
                }
                onOptionPatched: patch => desktopCanvas.patchLyricsOptions(patch, true)
                onCenterRequested: {
                    const target = desktopCanvas.lyricsPositionTarget();
                    const cx = Math.round(desktopCanvas.workCenterX - lyricsWrapper.width / 2);
                    const cy = Math.round(desktopCanvas.workCenterY - lyricsWrapper.height / 2);
                    target.background.desktopLyrics.x = Math.round(lyricsWrapper.clampX(cx, lyricsWrapper.width));
                    target.background.desktopLyrics.y = Math.round(lyricsWrapper.clampY(cy, lyricsWrapper.height));
                    target.save();
                }
                onResetPositionRequested: {
                    const target = desktopCanvas.lyricsPositionTarget();
                    target.background.desktopLyrics.x = -1;
                    target.background.desktopLyrics.y = -1;
                    target.save();
                }
                onHideLyricsRequested: {
                    const target = desktopCanvas.lyricsTargetFor("enabled", "");
                    target.background.desktopLyrics.enabled = false;
                    target.save();
                }
                onOpenNexusRequested: WindowFactory.openPage(PageRegistry.indexOfKey("background"), 2)
            }

        Loader {
            id: widgetsLoader

            readonly property bool occupied: win.workspaceOccupied
            property real occupiedProg: occupied ? 1 : 0
            readonly property real reveal: Config.background.desktopWidgets.hideWithWindows ? 1 - occupiedProg : 1

            z: (widgetsLoader.item?.editingWidgetId ?? "") !== "" ? 70 : 1

            Behavior on occupiedProg {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            active: Config.background.desktopWidgets.enabled && reveal > 0.01
            visible: reveal > 0.01
            opacity: reveal
            scale: 0.97 + 0.03 * reveal

            x: 0
            y: 0
            width: parent.width
            height: parent.height

            sourceComponent: DesktopWidgets {
                wallpaper: behindClock
            }
        }
        }
    }
    }
}

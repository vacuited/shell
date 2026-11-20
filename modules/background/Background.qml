pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import qs.utils
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
            onActivated: Visibilities.desktopWidgetsUnlocked = false
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
            readonly property int edgeBorderInset: GlobalConfig.appearance.islands ? 0 : Config.border.thickness
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
                visible: Config.background.desktopClock.enabled
                outlineShape: Config.background.desktopClock.style === "cookie"
                    ? WidgetMetrics.resolveShapeEnum(String(Config.background.desktopClock.options?.shape ?? "Cookie9Sided"), "Cookie9Sided")
                    : -1
                implicitWidth: clockLoader.implicitWidth
                implicitHeight: clockLoader.implicitHeight
                width: implicitWidth
                height: implicitHeight
                initialX: hasCustomPos ? Config.background.desktopClock.x : anchorX
                initialY: hasCustomPos ? Config.background.desktopClock.y : anchorY
                onPositionCommitted: (newX, newY) => {
                    const scr = Config.forScreen(win.modelData.name);
                    const hasScreenOverride = scr.background.desktopClock.isOverride("x")
                        || scr.background.desktopClock.isOverride("y");
                    const target = hasScreenOverride ? scr : GlobalConfig;
                    target.background.desktopClock.x = Math.round(newX);
                    target.background.desktopClock.y = Math.round(newY);
                    target.save();
                }

                Loader {
                    id: clockLoader

                    asynchronous: true
                    active: Config.background.desktopClock.enabled

                    sourceComponent: DesktopClock {
                        wallpaper: behindClock
                        absX: clockWrapper.x
                        absY: clockWrapper.y
                        desktopOccluded: win.workspaceOccupied
                    }
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

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Caelestia.Components
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen
    required property Item wallpaper

    readonly property var vis: Config.background.visualiser
    readonly property bool shouldBeActive: vis.enabled && !(GameMode.enabled && GlobalConfig.utilities.gameMode.disableVisualizer) && (!vis.autoHide || (Hypr.monitorFor(screen)?.activeWorkspace?.toplevels?.values.every(t => t.lastIpcObject?.floating) ?? true))
    property real offset: shouldBeActive ? 0 : screen.height * 0.2

    readonly property int barExclusiveZone: Visibilities.bars.get(root.screen.name)?.exclusiveZone ?? (Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.small, Config.border.thickness))

    readonly property bool useGpuPipeline: vis.renderer !== "cpu" || vis.style !== "bars"
    readonly property bool weActive: !!(wallpaper?.item?.weSurfaceVisible || wallpaper?.item?.weRunning || wallpaper?.weSurfaceActive || wallpaper?.weSurfaceVisible)
    readonly property bool workspaceOccupied: !(Hypr.monitorFor(root.screen)?.activeWorkspace?.toplevels?.values.every(t => t.lastIpcObject?.floating) ?? true)

    property color primaryCol: Qt.alpha(resolveM3Color(vis.primaryColorRole), vis.opacity)
    property color secondaryCol: Qt.alpha(resolveM3Color(vis.secondaryColorRole), vis.opacity)
    property color accentCol: Qt.alpha(resolveM3Color(vis.accentColorRole), vis.opacity)

    function resolveM3Color(role: string): color {
        switch (role) {
        case "secondary":
            return Colours.palette.m3secondary;
        case "tertiary":
            return Colours.palette.m3tertiary;
        case "inversePrimary":
            return Colours.palette.m3inversePrimary;
        case "onSurface":
            return Colours.palette.m3onSurface;
        case "primaryContainer":
            return Colours.palette.m3primaryContainer;
        case "secondaryContainer":
            return Colours.palette.m3secondaryContainer;
        case "tertiaryContainer":
            return Colours.palette.m3tertiaryContainer;
        case "inverseSurface":
            return Colours.palette.m3inverseSurface;
        default:
            return Colours.palette.m3primary;
        }
    }

    opacity: shouldBeActive ? 1 : 0

    Behavior on primaryCol {
        CAnim {}
    }
    Behavior on secondaryCol {
        CAnim {}
    }
    Behavior on accentCol {
        CAnim {}
    }

    Loader {
        asynchronous: true
        anchors.fill: parent
        active: root.opacity > 0 && root.vis.blur && !root.weActive

        sourceComponent: MultiEffect {
            source: root.wallpaper
            maskSource: wrapper
            maskEnabled: true
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
            blurEnabled: true
            blur: 1
            blurMax: 32
            autoPaddingEnabled: false
        }
    }

    Item {
        id: wrapper

        anchors.fill: parent
        layer.enabled: root.opacity > 0 && root.vis.blur && !root.weActive

        Loader {
            asynchronous: true
            anchors.fill: parent
            anchors.topMargin: root.offset
            anchors.bottomMargin: -root.offset

            active: root.opacity > 0

            sourceComponent: Item {
                ServiceRef {
                    service: Audio.cava
                }

                ServiceRef {
                    service: root.useGpuPipeline && root.vis.beatReactivity > 0.001 ? Audio.beatTracker : null
                }

                Binding {
                    target: Audio.cava
                    property: "monstercat"
                    value: GlobalConfig.background.visualiser.monstercat
                    when: root.opacity > 0
                }

                Connections {
                    function onBeat(bpm: real): void {
                        gpuView.triggerBeat(bpm);
                    }

                    target: Audio.beatTracker
                    enabled: root.useGpuPipeline && root.vis.beatReactivity > 0.001
                }

                Item {
                    id: stageBounds

                    readonly property real borderInset: GlobalConfig.appearance.islands ? 0 : Config.border.thickness

                    anchors.fill: parent
                    anchors.leftMargin: Config.bar.position === "left" ? root.barExclusiveZone : borderInset
                    anchors.rightMargin: Config.bar.position === "right" ? root.barExclusiveZone : borderInset
                    anchors.topMargin: Config.bar.position === "top" ? root.barExclusiveZone : borderInset
                    anchors.bottomMargin: Config.bar.position === "bottom" ? root.barExclusiveZone : borderInset

                    Behavior on anchors.leftMargin {
                        Anim {}
                    }
                    Behavior on anchors.rightMargin {
                        Anim {}
                    }
                    Behavior on anchors.topMargin {
                        Anim {}
                    }
                    Behavior on anchors.bottomMargin {
                        Anim {}
                    }

                    VisualiserView {
                        id: gpuView

                        anchors.fill: parent
                        visible: root.useGpuPipeline

                        values: Audio.cava.values
                        style: root.vis.style
                        position: root.vis.position
                        layout: root.vis.layout
                        mirrored: root.vis.mirrored
                        heightScale: root.vis.heightScale
                        rounding: Tokens.rounding.medium * root.vis.rounding
                        spacing: Tokens.spacing.extraSmall * root.vis.spacing
                        gradientMode: root.vis.gradientMode
                        primaryColor: root.primaryCol
                        secondaryColor: root.secondaryCol
                        accentColor: root.accentCol
                        glow: root.vis.glow
                        sensitivity: root.vis.sensitivity
                        attackMs: root.vis.attackMs
                        decayMs: root.vis.decayMs
                        beatReactivity: root.vis.beatReactivity
                        idleMode: root.vis.idleMode
                        idleTimeout: root.vis.idleTimeout
                        styleOptions: root.vis.options || ({})
                    }

                    VisualiserBars {
                        id: legacyBars

                        anchors.fill: parent
                        visible: !root.useGpuPipeline

                        values: Audio.cava.values
                        mirrored: root.vis.mirrored
                        singleRow: root.vis.layout === "full"
                        primaryColor: root.primaryCol
                        secondaryColor: root.secondaryCol
                        rounding: Tokens.rounding.medium * root.vis.rounding
                        spacing: Tokens.spacing.extraSmall * root.vis.spacing
                        animationDuration: Math.max(40, root.vis.decayMs)
                    }
                }

                FrameAnimation {
                    property real frameAccum: 0
                    readonly property real minFrameInterval: (root.weActive || root.workspaceOccupied) ? (1.0 / 30.0) : (1.0 / 60.0)

                    running: root.opacity > 0 && (root.useGpuPipeline ? !gpuView.settled : !legacyBars.settled)
                    onRunningChanged: if (!running) frameAccum = 0
                    onTriggered: {
                        frameAccum += frameTime;
                        if (frameAccum < minFrameInterval)
                            return;
                        const dt = frameAccum;
                        frameAccum = 0;
                        if (root.useGpuPipeline) {
                            gpuView.advance(dt);
                        } else {
                            legacyBars.advance(dt);
                        }
                    }
                }
            }
        }
    }

    Behavior on offset {
        Anim {}
    }

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Components
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property var visConfig: root.targetConfig.background.visualiser
    readonly property var visOpts: visConfig.options || ({})
    readonly property string activeStyle: visConfig.style || "aurora"
    readonly property bool isEnabled: visConfig.enabled
    readonly property bool isGpuActive: visConfig.renderer !== "cpu" || activeStyle !== "bars"

    readonly property list<string> styleValues: ["aurora", "bars", "wave", "dots", "glow"]
    readonly property list<MenuItem> styleItems: [
        MenuItem { text: qsTr("Aurora Waves") },
        MenuItem { text: qsTr("Bars") },
        MenuItem { text: qsTr("Smooth Wave") },
        MenuItem { text: qsTr("Floating Dots") },
        MenuItem { text: qsTr("Ambient Edge Glow") }
    ]

    readonly property list<string> positionValues: ["bottom", "top", "left", "right", "center"]
    readonly property list<MenuItem> positionItems: [
        MenuItem { text: qsTr("Bottom") },
        MenuItem { text: qsTr("Top") },
        MenuItem { text: qsTr("Left") },
        MenuItem { text: qsTr("Right") },
        MenuItem { text: qsTr("Center") }
    ]

    readonly property list<string> layoutValues: ["split", "full"]
    readonly property list<MenuItem> layoutItems: [
        MenuItem { text: qsTr("Split (Center gap)") },
        MenuItem { text: qsTr("Full width") }
    ]

    readonly property list<string> gradientValues: ["tritone", "vertical", "horizontal", "amplitude"]
    readonly property list<MenuItem> gradientItems: [
        MenuItem { text: qsTr("Tri-Tone Blend") },
        MenuItem { text: qsTr("Vertical") },
        MenuItem { text: qsTr("Horizontal") },
        MenuItem { text: qsTr("Amplitude") }
    ]

    readonly property list<string> colorRoleValues: ["primary", "inversePrimary", "secondary", "tertiary", "onSurface", "primaryContainer", "secondaryContainer", "tertiaryContainer", "inverseSurface"]
    readonly property list<MenuItem> primaryRoleItems: [
        MenuItem { text: qsTr("Primary") },
        MenuItem { text: qsTr("Inverse Primary") },
        MenuItem { text: qsTr("Secondary") },
        MenuItem { text: qsTr("Tertiary") },
        MenuItem { text: qsTr("On Surface") },
        MenuItem { text: qsTr("Primary Container") },
        MenuItem { text: qsTr("Secondary Container") },
        MenuItem { text: qsTr("Tertiary Container") },
        MenuItem { text: qsTr("Inverse Surface") }
    ]
    readonly property list<MenuItem> secondaryRoleItems: [
        MenuItem { text: qsTr("Primary") },
        MenuItem { text: qsTr("Inverse Primary") },
        MenuItem { text: qsTr("Secondary") },
        MenuItem { text: qsTr("Tertiary") },
        MenuItem { text: qsTr("On Surface") },
        MenuItem { text: qsTr("Primary Container") },
        MenuItem { text: qsTr("Secondary Container") },
        MenuItem { text: qsTr("Tertiary Container") },
        MenuItem { text: qsTr("Inverse Surface") }
    ]
    readonly property list<MenuItem> accentRoleItems: [
        MenuItem { text: qsTr("Primary") },
        MenuItem { text: qsTr("Inverse Primary") },
        MenuItem { text: qsTr("Secondary") },
        MenuItem { text: qsTr("Tertiary") },
        MenuItem { text: qsTr("On Surface") },
        MenuItem { text: qsTr("Primary Container") },
        MenuItem { text: qsTr("Secondary Container") },
        MenuItem { text: qsTr("Tertiary Container") },
        MenuItem { text: qsTr("Inverse Surface") }
    ]

    readonly property list<string> idleValues: ["ambient", "fade", "flat"]
    readonly property list<MenuItem> idleItems: [
        MenuItem { text: qsTr("Match style (Ambient drift)") },
        MenuItem { text: qsTr("Fade out") },
        MenuItem { text: qsTr("Flat resting") }
    ]

    readonly property list<MenuItem> rendererItems: [
        MenuItem { text: qsTr("GPU (Shader)") },
        MenuItem { text: qsTr("CPU (Legacy Bars)") }
    ]

    function indexOrDefault(values: list<string>, value: string, fallbackIdx: int): int {
        const idx = values.indexOf(value);
        return idx >= 0 ? idx : fallbackIdx;
    }

    function setVisOption(key: string, value: var): void {
        const next = Object.assign({}, root.visOpts);
        next[key] = value;
        root.visConfig.options = next;
        root.targetConfig.save();
    }

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

    function resetDefaults(): void {
        const keys = [
            "autoHide", "blur", "renderer", "style", "position", "layout", "mirrored",
            "heightScale", "opacity", "rounding", "spacing", "gradientMode",
            "primaryColorRole", "secondaryColorRole", "accentColorRole", "glow",
            "sensitivity", "attackMs", "decayMs", "beatReactivity", "monstercat",
            "idleMode", "idleTimeout", "options"
        ];
        for (const k of keys)
            root.visConfig.resetOption(k);
        root.targetConfig.save();
    }

    title: qsTr("Background visualiser")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Live Interactive Mini-Preview
        StyledRect {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            implicitHeight: 150
            radius: Tokens.rounding.extraLarge
            color: Colours.tPalette.m3surfaceContainerLowest
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.35)
            clip: true

            ServiceRef {
                service: root.visible ? Audio.cava : null
            }

            ServiceRef {
                service: root.visible && root.visConfig.beatReactivity > 0.001 ? Audio.beatTracker : null
            }

            Connections {
                function onBeat(bpm: real): void {
                    previewView.triggerBeat(bpm);
                }

                target: Audio.beatTracker
                enabled: root.visible && root.visConfig.beatReactivity > 0.001
            }

            VisualiserView {
                id: previewView

                anchors.fill: parent
                anchors.margins: root.activeStyle === "glow" ? 0 : Tokens.padding.small
                previewMode: true

                values: Audio.cava.values
                style: root.activeStyle
                position: root.visConfig.position
                layout: root.visConfig.layout
                mirrored: root.visConfig.mirrored
                heightScale: Math.min(0.8, root.visConfig.heightScale * 1.4)
                rounding: Tokens.rounding.medium * root.visConfig.rounding * 0.6
                spacing: Tokens.spacing.extraSmall * root.visConfig.spacing * 0.6
                gradientMode: root.visConfig.gradientMode
                primaryColor: Qt.alpha(root.resolveM3Color(root.visConfig.primaryColorRole), root.visConfig.opacity)
                secondaryColor: Qt.alpha(root.resolveM3Color(root.visConfig.secondaryColorRole), root.visConfig.opacity)
                accentColor: Qt.alpha(root.resolveM3Color(root.visConfig.accentColorRole), root.visConfig.opacity)
                glow: root.visConfig.glow
                sensitivity: root.visConfig.sensitivity
                attackMs: root.visConfig.attackMs
                decayMs: root.visConfig.decayMs
                beatReactivity: root.visConfig.beatReactivity
                idleMode: root.visConfig.idleMode
                idleTimeout: root.visConfig.idleTimeout
                styleOptions: root.visOpts
            }

            FrameAnimation {
                running: root.visible && !previewView.settled
                onTriggered: previewView.advance(frameTime)
            }

            StyledRect {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Tokens.padding.small
                radius: Tokens.rounding.full
                color: Qt.alpha(Colours.tPalette.m3surfaceContainerHigh, 0.8)
                implicitWidth: previewBadgeText.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: previewBadgeText.implicitHeight + Tokens.padding.extraSmall * 2

                StyledText {
                    id: previewBadgeText

                    anchors.centerIn: parent
                    text: root.styleItems[root.indexOrDefault(root.styleValues, root.activeStyle, 0)].text
                    font: Tokens.font.label.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }

        SectionHeader {
            first: true
            text: qsTr("General")
        }

        ToggleRow {
            first: true
            Layout.fillWidth: true
            text: qsTr("Enable background visualiser")
            configNode: root.visConfig
            propertyName: "enabled"
            checked: root.visConfig.enabled
            onToggled: {
                root.visConfig.enabled = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: qsTr("Auto-hide visualiser")
            subtext: qsTr("Hide visualiser when a tiled window is open")
            configNode: root.visConfig
            propertyName: "autoHide"
            checked: root.visConfig.autoHide
            onToggled: {
                root.visConfig.autoHide = checked;
                root.targetConfig.save();
            }
            disabled: !root.isEnabled
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: qsTr("Blur background")
            subtext: Wallpapers.committedWeDir !== "" ? qsTr("Unavailable while Wallpaper Engine is active") : qsTr("Blur the wallpaper behind the visualiser")
            configNode: root.visConfig
            propertyName: "blur"
            checked: root.visConfig.blur
            onToggled: {
                root.visConfig.blur = checked;
                root.targetConfig.save();
            }
            disabled: !(root.isEnabled && Wallpapers.committedWeDir === "")
        }

        SelectRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            label: qsTr("Renderer")
            subtext: root.activeStyle === "bars" ? qsTr("GPU shader recommended; CPU is legacy fallback for Bars") : qsTr("Using GPU shader pipeline for %1").arg(root.styleItems[root.indexOrDefault(root.styleValues, root.activeStyle, 0)].text)
            configNode: root.visConfig
            propertyName: "renderer"
            menuItems: root.rendererItems
            active: root.visConfig.renderer === "cpu" ? root.rendererItems[1] : root.rendererItems[0]
            onSelected: item => {
                root.visConfig.renderer = item === root.rendererItems[1] ? "cpu" : "gpu";
                root.targetConfig.save();
            }
            enabled: root.isEnabled && root.activeStyle === "bars"
        }

        SectionHeader {
            text: qsTr("Style & Options")
        }

        SelectRow {
            first: true
            Layout.fillWidth: true
            label: qsTr("Visualiser style")
            configNode: root.visConfig
            propertyName: "style"
            menuItems: root.styleItems
            active: root.styleItems[root.indexOrDefault(root.styleValues, root.activeStyle, 0)]
            onSelected: item => {
                const idx = root.styleItems.indexOf(item);
                if (idx >= 0) {
                    root.visConfig.style = root.styleValues[idx];
                    root.targetConfig.save();
                }
            }
            enabled: root.isEnabled
        }

        // --- Aurora Waves Options ---
        StepperRow {
            visible: root.activeStyle === "aurora"
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Ribbon layers")
            value: Math.round(Number(root.visOpts.auroraLayers ?? 3))
            from: 2
            to: 4
            stepSize: 1
            onMoved: v => root.setVisOption("auroraLayers", Math.round(v))
            enabled: root.isEnabled
        }

        SliderRow {
            visible: root.activeStyle === "aurora"
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Flow speed")
            value: (Number(root.visOpts.auroraSpeed ?? 0.85) - 0.2) / 2.3
            valueLabel: (0.2 + value * 2.3).toFixed(2) + "x"
            onMoved: v => root.setVisOption("auroraSpeed", 0.2 + v * 2.3)
            enabled: root.isEnabled
        }

        SliderRow {
            visible: root.activeStyle === "aurora"
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Curtain shimmer")
            value: Number(root.visOpts.auroraShimmer ?? 0.65)
            valueLabel: Math.round(value * 100) + "%"
            onMoved: v => root.setVisOption("auroraShimmer", v)
            enabled: root.isEnabled
        }

        // --- Bars Options ---
        SliderRow {
            visible: root.activeStyle === "bars"
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Rounding")
            configNode: root.visConfig
            propertyName: "rounding"
            value: root.visConfig.rounding / 10.0
            valueLabel: (value * 10.0).toFixed(1)
            onMoved: v => {
                root.visConfig.rounding = v * 10.0;
                root.targetConfig.save();
            }
            enabled: root.isEnabled
        }

        SliderRow {
            visible: root.activeStyle === "bars"
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Spacing")
            configNode: root.visConfig
            propertyName: "spacing"
            value: root.visConfig.spacing / 10.0
            valueLabel: (value * 10.0).toFixed(1)
            onMoved: v => {
                root.visConfig.spacing = v * 10.0;
                root.targetConfig.save();
            }
            enabled: root.isEnabled
        }

        ToggleRow {
            visible: root.activeStyle === "bars" && root.isGpuActive
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: qsTr("Peak-hold caps")
            subtext: qsTr("Floating caps that ease down with gravity")
            checked: root.visOpts.peakCaps ?? true
            onToggled: root.setVisOption("peakCaps", checked)
            disabled: !root.isEnabled
        }

        // --- Smooth Wave Options ---
        StepperRow {
            visible: root.activeStyle === "wave"
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Wave layers")
            value: Math.round(Number(root.visOpts.waveLayers ?? 2))
            from: 1
            to: 3
            stepSize: 1
            onMoved: v => root.setVisOption("waveLayers", Math.round(v))
            enabled: root.isEnabled
        }

        SliderRow {
            visible: root.activeStyle === "wave"
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Fill opacity")
            value: (Number(root.visOpts.waveFill ?? 0.45) - 0.1) / 0.85
            valueLabel: Math.round((0.1 + value * 0.85) * 100) + "%"
            onMoved: v => root.setVisOption("waveFill", 0.1 + v * 0.85)
            enabled: root.isEnabled
        }

        SliderRow {
            visible: root.activeStyle === "wave"
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Crest thickness")
            value: (Number(root.visOpts.waveCrest ?? 2.5) - 0.5) / 5.5
            valueLabel: (0.5 + value * 5.5).toFixed(1) + "px"
            onMoved: v => root.setVisOption("waveCrest", 0.5 + v * 5.5)
            enabled: root.isEnabled
        }

        // --- Floating Dots Options ---
        SliderRow {
            visible: root.activeStyle === "dots"
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Dot size")
            value: (Number(root.visOpts.dotSize ?? 1.0) - 0.4) / 2.1
            valueLabel: (0.4 + value * 2.1).toFixed(1) + "x"
            onMoved: v => root.setVisOption("dotSize", 0.4 + v * 2.1)
            enabled: root.isEnabled
        }

        ToggleRow {
            visible: root.activeStyle === "dots"
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: qsTr("Vertical trails")
            subtext: qsTr("Soft vertical light trails below each orb")
            checked: root.visOpts.dotTrails ?? true
            onToggled: root.setVisOption("dotTrails", checked)
            disabled: !root.isEnabled
        }

        // --- Ambient Edge Glow Options ---
        SliderRow {
            visible: root.activeStyle === "glow"
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Glow spread")
            value: (Number(root.visOpts.glowSpread ?? 0.8) - 0.25) / 1.25
            valueLabel: (0.25 + value * 1.25).toFixed(2) + "x"
            onMoved: v => root.setVisOption("glowSpread", 0.25 + v * 1.25)
            enabled: root.isEnabled
        }

        ToggleRow {
            visible: root.activeStyle === "glow"
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: qsTr("All-edges frame")
            subtext: qsTr("Wrap reactive glow around all four screen edges")
            checked: root.visOpts.glowAllEdges ?? false
            onToggled: root.setVisOption("glowAllEdges", checked)
            disabled: !root.isEnabled
        }

        StepperRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            label: qsTr("Visualiser bars")
            subtext: qsTr("Frequency resolution across all audio visualisers")
            configNode: GlobalConfig.services
            propertyName: "visualiserBars"
            value: GlobalConfig.services.visualiserBars
            from: 10
            to: 120
            stepSize: 2
            onMoved: v => {
                GlobalConfig.services.visualiserBars = Math.round(v);
                GlobalConfig.save();
            }
            enabled: root.isEnabled
        }

        SectionHeader {
            text: qsTr("Layout & Positioning")
        }

        SelectRow {
            first: true
            Layout.fillWidth: true
            label: qsTr("Position")
            configNode: root.visConfig
            propertyName: "position"
            menuItems: root.positionItems
            active: root.positionItems[root.indexOrDefault(root.positionValues, root.visConfig.position, 0)]
            onSelected: item => {
                const idx = root.positionItems.indexOf(item);
                if (idx >= 0) {
                    root.visConfig.position = root.positionValues[idx];
                    root.targetConfig.save();
                }
            }
            enabled: root.isEnabled
        }

        SelectRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Arrangement")
            configNode: root.visConfig
            propertyName: "layout"
            menuItems: root.layoutItems
            active: root.layoutItems[root.indexOrDefault(root.layoutValues, root.visConfig.layout, 0)]
            onSelected: item => {
                const idx = root.layoutItems.indexOf(item);
                if (idx >= 0) {
                    root.visConfig.layout = root.layoutValues[idx];
                    root.targetConfig.save();
                }
            }
            enabled: root.isEnabled
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: qsTr("Mirrored symmetry")
            subtext: qsTr("Mirror displacement symmetrically across the baseline")
            configNode: root.visConfig
            propertyName: "mirrored"
            checked: root.visConfig.mirrored
            onToggled: {
                root.visConfig.mirrored = checked;
                root.targetConfig.save();
            }
            disabled: !(root.isEnabled && root.activeStyle !== "glow")
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Height / Reach")
            configNode: root.visConfig
            propertyName: "heightScale"
            value: (root.visConfig.heightScale - 0.10) / 0.60
            valueLabel: Math.round((0.10 + value * 0.60) * 100) + "%"
            onMoved: v => {
                root.visConfig.heightScale = 0.10 + v * 0.60;
                root.targetConfig.save();
            }
            enabled: root.isEnabled
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            label: qsTr("Opacity")
            configNode: root.visConfig
            propertyName: "opacity"
            value: (root.visConfig.opacity - 0.10) / 0.90
            valueLabel: Math.round((0.10 + value * 0.90) * 100) + "%"
            onMoved: v => {
                root.visConfig.opacity = 0.10 + v * 0.90;
                root.targetConfig.save();
            }
            enabled: root.isEnabled
        }

        SectionHeader {
            text: qsTr("Colors & Polish")
        }

        SelectRow {
            first: true
            Layout.fillWidth: true
            label: qsTr("Gradient mode")
            configNode: root.visConfig
            propertyName: "gradientMode"
            menuItems: root.gradientItems
            active: root.gradientItems[root.indexOrDefault(root.gradientValues, root.visConfig.gradientMode, 0)]
            onSelected: item => {
                const idx = root.gradientItems.indexOf(item);
                if (idx >= 0) {
                    root.visConfig.gradientMode = root.gradientValues[idx];
                    root.targetConfig.save();
                }
            }
            enabled: root.isEnabled && root.isGpuActive
        }

        SelectRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Primary M3 color")
            configNode: root.visConfig
            propertyName: "primaryColorRole"
            menuItems: root.primaryRoleItems
            active: root.primaryRoleItems[root.indexOrDefault(root.colorRoleValues, root.visConfig.primaryColorRole, 0)]
            onSelected: item => {
                const idx = root.primaryRoleItems.indexOf(item);
                if (idx >= 0) {
                    root.visConfig.primaryColorRole = root.colorRoleValues[idx];
                    root.targetConfig.save();
                }
            }
            enabled: root.isEnabled
        }

        SelectRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Secondary M3 color")
            configNode: root.visConfig
            propertyName: "secondaryColorRole"
            menuItems: root.secondaryRoleItems
            active: root.secondaryRoleItems[root.indexOrDefault(root.colorRoleValues, root.visConfig.secondaryColorRole, 1)]
            onSelected: item => {
                const idx = root.secondaryRoleItems.indexOf(item);
                if (idx >= 0) {
                    root.visConfig.secondaryColorRole = root.colorRoleValues[idx];
                    root.targetConfig.save();
                }
            }
            enabled: root.isEnabled
        }

        SelectRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Accent M3 color")
            configNode: root.visConfig
            propertyName: "accentColorRole"
            menuItems: root.accentRoleItems
            active: root.accentRoleItems[root.indexOrDefault(root.colorRoleValues, root.visConfig.accentColorRole, 3)]
            onSelected: item => {
                const idx = root.accentRoleItems.indexOf(item);
                if (idx >= 0) {
                    root.visConfig.accentColorRole = root.colorRoleValues[idx];
                    root.targetConfig.save();
                }
            }
            enabled: root.isEnabled && root.isGpuActive
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            label: qsTr("Glow intensity")
            configNode: root.visConfig
            propertyName: "glow"
            value: root.visConfig.glow
            valueLabel: Math.round(value * 100) + "%"
            onMoved: v => {
                root.visConfig.glow = v;
                root.targetConfig.save();
            }
            enabled: root.isEnabled && root.isGpuActive
        }

        SectionHeader {
            text: qsTr("Audio Physics & Idle")
        }

        SliderRow {
            first: true
            Layout.fillWidth: true
            label: qsTr("Sensitivity")
            configNode: root.visConfig
            propertyName: "sensitivity"
            value: (root.visConfig.sensitivity - 0.2) / 2.8
            valueLabel: (0.2 + value * 2.8).toFixed(2) + "x"
            onMoved: v => {
                root.visConfig.sensitivity = 0.2 + v * 2.8;
                root.targetConfig.save();
            }
            enabled: root.isEnabled && root.isGpuActive
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Attack speed")
            configNode: root.visConfig
            propertyName: "attackMs"
            value: (root.visConfig.attackMs - 15) / 235.0
            valueLabel: Math.round(15 + value * 235) + "ms"
            onMoved: v => {
                root.visConfig.attackMs = Math.round(15 + v * 235);
                root.targetConfig.save();
            }
            enabled: root.isEnabled && root.isGpuActive
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Decay speed")
            configNode: root.visConfig
            propertyName: "decayMs"
            value: (root.visConfig.decayMs - 60) / 540.0
            valueLabel: Math.round(60 + value * 540) + "ms"
            onMoved: v => {
                root.visConfig.decayMs = Math.round(60 + v * 540);
                root.targetConfig.save();
            }
            enabled: root.isEnabled
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Beat reactivity")
            configNode: root.visConfig
            propertyName: "beatReactivity"
            value: root.visConfig.beatReactivity
            valueLabel: Math.round(value * 100) + "%"
            onMoved: v => {
                root.visConfig.beatReactivity = v;
                root.targetConfig.save();
            }
            enabled: root.isEnabled && root.isGpuActive
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: qsTr("Monstercat smoothing")
            subtext: qsTr("Blend adjacent frequency bars into smoother envelopes")
            configNode: root.visConfig
            propertyName: "monstercat"
            checked: root.visConfig.monstercat
            onToggled: {
                root.visConfig.monstercat = checked;
                root.targetConfig.save();
            }
            disabled: !root.isEnabled
        }

        SelectRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: root.visConfig.idleMode === "flat"
            Layout.fillWidth: true
            label: qsTr("Idle behavior")
            configNode: root.visConfig
            propertyName: "idleMode"
            menuItems: root.idleItems
            active: root.idleItems[root.indexOrDefault(root.idleValues, root.visConfig.idleMode, 0)]
            onSelected: item => {
                const idx = root.idleItems.indexOf(item);
                if (idx >= 0) {
                    root.visConfig.idleMode = root.idleValues[idx];
                    root.targetConfig.save();
                }
            }
            enabled: root.isEnabled && root.isGpuActive
        }

        SliderRow {
            visible: root.visConfig.idleMode !== "flat"
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            label: qsTr("Silence delay")
            configNode: root.visConfig
            propertyName: "idleTimeout"
            value: (root.visConfig.idleTimeout - 1.0) / 14.0
            valueLabel: (1.0 + value * 14.0).toFixed(1) + "s"
            onMoved: v => {
                root.visConfig.idleTimeout = 1.0 + v * 14.0;
                root.targetConfig.save();
            }
            enabled: root.isEnabled && root.isGpuActive
        }

        TextButton {
            Layout.alignment: Qt.AlignRight
            Layout.topMargin: Tokens.spacing.medium
            text: qsTr("Reset to defaults")
            type: TextButton.Tonal
            onClicked: root.resetDefaults()
        }
    }
}

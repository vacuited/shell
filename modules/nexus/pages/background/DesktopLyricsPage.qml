pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property var lyricsConfig: root.targetConfig.background.desktopLyrics
    readonly property string lyricsStyle: lyricsConfig.style || "apple"
    readonly property var lyricsOptions: lyricsConfig.options || ({})
    readonly property string curFontFamily: String(lyricsOptions.fontFamily ?? "body")
    readonly property bool isCustomFont: !["body", "display", "clock", "mono"].includes(curFontFamily)
    readonly property real resolvedGlow: (lyricsOptions.glowStrength !== undefined)
        ? Number(lyricsOptions.glowStrength)
        : defaultGlowForStyle(lyricsStyle)
    readonly property int resolvedLineCount: Math.round(Number(lyricsOptions.lineCount ?? (lyricsStyle === "minimal" ? 1 : 3)))

    readonly property list<string> styleValues: ["apple", "minimal", "editorial", "neon"]
    readonly property list<MenuItem> styleItems: [
        MenuItem { text: qsTr("Apple Flow") },
        MenuItem { text: qsTr("Minimal") },
        MenuItem { text: qsTr("Editorial") },
        MenuItem { text: qsTr("Neon Glow") }
    ]

    readonly property list<string> surfaceStyleValues: ["glass", "blur", "frosted", "material"]
    readonly property list<MenuItem> surfaceStyleItems: [
        MenuItem { text: qsTr("Glass") },
        MenuItem { text: qsTr("Blur") },
        MenuItem { text: qsTr("Frosted") },
        MenuItem { text: qsTr("Material") }
    ]

    readonly property list<string> positionValues: ["top-left", "top-center", "top-right", "middle-left", "middle-center", "middle-right", "bottom-left", "bottom-center", "bottom-right"]
    readonly property list<MenuItem> positionItems: [
        MenuItem { text: qsTr("Top Left") },
        MenuItem { text: qsTr("Top Center") },
        MenuItem { text: qsTr("Top Right") },
        MenuItem { text: qsTr("Middle Left") },
        MenuItem { text: qsTr("Middle Center") },
        MenuItem { text: qsTr("Middle Right") },
        MenuItem { text: qsTr("Bottom Left") },
        MenuItem { text: qsTr("Bottom Center") },
        MenuItem { text: qsTr("Bottom Right") }
    ]

    readonly property list<int> alignmentValues: [0, 1, 2]
    readonly property list<MenuItem> alignmentItems: [
        MenuItem { text: qsTr("Left") },
        MenuItem { text: qsTr("Center") },
        MenuItem { text: qsTr("Right") }
    ]

    readonly property list<string> verticalAnchorValues: ["top", "center", "bottom"]
    readonly property list<MenuItem> verticalAnchorItems: [
        MenuItem { text: qsTr("Top") },
        MenuItem { text: qsTr("Center") },
        MenuItem { text: qsTr("Bottom") }
    ]

    readonly property list<int> lineCountValues: [1, 3, 5]
    readonly property list<MenuItem> lineCountItems: [
        MenuItem { text: "1" },
        MenuItem { text: "3" },
        MenuItem { text: "5" }
    ]

    readonly property list<string> fontPresetValues: ["body", "display", "clock", "mono"]
    readonly property list<MenuItem> fontPresetBaseItems: [
        MenuItem { text: qsTr("Body"); value: "body" },
        MenuItem { text: qsTr("Display"); value: "display" },
        MenuItem { text: qsTr("Clock"); value: "clock" },
        MenuItem { text: qsTr("Mono"); value: "mono" }
    ]
    readonly property list<MenuItem> fontPresetCustomItems: [
        MenuItem { text: qsTr("Body"); value: "body" },
        MenuItem { text: qsTr("Display"); value: "display" },
        MenuItem { text: qsTr("Clock"); value: "clock" },
        MenuItem { text: qsTr("Mono"); value: "mono" },
        MenuItem { text: qsTr("Custom"); value: "custom" }
    ]

    readonly property list<string> fontWeightValues: ["regular", "medium", "demibold", "bold", "black"]
    readonly property list<MenuItem> fontWeightItems: [
        MenuItem { text: qsTr("Regular") },
        MenuItem { text: qsTr("Medium") },
        MenuItem { text: qsTr("DemiBold") },
        MenuItem { text: qsTr("Bold") },
        MenuItem { text: qsTr("Black") }
    ]

    readonly property list<string> colorRoleValues: ["", "primary", "secondary", "tertiary", "onSurface", "inverseSurface", "primaryContainer", "secondaryContainer", "tertiaryContainer"]
    readonly property list<MenuItem> activeColorItems: [
        MenuItem { text: qsTr("Auto") },
        MenuItem { text: qsTr("Primary") },
        MenuItem { text: qsTr("Secondary") },
        MenuItem { text: qsTr("Tertiary") },
        MenuItem { text: qsTr("On Surface") },
        MenuItem { text: qsTr("Inverse Surface") },
        MenuItem { text: qsTr("Primary Container") },
        MenuItem { text: qsTr("Secondary Container") },
        MenuItem { text: qsTr("Tertiary Container") }
    ]
    readonly property list<MenuItem> unsungColorItems: [
        MenuItem { text: qsTr("Auto") },
        MenuItem { text: qsTr("Primary") },
        MenuItem { text: qsTr("Secondary") },
        MenuItem { text: qsTr("Tertiary") },
        MenuItem { text: qsTr("On Surface") },
        MenuItem { text: qsTr("Inverse Surface") },
        MenuItem { text: qsTr("Primary Container") },
        MenuItem { text: qsTr("Secondary Container") },
        MenuItem { text: qsTr("Tertiary Container") }
    ]
    readonly property list<MenuItem> inactiveColorItems: [
        MenuItem { text: qsTr("Auto") },
        MenuItem { text: qsTr("Primary") },
        MenuItem { text: qsTr("Secondary") },
        MenuItem { text: qsTr("Tertiary") },
        MenuItem { text: qsTr("On Surface") },
        MenuItem { text: qsTr("Inverse Surface") },
        MenuItem { text: qsTr("Primary Container") },
        MenuItem { text: qsTr("Secondary Container") },
        MenuItem { text: qsTr("Tertiary Container") }
    ]

    readonly property list<string> secondaryTextModeValues: ["off", "auto", "translation", "romanization"]
    readonly property list<MenuItem> secondaryTextModeItems: [
        MenuItem { text: qsTr("Off") },
        MenuItem { text: qsTr("Auto") },
        MenuItem { text: qsTr("Translation") },
        MenuItem { text: qsTr("Romanization") }
    ]

    function setLyricsOption(key: string, value: var): void {
        const next = Object.assign({}, root.lyricsOptions);
        next[key] = value;
        root.lyricsConfig.options = next;
        root.targetConfig.save();
    }

    function setLyricsOptions(patch: var): void {
        const next = Object.assign({}, root.lyricsOptions, patch);
        root.lyricsConfig.options = next;
        root.targetConfig.save();
    }

    function indexOrDefault(values: list<string>, value: string, fallbackIdx: int): int {
        const idx = values.indexOf(value);
        return idx >= 0 ? idx : fallbackIdx;
    }

    function indexOrDefaultInt(values: list<int>, value: int, fallbackIdx: int): int {
        const idx = values.indexOf(value);
        return idx >= 0 ? idx : fallbackIdx;
    }

    function defaultGlowForStyle(style: string): real {
        switch (style) {
        case "neon":
            return 0.85;
        case "minimal":
            return 0.15;
        case "editorial":
            return 0.0;
        default:
            return 0.40;
        }
    }

    title: qsTr("Desktop lyrics")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("General")
        }

        ToggleRow {
            first: true
            Layout.fillWidth: true
            text: qsTr("Enable desktop lyrics")
            configNode: root.lyricsConfig
            propertyName: "enabled"
            checked: root.lyricsConfig.enabled
            onToggled: {
                root.lyricsConfig.enabled = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: qsTr("Edit on desktop")
            subtext: qsTr("Unlock desktop lyrics and widgets for dragging")
            checked: Visibilities.desktopWidgetsUnlocked
            onToggled: Visibilities.desktopWidgetsUnlocked = checked
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: qsTr("Overlay lyrics")
            subtext: qsTr("Render lyrics on top of all windows")
            configNode: root.lyricsConfig
            propertyName: "overlay"
            checked: root.lyricsConfig.overlay
            disabled: !root.lyricsConfig.enabled
            onToggled: {
                root.lyricsConfig.overlay = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: qsTr("Auto-hide for fullscreen windows")
            subtext: qsTr("Hide lyrics when a window is fullscreen")
            configNode: root.lyricsConfig
            propertyName: "autoHideFullscreen"
            checked: root.lyricsConfig.autoHideFullscreen
            disabled: !root.lyricsConfig.enabled
            onToggled: {
                root.lyricsConfig.autoHideFullscreen = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            text: qsTr("Auto-hide for tiled windows")
            subtext: qsTr("Hide lyrics when tiled windows are open")
            configNode: root.lyricsConfig
            propertyName: "autoHideTiled"
            checked: root.lyricsConfig.autoHideTiled
            disabled: !root.lyricsConfig.enabled
            onToggled: {
                root.lyricsConfig.autoHideTiled = checked;
                root.targetConfig.save();
            }
        }

        TextButton {
            Layout.alignment: Qt.AlignRight
            Layout.topMargin: Tokens.spacing.extraSmall
            text: qsTr("Reset desktop position")
            type: TextButton.Tonal
            disabled: root.lyricsConfig.x < 0 && root.lyricsConfig.y < 0
            onClicked: {
                root.lyricsConfig.x = -1;
                root.lyricsConfig.y = -1;
                root.targetConfig.save();
            }
        }

        SectionHeader {
            text: qsTr("Appearance & layout")
        }

        SelectRow {
            first: true
            Layout.fillWidth: true
            label: qsTr("Style")
            configNode: root.lyricsConfig
            propertyName: "style"
            menuItems: root.styleItems
            active: root.styleItems[root.indexOrDefault(root.styleValues, root.lyricsStyle, 0)]
            onSelected: item => {
                const idx = root.styleItems.indexOf(item);
                if (idx !== -1) {
                    root.lyricsConfig.style = root.styleValues[idx];
                    root.targetConfig.save();
                }
            }
        }

        SelectRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Surface style")
            configNode: root.lyricsConfig
            propertyName: "surfaceStyle"
            menuItems: root.surfaceStyleItems
            active: root.surfaceStyleItems[root.indexOrDefault(root.surfaceStyleValues, root.lyricsConfig.surfaceStyle || "glass", 0)]
            onSelected: item => {
                const idx = root.surfaceStyleItems.indexOf(item);
                if (idx !== -1) {
                    root.lyricsConfig.surfaceStyle = root.surfaceStyleValues[idx];
                    root.targetConfig.save();
                }
            }
        }

        SelectRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Position")
            configNode: root.lyricsConfig
            propertyName: "position"
            menuItems: root.positionItems
            active: root.positionItems[root.indexOrDefault(root.positionValues, root.lyricsConfig.position, 7)]
            onSelected: item => {
                const idx = root.positionItems.indexOf(item);
                if (idx !== -1) {
                    root.lyricsConfig.position = root.positionValues[idx];
                    root.lyricsConfig.x = -1;
                    root.lyricsConfig.y = -1;
                    root.targetConfig.save();
                }
            }
        }

        SelectRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Text alignment")
            configNode: root.lyricsConfig
            propertyName: "alignment"
            menuItems: root.alignmentItems
            active: root.alignmentItems[root.indexOrDefaultInt(root.alignmentValues, root.lyricsConfig.alignment, 1)]
            onSelected: item => {
                const idx = root.alignmentItems.indexOf(item);
                if (idx !== -1) {
                    root.lyricsConfig.alignment = root.alignmentValues[idx];
                    root.targetConfig.save();
                }
            }
        }

        SelectRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Active line anchor")
            subtext: qsTr("Where the currently sung line sits vertically")
            enabled: root.resolvedLineCount > 1
            menuItems: root.verticalAnchorItems
            active: root.verticalAnchorItems[root.indexOrDefault(root.verticalAnchorValues, String(root.lyricsOptions.verticalAnchor ?? "center"), 1)]
            onSelected: item => {
                const idx = root.verticalAnchorItems.indexOf(item);
                if (idx !== -1)
                    root.setLyricsOption("verticalAnchor", root.verticalAnchorValues[idx]);
            }
        }

        StepperRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Box width")
            subtext: qsTr("Horizontal width of the lyrics box (px)")
            configNode: root.lyricsConfig
            propertyName: "width"
            value: Math.round(root.lyricsConfig.width)
            from: 260
            to: 1100
            stepSize: 20
            onMoved: v => {
                root.lyricsConfig.width = Math.max(260, Math.min(1100, Math.round(v)));
                root.targetConfig.save();
            }
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Scale")
            configNode: root.lyricsConfig
            propertyName: "scale"
            value: Math.max(0, Math.min(1, (root.lyricsConfig.scale - 0.6) / 1.8))
            valueLabel: (0.6 + value * 1.8).toFixed(2) + "×"
            onMoved: v => {
                root.lyricsConfig.scale = Math.max(0.6, Math.min(2.4, Math.round((0.6 + v * 1.8) * 20) / 20));
                root.targetConfig.save();
            }
        }

        SelectRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            label: qsTr("Visible lines")
            menuItems: root.lineCountItems
            active: root.lineCountItems[root.indexOrDefaultInt(root.lineCountValues, root.resolvedLineCount, 1)]
            onSelected: item => {
                const idx = root.lineCountItems.indexOf(item);
                if (idx !== -1)
                    root.setLyricsOption("lineCount", root.lineCountValues[idx]);
            }
        }

        SectionHeader {
            text: qsTr("Typography & colors")
        }

        SelectRow {
            first: true
            Layout.fillWidth: true
            label: qsTr("Font preset")
            menuItems: root.isCustomFont ? root.fontPresetCustomItems : root.fontPresetBaseItems
            active: root.isCustomFont
                ? root.fontPresetCustomItems[4]
                : root.fontPresetBaseItems[root.indexOrDefault(root.fontPresetValues, root.curFontFamily, 0)]
            onSelected: item => {
                if (item.value && item.value !== "custom") {
                    root.setLyricsOption("fontFamily", item.value);
                    customFontRow.clear();
                }
            }
        }

        TextFieldRow {
            id: customFontRow

            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Custom font family")
            subtext: qsTr("Override preset with a system font name")
            value: root.isCustomFont ? root.curFontFamily : ""
            placeholderText: qsTr("Leave empty for preset")
            onEditingFinished: val => {
                const trimmed = val.trim();
                if (trimmed !== "") {
                    root.setLyricsOption("fontFamily", trimmed);
                } else if (root.isCustomFont) {
                    root.setLyricsOption("fontFamily", "body");
                }
            }
        }

        SelectRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Font weight")
            menuItems: root.fontWeightItems
            active: root.fontWeightItems[root.indexOrDefault(root.fontWeightValues, String(root.lyricsOptions.fontWeight ?? "bold"), 3)]
            onSelected: item => {
                const idx = root.fontWeightItems.indexOf(item);
                if (idx !== -1)
                    root.setLyricsOption("fontWeight", root.fontWeightValues[idx]);
            }
        }

        SelectRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Active word color")
            menuItems: root.activeColorItems
            active: root.activeColorItems[root.indexOrDefault(root.colorRoleValues, String(root.lyricsOptions.activeColor ?? ""), 0)]
            onSelected: item => {
                const idx = root.activeColorItems.indexOf(item);
                if (idx !== -1)
                    root.setLyricsOption("activeColor", root.colorRoleValues[idx]);
            }
        }

        SelectRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Unsung word color")
            menuItems: root.unsungColorItems
            active: root.unsungColorItems[root.indexOrDefault(root.colorRoleValues, String(root.lyricsOptions.unsungColor ?? ""), 0)]
            onSelected: item => {
                const idx = root.unsungColorItems.indexOf(item);
                if (idx !== -1)
                    root.setLyricsOption("unsungColor", root.colorRoleValues[idx]);
            }
        }

        SelectRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Inactive line color")
            menuItems: root.inactiveColorItems
            active: root.inactiveColorItems[root.indexOrDefault(root.colorRoleValues, String(root.lyricsOptions.inactiveColor ?? ""), 0)]
            onSelected: item => {
                const idx = root.inactiveColorItems.indexOf(item);
                if (idx !== -1)
                    root.setLyricsOption("inactiveColor", root.colorRoleValues[idx]);
            }
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            text: qsTr("Invert colors")
            subtext: qsTr("Invert the lyrics color when using light wallpaper")
            configNode: root.lyricsConfig
            propertyName: "invertColors"
            checked: root.lyricsConfig.invertColors
            onToggled: {
                root.lyricsConfig.invertColors = checked;
                root.targetConfig.save();
            }
        }

        SectionHeader {
            text: qsTr("Karaoke & effects")
        }

        ToggleRow {
            first: true
            Layout.fillWidth: true
            text: qsTr("Word lift")
            subtext: qsTr("Gently float active words upward while singing")
            checked: Boolean(root.lyricsOptions.wordLift ?? true)
            onToggled: root.setLyricsOption("wordLift", checked)
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: qsTr("Depth blur")
            subtext: qsTr("Softly blur inactive lines for depth")
            checked: Boolean(root.lyricsOptions.depthBlur ?? true)
            onToggled: root.setLyricsOption("depthBlur", checked)
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: qsTr("Fade top/bottom edges")
            subtext: qsTr("Smoothly fade lyrics near the top and bottom edges")
            checked: Boolean(root.lyricsOptions.fadeEdges ?? true)
            onToggled: root.setLyricsOption("fadeEdges", checked)
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Glow strength")
            value: Math.max(0, Math.min(1, root.resolvedGlow))
            valueLabel: Math.round(value * 100) + "%"
            onMoved: v => root.setLyricsOption("glowStrength", Math.round(v * 20) / 20)
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: qsTr("Instrumental dots")
            subtext: qsTr("Show pulsing dots during instrumental breaks")
            checked: Boolean(root.lyricsOptions.showInstrumentalDots ?? true)
            onToggled: root.setLyricsOption("showInstrumentalDots", checked)
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: qsTr("Backing vocals")
            subtext: qsTr("Show parenthetical or secondary vocal lines")
            checked: Boolean(root.lyricsOptions.showBackingVocals ?? true)
            onToggled: root.setLyricsOption("showBackingVocals", checked)
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: qsTr("Duet opposite alignment")
            subtext: qsTr("Align alternating singers to opposite sides")
            checked: Boolean(root.lyricsOptions.duetOppositeAlign ?? true)
            onToggled: root.setLyricsOption("duetOppositeAlign", checked)
        }

        SelectRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Secondary subtitle")
            subtext: qsTr("Translation or romanization shown under each line")
            menuItems: root.secondaryTextModeItems
            active: root.secondaryTextModeItems[root.indexOrDefault(root.secondaryTextModeValues, String(root.lyricsOptions.secondaryTextMode ?? "auto"), 1)]
            onSelected: item => {
                const idx = root.secondaryTextModeItems.indexOf(item);
                if (idx !== -1)
                    root.setLyricsOption("secondaryTextMode", root.secondaryTextModeValues[idx]);
            }
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            text: qsTr("Line-synced sweep")
            subtext: qsTr("Simulate a smooth sweep across line-synced lyrics")
            checked: Boolean(root.lyricsOptions.lineSyncedSweep ?? false)
            onToggled: root.setLyricsOption("lineSyncedSweep", checked)
        }

        SectionHeader {
            text: qsTr("Background")
        }

        ToggleRow {
            first: true
            Layout.fillWidth: true
            text: qsTr("Card background")
            configNode: root.lyricsConfig.background
            propertyName: "enabled"
            checked: root.lyricsConfig.background.enabled
            onToggled: {
                root.lyricsConfig.background.enabled = checked;
                root.targetConfig.save();
            }
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Opacity")
            configNode: root.lyricsConfig.background
            propertyName: "opacity"
            value: root.lyricsConfig.background.opacity
            valueLabel: Math.round(value * 100) + "%"
            enabled: root.lyricsConfig.background.enabled
            onMoved: v => {
                root.lyricsConfig.background.opacity = v;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            text: qsTr("Glass blur")
            subtext: qsTr("Blur the wallpaper behind Glass cards (Blur and Frosted always blur)")
            configNode: root.lyricsConfig.background
            propertyName: "blur"
            checked: root.lyricsConfig.background.blur
            disabled: !root.lyricsConfig.background.enabled
            onToggled: {
                root.lyricsConfig.background.blur = checked;
                root.targetConfig.save();
            }
        }

        SectionHeader {
            text: qsTr("Shadow")
        }

        ToggleRow {
            first: true
            Layout.fillWidth: true
            text: qsTr("Enable shadow")
            configNode: root.lyricsConfig.shadow
            propertyName: "enabled"
            checked: root.lyricsConfig.shadow.enabled
            onToggled: {
                root.lyricsConfig.shadow.enabled = checked;
                root.targetConfig.save();
            }
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Opacity")
            configNode: root.lyricsConfig.shadow
            propertyName: "opacity"
            value: root.lyricsConfig.shadow.opacity
            valueLabel: Math.round(value * 100) + "%"
            enabled: root.lyricsConfig.shadow.enabled
            onMoved: v => {
                root.lyricsConfig.shadow.opacity = v;
                root.targetConfig.save();
            }
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            label: qsTr("Blur strength")
            configNode: root.lyricsConfig.shadow
            propertyName: "blur"
            value: root.lyricsConfig.shadow.blur / 2.0
            valueLabel: (value * 2.0).toFixed(1)
            enabled: root.lyricsConfig.shadow.enabled
            onMoved: v => {
                root.lyricsConfig.shadow.blur = v * 2.0;
                root.targetConfig.save();
            }
        }
    }
}

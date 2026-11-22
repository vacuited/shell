pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

Item {
    id: root

    property bool open: false
    property string lyricsStyle: "apple"
    property string surfaceStyle: "glass"
    property real lyricsScale: 1.0
    property int lyricsWidth: 480
    property int alignment: 1
    property bool cardBackground: false
    property bool bgBlur: true
    property real bgOpacity: 0.7
    property bool shadowEnabled: true
    property bool invertColors: false
    property bool hasCustomPos: false
    property string positionPreset: "bottom-center"
    property bool sourceExpanded: false
    property var lyricsOptions: ({})
    property real anchorX: 0
    property real anchorY: 0
    property real anchorWidth: 480
    property real anchorHeight: 196
    property real safeLeft: 0
    property real safeTop: 0
    property real safeRight: 1920
    property real safeBottom: 1080

    readonly property string activeStyleLabel: styleLabel(lyricsStyle)
    readonly property string activeSurfaceLabel: surfaceLabel(surfaceStyle)
    readonly property int effectiveLineCount: {
        const raw = Number(lyricsOptions?.lineCount);
        if (raw === 1 || raw === 3 || raw === 5)
            return raw;
        return lyricsStyle === "minimal" ? 1 : 3;
    }

    readonly property list<string> positionPresets: [
        "top-left", "top-center", "top-right",
        "middle-left", "middle-center", "middle-right",
        "bottom-left", "bottom-center", "bottom-right"
    ]

    readonly property var colorPaletteRoles: [
        { key: "auto", label: qsTr("Auto"), swatch: Colours.palette.m3primary },
        { key: "primary", label: qsTr("Primary"), swatch: Colours.palette.m3primary },
        { key: "secondary", label: qsTr("Secondary"), swatch: Colours.palette.m3secondary },
        { key: "tertiary", label: qsTr("Tertiary"), swatch: Colours.palette.m3tertiary },
        { key: "onSurface", label: qsTr("On Surface"), swatch: Colours.palette.m3onSurface },
        { key: "inverseSurface", label: qsTr("Inverse"), swatch: Colours.palette.m3inverseSurface },
        { key: "primaryContainer", label: qsTr("Primary C"), swatch: Colours.palette.m3primaryContainer },
        { key: "secondaryContainer", label: qsTr("Secondary C"), swatch: Colours.palette.m3secondaryContainer },
        { key: "tertiaryContainer", label: qsTr("Tertiary C"), swatch: Colours.palette.m3tertiaryContainer }
    ]

    signal closed()
    signal styleSelected(string style)
    signal surfaceStyleSelected(string style)
    signal alignmentSelected(int alignment)
    signal positionPresetSelected(string pos)
    signal cardBackgroundToggled(bool enabled)
    signal toggleGlassBlur()
    signal opacityChangedLive(real opacity, bool save)
    signal scaleChangedLive(real scale, bool save)
    signal widthChangedLive(int width, bool save)
    signal shadowToggled(bool enabled)
    signal invertColorsToggled(bool enabled)
    signal optionPatched(var patch)
    signal centerRequested()
    signal resetPositionRequested()
    signal hideLyricsRequested()
    signal openNexusRequested()

    function styleLabel(style: string): string {
        switch (style) {
        case "minimal":
            return qsTr("Minimal");
        case "editorial":
            return qsTr("Editorial");
        case "neon":
            return qsTr("Neon Glow");
        default:
            return qsTr("Apple Flow");
        }
    }

    function surfaceLabel(style: string): string {
        switch (style) {
        case "blur":
            return qsTr("Blur");
        case "frosted":
            return qsTr("Frosted");
        case "material":
            return qsTr("Material");
        default:
            return qsTr("Glass");
        }
    }

    function backendDisplayName(b: int): string {
        switch (b) {
        case LyricsBackend.Local:
            return qsTr("Local");
        case LyricsBackend.Boidu:
            return "Boidu";
        case LyricsBackend.LyricsPlus:
            return "LyricsPlus";
        case LyricsBackend.NetEase:
            return "NetEase";
        case LyricsBackend.LRCLIB:
            return "LRCLIB";
        default:
            return qsTr("Automatic");
        }
    }

    function roleLabel(roles: var, key: string): string {
        for (let i = 0; i < roles.length; i++) {
            if (roles[i].key === key)
                return roles[i].label;
        }
        return roles.length > 0 ? roles[0].label : "";
    }

    function snapScale(normVal: real): real {
        const clamped = Math.max(0, Math.min(1, normVal));
        return Math.max(0.6, Math.min(2.4, Math.round((0.6 + clamped * 1.8) * 20) / 20));
    }

    function snapWidth(normVal: real): int {
        const clamped = Math.max(0, Math.min(1, normVal));
        return Math.max(260, Math.min(1100, Math.round((260 + clamped * 840) / 20) * 20));
    }

    function clampOpacity(normVal: real): real {
        const clamped = Math.max(0, Math.min(1, normVal));
        return Math.max(0.1, Math.min(1.0, Math.round((0.1 + clamped * 0.9) * 100) / 100));
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

    function positionLabel(pos: string): string {
        switch (pos) {
        case "top-left":
            return qsTr("Top Left");
        case "top-center":
            return qsTr("Top Center");
        case "top-right":
            return qsTr("Top Right");
        case "middle-left":
            return qsTr("Middle Left");
        case "middle-center":
            return qsTr("Middle Center");
        case "middle-right":
            return qsTr("Middle Right");
        case "bottom-left":
            return qsTr("Bottom Left");
        case "bottom-right":
            return qsTr("Bottom Right");
        default:
            return qsTr("Bottom Center");
        }
    }

    anchors.fill: parent
    z: 80
    visible: open

    // Backdrop dismiss layer when clicking outside popover while unlocked.
    MouseArea {
        anchors.fill: parent
        enabled: root.open
        onClicked: root.closed()
    }

    Item {
        id: popoverContainer

        readonly property int cardWidth: 352
        readonly property int maxCardHeight: Math.max(260, Math.round(root.safeBottom - root.safeTop - 24))
        readonly property int cardHeight: Math.min(maxCardHeight, Math.round(contentCol.implicitHeight + Tokens.padding.large * 2 + 2))

        readonly property real targetX: {
            const gap = Tokens.spacing.medium;
            const leftCandidate = root.anchorX - gap - cardWidth;
            const rightCandidate = root.anchorX + root.anchorWidth + gap;
            if (rightCandidate + cardWidth <= root.safeRight)
                return Math.round(rightCandidate);
            if (leftCandidate >= root.safeLeft)
                return Math.round(leftCandidate);
            const centered = root.anchorX + (root.anchorWidth - cardWidth) / 2;
            return Math.round(Math.max(root.safeLeft, Math.min(root.safeRight - cardWidth, centered)));
        }

        readonly property real targetY: {
            const gap = Tokens.spacing.medium;
            const placedHorizontally = (root.anchorX - gap - cardWidth >= root.safeLeft)
                || (root.anchorX + root.anchorWidth + gap + cardWidth <= root.safeRight);
            let desiredY = root.anchorY;
            if (!placedHorizontally) {
                const below = root.anchorY + root.anchorHeight + gap;
                const above = root.anchorY - gap - cardHeight;
                desiredY = (below + cardHeight <= root.safeBottom) ? below : Math.max(root.safeTop, above);
            }
            return Math.round(Math.max(root.safeTop, Math.min(root.safeBottom - cardHeight, desiredY)));
        }

        x: targetX
        y: targetY
        width: cardWidth
        height: cardHeight

        Elevation {
            anchors.fill: cardRect
            radius: cardRect.radius
            level: 3
        }

        StyledRect {
            id: cardRect

            anchors.fill: parent
            radius: Tokens.rounding.extraLarge
            color: WidgetMetrics.popoverSurface
            border.width: 1
            border.color: Colours.palette.m3outlineVariant

            // Consume pointer events inside card so clicks do not dismiss or drag behind it.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
            }

            Flickable {
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                contentWidth: width
                contentHeight: contentCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: contentCol

                    width: parent.width
                    spacing: Tokens.spacing.medium

                    // 1. Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        StyledRect {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: Tokens.rounding.small
                            color: Colours.palette.m3primaryContainer

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "lyrics"
                                fontStyle: Tokens.font.icon.small
                                color: Colours.palette.m3onPrimaryContainer
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Desktop Lyrics")
                                font: Tokens.font.title.builders.small.weight(Font.DemiBold).build()
                                color: Colours.palette.m3onSurface
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: {
                                    const src = Lyrics.hasLyrics ? root.backendDisplayName(Lyrics.backend) : qsTr("Preview");
                                    const mode = Lyrics.hasLyrics ? (Lyrics.isWordSynced ? qsTr("Word by Word") : qsTr("Synced")) : root.activeSurfaceLabel;
                                    return `${root.activeStyleLabel} · ${src} · ${mode}`;
                                }
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }

                        IconButton {
                            icon: "close"
                            type: IconButton.Text
                            onClicked: root.closed()
                        }
                    }

                    // 2. Style Preset
                    ChipGroup {
                        label: qsTr("Style")
                        activeKey: root.lyricsStyle
                        useSecondaryAccent: false
                        items: [
                            { key: "apple", label: qsTr("Apple Flow") },
                            { key: "minimal", label: qsTr("Minimal") },
                            { key: "editorial", label: qsTr("Editorial") },
                            { key: "neon", label: qsTr("Neon Glow") }
                        ]
                        onPicked: key => root.styleSelected(key)
                    }

                    // 3. Alignment, Position & Sizing
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        SegmentedGroup {
                            label: qsTr("Text Alignment")
                            activeKey: String(root.alignment)
                            items: [
                                { key: "0", icon: "format_align_left", label: qsTr("Left") },
                                { key: "1", icon: "format_align_center", label: qsTr("Center") },
                                { key: "2", icon: "format_align_right", label: qsTr("Right") }
                            ]
                            onPicked: key => root.alignmentSelected(parseInt(key, 10))
                        }

                        SegmentedGroup {
                            label: qsTr("Active Line Anchor")
                            activeKey: String(root.lyricsOptions?.verticalAnchor ?? "center")
                            enabled: root.effectiveLineCount > 1
                            opacity: enabled ? 1.0 : 0.45
                            items: [
                                { key: "top", icon: "vertical_align_top", label: qsTr("Top") },
                                { key: "center", icon: "vertical_align_center", label: qsTr("Center") },
                                { key: "bottom", icon: "vertical_align_bottom", label: qsTr("Bottom") }
                            ]
                            onPicked: key => root.optionPatched({ verticalAnchor: key })
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            StyledRect {
                                Layout.preferredWidth: 90
                                Layout.preferredHeight: 64
                                radius: Tokens.rounding.medium
                                color: WidgetMetrics.innerSurface
                                border.width: 1
                                border.color: WidgetMetrics.innerBorder

                                Grid {
                                    anchors.fill: parent
                                    anchors.margins: 5
                                    columns: 3
                                    columnSpacing: 4
                                    rowSpacing: 4

                                    Repeater {
                                        model: root.positionPresets

                                        delegate: StyledRect {
                                            id: posCell

                                            required property string modelData
                                            readonly property bool active: !root.hasCustomPos && root.positionPreset === modelData

                                            width: 24
                                            height: 15
                                            radius: 5
                                            color: active ? Colours.palette.m3primaryContainer : WidgetMetrics.innerSurfaceStrong
                                            border.width: active ? 1 : 0
                                            border.color: Colours.palette.m3primary

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: posCell.active ? 8 : 4
                                                height: width
                                                radius: width / 2
                                                color: posCell.active ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
                                            }

                                            StateLayer {
                                                onClicked: root.positionPresetSelected(posCell.modelData)
                                            }
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: Tokens.spacing.extraSmall

                                RowLayout {
                                    Layout.fillWidth: true

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: qsTr("Screen Position")
                                        font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
                                        color: Colours.palette.m3onSurfaceVariant
                                    }

                                    StyledText {
                                        text: root.hasCustomPos ? qsTr("Custom") : root.positionLabel(root.positionPreset)
                                        font: Tokens.font.label.small
                                        color: Colours.palette.m3primary
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Tokens.spacing.small

                                    StyledRect {
                                        Layout.fillWidth: true
                                        height: 32
                                        radius: 16
                                        color: WidgetMetrics.innerSurfaceStrong

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 5

                                            MaterialIcon {
                                                text: "center_focus_strong"
                                                fontStyle: Tokens.font.icon.small
                                                color: Colours.palette.m3onSurface
                                            }

                                            StyledText {
                                                text: qsTr("Center")
                                                font: Tokens.font.label.small
                                                color: Colours.palette.m3onSurface
                                            }
                                        }

                                        StateLayer {
                                            onClicked: root.centerRequested()
                                        }
                                    }

                                    StyledRect {
                                        Layout.fillWidth: true
                                        height: 32
                                        radius: 16
                                        enabled: root.hasCustomPos
                                        opacity: root.hasCustomPos ? 1.0 : 0.45
                                        color: WidgetMetrics.innerSurfaceStrong

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 5

                                            MaterialIcon {
                                                text: "restart_alt"
                                                fontStyle: Tokens.font.icon.small
                                                color: Colours.palette.m3onSurface
                                            }

                                            StyledText {
                                                text: qsTr("Reset")
                                                font: Tokens.font.label.small
                                                color: Colours.palette.m3onSurface
                                            }
                                        }

                                        StateLayer {
                                            disabled: !root.hasCustomPos
                                            onClicked: root.resetPositionRequested()
                                        }
                                    }
                                }
                            }
                        }

                        ChipGroup {
                            label: qsTr("Visible Lines")
                            activeKey: String(root.effectiveLineCount)
                            items: [
                                { key: "1", label: "1" },
                                { key: "3", label: "3" },
                                { key: "5", label: "5" }
                            ]
                            onPicked: key => root.optionPatched({ lineCount: parseInt(key, 10) })
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Width")
                                font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
                                color: Colours.palette.m3onSurfaceVariant
                            }

                            StyledText {
                                text: root.lyricsWidth + " px"
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurface
                            }
                        }

                        StyledSlider {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            Layout.bottomMargin: 4
                            implicitHeight: Tokens.padding.medium * 2
                            radius: Tokens.rounding.small
                            value: Math.max(0, Math.min(1, (root.lyricsWidth - 260) / 840))
                            onInteraction: v => root.widthChangedLive(root.snapWidth(v), false)
                            onReleased: v => root.widthChangedLive(root.snapWidth(v), true)
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Scale")
                                font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
                                color: Colours.palette.m3onSurfaceVariant
                            }

                            StyledRect {
                                visible: Math.abs(root.lyricsScale - 1.0) > 0.02
                                width: Math.round(resetScaleTxt.implicitWidth + Tokens.padding.small * 2)
                                height: 22
                                radius: 11
                                color: WidgetMetrics.innerSurfaceStrong

                                StyledText {
                                    id: resetScaleTxt

                                    anchors.centerIn: parent
                                    text: "1.0×"
                                    font: Tokens.font.label.small
                                    color: Colours.palette.m3primary
                                }

                                StateLayer {
                                    onClicked: root.scaleChangedLive(1.0, true)
                                }
                            }

                            StyledText {
                                text: root.lyricsScale.toFixed(2) + "×"
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurface
                            }
                        }

                        StyledSlider {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            Layout.bottomMargin: 4
                            implicitHeight: Tokens.padding.medium * 2
                            radius: Tokens.rounding.small
                            value: Math.max(0, Math.min(1, (root.lyricsScale - 0.6) / 1.8))
                            onInteraction: v => root.scaleChangedLive(root.snapScale(v), false)
                            onReleased: v => root.scaleChangedLive(root.snapScale(v), true)
                        }
                    }

                    // 4. Surface & Backdrop
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Surface")
                                font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
                                color: Colours.palette.m3onSurfaceVariant
                            }

                            StyledRect {
                                visible: root.cardBackground && (root.surfaceStyle === "glass" || !root.bgBlur)
                                width: Math.round(glassBlurBadge.implicitWidth + Tokens.padding.small * 2)
                                height: 22
                                radius: 11
                                color: root.bgBlur ? WidgetMetrics.innerSurfaceStrong : Colours.palette.m3tertiaryContainer

                                StyledText {
                                    id: glassBlurBadge

                                    anchors.centerIn: parent
                                    text: root.bgBlur ? qsTr("Glass blur: On") : qsTr("Glass blur: Off")
                                    font: Tokens.font.label.builders.small.weight(Font.Medium).build()
                                    color: root.bgBlur ? Colours.palette.m3onSurface : Colours.palette.m3onTertiaryContainer
                                }

                                StateLayer {
                                    onClicked: root.toggleGlassBlur()
                                }
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            Repeater {
                                model: [
                                    { key: "glass", label: qsTr("Glass") },
                                    { key: "blur", label: qsTr("Blur") },
                                    { key: "frosted", label: qsTr("Frosted") },
                                    { key: "material", label: qsTr("Material") }
                                ]

                                delegate: StyledRect {
                                    id: surfChip

                                    required property var modelData
                                    readonly property bool active: root.surfaceStyle === modelData.key

                                    width: Math.round(surfTxt.implicitWidth + Tokens.padding.medium * 2)
                                    height: 28
                                    radius: 14
                                    color: active ? Colours.palette.m3secondaryContainer : WidgetMetrics.innerSurfaceStrong
                                    border.width: active ? 1 : 0
                                    border.color: Colours.palette.m3secondary

                                    StyledText {
                                        id: surfTxt

                                        anchors.centerIn: parent
                                        text: surfChip.modelData.label
                                        font: Tokens.font.label.builders.small.weight(surfChip.active ? Font.Bold : Font.Medium).build()
                                        color: surfChip.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                    }

                                    StateLayer {
                                        onClicked: root.surfaceStyleSelected(surfChip.modelData.key)
                                    }
                                }
                            }
                        }

                        SwitchRow {
                            label: qsTr("Card Background")
                            checked: root.cardBackground
                            onToggled: state => root.cardBackgroundToggled(state)
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.extraSmall
                            enabled: root.cardBackground
                            opacity: enabled ? 1.0 : 0.45

                            RowLayout {
                                Layout.fillWidth: true

                                StyledText {
                                    Layout.fillWidth: true
                                    text: qsTr("Opacity")
                                    font: Tokens.font.label.small
                                    color: Colours.palette.m3onSurfaceVariant
                                }

                                StyledText {
                                    text: Math.round(root.bgOpacity * 100) + "%"
                                    font: Tokens.font.label.small
                                    color: Colours.palette.m3onSurface
                                }
                            }

                            StyledSlider {
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                Layout.bottomMargin: 4
                                implicitHeight: Tokens.padding.medium * 2
                                radius: Tokens.rounding.small
                                value: Math.max(0, Math.min(1, (root.bgOpacity - 0.1) / 0.9))
                                onInteraction: v => root.opacityChangedLive(root.clampOpacity(v), false)
                                onReleased: v => root.opacityChangedLive(root.clampOpacity(v), true)
                            }
                        }
                    }

                    // 5. Typography & Colors
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        ChipGroup {
                            label: qsTr("Font")
                            activeKey: String(root.lyricsOptions?.fontFamily ?? "body")
                            items: [
                                { key: "body", label: qsTr("Body") },
                                { key: "display", label: qsTr("Display") },
                                { key: "clock", label: qsTr("Clock") },
                                { key: "mono", label: qsTr("Mono") }
                            ]
                            onPicked: key => root.optionPatched({ fontFamily: key })
                        }

                        ChipGroup {
                            label: qsTr("Weight")
                            activeKey: String(root.lyricsOptions?.fontWeight ?? "bold")
                            items: [
                                { key: "regular", label: qsTr("Regular") },
                                { key: "medium", label: qsTr("Medium") },
                                { key: "demibold", label: qsTr("SemiBold") },
                                { key: "bold", label: qsTr("Bold") },
                                { key: "black", label: qsTr("Black") }
                            ]
                            onPicked: key => root.optionPatched({ fontWeight: key })
                        }

                        ColorSwatchGroup {
                            label: qsTr("Active Word Color")
                            activeKey: {
                                const raw = String(root.lyricsOptions?.activeColor ?? "");
                                return raw === "" ? "auto" : raw;
                            }
                            roles: root.colorPaletteRoles
                            onPicked: key => root.optionPatched({ activeColor: key === "auto" ? "" : key })
                        }

                        ColorSwatchGroup {
                            label: qsTr("Unsung Word Color")
                            activeKey: {
                                const raw = String(root.lyricsOptions?.unsungColor ?? "");
                                return raw === "" ? "auto" : raw;
                            }
                            roles: root.colorPaletteRoles
                            onPicked: key => root.optionPatched({ unsungColor: key === "auto" ? "" : key })
                        }

                        ColorSwatchGroup {
                            label: qsTr("Inactive Line Color")
                            activeKey: {
                                const raw = String(root.lyricsOptions?.inactiveColor ?? "");
                                return raw === "" ? "auto" : raw;
                            }
                            roles: root.colorPaletteRoles
                            onPicked: key => root.optionPatched({ inactiveColor: key === "auto" ? "" : key })
                        }
                    }

                    // 6. Karaoke & Effects
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        StyledText {
                            text: qsTr("Karaoke & Effects")
                            font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        SwitchRow {
                            label: qsTr("Word lift")
                            checked: Boolean(root.lyricsOptions?.wordLift ?? true)
                            onToggled: state => root.optionPatched({ wordLift: state })
                        }

                        SwitchRow {
                            label: qsTr("Depth blur")
                            checked: Boolean(root.lyricsOptions?.depthBlur ?? true)
                            onToggled: state => root.optionPatched({ depthBlur: state })
                        }

                        SwitchRow {
                            label: qsTr("Fade edges")
                            checked: Boolean(root.lyricsOptions?.fadeEdges ?? true)
                            onToggled: state => root.optionPatched({ fadeEdges: state })
                        }

                        SwitchRow {
                            label: qsTr("Instrumental dots")
                            checked: Boolean(root.lyricsOptions?.showInstrumentalDots ?? true)
                            onToggled: state => root.optionPatched({ showInstrumentalDots: state })
                        }

                        SwitchRow {
                            label: qsTr("Backing vocals")
                            checked: Boolean(root.lyricsOptions?.showBackingVocals ?? true)
                            onToggled: state => root.optionPatched({ showBackingVocals: state })
                        }

                        SwitchRow {
                            label: qsTr("Duet alignment")
                            checked: Boolean(root.lyricsOptions?.duetOppositeAlign ?? true)
                            onToggled: state => root.optionPatched({ duetOppositeAlign: state })
                        }

                        SwitchRow {
                            label: qsTr("Drop shadow")
                            checked: root.shadowEnabled
                            onToggled: state => root.shadowToggled(state)
                        }

                        SwitchRow {
                            label: qsTr("Invert colors")
                            checked: root.invertColors
                            onToggled: state => root.invertColorsToggled(state)
                        }

                        ChipGroup {
                            label: qsTr("Secondary Text")
                            activeKey: String(root.lyricsOptions?.secondaryTextMode ?? "auto")
                            items: [
                                { key: "off", label: qsTr("Off") },
                                { key: "auto", label: qsTr("Auto") },
                                { key: "translation", label: qsTr("Translation") },
                                { key: "romanization", label: qsTr("Romanized") }
                            ]
                            onPicked: key => root.optionPatched({ secondaryTextMode: key })
                        }

                        ColumnLayout {
                            id: glowCol

                            readonly property real curGlow: (root.lyricsOptions?.glowStrength !== undefined)
                                ? Number(root.lyricsOptions.glowStrength)
                                : root.defaultGlowForStyle(root.lyricsStyle)

                            Layout.fillWidth: true
                            spacing: Tokens.spacing.extraSmall

                            RowLayout {
                                Layout.fillWidth: true

                                StyledText {
                                    Layout.fillWidth: true
                                    text: qsTr("Glow")
                                    font: Tokens.font.label.small
                                    color: Colours.palette.m3onSurfaceVariant
                                }

                                StyledText {
                                    text: Math.round(glowCol.curGlow * 100) + "%"
                                    font: Tokens.font.label.small
                                    color: Colours.palette.m3onSurface
                                }
                            }

                            StyledSlider {
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                Layout.bottomMargin: 4
                                implicitHeight: Tokens.padding.medium * 2
                                radius: Tokens.rounding.small
                                value: Math.max(0, Math.min(1, glowCol.curGlow))
                                onInteraction: v => root.optionPatched({ glowStrength: Math.round(v * 20) / 20 })
                                onReleased: v => root.optionPatched({ glowStrength: Math.round(v * 20) / 20 })
                            }
                        }
                    }

                    // 7. Lyrics Source & Sync (Collapsible)
                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: sourceCol.implicitHeight + Tokens.padding.medium * 2
                        radius: Tokens.rounding.large
                        color: WidgetMetrics.innerSurface
                        border.width: 1
                        border.color: WidgetMetrics.innerBorder

                        ColumnLayout {
                            id: sourceCol

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Tokens.padding.medium
                            spacing: Tokens.spacing.extraSmall

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.spacing.extraSmall

                                StyledRect {
                                    Layout.fillWidth: true
                                    height: 30
                                    radius: Tokens.rounding.small
                                    color: "transparent"

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Tokens.padding.small
                                        anchors.rightMargin: Tokens.padding.small
                                        spacing: Tokens.spacing.small

                                        MaterialIcon {
                                            text: "lyrics"
                                            fontStyle: Tokens.font.icon.small
                                            color: Colours.palette.m3primary
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: {
                                                const src = Lyrics.hasLyrics
                                                    ? root.backendDisplayName(Lyrics.backend)
                                                    : (Lyrics.loading ? qsTr("Searching...") : qsTr("No lyrics"));
                                                return Lyrics.trackTitle !== "" ? `${src} · ${Lyrics.trackTitle}` : src;
                                            }
                                            font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
                                            color: Colours.palette.m3onSurface
                                            elide: Text.ElideRight
                                        }

                                        StyledRect {
                                            visible: Lyrics.hasLyrics
                                            width: Math.round(headerSyncTxt.implicitWidth + 10)
                                            height: 18
                                            radius: 9
                                            color: Lyrics.isWordSynced ? Colours.palette.m3primaryContainer : Colours.palette.m3secondaryContainer

                                            StyledText {
                                                id: headerSyncTxt

                                                anchors.centerIn: parent
                                                text: Lyrics.isWordSynced ? qsTr("WORD BY WORD") : qsTr("SYNCED")
                                                font.family: Tokens.font.label.small.family
                                                font.pointSize: Math.max(7, Tokens.font.label.small.pointSize - 2)
                                                font.weight: Font.Bold
                                                color: Lyrics.isWordSynced ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSecondaryContainer
                                            }
                                        }

                                        MaterialIcon {
                                            text: root.sourceExpanded ? "expand_less" : "expand_more"
                                            fontStyle: Tokens.font.icon.small
                                            color: Colours.palette.m3onSurfaceVariant
                                        }
                                    }

                                    StateLayer {
                                        onClicked: root.sourceExpanded = !root.sourceExpanded
                                    }
                                }

                                IconButton {
                                    icon: "refresh"
                                    type: IconButton.Text
                                    font: Tokens.font.icon.small
                                    disabled: Lyrics.trackTitle === "" && Lyrics.trackArtist === ""
                                    onClicked: Lyrics.refresh()
                                }
                            }

                            // Sync offset row
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.spacing.extraSmall

                                StyledText {
                                    Layout.fillWidth: true
                                    text: qsTr("Sync Offset: %1 ms").arg(Math.round(Lyrics.offset * 1000))
                                    font: Tokens.font.label.small
                                    color: Colours.palette.m3onSurfaceVariant
                                }

                                IconButton {
                                    icon: "restart_alt"
                                    type: IconButton.Text
                                    font: Tokens.font.icon.small
                                    visible: Math.abs(Lyrics.offset) > 0.001
                                    onClicked: Lyrics.offset = 0
                                }

                                IconButton {
                                    icon: "remove"
                                    type: IconButton.Tonal
                                    font: Tokens.font.icon.small
                                    onClicked: Lyrics.offset = Math.round((Lyrics.offset - 0.1) * 100) / 100
                                }

                                IconButton {
                                    icon: "add"
                                    type: IconButton.Tonal
                                    font: Tokens.font.icon.small
                                    onClicked: Lyrics.offset = Math.round((Lyrics.offset + 0.1) * 100) / 100
                                }
                            }

                            // Expanded providers body
                            ColumnLayout {
                                visible: root.sourceExpanded
                                Layout.fillWidth: true
                                Layout.topMargin: Tokens.spacing.extraSmall
                                spacing: Tokens.spacing.extraSmall

                                StyledRect {
                                    Layout.fillWidth: true
                                    height: 34
                                    radius: Tokens.rounding.medium
                                    color: !Lyrics.manualSource ? Colours.palette.m3secondaryContainer : "transparent"
                                    border.width: !Lyrics.manualSource ? 1 : 0
                                    border.color: Colours.palette.m3secondary

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Tokens.padding.small
                                        anchors.rightMargin: Tokens.padding.small
                                        spacing: Tokens.spacing.small

                                        MaterialIcon {
                                            text: "auto_awesome"
                                            fontStyle: Tokens.font.icon.small
                                            color: !Lyrics.manualSource ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: -2

                                            StyledText {
                                                text: qsTr("Automatic")
                                                font: Tokens.font.label.builders.small.weight(!Lyrics.manualSource ? Font.Bold : Font.Medium).build()
                                                color: !Lyrics.manualSource ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                            }

                                            StyledText {
                                                visible: !Lyrics.manualSource && Lyrics.hasLyrics && Lyrics.backend !== LyricsBackend.Auto
                                                text: qsTr("Showing %1").arg(root.backendDisplayName(Lyrics.backend))
                                                font: Tokens.font.label.small
                                                color: Colours.palette.m3onSecondaryContainer
                                                opacity: 0.8
                                            }
                                        }

                                        MaterialIcon {
                                            visible: !Lyrics.manualSource
                                            text: "check"
                                            fontStyle: Tokens.font.icon.small
                                            color: Colours.palette.m3onSecondaryContainer
                                        }
                                    }

                                    StateLayer {
                                        onClicked: Lyrics.selectProvider(LyricsBackend.Auto)
                                    }
                                }

                                Repeater {
                                    model: Lyrics.providerStates

                                    delegate: StyledRect {
                                        id: provRow

                                        required property var modelData
                                        readonly property bool isSelected: Lyrics.manualSource && Lyrics.backend === modelData.backend
                                        readonly property bool isCurrentActive: modelData.active
                                        readonly property bool isReady: modelData.status === "ready"
                                        readonly property bool isLoading: modelData.status === "loading"

                                        Layout.fillWidth: true
                                        height: 30
                                        radius: Tokens.rounding.small
                                        color: isSelected ? Colours.palette.m3primaryContainer : "transparent"

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: Tokens.padding.small
                                            anchors.rightMargin: Tokens.padding.small
                                            spacing: Tokens.spacing.small

                                            Rectangle {
                                                width: 12
                                                height: 12
                                                radius: 6
                                                color: "transparent"
                                                border.width: 1.5
                                                border.color: provRow.isCurrentActive ? Colours.palette.m3primary : Colours.palette.m3outline

                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: 6
                                                    height: 6
                                                    radius: 3
                                                    visible: provRow.isCurrentActive
                                                    color: Colours.palette.m3primary
                                                }
                                            }

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: provRow.modelData.label
                                                font: Tokens.font.label.builders.small.weight(provRow.isCurrentActive ? Font.Bold : Font.Medium).build()
                                                color: provRow.isReady || provRow.isLoading ? Colours.palette.m3onSurface : Colours.palette.m3outline
                                                elide: Text.ElideRight
                                            }

                                            MaterialIcon {
                                                visible: Boolean(provRow.modelData.hasTranslation || provRow.modelData.hasRomanization)
                                                text: "translate"
                                                fontStyle: Tokens.font.icon.small
                                                color: Colours.palette.m3onSurfaceVariant
                                            }

                                            StyledRect {
                                                visible: provRow.isReady || provRow.isLoading || provRow.modelData.status === "not_found" || provRow.modelData.status === "error"
                                                width: Math.round(badgeTxt.implicitWidth + 10)
                                                height: 18
                                                radius: 9
                                                color: {
                                                    if (!provRow.isReady)
                                                        return "transparent";
                                                    return provRow.modelData.syncType === "word"
                                                        ? Colours.palette.m3primaryContainer
                                                        : Colours.palette.m3secondaryContainer;
                                                }

                                                StyledText {
                                                    id: badgeTxt

                                                    anchors.centerIn: parent
                                                    text: {
                                                        if (provRow.isLoading)
                                                            return qsTr("Loading");
                                                        if (provRow.modelData.status === "error")
                                                            return qsTr("Error");
                                                        if (!provRow.isReady)
                                                            return qsTr("Not found");
                                                        return provRow.modelData.syncType === "word"
                                                            ? qsTr("WORD BY WORD")
                                                            : qsTr("SYNCED");
                                                    }
                                                    font.family: Tokens.font.label.small.family
                                                    font.pointSize: Math.max(7, Tokens.font.label.small.pointSize - 2)
                                                    font.weight: provRow.isReady ? Font.Bold : Font.Normal
                                                    color: {
                                                        if (!provRow.isReady)
                                                            return Colours.palette.m3outline;
                                                        return provRow.modelData.syncType === "word"
                                                            ? Colours.palette.m3onPrimaryContainer
                                                            : Colours.palette.m3onSecondaryContainer;
                                                    }
                                                }
                                            }
                                        }

                                        StateLayer {
                                            onClicked: Lyrics.selectProvider(provRow.modelData.backend)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 8. Footer: More in Nexus & Hide
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        StyledRect {
                            Layout.fillWidth: true
                            height: 34
                            radius: 17
                            color: WidgetMetrics.innerSurfaceStrong

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                MaterialIcon {
                                    text: "tune"
                                    fontStyle: Tokens.font.icon.small
                                    color: Colours.palette.m3onSurface
                                }

                                StyledText {
                                    text: qsTr("More in Nexus")
                                    font: Tokens.font.label.small
                                    color: Colours.palette.m3onSurface
                                }
                            }

                            StateLayer {
                                onClicked: {
                                    root.closed();
                                    root.openNexusRequested();
                                }
                            }
                        }

                        StyledRect {
                            Layout.preferredWidth: 96
                            height: 34
                            radius: 17
                            color: Colours.palette.m3errorContainer

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 4

                                MaterialIcon {
                                    text: "visibility_off"
                                    fontStyle: Tokens.font.icon.small
                                    color: Colours.palette.m3onErrorContainer
                                }

                                StyledText {
                                    text: qsTr("Hide")
                                    font: Tokens.font.label.small
                                    color: Colours.palette.m3onErrorContainer
                                }
                            }

                            StateLayer {
                                onClicked: {
                                    root.hideLyricsRequested();
                                    root.closed();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component SwitchRow: RowLayout {
        id: swRow

        required property string label
        property bool checked: false

        signal toggled(bool state)

        Layout.fillWidth: true

        StyledText {
            text: swRow.label
            font: Tokens.font.label.small
            color: Colours.palette.m3onSurface
            Layout.fillWidth: true
        }

        StyledSwitch {
            checked: swRow.checked
            onToggled: swRow.toggled(checked)
        }
    }

    component SegmentedGroup: ColumnLayout {
        id: segGroup

        required property string label
        required property string activeKey
        required property var items

        signal picked(string key)

        Layout.fillWidth: true
        spacing: Tokens.spacing.extraSmall

        StyledText {
            text: segGroup.label
            font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
            color: Colours.palette.m3onSurfaceVariant
        }

        StyledRect {
            Layout.fillWidth: true
            height: 32
            radius: 16
            color: WidgetMetrics.innerSurfaceStrong

            RowLayout {
                anchors.fill: parent
                anchors.margins: 3
                spacing: 3

                Repeater {
                    model: segGroup.items

                    delegate: StyledRect {
                        id: segBtn

                        required property var modelData
                        readonly property bool active: segGroup.activeKey === modelData.key

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 13
                        color: active ? Colours.palette.m3secondaryContainer : "transparent"
                        border.width: active ? 1 : 0
                        border.color: Colours.palette.m3secondary

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            MaterialIcon {
                                visible: Boolean(segBtn.modelData.icon ?? "")
                                text: String(segBtn.modelData.icon ?? "")
                                fontStyle: Tokens.font.icon.small
                                color: segBtn.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            }

                            StyledText {
                                text: segBtn.modelData.label
                                font: Tokens.font.label.builders.small.weight(segBtn.active ? Font.Bold : Font.Medium).build()
                                color: segBtn.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                            }
                        }

                        StateLayer {
                            onClicked: segGroup.picked(segBtn.modelData.key)
                        }
                    }
                }
            }
        }
    }

    component ChipGroup: ColumnLayout {
        id: chipGroup

        required property string label
        required property string activeKey
        required property var items
        property bool useSecondaryAccent: true

        signal picked(string key)

        Layout.fillWidth: true
        spacing: Tokens.spacing.extraSmall

        StyledText {
            text: chipGroup.label
            font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
            color: Colours.palette.m3onSurfaceVariant
        }

        Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Repeater {
                model: chipGroup.items

                delegate: StyledRect {
                    id: chip

                    required property var modelData
                    readonly property bool active: chipGroup.activeKey === modelData.key

                    width: Math.round(chipTxt.implicitWidth + Tokens.padding.medium * 2)
                    height: 26
                    radius: 13
                    color: active
                        ? (chipGroup.useSecondaryAccent ? Colours.palette.m3secondaryContainer : Colours.palette.m3primaryContainer)
                        : WidgetMetrics.innerSurfaceStrong
                    border.width: active ? 1 : 0
                    border.color: chipGroup.useSecondaryAccent ? Colours.palette.m3secondary : Colours.palette.m3primary

                    StyledText {
                        id: chipTxt

                        anchors.centerIn: parent
                        text: chip.modelData.label
                        font: Tokens.font.label.builders.small.weight(chip.active ? Font.Bold : Font.Medium).build()
                        color: chip.active
                            ? (chipGroup.useSecondaryAccent ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onPrimaryContainer)
                            : Colours.palette.m3onSurface
                    }

                    StateLayer {
                        onClicked: chipGroup.picked(chip.modelData.key)
                    }
                }
            }
        }
    }

    component ColorSwatchGroup: ColumnLayout {
        id: swatchGroup

        required property string label
        required property string activeKey
        required property var roles

        signal picked(string key)

        Layout.fillWidth: true
        spacing: Tokens.spacing.extraSmall

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true
                text: swatchGroup.label
                font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledText {
                text: root.roleLabel(swatchGroup.roles, swatchGroup.activeKey)
                font: Tokens.font.label.small
                color: Colours.palette.m3primary
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Repeater {
                model: swatchGroup.roles

                delegate: StyledRect {
                    id: swatchTile

                    required property var modelData
                    readonly property bool active: swatchGroup.activeKey === modelData.key

                    width: 28
                    height: 28
                    radius: 14
                    color: active ? Colours.palette.m3primaryContainer : WidgetMetrics.innerSurfaceStrong
                    border.width: active ? 1.5 : 1
                    border.color: active ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outlineVariant, 0.45)

                    Rectangle {
                        anchors.centerIn: parent
                        width: swatchTile.active ? 16 : 18
                        height: width
                        radius: width / 2
                        color: swatchTile.modelData.swatch
                        border.width: 1
                        border.color: Qt.alpha(Colours.palette.m3outline, 0.35)
                    }

                    StateLayer {
                        onClicked: swatchGroup.picked(swatchTile.modelData.key)
                    }
                }
            }
        }
    }
}

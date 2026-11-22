pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import M3Shapes
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

Item {
    id: root

    property bool open: false
    property string clockStyle: "classic"
    property string surfaceStyle: "glass"
    property real clockScale: 1.0
    property bool cardBackground: false
    property bool bgBlur: true
    property real bgOpacity: 0.7
    property bool shadowEnabled: true
    property bool invertColors: false
    property bool hasCustomPos: false
    property var clockOptions: ({})
    property real anchorX: 0
    property real anchorY: 0
    property real anchorWidth: 230
    property real anchorHeight: 230
    property real safeLeft: 0
    property real safeTop: 0
    property real safeRight: 1920
    property real safeBottom: 1080

    readonly property var cookieShapeCatalog: WidgetMetrics.shapeCatalog.filter(s => s.shape >= 0)
    readonly property string activeCookieShape: String(clockOptions?.shape ?? "Cookie9Sided")
    readonly property string activeStyleLabel: styleLabel(clockStyle)
    readonly property string activeSurfaceLabel: surfaceLabel(surfaceStyle)

    readonly property var fullPaletteRoles: [
        { key: "primary", label: qsTr("Primary"), swatch: Colours.palette.m3primary },
        { key: "secondary", label: qsTr("Secondary"), swatch: Colours.palette.m3secondary },
        { key: "tertiary", label: qsTr("Tertiary"), swatch: Colours.palette.m3tertiary },
        { key: "onSurface", label: qsTr("On Surface"), swatch: Colours.palette.m3onSurface },
        { key: "inverseSurface", label: qsTr("Inverse"), swatch: Colours.palette.m3inverseSurface },
        { key: "primaryContainer", label: qsTr("Primary C"), swatch: Colours.palette.m3primaryContainer },
        { key: "secondaryContainer", label: qsTr("Secondary C"), swatch: Colours.palette.m3secondaryContainer },
        { key: "tertiaryContainer", label: qsTr("Tertiary C"), swatch: Colours.palette.m3tertiaryContainer }
    ]

    readonly property var accentPaletteRoles: [
        { key: "default", label: qsTr("Default"), swatch: Colours.palette.m3primary },
        { key: "primary", label: qsTr("Primary"), swatch: Colours.palette.m3primary },
        { key: "secondary", label: qsTr("Secondary"), swatch: Colours.palette.m3secondary },
        { key: "tertiary", label: qsTr("Tertiary"), swatch: Colours.palette.m3tertiary },
        { key: "onSurface", label: qsTr("On Surface"), swatch: Colours.palette.m3onSurface },
        { key: "inverseSurface", label: qsTr("Inverse"), swatch: Colours.palette.m3inverseSurface }
    ]

    readonly property var smoothPaletteRoles: [
        { key: "onSurface", label: qsTr("On Surface"), swatch: Colours.palette.m3onSurface },
        { key: "primary", label: qsTr("Primary"), swatch: Colours.palette.m3primary },
        { key: "secondary", label: qsTr("Secondary"), swatch: Colours.palette.m3secondary },
        { key: "tertiary", label: qsTr("Tertiary"), swatch: Colours.palette.m3tertiary },
        { key: "inverseSurface", label: qsTr("Inverse"), swatch: Colours.palette.m3inverseSurface }
    ]

    signal closed()
    signal styleSelected(string style)
    signal surfaceStyleSelected(string style)
    signal cardBackgroundToggled(bool enabled)
    signal toggleGlassBlur()
    signal opacityChangedLive(real opacity, bool save)
    signal scaleChangedLive(real scale, bool save)
    signal shadowToggled(bool enabled)
    signal invertColorsToggled(bool enabled)
    signal optionPatched(var patch)
    signal centerRequested()
    signal resetPositionRequested()
    signal hideClockRequested()
    signal openNexusRequested()

    function styleLabel(style: string): string {
        switch (style) {
        case "cookie":
            return qsTr("Cookie");
        case "pixel":
            return qsTr("Pixel");
        case "stacked":
            return qsTr("Stacked");
        case "smooth":
            return qsTr("Smooth");
        default:
            return qsTr("Classic");
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

    function roleLabel(roles: var, key: string): string {
        for (let i = 0; i < roles.length; i++) {
            if (roles[i].key === key)
                return roles[i].label;
        }
        return roles.length > 0 ? roles[0].label : "";
    }

    function snapScale(normVal: real): real {
        const clamped = Math.max(0, Math.min(1, normVal));
        return Math.max(0.5, Math.min(3.0, Math.round((0.5 + clamped * 2.5) * 20) / 20));
    }

    function clampOpacity(normVal: real): real {
        const clamped = Math.max(0, Math.min(1, normVal));
        return Math.max(0.1, Math.min(1.0, Math.round((0.1 + clamped * 0.9) * 100) / 100));
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

        readonly property int cardWidth: 336
        readonly property int maxCardHeight: Math.max(240, Math.round(root.safeBottom - root.safeTop - 24))
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

                        Item {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32

                            MaterialShape {
                                anchors.fill: parent
                                visible: root.clockStyle === "cookie"
                                shape: {
                                    const s = WidgetMetrics.resolveShapeEnum(root.activeCookieShape, "Cookie9Sided");
                                    return s >= 0 ? s : MaterialShape.Cookie9Sided;
                                }
                                color: Colours.palette.m3primaryContainer
                            }

                            StyledRect {
                                anchors.fill: parent
                                visible: root.clockStyle !== "cookie"
                                radius: Tokens.rounding.small
                                color: Colours.palette.m3primaryContainer
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "schedule"
                                fontStyle: Tokens.font.icon.small
                                color: Colours.palette.m3onPrimaryContainer
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                text: qsTr("Desktop Clock")
                                font: Tokens.font.title.builders.small.weight(Font.DemiBold).build()
                                color: Colours.palette.m3onSurface
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            StyledText {
                                text: `${root.activeStyleLabel} · ${root.activeSurfaceLabel} · ${root.clockScale.toFixed(2)}×`
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurfaceVariant
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        IconButton {
                            icon: "close"
                            type: IconButton.Text
                            onClicked: root.closed()
                        }
                    }

                    // 2. Clock Style
                    ChipGroup {
                        label: qsTr("Style")
                        activeKey: root.clockStyle
                        useSecondaryAccent: false
                        items: [
                            { key: "classic", label: qsTr("Classic") },
                            { key: "cookie", label: qsTr("Cookie") },
                            { key: "pixel", label: qsTr("Pixel") },
                            { key: "stacked", label: qsTr("Stacked") },
                            { key: "smooth", label: qsTr("Smooth") }
                        ]
                        onPicked: key => root.styleSelected(key)
                    }

                    // 3. Surface
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
                                visible: root.surfaceStyle === "glass" || !root.bgBlur
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
                            visible: root.clockStyle !== "cookie"
                            label: qsTr("Card Background")
                            checked: root.cardBackground
                            onToggled: state => root.cardBackgroundToggled(state)
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.extraSmall
                            enabled: root.clockStyle === "cookie" || root.cardBackground || (root.clockStyle !== "classic" && root.surfaceStyle !== "material")
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

                    // 4. Size & Position
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Scale")
                                font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
                                color: Colours.palette.m3onSurfaceVariant
                            }

                            StyledRect {
                                visible: Math.abs(root.clockScale - 1.0) > 0.02
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
                                text: root.clockScale.toFixed(2) + "×"
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
                            value: Math.max(0, Math.min(1, (root.clockScale - 0.5) / 2.5))
                            onInteraction: v => root.scaleChangedLive(root.snapScale(v), false)
                            onReleased: v => root.scaleChangedLive(root.snapScale(v), true)
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
                                    spacing: 6

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
                                    spacing: 6

                                    MaterialIcon {
                                        text: "restart_alt"
                                        fontStyle: Tokens.font.icon.small
                                        color: Colours.palette.m3onSurface
                                    }

                                    StyledText {
                                        text: qsTr("Reset anchor")
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

                    // 5a. Cookie Options
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.clockStyle === "cookie"
                        spacing: Tokens.spacing.small

                        StyledText {
                            text: qsTr("Shape")
                            font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        Grid {
                            Layout.fillWidth: true
                            columns: 6
                            columnSpacing: 6
                            rowSpacing: 6

                            Repeater {
                                model: root.cookieShapeCatalog

                                delegate: StyledRect {
                                    id: shapeTile

                                    required property var modelData
                                    readonly property bool active: root.activeCookieShape === modelData.key

                                    width: 42
                                    height: 42
                                    radius: Tokens.rounding.medium
                                    color: active ? Colours.palette.m3primaryContainer : WidgetMetrics.innerSurfaceStrong
                                    border.width: active ? 1.5 : 0
                                    border.color: Colours.palette.m3primary

                                    MaterialShape {
                                        anchors.centerIn: parent
                                        width: 24
                                        height: 24
                                        shape: shapeTile.modelData.shape
                                        color: shapeTile.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                    }

                                    StateLayer {
                                        onClicked: root.optionPatched({ shape: shapeTile.modelData.key })
                                    }
                                }
                            }
                        }

                        SwitchRow {
                            label: qsTr("Rotate Shape")
                            checked: Boolean(root.clockOptions?.constantlyRotate ?? false)
                            onToggled: state => root.optionPatched({ constantlyRotate: state })
                        }

                        SwitchRow {
                            label: qsTr("Digital Backdrop")
                            checked: Boolean(root.clockOptions?.timeIndicators ?? true)
                            onToggled: state => root.optionPatched({ timeIndicators: state })
                        }

                        ChipGroup {
                            label: qsTr("Hour Hand")
                            activeKey: String(root.clockOptions?.hourHandStyle ?? "classic")
                            items: [
                                { key: "classic", label: qsTr("Classic") },
                                { key: "fill", label: qsTr("Fill") },
                                { key: "hollow", label: qsTr("Hollow") },
                                { key: "hide", label: qsTr("Hide") }
                            ]
                            onPicked: key => root.optionPatched({ hourHandStyle: key })
                        }

                        ChipGroup {
                            label: qsTr("Minute Hand")
                            activeKey: String(root.clockOptions?.minuteHandStyle ?? "classic")
                            items: [
                                { key: "classic", label: qsTr("Classic") },
                                { key: "thin", label: qsTr("Thin") },
                                { key: "medium", label: qsTr("Medium") },
                                { key: "bold", label: qsTr("Bold") },
                                { key: "hide", label: qsTr("Hide") }
                            ]
                            onPicked: key => root.optionPatched({ minuteHandStyle: key })
                        }

                        ChipGroup {
                            label: qsTr("Second Hand")
                            activeKey: String(root.clockOptions?.secondHandStyle ?? "line")
                            items: [
                                { key: "line", label: qsTr("Line") },
                                { key: "dot", label: qsTr("Dot") },
                                { key: "both", label: qsTr("Both") },
                                { key: "hide", label: qsTr("Hide") }
                            ]
                            onPicked: key => root.optionPatched({ secondHandStyle: key })
                        }

                        ChipGroup {
                            label: qsTr("Dial")
                            activeKey: String(root.clockOptions?.dialNumberStyle ?? "full")
                            items: [
                                { key: "full", label: qsTr("Ticks") },
                                { key: "dots", label: qsTr("Dots") },
                                { key: "numbers", label: qsTr("Numbers") },
                                { key: "none", label: qsTr("None") }
                            ]
                            onPicked: key => root.optionPatched({ dialNumberStyle: key })
                        }

                        ChipGroup {
                            label: qsTr("Date Badge")
                            activeKey: (root.clockOptions?.showDate === false)
                                ? "hide"
                                : String(root.clockOptions?.dateStyle ?? "bubble")
                            items: [
                                { key: "bubble", label: qsTr("Bubble") },
                                { key: "rect", label: qsTr("Filled") },
                                { key: "border", label: qsTr("Outline") },
                                { key: "hide", label: qsTr("Hide") }
                            ]
                            onPicked: key => root.optionPatched({
                                dateStyle: key,
                                showDate: key !== "hide"
                            })
                        }
                    }

                    // 5b. Classic Options
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.clockStyle === "classic"
                        spacing: Tokens.spacing.small

                        SwitchRow {
                            label: qsTr("Show Seconds")
                            checked: Boolean(root.clockOptions?.showSeconds ?? false)
                            onToggled: state => root.optionPatched({ showSeconds: state })
                        }

                        SwitchRow {
                            label: qsTr("Show Date")
                            checked: Boolean(root.clockOptions?.showDate ?? true)
                            onToggled: state => root.optionPatched({ showDate: state })
                        }

                        SwitchRow {
                            label: qsTr("Invert Colors")
                            checked: root.invertColors
                            onToggled: state => root.invertColorsToggled(state)
                        }

                        ColorSwatchGroup {
                            label: qsTr("Accent")
                            activeKey: {
                                const raw = String(root.clockOptions?.colorRole ?? "");
                                return raw === "" ? "default" : raw;
                            }
                            roles: root.accentPaletteRoles
                            onPicked: key => root.optionPatched({ colorRole: key === "default" ? "" : key })
                        }
                    }

                    // 5c. Pixel Options
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.clockStyle === "pixel"
                        spacing: Tokens.spacing.small

                        ChipGroup {
                            label: qsTr("Orientation")
                            activeKey: String(root.clockOptions?.orientation ?? "vertical")
                            items: [
                                { key: "vertical", label: qsTr("Vertical") },
                                { key: "horizontal", label: qsTr("Horizontal") }
                            ]
                            onPicked: key => root.optionPatched({ orientation: key })
                        }

                        ChipGroup {
                            label: qsTr("Font")
                            activeKey: String(root.clockOptions?.font ?? "gsans")
                            items: [
                                { key: "gsans", label: qsTr("Google Sans") },
                                { key: "titan", label: qsTr("Titan One") },
                                { key: "clock", label: qsTr("Clock Font") }
                            ]
                            onPicked: key => root.optionPatched({ font: key })
                        }

                        SwitchRow {
                            label: qsTr("Show Date")
                            checked: Boolean(root.clockOptions?.showDate ?? false)
                            onToggled: state => root.optionPatched({ showDate: state })
                        }

                        ColorSwatchGroup {
                            label: qsTr("Bold Digit")
                            activeKey: String(root.clockOptions?.boldColor ?? "inverseSurface")
                            roles: root.fullPaletteRoles
                            onPicked: key => root.optionPatched({ boldColor: key })
                        }

                        ColorSwatchGroup {
                            label: qsTr("Soft Digit")
                            activeKey: String(root.clockOptions?.softColor ?? "primary")
                            roles: root.fullPaletteRoles
                            onPicked: key => root.optionPatched({ softColor: key })
                        }
                    }

                    // 5d. Stacked Options
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.clockStyle === "stacked"
                        spacing: Tokens.spacing.small

                        ChipGroup {
                            label: qsTr("Alignment")
                            activeKey: String(root.clockOptions?.alignment ?? "left")
                            items: [
                                { key: "left", label: qsTr("Left") },
                                { key: "center", label: qsTr("Center") },
                                { key: "right", label: qsTr("Right") }
                            ]
                            onPicked: key => root.optionPatched({ alignment: key })
                        }

                        SwitchRow {
                            label: qsTr("Show Date")
                            checked: Boolean(root.clockOptions?.showDate ?? true)
                            onToggled: state => root.optionPatched({ showDate: state })
                        }

                        SwitchRow {
                            label: qsTr("Show Seconds")
                            checked: Boolean(root.clockOptions?.showSeconds ?? false)
                            onToggled: state => root.optionPatched({ showSeconds: state })
                        }

                        ChipGroup {
                            label: qsTr("Weight")
                            activeKey: String(root.clockOptions?.weight ?? root.clockOptions?.fontWeight ?? "medium")
                            items: [
                                { key: "light", label: qsTr("Light") },
                                { key: "regular", label: qsTr("Regular") },
                                { key: "medium", label: qsTr("Medium") },
                                { key: "bold", label: qsTr("Bold") }
                            ]
                            onPicked: key => root.optionPatched({ weight: key })
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Time Size: %1px").arg(Math.round(Number(root.clockOptions?.fontSize ?? 84)))
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurfaceVariant
                            }

                            IconButton {
                                icon: "remove"
                                type: IconButton.Tonal
                                onClicked: {
                                    const cur = Math.round(Number(root.clockOptions?.fontSize ?? 84));
                                    root.optionPatched({ fontSize: Math.max(36, cur - 4) });
                                }
                            }

                            IconButton {
                                icon: "add"
                                type: IconButton.Tonal
                                onClicked: {
                                    const cur = Math.round(Number(root.clockOptions?.fontSize ?? 84));
                                    root.optionPatched({ fontSize: Math.min(160, cur + 4) });
                                }
                            }
                        }

                        ColorSwatchGroup {
                            label: qsTr("Time Color")
                            activeKey: String(root.clockOptions?.timeColor ?? "primary")
                            roles: root.fullPaletteRoles
                            onPicked: key => root.optionPatched({ timeColor: key })
                        }

                        ColorSwatchGroup {
                            label: qsTr("Date Color")
                            activeKey: String(root.clockOptions?.labelColor ?? "onSurface")
                            roles: root.fullPaletteRoles
                            onPicked: key => root.optionPatched({ labelColor: key })
                        }
                    }

                    // 5e. Smooth Options
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.clockStyle === "smooth"
                        spacing: Tokens.spacing.small

                        SwitchRow {
                            label: qsTr("Date & Weather")
                            checked: Boolean(root.clockOptions?.showDateAndWeather ?? true)
                            onToggled: state => root.optionPatched({ showDateAndWeather: state })
                        }

                        SwitchRow {
                            label: qsTr("Show Seconds")
                            checked: Boolean(root.clockOptions?.showSeconds ?? false)
                            onToggled: state => root.optionPatched({ showSeconds: state })
                        }

                        ColorSwatchGroup {
                            label: qsTr("Time Color")
                            activeKey: String(root.clockOptions?.timeColor ?? "onSurface")
                            roles: root.smoothPaletteRoles
                            onPicked: key => root.optionPatched({ timeColor: key })
                        }
                    }

                    // 6. Behavior
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        StyledText {
                            text: qsTr("Behavior")
                            font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        SwitchRow {
                            label: qsTr("Hide with windows")
                            checked: Boolean(root.clockOptions?.hideWithWindows ?? false)
                            onToggled: state => root.optionPatched({ hideWithWindows: state })
                        }

                        SwitchRow {
                            label: qsTr("Drop shadow")
                            checked: root.shadowEnabled
                            onToggled: state => root.shadowToggled(state)
                        }
                    }

                    // 7. Footer: More in Nexus & Hide
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
                                    root.hideClockRequested();
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

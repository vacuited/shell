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
    property string widgetId: ""
    property string widgetType: ""
    property string sizeMode: "1x1"
    property real itemScale: 1.0
    property var supportedSizes: []
    property string surfaceStyle: ""
    property bool glassBlurEnabled: true
    property var widgetOptions: ({})
    property real anchorX: 0
    property real anchorY: 0
    property real anchorWidth: 164
    property real anchorHeight: 164
    property real safeLeft: 0
    property real safeTop: 0
    property real safeRight: 1920
    property real safeBottom: 1080
    readonly property var meta: WidgetMetrics.metaFor(widgetType)
    readonly property string canonicalType: WidgetMetrics.normalizeType(widgetType)
    readonly property string globalSurfaceStyle: Config.background.desktopWidgets.surfaceStyle || "glass"
    readonly property string effectiveSurfaceStyle: (surfaceStyle && surfaceStyle !== "") ? surfaceStyle : globalSurfaceStyle
    readonly property string activeOuterShape: WidgetMetrics.effectiveShapeKey(
        canonicalType,
        sizeMode,
        widgetOptions?.outerShape ?? ""
    )
    readonly property bool showShapeGrid: WidgetMetrics.supportsOuterShape(canonicalType)
        && (sizeMode === "1x1" || WidgetMetrics.isAspectResizable(canonicalType))

    signal closed()
    signal sizeModeSelected(string mode)
    signal itemScaleSelected(real nextScale)
    signal surfaceStyleSelected(string style)
    signal toggleGlassBlur()
    signal optionPatched(var patch)
    signal actionTriggered(string actionName)
    signal duplicateRequested()
    signal hideWidgetRequested()
    signal openNexusRequested()

    function syncTextFields(): void {
        const txt = String(widgetOptions?.content ?? widgetOptions?.text ?? "");
        if (customTextField.text !== txt && !customTextField.activeFocus)
            customTextField.text = txt;
        const cTitle = String(widgetOptions?.customTitle ?? "");
        if (customTitleField.text !== cTitle && !customTitleField.activeFocus)
            customTitleField.text = cTitle;
        const cDate = String(widgetOptions?.customDate ?? "");
        if (customDateField.text !== cDate && !customDateField.activeFocus) {
            customDateField.text = cDate;
            customDateField.isError = false;
        }
    }

    onOpenChanged: syncTextFields()
    onWidgetIdChanged: syncTextFields()
    onWidgetOptionsChanged: syncTextFields()
    Component.onCompleted: syncTextFields()

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

        readonly property int cardWidth: 320
        readonly property int maxCardHeight: Math.max(240, Math.round(root.safeBottom - root.safeTop - 24))
        readonly property int cardHeight: Math.min(maxCardHeight, Math.round(contentCol.implicitHeight + Tokens.padding.large * 2 + 2))

        readonly property real targetX: {
            const gap = Tokens.spacing.medium;
            const leftCandidate = root.anchorX - gap - cardWidth;
            const rightCandidate = root.anchorX + root.anchorWidth + gap;
            if (leftCandidate >= root.safeLeft)
                return Math.round(leftCandidate);
            if (rightCandidate + cardWidth <= root.safeRight)
                return Math.round(rightCandidate);
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

                    // Popover Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        Item {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32

                            MaterialShape {
                                anchors.fill: parent
                                shape: {
                                    const s = WidgetMetrics.resolveShapeEnum(root.activeOuterShape, "Cookie9Sided");
                                    return s >= 0 ? s : MaterialShape.Circle;
                                }
                                visible: WidgetMetrics.resolveShapeEnum(root.activeOuterShape, "Rounded") >= 0
                                color: Colours.palette.m3primaryContainer
                            }

                            StyledRect {
                                anchors.fill: parent
                                visible: WidgetMetrics.resolveShapeEnum(root.activeOuterShape, "Rounded") < 0
                                radius: Tokens.rounding.small
                                color: Colours.palette.m3primaryContainer
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: root.meta.icon
                                fontStyle: Tokens.font.icon.small
                                color: Colours.palette.m3onPrimaryContainer
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                text: root.meta.label
                                font: Tokens.font.title.builders.small.weight(Font.DemiBold).build()
                                color: Colours.palette.m3onSurface
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            StyledText {
                                text: WidgetMetrics.formatSizeLabel(root.sizeMode)
                                    + (Math.abs(root.itemScale - 1.0) >= 0.005 ? (" · " + WidgetMetrics.formatScaleLabel(root.itemScale)) : "")
                                    + " · "
                                    + (root.surfaceStyle === "" ? qsTr("Default (%1)").arg(root.globalSurfaceStyle) : root.surfaceStyle)
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurfaceVariant
                                Layout.fillWidth: true
                            }
                        }

                        IconButton {
                            icon: "close"
                            type: IconButton.Text
                            onClicked: root.closed()
                        }
                    }

                    // Size presets (when widget supports discrete modes)
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: (root.supportedSizes?.length ?? 0) > 0
                        spacing: Tokens.spacing.small

                        StyledText {
                            text: qsTr("Size")
                            font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            Repeater {
                                model: root.supportedSizes ?? []

                                delegate: StyledRect {
                                    id: sizeChip

                                    required property string modelData
                                    readonly property bool active: root.sizeMode === modelData

                                    width: Math.round(sizeChipText.implicitWidth + Tokens.padding.medium * 2)
                                    height: 28
                                    radius: 14
                                    color: active ? Colours.palette.m3primaryContainer : WidgetMetrics.innerSurfaceStrong
                                    border.width: active ? 1 : 0
                                    border.color: Colours.palette.m3primary

                                    StyledText {
                                        id: sizeChipText

                                        anchors.centerIn: parent
                                        text: WidgetMetrics.formatSizeLabel(sizeChip.modelData)
                                        font: Tokens.font.label.builders.small.weight(sizeChip.active ? Font.Bold : Font.Medium).build()
                                        color: sizeChip.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                                    }

                                    StateLayer {
                                        onClicked: root.sizeModeSelected(sizeChip.modelData)
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.extraSmall

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Scale")
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurfaceVariant
                            }

                            IconButton {
                                icon: "remove"
                                type: IconButton.Tonal
                                disabled: root.itemScale <= WidgetMetrics.minWidgetScale + 0.005
                                onClicked: root.itemScaleSelected(WidgetMetrics.clampItemScale(root.itemScale - 0.05))
                            }

                            StyledRect {
                                id: scaleResetPill

                                readonly property bool isCustomScale: Math.abs(root.itemScale - 1.0) >= 0.005

                                Layout.preferredWidth: Math.max(54, Math.round(scaleResetText.implicitWidth + Tokens.padding.medium * 2))
                                height: 28
                                radius: 14
                                color: isCustomScale ? Colours.palette.m3primaryContainer : WidgetMetrics.innerSurfaceStrong
                                border.width: isCustomScale ? 1 : 0
                                border.color: Colours.palette.m3primary

                                StyledText {
                                    id: scaleResetText

                                    anchors.centerIn: parent
                                    text: WidgetMetrics.formatScaleLabel(root.itemScale)
                                    font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
                                    color: scaleResetPill.isCustomScale ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                                }

                                StateLayer {
                                    enabled: scaleResetPill.isCustomScale
                                    onClicked: root.itemScaleSelected(1.0)
                                }
                            }

                            IconButton {
                                icon: "add"
                                type: IconButton.Tonal
                                disabled: root.itemScale >= WidgetMetrics.maxWidgetScale - 0.005
                                onClicked: root.itemScaleSelected(WidgetMetrics.clampItemScale(root.itemScale + 0.05))
                            }
                        }
                    }

                    // Surface style
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
                                visible: root.effectiveSurfaceStyle === "glass" || !root.glassBlurEnabled
                                width: Math.round(glassBlurBadge.implicitWidth + Tokens.padding.small * 2)
                                height: 22
                                radius: 11
                                color: root.glassBlurEnabled ? WidgetMetrics.innerSurfaceStrong : Colours.palette.m3tertiaryContainer

                                StyledText {
                                    id: glassBlurBadge

                                    anchors.centerIn: parent
                                    text: root.glassBlurEnabled ? qsTr("Glass blur: On") : qsTr("Glass blur: Off")
                                    font: Tokens.font.label.builders.small.weight(Font.Medium).build()
                                    color: root.glassBlurEnabled ? Colours.palette.m3onSurface : Colours.palette.m3onTertiaryContainer
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
                                    { key: "", label: qsTr("Default") },
                                    { key: "glass", label: qsTr("Glass") },
                                    { key: "blur", label: qsTr("Blur") },
                                    { key: "frosted", label: qsTr("Frosted") },
                                    { key: "material", label: qsTr("Material") }
                                ]

                                delegate: StyledRect {
                                    id: surfChip

                                    required property var modelData
                                    readonly property bool active: (root.surfaceStyle ?? "") === modelData.key

                                    width: Math.round(surfText.implicitWidth + Tokens.padding.medium * 2)
                                    height: 28
                                    radius: 14
                                    color: active ? Colours.palette.m3secondaryContainer : WidgetMetrics.innerSurfaceStrong
                                    border.width: active ? 1 : 0
                                    border.color: Colours.palette.m3secondary

                                    StyledText {
                                        id: surfText

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
                    }

                    // Outer MaterialShape picker
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.showShapeGrid
                        spacing: Tokens.spacing.small

                        StyledText {
                            text: qsTr("Outer Shape")
                            font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        Grid {
                            Layout.fillWidth: true
                            columns: 6
                            columnSpacing: 6
                            rowSpacing: 6

                            Repeater {
                                model: WidgetMetrics.shapeCatalog

                                delegate: StyledRect {
                                    id: shapeTile

                                    required property var modelData
                                    readonly property bool active: root.activeOuterShape === modelData.key

                                    width: 42
                                    height: 42
                                    radius: Tokens.rounding.medium
                                    color: active ? Colours.palette.m3primaryContainer : WidgetMetrics.innerSurfaceStrong
                                    border.width: active ? 1.5 : 0
                                    border.color: Colours.palette.m3primary

                                    MaterialShape {
                                        visible: shapeTile.modelData.shape >= 0
                                        anchors.centerIn: parent
                                        width: 24
                                        height: 24
                                        shape: shapeTile.modelData.shape >= 0 ? shapeTile.modelData.shape : MaterialShape.Circle
                                        color: shapeTile.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                    }

                                    StyledRect {
                                        visible: shapeTile.modelData.shape < 0
                                        anchors.centerIn: parent
                                        width: 22
                                        height: 22
                                        radius: 6
                                        color: shapeTile.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                    }

                                    StateLayer {
                                        onClicked: {
                                            if (root.canonicalType === "customText" && shapeTile.modelData.shape >= 0) {
                                                root.optionPatched({
                                                    outerShape: shapeTile.modelData.key,
                                                    backdropMode: "shape"
                                                });
                                            } else {
                                                root.optionPatched({ outerShape: shapeTile.modelData.key });
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Widget-specific controls: Custom Image / Sticker
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.canonicalType === "customImage" || root.canonicalType === "sticker"
                        spacing: Tokens.spacing.small

                        StyledRect {
                            Layout.fillWidth: true
                            height: 36
                            radius: Tokens.rounding.large
                            color: Colours.palette.m3primaryContainer

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: Tokens.spacing.small

                                MaterialIcon {
                                    text: "add_photo_alternate"
                                    fontStyle: Tokens.font.icon.small
                                    color: Colours.palette.m3onPrimaryContainer
                                }

                                StyledText {
                                    text: root.canonicalType === "sticker" ? qsTr("Choose sticker...") : qsTr("Choose image...")
                                    font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
                                    color: Colours.palette.m3onPrimaryContainer
                                }
                            }

                            StateLayer {
                                onClicked: root.actionTriggered("pickFile")
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: root.canonicalType === "customImage"
                            spacing: Tokens.spacing.small

                            StyledText {
                                text: qsTr("Aspect")
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurfaceVariant
                                Layout.fillWidth: true
                            }

                            Repeater {
                                model: [
                                    { key: "shape", label: qsTr("1:1 Crop") },
                                    { key: "auto", label: qsTr("Original") }
                                ]

                                delegate: StyledRect {
                                    id: fitChip

                                    required property var modelData
                                    readonly property bool active: (root.widgetOptions?.fitMode ?? "shape") === modelData.key

                                    width: Math.round(fitTxt.implicitWidth + Tokens.padding.medium * 2)
                                    height: 26
                                    radius: 13
                                    color: active ? Colours.palette.m3primaryContainer : WidgetMetrics.innerSurfaceStrong

                                    StyledText {
                                        id: fitTxt

                                        anchors.centerIn: parent
                                        text: fitChip.modelData.label
                                        font: Tokens.font.label.small
                                        color: fitChip.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                                    }

                                    StateLayer {
                                        onClicked: root.optionPatched({ fitMode: fitChip.modelData.key })
                                    }
                                }
                            }
                        }
                    }

                    // Widget-specific controls: Custom Text
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.canonicalType === "customText"
                        spacing: Tokens.spacing.small

                        StyledTextField {
                            id: customTextField

                            Layout.fillWidth: true
                            placeholderText: qsTr("Text content...")
                            onTextEdited: root.optionPatched({ content: text })
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            StyledText {
                                text: qsTr("Backdrop")
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurfaceVariant
                                Layout.fillWidth: true
                            }

                            Repeater {
                                model: [
                                    { key: "none", label: qsTr("None") },
                                    { key: "pill", label: qsTr("Pill") },
                                    { key: "card", label: qsTr("Card") },
                                    { key: "shape", label: qsTr("Shape") }
                                ]

                                delegate: StyledRect {
                                    id: bdChip

                                    required property var modelData
                                    readonly property bool active: (root.widgetOptions?.backdropMode ?? "none") === modelData.key

                                    width: Math.round(bdTxt.implicitWidth + Tokens.padding.small * 2)
                                    height: 26
                                    radius: 13
                                    color: active ? Colours.palette.m3primaryContainer : WidgetMetrics.innerSurfaceStrong

                                    StyledText {
                                        id: bdTxt

                                        anchors.centerIn: parent
                                        text: bdChip.modelData.label
                                        font: Tokens.font.label.small
                                        color: bdChip.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                                    }

                                    StateLayer {
                                        onClicked: root.optionPatched({ backdropMode: bdChip.modelData.key })
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            StyledText {
                                text: qsTr("Font Size: %1pt").arg(Math.round(root.widgetOptions?.fontSize ?? 28))
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurfaceVariant
                                Layout.fillWidth: true
                            }

                            IconButton {
                                icon: "remove"
                                type: IconButton.Tonal
                                onClicked: root.optionPatched({ fontSize: Math.max(12, Math.round((root.widgetOptions?.fontSize ?? 28) - 4)) })
                            }

                            IconButton {
                                icon: "add"
                                type: IconButton.Tonal
                                onClicked: root.optionPatched({ fontSize: Math.min(140, Math.round((root.widgetOptions?.fontSize ?? 28) + 4)) })
                            }
                        }
                    }

                    // Widget-specific controls: Countdown
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.canonicalType === "countdown"
                        spacing: Tokens.spacing.small

                        StyledText {
                            visible: (FocusLedger.countdowns || []).length > 0
                            text: qsTr("Shared Countdown")
                            font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        Flow {
                            Layout.fillWidth: true
                            visible: (FocusLedger.countdowns || []).length > 0
                            spacing: Tokens.spacing.small

                            Repeater {
                                model: {
                                    void FocusLedger.revision;
                                    return FocusLedger.countdowns || [];
                                }

                                delegate: StyledRect {
                                    id: cdPickChip

                                    required property var modelData
                                    readonly property bool hasCustomDate: FocusLedger.parseLocalDate(String(root.widgetOptions?.customDate ?? "").trim()) !== null
                                    readonly property bool active: !hasCustomDate && String(root.widgetOptions?.countdownId ?? "") === String(modelData?.id ?? "")

                                    width: Math.min(260, Math.round(cdChipTxt.implicitWidth + Tokens.padding.medium * 2))
                                    height: 26
                                    radius: 13
                                    color: active ? Colours.palette.m3primaryContainer : WidgetMetrics.innerSurfaceStrong
                                    border.width: active ? 1 : 0
                                    border.color: Colours.palette.m3primary

                                    StyledText {
                                        id: cdChipTxt
                                        anchors.centerIn: parent
                                        width: Math.min(implicitWidth, Math.max(20, parent.width - Tokens.padding.medium * 2))
                                        text: cdPickChip.modelData?.title ?? ""
                                        font: Tokens.font.label.small
                                        color: cdPickChip.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                                        elide: Text.ElideRight
                                    }

                                    StateLayer {
                                        onClicked: {
                                            customTitleField.text = "";
                                            customDateField.text = "";
                                            customDateField.isError = false;
                                            root.optionPatched({
                                                countdownId: String(cdPickChip.modelData?.id ?? ""),
                                                customTitle: "",
                                                customDate: ""
                                            });
                                        }
                                    }
                                }
                            }
                        }

                        StyledText {
                            text: qsTr("Or Custom Countdown")
                            font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        StyledTextField {
                            id: customTitleField

                            Layout.fillWidth: true
                            placeholderText: qsTr("Custom title (e.g. Term Test)")
                            onTextEdited: root.optionPatched({ customTitle: text })
                        }

                        StyledTextField {
                            id: customDateField

                            Layout.fillWidth: true
                            placeholderText: "YYYY-MM-DD"
                            maximumLength: 10
                            emptyIsValid: true
                            validate: val => FocusLedger.parseLocalDate(val) !== null
                            errorText: qsTr("Use YYYY-MM-DD")
                            onTextEdited: {
                                const trimmed = text.trim();
                                if (trimmed === "" || FocusLedger.parseLocalDate(trimmed) !== null) {
                                    isError = false;
                                    root.optionPatched({ customDate: trimmed });
                                }
                            }
                            onEditingFinished: {
                                const trimmed = text.trim();
                                if (trimmed === "" || FocusLedger.parseLocalDate(trimmed) !== null) {
                                    isError = false;
                                    root.optionPatched({ customDate: trimmed });
                                } else {
                                    isError = true;
                                }
                            }
                        }
                    }

                    // Widget-specific controls: Resources
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.canonicalType === "resources"
                        spacing: Tokens.spacing.small

                        RowLayout {
                            Layout.fillWidth: true

                            StyledText {
                                text: qsTr("Meter Style")
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurfaceVariant
                                Layout.fillWidth: true
                            }

                            Repeater {
                                model: [
                                    { key: "ring", label: qsTr("Ring") },
                                    { key: "shape", label: qsTr("Shape Fill") }
                                ]

                                delegate: StyledRect {
                                    id: resStyleChip

                                    required property var modelData
                                    readonly property bool active: (root.widgetOptions?.fillStyle ?? "shape") === modelData.key

                                    width: Math.round(resTxt.implicitWidth + Tokens.padding.medium * 2)
                                    height: 26
                                    radius: 13
                                    color: active ? Colours.palette.m3primaryContainer : WidgetMetrics.innerSurfaceStrong

                                    StyledText {
                                        id: resTxt

                                        anchors.centerIn: parent
                                        text: resStyleChip.modelData.label
                                        font: Tokens.font.label.small
                                        color: resStyleChip.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                                    }

                                    StateLayer {
                                        onClicked: root.optionPatched({ fillStyle: resStyleChip.modelData.key })
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: root.sizeMode === "1x1"
                            spacing: Tokens.spacing.small

                            StyledText {
                                text: qsTr("Metric")
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurfaceVariant
                                Layout.fillWidth: true
                            }

                            Repeater {
                                model: ["cpu", "ram", "gpu", "disk"]

                                delegate: StyledRect {
                                    id: metricChip

                                    required property string modelData
                                    readonly property bool active: (root.widgetOptions?.focusMetric ?? "cpu") === modelData

                                    width: Math.round(mTxt.implicitWidth + Tokens.padding.small * 2)
                                    height: 24
                                    radius: 12
                                    color: active ? Colours.palette.m3secondaryContainer : WidgetMetrics.innerSurfaceStrong

                                    StyledText {
                                        id: mTxt

                                        anchors.centerIn: parent
                                        text: metricChip.modelData.toUpperCase()
                                        font: Tokens.font.label.small
                                        color: metricChip.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                    }

                                    StateLayer {
                                        onClicked: root.optionPatched({ focusMetric: metricChip.modelData })
                                    }
                                }
                            }
                        }
                    }

                    // Widget-specific controls: UserCard
                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.canonicalType === "usercard"

                        StyledText {
                            text: qsTr("Show Lock / Power Actions")
                            font: Tokens.font.label.small
                            color: Colours.palette.m3onSurface
                            Layout.fillWidth: true
                        }

                        StyledSwitch {
                            checked: (root.widgetOptions?.showActions ?? true) !== false
                            onToggled: root.optionPatched({ showActions: checked })
                        }
                    }

                    // Widget-specific controls: Media
                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.canonicalType === "media"

                        StyledText {
                            text: qsTr("Live Audio Shapes")
                            font: Tokens.font.label.small
                            color: Colours.palette.m3onSurface
                            Layout.fillWidth: true
                        }

                        StyledSwitch {
                            checked: (root.widgetOptions?.showVisualizer ?? true) !== false
                            onToggled: root.optionPatched({ showVisualizer: checked })
                        }
                    }

                    // Footer: Nexus & Hide Widget
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
                            visible: WidgetMetrics.isMultiInstance(root.canonicalType)
                            Layout.preferredWidth: 36
                            height: 34
                            radius: 17
                            color: Colours.palette.m3secondaryContainer

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "content_copy"
                                fontStyle: Tokens.font.icon.small
                                color: Colours.palette.m3onSecondaryContainer
                            }

                            StateLayer {
                                onClicked: {
                                    root.duplicateRequested();
                                    root.closed();
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
                                    root.hideWidgetRequested();
                                    root.closed();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

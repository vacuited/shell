pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common
import qs.modules.background.components

PageBase {
    id: root

    readonly property var widgetsConfig: root.targetConfig.background.desktopWidgets

    readonly property var widgetNames: ({
        atAGlance: qsTr("At a glance"),
        calendar: qsTr("Calendar"),
        weather: qsTr("Weather"),
        weatherPill: qsTr("Weather pill"),
        timers: qsTr("Timers & focus"),
        pomodoro: qsTr("Timers & focus"),
        countdown: qsTr("Countdown"),
        resources: qsTr("System resources"),
        media: qsTr("Now playing"),
        todo: qsTr("Todo list"),
        notes: qsTr("Notes"),
        usercard: qsTr("User card"),
        battery: qsTr("Battery"),
        customImage: qsTr("Custom image"),
        sticker: qsTr("Sticker"),
        customText: qsTr("Custom text")
    })

    readonly property list<string> addableWidgets: [
        "atAGlance",
        "calendar",
        "weather",
        "weatherPill",
        "timers",
        "countdown",
        "resources",
        "media",
        "todo",
        "notes",
        "usercard",
        "battery",
        "customImage",
        "sticker",
        "customText"
    ]
    readonly property list<string> multiInstanceTypes: ["resources", "countdown", "customImage", "sticker", "customText"]

    readonly property list<string> positionValues: ["top-left", "top-right", "bottom-left", "bottom-right"]
    readonly property list<MenuItem> positionItems: [
        MenuItem { text: qsTr("Top Left") },
        MenuItem { text: qsTr("Top Right") },
        MenuItem { text: qsTr("Bottom Left") },
        MenuItem { text: qsTr("Bottom Right") }
    ]

    readonly property list<string> surfaceStyleValues: ["glass", "blur", "frosted", "material"]
    readonly property list<MenuItem> surfaceStyleItems: [
        MenuItem { text: qsTr("Glass") },
        MenuItem { text: qsTr("Blur") },
        MenuItem { text: qsTr("Frosted") },
        MenuItem { text: qsTr("Material") }
    ]

    function typeFor(item: var): string {
        if (!item)
            return "";
        const raw = (item.type && item.type !== "") ? item.type : item.id;
        return raw === "pomodoro" ? "timers" : raw;
    }

    function entryDisplayName(item: var): string {
        const t = typeFor(item);
        const base = widgetNames[t] ?? t;
        if (!item)
            return base;
        if (t === "customText") {
            const txt = String(item.options?.content ?? "").trim();
            if (txt.length > 0)
                return `${base} — ${txt.slice(0, 20)}`;
        } else if (t === "customImage" || t === "sticker") {
            const p = String(item.options?.path ?? "").trim();
            if (p.length > 0) {
                const parts = p.split("/");
                return `${base} — ${parts[parts.length - 1]}`;
            }
        }
        if (multiInstanceTypes.includes(t)) {
            const same = widgetsConfig.entries.values.filter(e => typeFor(e) === t);
            const idx = same.findIndex(e => e.id === item.id);
            if (t === "resources") {
                const sz = item.sizeMode || WidgetMetrics.defaultSizeFor("resources");
                const tag = sz === "1x1"
                    ? String(item.options?.focusMetric ?? "cpu").toUpperCase()
                    : sz;
                return same.length > 1 && idx >= 0
                    ? `${base} #${idx + 1} (${tag})`
                    : `${base} (${tag})`;
            }
            if (t === "countdown") {
                const customDate = String(item.options?.customDate ?? "").trim();
                const hasValidCustom = FocusLedger.parseLocalDate(customDate) !== null;
                const customTitle = String(item.options?.customTitle ?? "").trim();
                const cdId = String(item.options?.countdownId ?? "");
                let tag = hasValidCustom ? (customTitle !== "" ? customTitle : customDate) : "";
                if (tag === "" && cdId !== "") {
                    const found = (FocusLedger.countdowns || []).find(c => c && c.id === cdId);
                    if (found) tag = found.title;
                }
                const label = same.length > 1 && idx >= 0 ? `${base} #${idx + 1}` : base;
                return tag !== "" ? `${label} (${tag})` : label;
            }
            if (same.length > 1 && idx >= 0)
                return `${base} #${idx + 1}`;
        }
        return base;
    }

    function hasAnyEnabled(): bool {
        const list = widgetsConfig.entries.values;
        for (let i = 0; i < list.length; i++) {
            if (list[i].enabled)
                return true;
        }
        return false;
    }

    function hasEntryOverrides(entriesNode: var): bool {
        if (!entriesNode)
            return false;
        if (entriesNode.isOverride("values"))
            return true;
        const keys = ["id", "type", "enabled", "col", "row", "right", "x", "y", "style", "sizeMode", "options"];
        const list = entriesNode.values;
        for (let i = 0; i < list.length; i++) {
            const e = list[i];
            if (!e)
                continue;
            for (let k = 0; k < keys.length; k++) {
                if (e.isOverride(keys[k]))
                    return true;
            }
        }
        return false;
    }

    readonly property list<string> overriddenScreens: {
        if (root.nState.targetScreen !== "")
            return [];
        const screens = [];
        for (const s of Screens.screens) {
            const dw = GlobalConfig.forScreen(s.name).background.desktopWidgets;
            for (const e of dw.entries.values)
                void [e.id, e.type, e.enabled, e.col, e.row, e.right, e.x, e.y, e.style, e.sizeMode, e.options];
            if (hasEntryOverrides(dw.entries))
                screens.push(s.name);
        }
        return screens;
    }

    title: qsTr("Desktop widgets")
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
            text: qsTr("Enabled")
            subtext: qsTr("Show widget cards on the desktop")
            configNode: root.widgetsConfig
            propertyName: "enabled"
            checked: root.widgetsConfig.enabled
            onToggled: {
                root.widgetsConfig.enabled = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            text: qsTr("Edit layout on desktop")
            subtext: qsTr("Unlock widgets on the desktop to drag and resize them directly")
            checked: Visibilities.desktopWidgetsUnlocked
            onToggled: Visibilities.desktopWidgetsUnlocked = checked
        }

        ToggleRow {
            text: qsTr("Hide when windows are open")
            subtext: qsTr("Fade the widget cards out while the workspace has windows on it")
            configNode: root.widgetsConfig
            propertyName: "hideWithWindows"
            checked: root.widgetsConfig.hideWithWindows
            onToggled: {
                root.widgetsConfig.hideWithWindows = checked;
                root.targetConfig.save();
            }
        }

        SelectRow {
            label: qsTr("Surface style")
            configNode: root.widgetsConfig
            propertyName: "surfaceStyle"
            menuItems: root.surfaceStyleItems
            active: root.surfaceStyleItems[Math.max(0, root.surfaceStyleValues.indexOf(root.widgetsConfig.surfaceStyle))]
            onSelected: item => {
                const index = root.surfaceStyleItems.indexOf(item);
                if (index !== -1) {
                    root.widgetsConfig.surfaceStyle = root.surfaceStyleValues[index];
                    root.targetConfig.save();
                }
            }
        }

        ToggleRow {
            text: qsTr("Blur background")
            subtext: qsTr("Blur the wallpaper behind Glass cards (Blur and Frosted always blur)")
            configNode: root.widgetsConfig
            propertyName: "blur"
            checked: root.widgetsConfig.blur
            onToggled: {
                root.widgetsConfig.blur = checked;
                root.targetConfig.save();
            }
        }

        StepperRow {
            label: qsTr("Card opacity")
            subtext: qsTr("How opaque the card backgrounds are (%)")
            configNode: root.widgetsConfig
            propertyName: "opacity"
            value: Math.round(root.widgetsConfig.opacity * 100)
            from: 10
            to: 100
            stepSize: 5
            onMoved: v => {
                root.widgetsConfig.opacity = Math.round(v) / 100;
                root.targetConfig.save();
            }
        }

        SliderRow {
            label: qsTr("Widget scale")
            configNode: root.widgetsConfig
            propertyName: "scale"
            value: (root.widgetsConfig.scale - 0.7) / 0.8
            valueLabel: root.widgetsConfig.scale.toFixed(2) + "x"
            onMoved: v => {
                root.widgetsConfig.scale = Math.round((0.7 + v * 0.8) * 20) / 20;
                root.targetConfig.save();
            }
        }

        SelectRow {
            label: qsTr("Default corner position")
            configNode: root.widgetsConfig
            propertyName: "position"
            menuItems: root.positionItems
            active: root.positionItems[Math.max(0, root.positionValues.indexOf(root.widgetsConfig.position))]
            onSelected: item => {
                const index = root.positionItems.indexOf(item);
                if (index !== -1) {
                    root.widgetsConfig.position = root.positionValues[index];
                    root.targetConfig.save();
                }
            }
        }

        StepperRow {
            last: true
            label: qsTr("Columns")
            subtext: qsTr("Number of widget columns when unplaced")
            configNode: root.widgetsConfig
            propertyName: "columns"
            value: root.widgetsConfig.columns
            from: 1
            to: 6
            stepSize: 1
            onMoved: v => {
                root.widgetsConfig.columns = Math.round(v);
                root.targetConfig.save();
            }
        }

        TextButton {
            Layout.alignment: Qt.AlignRight
            Layout.topMargin: Tokens.spacing.extraSmall
            text: qsTr("Reset all positions")
            type: TextButton.Tonal
            onClicked: {
                const list = root.widgetsConfig.entries;
                for (let i = 0; i < root.widgetsConfig.entries.values.length; i++) {
                    const entry = list.at(i);
                    entry.x = -1;
                    entry.y = -1;
                    entry.col = -1;
                    entry.row = -1;
                    entry.right = false;
                }
                root.targetConfig.save();
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.largeIncreased - (Tokens.spacing.extraSmall / 2)
            Layout.bottomMargin: Tokens.spacing.extraSmall
            Layout.leftMargin: Tokens.padding.small
            spacing: Tokens.spacing.small

            StyledText {
                text: qsTr("Widget list")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
                elide: Text.ElideRight
            }

            IconButton {
                readonly property bool isOverridden: {
                    for (const e of root.widgetsConfig.entries.values)
                        void [e.id, e.type, e.enabled, e.col, e.row, e.right, e.x, e.y, e.style, e.sizeMode, e.options];
                    return root.nState.targetScreen !== "" && root.hasEntryOverrides(root.widgetsConfig.entries);
                }

                visible: isOverridden
                icon: "restart_alt"
                type: IconButton.Text
                font: Tokens.font.icon.small
                inactiveOnColour: Colours.palette.m3tertiary
                Layout.alignment: Qt.AlignVCenter
                onClicked: {
                    root.widgetsConfig.resetOption("entries");
                    root.targetConfig.save();
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }

        StyledRect {
            visible: root.overriddenScreens.length > 0
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.extraSmall
            implicitHeight: overrideRow.implicitHeight + Tokens.padding.medium * 2
            radius: Tokens.rounding.large
            color: Colours.palette.m3errorContainer

            RowLayout {
                id: overrideRow

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "sync_problem"
                    color: Colours.palette.m3onErrorContainer
                    fontStyle: Tokens.font.icon.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Monitor override active on %1 — widget list edits here are shadowed until synced.").arg(root.overriddenScreens.join(", "))
                    color: Colours.palette.m3onErrorContainer
                    font: Tokens.font.body.small
                    wrapMode: Text.WordWrap
                }

                TextButton {
                    text: qsTr("Use Global")
                    type: TextButton.Tonal
                    onClicked: {
                        for (const scr of root.overriddenScreens) {
                            const cfg = GlobalConfig.forScreen(scr);
                            cfg.background.desktopWidgets.resetOption("entries");
                            cfg.save();
                        }
                    }
                }
            }
        }

        ListEditor {
            function labelFor(item: var): string {
                return root.entryDisplayName(item);
            }

            function toggledFor(item: var): bool {
                return item.enabled;
            }

            z: 1
            first: true
            values: root.widgetsConfig.entries.values
            onItemMoved: (from, to) => {
                root.widgetsConfig.entries.move(from, to);
                root.targetConfig.save();
            }
            onItemRemoved: index => {
                root.widgetsConfig.entries.remove(index);
                root.targetConfig.save();
            }
            onItemToggled: (index, checked) => {
                root.widgetsConfig.entries.at(index).enabled = checked;
                root.targetConfig.save();
            }
        }

        DialogSelectButton {
            rootParent: root.flickable
            icon: "add"
            label: qsTr("Add widget")
            header: qsTr("Add a widget")
            acceptLabel: qsTr("Add")

            model: root.addableWidgets.filter(id => {
                if (root.multiInstanceTypes.includes(id))
                    return true;
                return !root.widgetsConfig.entries.values.some(e => root.typeFor(e) === id);
            }).map(id => ({
                id: id,
                label: root.widgetNames[id]
            }))

            onAccepted: {
                if (!selectedItem)
                    return;
                const multi = root.multiInstanceTypes.includes(selectedItem);
                let entryId = selectedItem;
                if (multi) {
                    let suffix = Date.now();
                    while (root.widgetsConfig.entries.values.some(e => e.id === `${selectedItem}-${suffix}`))
                        suffix++;
                    entryId = `${selectedItem}-${suffix}`;
                }
                root.widgetsConfig.entries.insert({
                    id: entryId,
                    type: selectedItem,
                    enabled: true,
                    sizeMode: WidgetMetrics.defaultSizeFor(selectedItem)
                });
                root.targetConfig.save();
            }
        }

        SectionHeader {
            visible: root.hasAnyEnabled()
            text: qsTr("Widget customization")
        }

        Repeater {
            model: root.widgetsConfig.entries.values

            delegate: WidgetOptionCard {}
        }
    }

    component WidgetOptionCard: ColumnLayout {
        id: card

        required property var modelData
        required property int index

        readonly property string wType: root.typeFor(modelData)
        readonly property var opts: modelData?.options || ({})
        readonly property var supportedSizes: WidgetMetrics.supportedSizesFor(wType)
        readonly property bool isMultiSize: supportedSizes.length > 0
        readonly property bool supportsOuterShape: WidgetMetrics.supportsOuterShape(wType)
            && ((modelData?.sizeMode || WidgetMetrics.defaultSizeFor(wType)) === "1x1" || WidgetMetrics.isAspectResizable(wType))
        readonly property bool hasExtraOptions: ["customText", "customImage", "sticker", "resources", "countdown", "media", "atAGlance", "usercard"].includes(wType)

        readonly property list<string> styleValues: ["", "glass", "blur", "frosted", "material"]
        readonly property list<MenuItem> styleItems: [
            MenuItem { text: qsTr("Default") },
            MenuItem { text: qsTr("Glass") },
            MenuItem { text: qsTr("Blur") },
            MenuItem { text: qsTr("Frosted") },
            MenuItem { text: qsTr("Material") }
        ]

        readonly property list<string> backdropValues: ["none", "pill", "card", "shape"]
        readonly property list<MenuItem> backdropItems: [
            MenuItem { text: qsTr("None") },
            MenuItem { text: qsTr("Pill") },
            MenuItem { text: qsTr("Card") },
            MenuItem { text: qsTr("Shape") }
        ]

        readonly property list<string> textColorValues: ["onSurface", "primary", "secondary", "tertiary", "white", "onSurfaceVariant"]
        readonly property list<MenuItem> textColorItems: [
            MenuItem { text: qsTr("On Surface") },
            MenuItem { text: qsTr("Primary") },
            MenuItem { text: qsTr("Secondary") },
            MenuItem { text: qsTr("Tertiary") },
            MenuItem { text: qsTr("White") },
            MenuItem { text: qsTr("Muted") }
        ]

        readonly property list<string> alignValues: ["left", "center", "right"]
        readonly property list<MenuItem> alignItems: [
            MenuItem { text: qsTr("Left") },
            MenuItem { text: qsTr("Center") },
            MenuItem { text: qsTr("Right") }
        ]

        readonly property list<string> fitModeValues: ["shape", "auto"]
        readonly property list<MenuItem> fitModeItems: [
            MenuItem { text: qsTr("Fill shape") },
            MenuItem { text: qsTr("Keep aspect") }
        ]

        readonly property list<string> fillStyleValues: ["shape", "ring"]
        readonly property list<MenuItem> fillStyleItems: [
            MenuItem { text: qsTr("Material shape") },
            MenuItem { text: qsTr("Wavy ring") }
        ]

        readonly property list<string> focusMetricValues: ["cpu", "ram", "gpu", "disk"]
        readonly property list<MenuItem> focusMetricItems: [
            MenuItem { text: qsTr("CPU") },
            MenuItem { text: qsTr("RAM") },
            MenuItem { text: qsTr("GPU") },
            MenuItem { text: qsTr("Storage") }
        ]

        function setOption(key: string, value: var): void {
            if (!modelData)
                return;
            const next = Object.assign({}, modelData.options || ({}));
            next[key] = value;
            modelData.options = next;
            root.targetConfig.save();
        }

        function setOptions(patch: var): void {
            if (!modelData || !patch)
                return;
            const next = Object.assign({}, modelData.options || ({}), patch);
            modelData.options = next;
            root.targetConfig.save();
        }

        function idxOr(values: list<string>, value: string, fallbackIdx: int): int {
            const idx = values.indexOf(value);
            return idx >= 0 ? idx : fallbackIdx;
        }

        visible: Boolean(modelData?.enabled)
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.small
        spacing: Tokens.spacing.extraSmall / 2

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.spacing.extraSmall
            text: root.entryDisplayName(card.modelData)
            color: Colours.palette.m3primary
            font: Tokens.font.label.large
            elide: Text.ElideRight
        }

        SelectRow {
            first: true
            last: !card.isMultiSize && !card.supportsOuterShape && !card.hasExtraOptions
            label: qsTr("Surface style")
            menuItems: card.styleItems
            active: card.styleItems[card.idxOr(card.styleValues, String(card.modelData?.style ?? ""), 0)]
            onSelected: item => {
                const idx = card.styleItems.indexOf(item);
                if (idx !== -1 && card.modelData) {
                    card.modelData.style = card.styleValues[idx];
                    root.targetConfig.save();
                }
            }
        }

        SelectRow {
            id: sizeSelect

            visible: card.isMultiSize
            last: !card.supportsOuterShape && !card.hasExtraOptions
            label: qsTr("Size")
            fallbackText: qsTr("Size")
            menuItems: [...sizeVariants.instances]
            active: {
                const target = String(card.modelData?.sizeMode || WidgetMetrics.defaultSizeFor(card.wType));
                const idx = card.supportedSizes.indexOf(target);
                return idx >= 0 && idx < sizeSelect.menuItems.length
                    ? sizeSelect.menuItems[idx]
                    : (sizeSelect.menuItems.length > 0 ? sizeSelect.menuItems[0] : null);
            }
            onSelected: item => {
                const idx = sizeSelect.menuItems.indexOf(item);
                if (idx >= 0 && idx < card.supportedSizes.length && card.modelData) {
                    card.modelData.sizeMode = card.supportedSizes[idx];
                    root.targetConfig.save();
                }
            }

            Variants {
                id: sizeVariants

                model: card.supportedSizes

                MenuItem {
                    required property string modelData

                    text: WidgetMetrics.formatSizeLabel(modelData)
                }
            }
        }

        SelectRow {
            id: shapeSelect

            visible: card.supportsOuterShape
            last: !card.hasExtraOptions
            label: qsTr("Outer shape")
            menuItems: [defaultShapeItem, ...shapeVariants.instances]
            active: {
                const opt = String(card.opts.outerShape ?? "");
                if (opt === "")
                    return defaultShapeItem;
                const idx = WidgetMetrics.shapeCatalog.findIndex(s => s.key === opt);
                return idx >= 0 && (idx + 1) < shapeSelect.menuItems.length
                    ? shapeSelect.menuItems[idx + 1]
                    : defaultShapeItem;
            }
            onSelected: item => {
                const idx = shapeSelect.menuItems.indexOf(item);
                if (idx === 0) {
                    card.setOption("outerShape", "");
                } else if (idx > 0 && (idx - 1) < WidgetMetrics.shapeCatalog.length) {
                    const chosen = WidgetMetrics.shapeCatalog[idx - 1];
                    if (card.wType === "customText" && chosen.shape >= 0) {
                        card.setOptions({
                            outerShape: chosen.key,
                            backdropMode: "shape"
                        });
                    } else {
                        card.setOption("outerShape", chosen.key);
                    }
                }
            }

            MenuItem {
                id: defaultShapeItem

                text: qsTr("Default (%1)").arg(WidgetMetrics.defaultShapeFor(card.wType))
            }

            Variants {
                id: shapeVariants

                model: WidgetMetrics.shapeCatalog

                MenuItem {
                    required property var modelData

                    text: modelData.label
                }
            }
        }

        // Custom text options
        SelectRow {
            visible: card.wType === "customText"
            label: qsTr("Backdrop")
            menuItems: card.backdropItems
            active: card.backdropItems[card.idxOr(card.backdropValues, String(card.opts.backdropMode ?? "none"), 0)]
            onSelected: item => {
                const idx = card.backdropItems.indexOf(item);
                if (idx !== -1)
                    card.setOption("backdropMode", card.backdropValues[idx]);
            }
        }

        TextFieldRow {
            visible: card.wType === "customText"
            label: qsTr("Text")
            value: String(card.opts.content ?? "")
            placeholderText: qsTr("Your text")
            onEditingFinished: val => card.setOption("content", val)
        }

        StepperRow {
            visible: card.wType === "customText"
            label: qsTr("Font size")
            value: Math.round(Number(card.opts.fontSize ?? 28))
            from: 12
            to: 140
            stepSize: 2
            onMoved: v => card.setOption("fontSize", Math.round(v))
        }

        SelectRow {
            visible: card.wType === "customText"
            label: qsTr("Text color")
            menuItems: card.textColorItems
            active: card.textColorItems[card.idxOr(card.textColorValues, String(card.opts.colorRole ?? "onSurface"), 0)]
            onSelected: item => {
                const idx = card.textColorItems.indexOf(item);
                if (idx !== -1)
                    card.setOption("colorRole", card.textColorValues[idx]);
            }
        }

        SelectRow {
            visible: card.wType === "customText"
            last: true
            label: qsTr("Alignment")
            menuItems: card.alignItems
            active: card.alignItems[card.idxOr(card.alignValues, String(card.opts.align ?? "center"), 1)]
            onSelected: item => {
                const idx = card.alignItems.indexOf(item);
                if (idx !== -1)
                    card.setOption("align", card.alignValues[idx]);
            }
        }

        // Custom image options
        SelectRow {
            visible: card.wType === "customImage"
            label: qsTr("Image fit")
            menuItems: card.fitModeItems
            active: card.fitModeItems[card.idxOr(card.fitModeValues, String(card.opts.fitMode ?? "shape"), 0)]
            onSelected: item => {
                const idx = card.fitModeItems.indexOf(item);
                if (idx !== -1)
                    card.setOption("fitMode", card.fitModeValues[idx]);
            }
        }

        StepperRow {
            visible: card.wType === "customImage"
            label: qsTr("Size (px)")
            value: Math.round(Number(card.opts.size ?? 200))
            from: 80
            to: 600
            stepSize: 10
            onMoved: v => card.setOption("size", Math.round(v))
        }

        TextFieldRow {
            visible: card.wType === "customImage"
            last: true
            label: qsTr("Image path")
            value: String(card.opts.path ?? "")
            placeholderText: qsTr("Click widget or drop image")
            onEditingFinished: val => card.setOption("path", val)
        }

        // Sticker options
        StepperRow {
            visible: card.wType === "sticker"
            label: qsTr("Size (px)")
            value: Math.round(Number(card.opts.size ?? 196))
            from: 80
            to: 600
            stepSize: 10
            onMoved: v => card.setOption("size", Math.round(v))
        }

        TextFieldRow {
            visible: card.wType === "sticker"
            last: true
            label: qsTr("Sticker path")
            value: String(card.opts.path ?? "")
            placeholderText: qsTr("Click widget or drop PNG")
            onEditingFinished: val => card.setOption("path", val)
        }

        // Countdown options
        TextFieldRow {
            visible: card.wType === "countdown"
            label: qsTr("Custom title")
            value: String(card.opts.customTitle ?? "")
            placeholderText: qsTr("Leave blank to use shared exam")
            onEditingFinished: val => card.setOption("customTitle", val.trim())
        }

        TextFieldRow {
            visible: card.wType === "countdown"
            last: true
            label: qsTr("Custom date (YYYY-MM-DD)")
            value: String(card.opts.customDate ?? "")
            placeholderText: "YYYY-MM-DD"
            maximumLength: 10
            validate: val => FocusLedger.parseLocalDate(val) !== null
            errorText: qsTr("Use YYYY-MM-DD")
            onEditingFinished: val => {
                const t = val.trim();
                if (t === "" || FocusLedger.parseLocalDate(t) !== null)
                    card.setOption("customDate", t);
            }
        }

        // Resources options
        SelectRow {
            visible: card.wType === "resources"
            label: qsTr("Gauge style")
            menuItems: card.fillStyleItems
            active: card.fillStyleItems[card.idxOr(card.fillStyleValues, String(card.opts.fillStyle ?? "shape"), 0)]
            onSelected: item => {
                const idx = card.fillStyleItems.indexOf(item);
                if (idx !== -1)
                    card.setOption("fillStyle", card.fillStyleValues[idx]);
            }
        }

        SelectRow {
            visible: card.wType === "resources"
            last: true
            label: qsTr("1×1 Focus metric")
            menuItems: card.focusMetricItems
            active: card.focusMetricItems[card.idxOr(card.focusMetricValues, String(card.opts.focusMetric ?? "cpu"), 0)]
            onSelected: item => {
                const idx = card.focusMetricItems.indexOf(item);
                if (idx !== -1)
                    card.setOption("focusMetric", card.focusMetricValues[idx]);
            }
        }

        // Media options
        ToggleRow {
            visible: card.wType === "media"
            text: qsTr("Show audio visualizer")
            checked: (card.opts.showVisualizer ?? true) !== false
            onToggled: card.setOption("showVisualizer", checked)
        }

        ToggleRow {
            visible: card.wType === "media"
            last: true
            text: qsTr("Album art backdrop")
            checked: (card.opts.albumBackdrop ?? true) !== false
            onToggled: card.setOption("albumBackdrop", checked)
        }

        // User card options
        ToggleRow {
            visible: card.wType === "usercard"
            last: true
            text: qsTr("Show power actions")
            checked: (card.opts.showActions ?? true) !== false
            onToggled: card.setOption("showActions", checked)
        }

        // At a glance options
        ToggleRow {
            visible: card.wType === "atAGlance"
            text: qsTr("Show weather")
            checked: (card.opts.showWeather ?? true) !== false
            onToggled: card.setOption("showWeather", checked)
        }

        ToggleRow {
            visible: card.wType === "atAGlance"
            last: true
            text: qsTr("Show Bluetooth battery")
            checked: (card.opts.showBluetooth ?? true) !== false
            onToggled: card.setOption("showBluetooth", checked)
        }
    }
}

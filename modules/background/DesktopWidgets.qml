pragma ComponentBehavior: Bound

import "../../utils/widgetgrid.js" as WidgetGrid
import "components"
import "widgets"
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.Services
import qs.services
import qs.modules.nexus

Item {
    id: root

    required property Item wallpaper

    readonly property bool isWidgetCanvas: true
    property bool dragging: false
    property bool resizing: false
    property bool centerXActive: false
    property bool centerYActive: false

    readonly property var widgetConfig: Config.background.desktopWidgets
    readonly property bool weActive: wallpaper?.weSurfaceActive ?? wallpaper?.weSurfaceVisible ?? false
    readonly property var hostCanvas: {
        let p = root.parent;
        while (p) {
            if (p.isWidgetCanvas === true)
                return p;
            p = p.parent;
        }
        return null;
    }

    readonly property real safeLeft: hostCanvas?.safeLeft ?? 0
    readonly property real safeTop: hostCanvas?.safeTop ?? 0
    readonly property real safeRight: hostCanvas?.safeRight ?? width
    readonly property real safeBottom: hostCanvas?.safeBottom ?? height
    readonly property real safeWidth: Math.max(64, safeRight - safeLeft)
    readonly property real safeHeight: Math.max(64, safeBottom - safeTop)
    readonly property real workCenterX: hostCanvas?.workCenterX ?? Math.round((safeLeft + safeRight) / 2)
    readonly property real workCenterY: hostCanvas?.workCenterY ?? Math.round((safeTop + safeBottom) / 2)

    property string editingWidgetId: ""
    property var editingCard: null

    readonly property var placements: {
        const entries = widgetConfig.entries.values;
        const s = WidgetMetrics.scale;
        for (const e of entries)
            void [e.enabled, e.sizeMode, e.col, e.row, e.right, e.x, e.y];
        return WidgetGrid.place(
            entries,
            safeWidth,
            safeHeight,
            widgetConfig.columns,
            widgetConfig.position,
            WidgetMetrics.gridStep,
            Math.round(WidgetMetrics.baseCell * s),
            WidgetMetrics.gap,
            safeLeft,
            safeTop
        );
    }

    function setDragging(active: bool): void {
        dragging = active;
        if (hostCanvas?.setDragging)
            hostCanvas.setDragging(active);
    }

    function setResizing(active: bool): void {
        resizing = active;
        if (hostCanvas?.setResizing)
            hostCanvas.setResizing(active);
    }

    function setCenterActive(xA: bool, yA: bool): void {
        centerXActive = xA;
        centerYActive = yA;
        if (hostCanvas?.setCenterActive)
            hostCanvas.setCenterActive(xA, yA);
    }

    function setGuideLines(lines: var): void {
        if (hostCanvas?.setGuideLines)
            hostCanvas.setGuideLines(lines);
    }

    function registerItem(item: Item): void {
        if (hostCanvas?.registerItem)
            hostCanvas.registerItem(item);
    }

    function unregisterItem(item: Item): void {
        if (hostCanvas?.unregisterItem)
            hostCanvas.unregisterItem(item);
    }

    function siblingRects(excludeItem: Item): var {
        return hostCanvas?.siblingRects ? hostCanvas.siblingRects(excludeItem) : [];
    }

    function targetScreenName(): string {
        return Config.screenName || "";
    }

    function useScreenOverrideLayer(): bool {
        const scr = targetScreenName();
        return scr !== "" && Config.forScreen(scr).background.desktopWidgets.entries.isOverride("values");
    }

    function writableEntryFor(id: string): var {
        const scr = targetScreenName();
        const entries = useScreenOverrideLayer()
            ? Config.forScreen(scr).background.desktopWidgets.entries.values
            : GlobalConfig.background.desktopWidgets.entries.values;
        for (let i = 0; i < entries.length; i++) {
            if (entries[i].id === id)
                return entries[i];
        }
        return null;
    }

    function saveConfig(): void {
        if (useScreenOverrideLayer())
            Config.forScreen(targetScreenName()).save();
        else
            GlobalConfig.save();
    }

    function resolveWidgetType(entry: var): string {
        if (!entry)
            return "";
        const raw = (entry.type && entry.type !== "") ? entry.type : entry.id;
        return WidgetMetrics.normalizeType(raw);
    }

    function entryFor(id: string): var {
        const entries = widgetConfig.entries.values;
        for (let i = 0; i < entries.length; i++) {
            if (entries[i].id === id)
                return entries[i];
        }
        return null;
    }

    function slotFor(id: string): var {
        return placements[id] ?? {
            col: 0,
            row: 0,
            w: 1,
            h: 1,
            x: Math.round(safeLeft),
            y: Math.round(safeTop)
        };
    }

    function openQuickPopover(cardItem: var): void {
        if (!cardItem)
            return;
        if (editingWidgetId === cardItem.widgetId && editingCard === cardItem) {
            closeQuickPopover();
            return;
        }
        editingCard = cardItem;
        editingWidgetId = cardItem.widgetId;
    }

    function closeQuickPopover(): void {
        editingWidgetId = "";
        editingCard = null;
    }

    function syncShown(): void {
        const entries = widgetConfig.entries.values;
        const want = [];
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            if (e.enabled) {
                want.push({
                    id: e.id,
                    type: resolveWidgetType(e)
                });
            }
        }
        for (let i = shownModel.count - 1; i >= 0; i--) {
            const row = shownModel.get(i);
            const match = want.find(w => w.id === row.widgetId && w.type === row.widgetType);
            if (!match) {
                if (editingWidgetId === row.widgetId)
                    closeQuickPopover();
                shownModel.remove(i);
            }
        }
        for (let i = 0; i < want.length; i++) {
            const w = want[i];
            let found = -1;
            for (let j = i; j < shownModel.count; j++) {
                const row = shownModel.get(j);
                if (row.widgetId === w.id && row.widgetType === w.type) {
                    found = j;
                    break;
                }
            }
            if (found >= 0) {
                if (found !== i)
                    shownModel.move(found, i, 1);
            } else {
                shownModel.insert(i, {
                    widgetId: w.id,
                    widgetType: w.type
                });
            }
        }
    }

    implicitWidth: Math.max(0, hostCanvas?.width ?? parent?.width ?? 1920)
    implicitHeight: Math.max(0, hostCanvas?.height ?? parent?.height ?? 1080)
    onPlacementsChanged: syncShown()
    Component.onCompleted: syncShown()
    Component.onDestruction: {
        if (dragging && hostCanvas?.setDragging)
            hostCanvas.setDragging(false);
        if (resizing && hostCanvas?.setResizing)
            hostCanvas.setResizing(false);
    }

    Connections {
        target: Visibilities
        function onDesktopWidgetsUnlockedChanged(): void {
            if (!Visibilities.desktopWidgetsUnlocked)
                root.closeQuickPopover();
        }
    }

    ListModel {
        id: shownModel
    }

    Repeater {
        model: shownModel

        delegate: DelegateChooser {
            role: "widgetType"

            DelegateChoice {
                roleValue: "atAGlance"
                delegate: AtAGlanceCard {}
            }
            DelegateChoice {
                roleValue: "calendar"
                delegate: CalendarCard {}
            }
            DelegateChoice {
                roleValue: "weather"
                delegate: WeatherWidgetCard {}
            }
            DelegateChoice {
                roleValue: "weatherPill"
                delegate: WeatherPillCard {}
            }
            DelegateChoice {
                roleValue: "timers"
                delegate: TimersCard {}
            }
            DelegateChoice {
                roleValue: "resources"
                delegate: ResourcesCard {}
            }
            DelegateChoice {
                roleValue: "media"
                delegate: MediaCard {}
            }
            DelegateChoice {
                roleValue: "todo"
                delegate: TodoCard {}
            }
            DelegateChoice {
                roleValue: "notes"
                delegate: NotesCard {}
            }
            DelegateChoice {
                roleValue: "usercard"
                delegate: UserProfileCard {}
            }
            DelegateChoice {
                roleValue: "battery"
                delegate: BatteryCard {}
            }
            DelegateChoice {
                roleValue: "customImage"
                delegate: CustomImageCard {}
            }
            DelegateChoice {
                roleValue: "sticker"
                delegate: StickerCard {}
            }
            DelegateChoice {
                roleValue: "customText"
                delegate: CustomTextCard {}
            }
        }
    }

    WidgetQuickPopover {
        id: quickPopover

        open: root.editingCard !== null && Visibilities.desktopWidgetsUnlocked
        widgetId: root.editingCard?.widgetId ?? ""
        widgetType: root.editingCard?.widgetType ?? ""
        sizeMode: root.editingCard?.resolvedSizeMode ?? "1x1"
        supportedSizes: root.editingCard?.supportedSizes ?? []
        surfaceStyle: root.editingCard?.entry?.style ?? ""
        glassBlurEnabled: root.widgetConfig.blur
        widgetOptions: root.editingCard?.entryOptions ?? ({})
        anchorX: root.editingCard?.x ?? 0
        anchorY: root.editingCard?.y ?? 0
        anchorWidth: root.editingCard?.width ?? 164
        anchorHeight: root.editingCard?.height ?? 164
        safeLeft: root.safeLeft
        safeTop: root.safeTop
        safeRight: root.safeRight
        safeBottom: root.safeBottom

        onClosed: root.closeQuickPopover()
        onSizeModeSelected: mode => root.editingCard?.commitSizeMode(mode)
        onSurfaceStyleSelected: style => root.editingCard?.commitSurfaceStyle(style)
        onToggleGlassBlur: {
            const scr = root.targetScreenName();
            const scrCfg = scr !== "" ? Config.forScreen(scr) : null;
            const hasScrOverride = scrCfg && scrCfg.background.desktopWidgets.isOverride("blur");
            const target = hasScrOverride ? scrCfg : GlobalConfig;
            target.background.desktopWidgets.blur = !root.widgetConfig.blur;
            target.save();
        }
        onOptionPatched: patch => root.editingCard?.mergeOptions(patch, true)
        onActionTriggered: actionName => {
            const target = root.editingCard?.widgetContent;
            if (!target)
                return;
            if (actionName === "pickFile" && target.openPicker)
                target.openPicker();
            else if (actionName === "jumpToday" && target.jumpToToday)
                target.jumpToToday();
            else if (actionName === "refreshWeather" && target.refresh)
                target.refresh();
        }
        onDuplicateRequested: {
            const card = root.editingCard;
            if (!card)
                return;
            const scr = root.targetScreenName();
            const entries = root.useScreenOverrideLayer()
                ? Config.forScreen(scr).background.desktopWidgets.entries
                : GlobalConfig.background.desktopWidgets.entries;
            const wType = WidgetMetrics.normalizeType(card.widgetType);
            if (!WidgetMetrics.isMultiInstance(wType))
                return;
            let suffix = Date.now();
            while (entries.values.some(e => e.id === `${wType}-${suffix}`))
                suffix++;
            const step = Math.round(24 * WidgetMetrics.scale);
            const nextX = Math.round(Math.max(root.safeLeft, Math.min(Math.max(root.safeLeft, root.safeRight - card.width), card.x + step)));
            const nextY = Math.round(Math.max(root.safeTop, Math.min(Math.max(root.safeTop, root.safeBottom - card.height), card.y + step)));
            entries.insert({
                id: `${wType}-${suffix}`,
                type: wType,
                enabled: true,
                sizeMode: card.resolvedSizeMode,
                style: card.entry?.style ?? "",
                options: Object.assign({}, card.entryOptions || ({})),
                x: nextX,
                y: nextY
            });
            root.saveConfig();
        }
        onHideWidgetRequested: {
            const id = root.editingCard?.widgetId ?? "";
            const target = root.writableEntryFor(id);
            if (target) {
                target.enabled = false;
                root.saveConfig();
            }
        }
        onOpenNexusRequested: WindowFactory.create()
    }

    component WidgetCard: WidgetWrapper {
        id: card

        required property string widgetId
        required property string widgetType
        required property int index

        property Item widgetContent: null

        readonly property var entry: root.entryFor(widgetId)
        readonly property var slot: root.slotFor(widgetId)
        readonly property bool hasCustomPos: entry !== null && entry.x >= 0 && entry.y >= 0
        readonly property string resolvedSurfaceStyle: (entry && entry.style && entry.style !== "")
            ? entry.style
            : (root.widgetConfig.surfaceStyle || "glass")
        readonly property string resolvedSizeMode: {
            const allowed = WidgetMetrics.supportedSizesFor(widgetType);
            const raw = (entry && entry.sizeMode && entry.sizeMode !== "") ? entry.sizeMode : WidgetMetrics.defaultSizeFor(widgetType);
            if (allowed && allowed.length > 0 && allowed.indexOf(raw) < 0)
                return WidgetMetrics.defaultSizeFor(widgetType);
            return raw;
        }
        readonly property var entryOptions: (entry && entry.options) ? entry.options : ({})

        function mergeOptions(patch: var, save: bool): void {
            const target = root.writableEntryFor(widgetId);
            if (!target || !patch)
                return;
            target.options = Object.assign({}, target.options || ({}), patch);
            if (save)
                root.saveConfig();
        }

        function commitSizeMode(nextMode: string): void {
            const target = root.writableEntryFor(widgetId);
            if (!target || !nextMode)
                return;
            if (target.sizeMode !== nextMode) {
                target.sizeMode = nextMode;
                root.saveConfig();
            }
        }

        function commitSurfaceStyle(style: string): void {
            const target = root.writableEntryFor(widgetId);
            if (!target)
                return;
            if ((target.style ?? "") !== style) {
                target.style = style;
                root.saveConfig();
            }
        }

        canvas: root
        widgetScale: WidgetMetrics.scale
        initialX: hasCustomPos ? entry.x : slot.x
        initialY: hasCustomPos ? entry.y : slot.y
        sizeMode: card.resolvedSizeMode
        supportedSizes: WidgetMetrics.supportedSizesFor(card.widgetType)
        resizeMode: WidgetMetrics.isAspectResizable(card.widgetType) ? "diagonal" : "discrete"
        resizable: WidgetMetrics.isAspectResizable(card.widgetType) || (supportedSizes?.length ?? 0) > 1
        showSettingsHandle: true
        settingsActive: root.editingWidgetId === card.widgetId
        outlineShape: WidgetMetrics.resolveShapeEnum(WidgetMetrics.effectiveShapeKey(card.widgetType, card.resolvedSizeMode, card.entryOptions?.outerShape ?? ""), "Rounded")
        minWidth: WidgetMetrics.isAspectResizable(card.widgetType) ? Math.round(96 * WidgetMetrics.scale) : WidgetMetrics.widthFor("1x1", WidgetMetrics.scale)
        minHeight: WidgetMetrics.isAspectResizable(card.widgetType) ? Math.round(48 * WidgetMetrics.scale) : WidgetMetrics.heightFor("1x1", card.widgetType, WidgetMetrics.scale)
        implicitWidth: widgetContent ? widgetContent.implicitWidth : WidgetMetrics.widthFor(card.resolvedSizeMode, WidgetMetrics.scale)
        implicitHeight: widgetContent ? widgetContent.implicitHeight : WidgetMetrics.heightFor(card.resolvedSizeMode, card.widgetType, WidgetMetrics.scale)
        width: implicitWidth
        height: implicitHeight

        onPositionCommitted: (newX, newY) => {
            const target = root.writableEntryFor(card.widgetId);
            if (!target)
                return;
            target.x = newX;
            target.y = newY;
            root.saveConfig();
        }

        onSizeModeCommitted: newMode => card.commitSizeMode(newMode)
        onSettingsRequested: root.openQuickPopover(card)
    }

    component AtAGlanceCard: WidgetCard {
        id: glanceCard

        widgetContent: glanceW
        AtAGlanceWidget {
            id: glanceW
            anchors.fill: parent
            wallpaper: root.wallpaper
            weActive: root.weActive
            locked: glanceCard.locked
            sizeMode: glanceCard.resolvedSizeMode
            surfaceStyle: glanceCard.resolvedSurfaceStyle
            widgetOptions: glanceCard.entryOptions
        }
    }

    component CalendarCard: WidgetCard {
        id: calCard

        widgetContent: calW
        CalendarWidget {
            id: calW
            anchors.fill: parent
            wallpaper: root.wallpaper
            weActive: root.weActive
            locked: calCard.locked
            sizeMode: calCard.resolvedSizeMode
            surfaceStyle: calCard.resolvedSurfaceStyle
            widgetOptions: calCard.entryOptions
        }
    }

    component WeatherWidgetCard: WidgetCard {
        id: weatherCard

        widgetContent: weatherW
        WeatherCard {
            id: weatherW
            anchors.fill: parent
            wallpaper: root.wallpaper
            weActive: root.weActive
            locked: weatherCard.locked
            sizeMode: weatherCard.resolvedSizeMode
            surfaceStyle: weatherCard.resolvedSurfaceStyle
            widgetOptions: weatherCard.entryOptions
        }
    }

    component WeatherPillCard: WidgetCard {
        id: pillCard

        widgetContent: pillW
        WeatherPill {
            id: pillW
            anchors.fill: parent
            wallpaper: root.wallpaper
            weActive: root.weActive
            locked: pillCard.locked
            sizeMode: pillCard.resolvedSizeMode
            surfaceStyle: pillCard.resolvedSurfaceStyle
            widgetOptions: pillCard.entryOptions
        }
    }

    component TimersCard: WidgetCard {
        id: timersCard

        widgetContent: timersW
        TimersWidget {
            id: timersW
            anchors.fill: parent
            wallpaper: root.wallpaper
            weActive: root.weActive
            locked: timersCard.locked
            sizeMode: timersCard.resolvedSizeMode
            surfaceStyle: timersCard.resolvedSurfaceStyle
            widgetOptions: timersCard.entryOptions
        }
    }

    component ResourcesCard: WidgetCard {
        id: resCard

        widgetContent: resW
        ResourcesWidget {
            id: resW
            anchors.fill: parent
            wallpaper: root.wallpaper
            weActive: root.weActive
            locked: resCard.locked
            sizeMode: resCard.resolvedSizeMode
            surfaceStyle: resCard.resolvedSurfaceStyle
            widgetOptions: resCard.entryOptions
        }
    }

    component MediaCard: WidgetCard {
        id: mediaCard

        widgetContent: mediaW
        MediaWidget {
            id: mediaW
            anchors.fill: parent
            wallpaper: root.wallpaper
            weActive: root.weActive
            locked: mediaCard.locked
            sizeMode: mediaCard.resolvedSizeMode
            surfaceStyle: mediaCard.resolvedSurfaceStyle
            widgetOptions: mediaCard.entryOptions
        }
    }

    component TodoCard: WidgetCard {
        id: todoCard

        widgetContent: todoW
        TodoWidget {
            id: todoW
            anchors.fill: parent
            wallpaper: root.wallpaper
            weActive: root.weActive
            locked: todoCard.locked
            sizeMode: todoCard.resolvedSizeMode
            surfaceStyle: todoCard.resolvedSurfaceStyle
            widgetOptions: todoCard.entryOptions
        }
    }

    component NotesCard: WidgetCard {
        id: notesCard

        widgetContent: notesW
        NotesWidget {
            id: notesW
            anchors.fill: parent
            wallpaper: root.wallpaper
            weActive: root.weActive
            locked: notesCard.locked
            sizeMode: notesCard.resolvedSizeMode
            surfaceStyle: notesCard.resolvedSurfaceStyle
            widgetOptions: notesCard.entryOptions
            onOptionsUpdated: patch => notesCard.mergeOptions(patch, true)
        }
    }

    component UserProfileCard: WidgetCard {
        id: userCard

        widgetContent: userW
        UserCardWidget {
            id: userW
            anchors.fill: parent
            wallpaper: root.wallpaper
            weActive: root.weActive
            locked: userCard.locked
            sizeMode: userCard.resolvedSizeMode
            surfaceStyle: userCard.resolvedSurfaceStyle
            widgetOptions: userCard.entryOptions
        }
    }

    component BatteryCard: WidgetCard {
        id: batCard

        visible: UPower.displayDevice.isLaptopBattery || (Hardware.isSupported && Hardware.gpuPower > 0) || !batCard.locked
        widgetContent: batW
        BatteryWidget {
            id: batW
            anchors.fill: parent
            wallpaper: root.wallpaper
            weActive: root.weActive
            locked: batCard.locked
            sizeMode: batCard.resolvedSizeMode
            surfaceStyle: batCard.resolvedSurfaceStyle
            widgetOptions: batCard.entryOptions
        }
    }

    component CustomImageCard: WidgetCard {
        id: imageCard

        widgetContent: imageW
        resizeMode: "diagonal"
        onUnlockedTapped: imageW.openPicker()
        onResizeFinished: finalWidth => imageCard.mergeOptions({
            size: Math.max(96, Math.round(finalWidth / WidgetMetrics.scale))
        }, true)

        CustomImageWidget {
            id: imageW
            anchors.fill: parent
            wallpaper: root.wallpaper
            weActive: root.weActive
            locked: imageCard.locked
            sizeMode: imageCard.resolvedSizeMode
            surfaceStyle: imageCard.resolvedSurfaceStyle
            widgetOptions: imageCard.entryOptions
            onOptionsUpdated: patch => imageCard.mergeOptions(patch, true)
        }
    }

    component StickerCard: WidgetCard {
        id: stickerCard

        widgetContent: stickerW
        resizeMode: "diagonal"
        onUnlockedTapped: stickerW.openPicker()
        onResizeFinished: finalWidth => stickerCard.mergeOptions({
            size: Math.max(88, Math.round(finalWidth / WidgetMetrics.scale))
        }, true)

        StickerWidget {
            id: stickerW
            anchors.fill: parent
            wallpaper: root.wallpaper
            weActive: root.weActive
            locked: stickerCard.locked
            sizeMode: stickerCard.resolvedSizeMode
            surfaceStyle: stickerCard.resolvedSurfaceStyle
            widgetOptions: stickerCard.entryOptions
            onOptionsUpdated: patch => stickerCard.mergeOptions(patch, true)
        }
    }

    component CustomTextCard: WidgetCard {
        id: textCard

        widgetContent: textW
        resizeMode: "horizontal"
        onResizeFinished: finalWidth => textCard.mergeOptions({
            maxWidth: Math.max(140, Math.round(finalWidth / WidgetMetrics.scale))
        }, true)

        CustomTextWidget {
            id: textW
            anchors.fill: parent
            wallpaper: root.wallpaper
            weActive: root.weActive
            locked: textCard.locked
            sizeMode: textCard.resolvedSizeMode
            surfaceStyle: textCard.resolvedSurfaceStyle
            widgetOptions: textCard.entryOptions
            onOptionsUpdated: patch => textCard.mergeOptions(patch, true)
        }
    }
}

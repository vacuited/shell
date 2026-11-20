pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Wallpaper Engine")
    isSubPage: true

    property int currentMode: 0 // 0 = Installed, 1 = Steam Workshop
    property string installedSearchText: ""
    property int installedCategory: 0 // 0 = All, 1 = Scenes, 2 = Videos
    property bool installedSortAsc: true
    property string confirmUnsubId: ""
    property string confirmWsUnsubId: ""

    property string workshopTypedQuery: ""
    property string workshopQuery: ""
    property int workshopSortType: 3 // 3 = Trending, 0 = Top Rated, 1 = Newest, 9 = Most Subscribed, 21 = Recently Updated
    property int workshopPage: 1

    readonly property list<MenuItem> fpsItems: [
        MenuItem {
            text: qsTr("Match Display")
            value: 0
        },
        MenuItem {
            text: qsTr("30 FPS")
            value: 30
        },
        MenuItem {
            text: qsTr("60 FPS")
            value: 60
        },
        MenuItem {
            text: qsTr("120 FPS")
            value: 120
        },
        MenuItem {
            text: qsTr("144 FPS")
            value: 144
        }
    ]

    readonly property list<MenuItem> sceneQualityItems: [
        MenuItem {
            text: qsTr("Auto")
            value: "auto"
        },
        MenuItem {
            text: qsTr("Performance (50%)")
            value: "performance"
        },
        MenuItem {
            text: qsTr("Balanced (67%)")
            value: "balanced"
        },
        MenuItem {
            text: qsTr("High (85%)")
            value: "high"
        },
        MenuItem {
            text: qsTr("Native (100%)")
            value: "native"
        }
    ]

    readonly property list<MenuItem> gpuModeItems: [
        MenuItem {
            text: qsTr("Auto (Compositor GPU)")
            value: "auto"
        },
        MenuItem {
            text: qsTr("dGPU on AC, iGPU on Battery")
            value: "ac_dgpu"
        },
        MenuItem {
            text: qsTr("Dedicated GPU (Scenes)")
            value: "dgpu"
        },
        MenuItem {
            text: qsTr("Integrated GPU")
            value: "igpu"
        }
    ]

    readonly property var rawInstalledItems: {
        if (Skwd.weInstalledItems && Skwd.weInstalledItems.length > 0) {
            return Skwd.weInstalledItems;
        }
        const walls = Wallpapers.list.filter(w => Wallpapers.getCategoryFor(w) === "Wallpaper Engine");
        return walls.map(w => {
            let title = "";
            try {
                let json = JSON.parse(CUtils.readFile(w.path));
                if (json.title)
                    title = json.title;
            } catch (e) {}
            if (!title)
                title = w.parentDir.split("/").pop();
            return {
                "id": w.parentDir.split("/").pop(),
                "title": title,
                "type": "scene",
                "path": w.parentDir,
                "thumb": Wallpapers.getThumbnailPath(w.path),
                "preview": Wallpapers.getThumbnailPath(w.path)
            };
        });
    }

    readonly property var filteredInstalledItems: {
        const list = root.rawInstalledItems;
        if (!list || list.length === 0)
            return [];
        const q = root.installedSearchText.trim().toLowerCase();
        const cat = root.installedCategory;
        let res = [];
        for (let i = 0; i < list.length; i++) {
            const item = list[i];
            if (!item)
                continue;
            const itemType = (item.type || "scene").toLowerCase();
            if (cat === 1 && itemType !== "scene")
                continue;
            if (cat === 2 && itemType !== "video")
                continue;
            if (q !== "") {
                const titleMatch = (item.title || "").toLowerCase().includes(q);
                const idMatch = String(item.id || "").toLowerCase().includes(q);
                if (!titleMatch && !idMatch)
                    continue;
            }
            res.push(item);
        }
        res.sort((a, b) => {
            const ta = (a.title || "").toLowerCase();
            const tb = (b.title || "").toLowerCase();
            return root.installedSortAsc ? ta.localeCompare(tb) : tb.localeCompare(ta);
        });
        return res;
    }

    readonly property int activeDownloadsCount: {
        let count = 0;
        const dl = Skwd.workshopDownloads;
        if (!dl)
            return 0;
        for (let k in dl) {
            if (dl[k] && (dl[k].status === "downloading" || dl[k].status === "starting")) {
                count++;
            }
        }
        return count;
    }

    function isItemCurrent(item): bool {
        if (!item)
            return false;
        const cur = Wallpapers.cleanPath(Wallpapers.actualCurrent || Wallpapers.current);
        const p = Wallpapers.cleanPath(item.path);
        if (cur === p || cur === p + "/project.json")
            return true;
        if (typeof Wallpapers.isCurrent === "function") {
            return Wallpapers.isCurrent(p + "/project.json") || Wallpapers.isCurrent(p);
        }
        return false;
    }

    function isWorkshopItemInstalled(itemId): bool {
        const sId = String(itemId);
        if (Skwd.steamInstalledMap && Skwd.steamInstalledMap[sId])
            return true;
        return root.rawInstalledItems.some(i => String(i.id) === sId);
    }

    function isWorkshopItemSubscribed(itemId): bool {
        const sId = String(itemId);
        if (Skwd.steamSubscribedIds && Skwd.steamSubscribedIds.includes(sId))
            return true;
        return false;
    }

    function getInstalledFolderPath(itemId): string {
        const sId = String(itemId);
        if (Skwd.steamInstalledMap && Skwd.steamInstalledMap[sId]) {
            const info = Skwd.steamInstalledMap[sId];
            if (info && info.folder)
                return info.folder;
        }
        const inst = root.rawInstalledItems.find(i => String(i.id) === sId);
        if (inst && inst.path)
            return inst.path;
        const baseDir = Skwd.resolvedWorkshopDir || Wallpapers.weWorkshopDir;
        if (baseDir)
            return baseDir + "/" + sId;
        return "";
    }

    function formatFileSize(bytes): string {
        if (!bytes || bytes <= 0)
            return "";
        if (bytes < 1024 * 1024)
            return Math.round(bytes / 1024) + " KB";
        if (bytes < 1024 * 1024 * 1024)
            return (bytes / (1024 * 1024)).toFixed(1) + " MB";
        return (bytes / (1024 * 1024 * 1024)).toFixed(2) + " GB";
    }

    function formatSubCount(count): string {
        if (!count || count <= 0)
            return "";
        if (count >= 1000000)
            return (count / 1000000).toFixed(1) + "M";
        if (count >= 1000)
            return (count / 1000).toFixed(1) + "K";
        return String(count);
    }

    function runWorkshopSearch(page: int): void {
        root.workshopPage = Math.max(1, page);
        root.workshopQuery = root.workshopTypedQuery.trim();
        if (typeof Skwd.searchWorkshop === "function") {
            Skwd.searchWorkshop(root.workshopQuery, root.workshopSortType, root.workshopPage);
        }
    }

    function getScenePropValue(prop): var {
        if (!prop)
            return undefined;
        const overrides = Skwd.sceneProperties ? Skwd.sceneProperties[Skwd.activeWeId] : null;
        if (overrides && overrides[prop.key] !== undefined)
            return overrides[prop.key];
        return prop.value;
    }

    function weColorToQColor(val): color {
        if (val === undefined || val === null)
            return Colours.palette.m3primary;
        const s = String(val).trim();
        if (s.startsWith("#")) {
            const hex = s.substring(1);
            if (hex.length === 3 && /^[0-9a-fA-F]{3}$/.test(hex)) {
                const r = parseInt(hex[0] + hex[0], 16) / 255.0;
                const g = parseInt(hex[1] + hex[1], 16) / 255.0;
                const b = parseInt(hex[2] + hex[2], 16) / 255.0;
                return Qt.rgba(r, g, b, 1.0);
            }
            if (hex.length === 6 && /^[0-9a-fA-F]{6}$/.test(hex)) {
                const r = parseInt(hex.substring(0, 2), 16) / 255.0;
                const g = parseInt(hex.substring(2, 4), 16) / 255.0;
                const b = parseInt(hex.substring(4, 6), 16) / 255.0;
                return Qt.rgba(r, g, b, 1.0);
            }
        }
        const parts = s.split(/[\s,]+/).filter(p => p.length > 0);
        if (parts.length >= 3) {
            let r = Number(parts[0]);
            let g = Number(parts[1]);
            let b = Number(parts[2]);
            if (!isNaN(r) && !isNaN(g) && !isNaN(b)) {
                if (r > 1.0 || g > 1.0 || b > 1.0) {
                    r /= 255.0;
                    g /= 255.0;
                    b /= 255.0;
                }
                return Qt.rgba(CUtils.clamp(r, 0, 1), CUtils.clamp(g, 0, 1), CUtils.clamp(b, 0, 1), 1.0);
            }
        }
        return Colours.palette.m3primary;
    }

    function weColorToHex(val): string {
        const c = weColorToQColor(val);
        const toHex = ch => {
            const n = Math.round(CUtils.clamp(ch, 0, 1) * 255);
            return (n < 16 ? "0" : "") + n.toString(16).toUpperCase();
        };
        return "#" + toHex(c.r) + toHex(c.g) + toHex(c.b);
    }

    function qColorToWeString(c: color): string {
        const fmt = ch => Number(CUtils.clamp(ch, 0, 1).toFixed(4));
        return fmt(c.r) + " " + fmt(c.g) + " " + fmt(c.b);
    }

    function parseColorInputToWe(input: string): string {
        const s = String(input || "").trim();
        if (!s)
            return "";
        if (s.startsWith("#")) {
            const hex = s.substring(1);
            if (hex.length === 3 && /^[0-9a-fA-F]{3}$/.test(hex)) {
                const r = parseInt(hex[0] + hex[0], 16) / 255.0;
                const g = parseInt(hex[1] + hex[1], 16) / 255.0;
                const b = parseInt(hex[2] + hex[2], 16) / 255.0;
                return Number(r.toFixed(4)) + " " + Number(g.toFixed(4)) + " " + Number(b.toFixed(4));
            }
            if (hex.length === 6 && /^[0-9a-fA-F]{6}$/.test(hex)) {
                const r = parseInt(hex.substring(0, 2), 16) / 255.0;
                const g = parseInt(hex.substring(2, 4), 16) / 255.0;
                const b = parseInt(hex.substring(4, 6), 16) / 255.0;
                return Number(r.toFixed(4)) + " " + Number(g.toFixed(4)) + " " + Number(b.toFixed(4));
            }
            return "";
        }
        const parts = s.split(/[\s,]+/).filter(p => p.length > 0);
        if (parts.length === 3) {
            let r = Number(parts[0]);
            let g = Number(parts[1]);
            let b = Number(parts[2]);
            if (!isNaN(r) && !isNaN(g) && !isNaN(b) && r >= 0 && g >= 0 && b >= 0) {
                if (r > 1.0 || g > 1.0 || b > 1.0) {
                    if (r > 255 || g > 255 || b > 255)
                        return "";
                    r /= 255.0;
                    g /= 255.0;
                    b /= 255.0;
                }
                return Number(CUtils.clamp(r, 0, 1).toFixed(4)) + " "
                    + Number(CUtils.clamp(g, 0, 1).toFixed(4)) + " "
                    + Number(CUtils.clamp(b, 0, 1).toFixed(4));
            }
        }
        return "";
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        Component.onCompleted: {
            Skwd.refreshWeInstalled();
            if (Skwd.steamAvailable) {
                Skwd.refreshSteamInventory();
            }
        }

        Timer {
            id: wsSearchDebounce
            interval: 400
            repeat: false
            onTriggered: root.runWorkshopSearch(1)
        }

        Variants {
            id: transitionMenuVariants
            model: Skwd.availableTransitions || []
            MenuItem {
                required property var modelData
                text: modelData ? String(modelData.label || modelData.id || "") : ""
                value: modelData ? String(modelData.id || "") : ""
            }
        }

        Component {
            id: sliderPropComp

            SliderRow {
                id: sliderRow

                property var propData: null
                property bool isFirst: false
                property bool isLast: false
                readonly property real minVal: propData && propData.min !== undefined ? Number(propData.min) : 0
                readonly property real maxVal: propData && propData.max !== undefined ? Number(propData.max) : 1
                readonly property real stepVal: propData && propData.step !== undefined ? Number(propData.step) : 0
                readonly property int decimals: {
                    if (propData && propData.precision !== undefined && propData.precision !== null)
                        return Math.max(0, Math.min(6, Math.round(Number(propData.precision))));
                    if (stepVal >= 1 || (propData && propData.fraction === false))
                        return 0;
                    return 2;
                }
                readonly property real currentVal: {
                    const _deps = Skwd.sceneProperties;
                    const v = root.getScenePropValue(propData);
                    return v !== undefined && !isNaN(Number(v)) ? Number(v) : minVal;
                }

                first: isFirst
                last: isLast
                Layout.fillWidth: true
                icon: ""
                label: propData ? (propData.text || propData.key || "") : ""
                value: {
                    const span = maxVal - minVal;
                    return span > 0 ? CUtils.clamp((currentVal - minVal) / span, 0, 1) : 0;
                }
                valueLabel: currentVal.toFixed(decimals)
                onMoved: val => {
                    if (!propData)
                        return;
                    let mapped = minVal + val * (maxVal - minVal);
                    if (stepVal > 0) {
                        mapped = minVal + Math.round((mapped - minVal) / stepVal) * stepVal;
                    } else if (propData.fraction === false) {
                        mapped = Math.round(mapped);
                    }
                    mapped = CUtils.clamp(mapped, minVal, maxVal);
                    mapped = Number(mapped.toFixed(decimals));
                    Skwd.setSceneProperty(Skwd.activeWeId, propData.key, mapped);
                }
            }
        }

        Component {
            id: boolPropComp

            ToggleRow {
                id: boolRow

                property var propData: null
                property bool isFirst: false
                property bool isLast: false
                readonly property bool currentVal: {
                    const _deps = Skwd.sceneProperties;
                    return Boolean(root.getScenePropValue(propData));
                }

                first: isFirst
                last: isLast
                Layout.fillWidth: true
                text: propData ? (propData.text || propData.key || "") : ""
                checked: currentVal
                onToggled: {
                    if (propData)
                        Skwd.setSceneProperty(Skwd.activeWeId, propData.key, checked);
                }
            }
        }

        Component {
            id: comboPropComp

            SelectRow {
                id: comboRow

                property var propData: null
                property bool isFirst: false
                property bool isLast: false
                readonly property var propOptions: propData && propData.options ? propData.options : []
                readonly property var currentVal: {
                    const _deps = Skwd.sceneProperties;
                    return root.getScenePropValue(propData);
                }

                first: isFirst
                last: isLast
                Layout.fillWidth: true
                label: propData ? (propData.text || propData.key || "") : ""
                menuOnTop: true
                menuItems: comboVariants.instances
                fallbackText: currentVal !== undefined ? String(currentVal) : ""
                active: {
                    const items = comboVariants.instances;
                    const cur = String(currentVal ?? "");
                    for (let i = 0; i < items.length; i++) {
                        if (String(items[i].value) === cur)
                            return items[i];
                    }
                    return items.length > 0 ? items[0] : null;
                }
                onSelected: item => {
                    if (item && propData)
                        Skwd.setSceneProperty(Skwd.activeWeId, propData.key, item.value);
                }

                Variants {
                    id: comboVariants
                    model: comboRow.propOptions
                    MenuItem {
                        required property var modelData
                        text: (modelData !== null && typeof modelData === "object")
                            ? String(modelData.label ?? modelData.text ?? modelData.value ?? "")
                            : String(modelData ?? "")
                        value: (modelData !== null && typeof modelData === "object")
                            ? (modelData.value !== undefined ? modelData.value : (modelData.label ?? ""))
                            : modelData
                    }
                }
            }
        }

        Component {
            id: colorPropComp

            ConnectedRect {
                id: colorRow

                property var propData: null
                property bool isFirst: false
                property bool isLast: false
                readonly property var currentVal: {
                    const _deps = Skwd.sceneProperties;
                    return root.getScenePropValue(propData);
                }
                readonly property string hexValue: root.weColorToHex(currentVal)

                first: isFirst
                last: isLast
                Layout.fillWidth: true
                implicitHeight: colorRowLayout.implicitHeight + Tokens.padding.medium * 2

                Connections {
                    target: colorRow
                    function onHexValueChanged(): void {
                        if (!colorInput.activeFocus) {
                            colorInput.text = colorRow.hexValue;
                        }
                    }
                }

                RowLayout {
                    id: colorRowLayout

                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.largeIncreased
                    anchors.topMargin: Tokens.padding.medium
                    anchors.bottomMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.small

                    StyledRect {
                        width: 28
                        height: 28
                        radius: Tokens.rounding.small
                        color: root.weColorToQColor(colorRow.currentVal)
                        border.width: 1
                        border.color: Colours.palette.m3outlineVariant
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: colorRow.propData ? (colorRow.propData.text || colorRow.propData.key || "") : ""
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    StyledTextField {
                        id: colorInput

                        implicitWidth: 140
                        verticalPadding: Tokens.padding.small
                        placeholderText: qsTr("#RRGGBB or r g b")
                        emptyIsValid: false
                        validate: txt => root.parseColorInputToWe(txt) !== ""
                        Component.onCompleted: text = colorRow.hexValue
                        onAccepted: {
                            const weStr = root.parseColorInputToWe(text);
                            if (weStr && colorRow.propData) {
                                Skwd.setSceneProperty(Skwd.activeWeId, colorRow.propData.key, weStr);
                            } else {
                                isError = true;
                            }
                        }
                    }

                    IconButton {
                        icon: "palette"
                        type: IconButton.Tonal
                        onClicked: {
                            if (colorRow.propData) {
                                Skwd.setSceneProperty(Skwd.activeWeId, colorRow.propData.key, root.qColorToWeString(Colours.palette.m3primary));
                            }
                        }
                    }

                    IconTextButton {
                        icon: "check"
                        text: qsTr("Apply")
                        type: IconTextButton.Filled
                        onClicked: {
                            const weStr = root.parseColorInputToWe(colorInput.text);
                            if (weStr && colorRow.propData) {
                                Skwd.setSceneProperty(Skwd.activeWeId, colorRow.propData.key, weStr);
                            } else {
                                colorInput.isError = true;
                            }
                        }
                    }
                }
            }
        }

        // Top Mode Switcher
        ButtonRow {
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.small

            IconTextButton {
                icon: "download_done"
                text: qsTr("Installed (%1)").arg(Skwd.weInstalledItems ? Skwd.weInstalledItems.length : 0)
                font: Tokens.font.body.large
                isRound: true
                shapeMorph: true
                type: root.currentMode === 0 ? IconTextButton.Filled : IconTextButton.Tonal
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                onClicked: root.currentMode = 0
            }

            IconTextButton {
                icon: "storefront"
                text: qsTr("Steam Workshop")
                font: Tokens.font.body.large
                isRound: true
                shapeMorph: true
                type: root.currentMode === 1 ? IconTextButton.Filled : IconTextButton.Tonal
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                onClicked: {
                    root.currentMode = 1;
                    if (Skwd.steamAvailable && Skwd.workshopResults.length === 0 && !Skwd.workshopSearching) {
                        root.runWorkshopSearch(1);
                    }
                }
            }
        }

        // Engine failure banner
        StyledRect {
            visible: Skwd.engineFailed && Skwd.lastError !== ""
            Layout.fillWidth: true
            radius: Tokens.rounding.large
            color: Colours.palette.m3errorContainer
            implicitHeight: engineErrRow.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: engineErrRow
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "error"
                    color: Colours.palette.m3onErrorContainer
                    fontStyle: Tokens.font.icon.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Skwd.lastError
                    color: Colours.palette.m3onErrorContainer
                    font: Tokens.font.body.small
                    wrapMode: Text.Wrap
                }

                IconTextButton {
                    visible: typeof Skwd.retryCurrent === "function"
                    icon: "refresh"
                    text: qsTr("Retry")
                    type: IconTextButton.Filled
                    onClicked: {
                        if (typeof Skwd.retryCurrent === "function") {
                            Skwd.retryCurrent();
                        }
                    }
                }
            }
        }

        // Audio & Workshop Settings Card
        SectionHeader {
            text: qsTr("Audio & Workshop Settings")
        }

        SliderRow {
            Layout.fillWidth: true
            first: true
            icon: "volume_up"
            label: qsTr("Volume")
            valueLabel: Math.round(Wallpapers.weVolume * 100) + "%"
            value: Wallpapers.weVolume
            onMoved: val => {
                const v = val > 1.0 ? val / 100.0 : val;
                if (typeof Wallpapers.setWeVolume === "function") {
                    Wallpapers.setWeVolume(v);
                } else {
                    Wallpapers.weVolume = v;
                }
            }
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: qsTr("Mute audio")
            checked: Wallpapers.weSilent
            onToggled: Wallpapers.weSilent = checked
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: qsTr("Mute audio when behind windows")
            checked: Wallpapers.weMuteBehindWindows
            onToggled: Wallpapers.setWeMuteBehindWindows(checked)
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: qsTr("Mute when other app plays audio")
            checked: Wallpapers.weMuteOnOtherAudio
            onToggled: Wallpapers.setWeMuteOnOtherAudio(checked)
        }

        ConnectedRect {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            last: !folderEditRow.visible
            implicitHeight: folderRowLayout.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: folderRowLayout
                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                anchors.topMargin: Tokens.padding.medium
                anchors.bottomMargin: Tokens.padding.medium
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "folder"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.medium
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Workshop Directory")
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            if (Wallpapers.weWorkshopDir)
                                return Wallpapers.weWorkshopDir;
                            if (Skwd.resolvedWorkshopDir)
                                return Skwd.resolvedWorkshopDir + qsTr(" (Auto-detected)");
                            if (Skwd.probeCompleted)
                                return qsTr("Not found (set path manually)");
                            return qsTr("Auto-detecting...");
                        }
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                        elide: Text.ElideMiddle
                    }
                }

                IconButton {
                    icon: "edit"
                    type: IconButton.Tonal
                    onClicked: folderEditRow.visible = !folderEditRow.visible
                }

                IconButton {
                    icon: "restart_alt"
                    type: IconButton.Text
                    visible: Wallpapers.weWorkshopDir !== ""
                    onClicked: {
                        if (typeof Wallpapers.setWeWorkshopDir === "function") {
                            Wallpapers.setWeWorkshopDir("");
                        } else {
                            Wallpapers.weWorkshopDir = "";
                        }
                        if (typeof Skwd.refreshWeInstalled === "function") {
                            Skwd.refreshWeInstalled();
                        }
                    }
                }
            }
        }

        ConnectedRect {
            id: folderEditRow
            visible: false
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            last: true
            implicitHeight: editLayout.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: editLayout
                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                anchors.topMargin: Tokens.padding.medium
                anchors.bottomMargin: Tokens.padding.medium
                spacing: Tokens.spacing.small

                StyledTextField {
                    id: customPathInput
                    Layout.fillWidth: true
                    placeholderText: qsTr("Enter path to steamapps/workshop/content/431960...")
                    text: Wallpapers.weWorkshopDir || Skwd.resolvedWorkshopDir || ""
                }

                IconTextButton {
                    icon: "check"
                    text: qsTr("Apply")
                    type: IconTextButton.Filled
                    onClicked: {
                        const p = customPathInput.text.trim();
                        if (typeof Wallpapers.setWeWorkshopDir === "function") {
                            Wallpapers.setWeWorkshopDir(p);
                        } else {
                            Wallpapers.weWorkshopDir = p;
                        }
                        if (typeof Skwd.refreshWeInstalled === "function") {
                            Skwd.refreshWeInstalled();
                        }
                        folderEditRow.visible = false;
                    }
                }
            }
        }

        // Engine & Performance Section
        SectionHeader {
            visible: root.currentMode === 0
            text: qsTr("Engine & Performance")
        }

        SelectRow {
            visible: root.currentMode === 0
            first: true
            Layout.fillWidth: true
            label: qsTr("Transition Effect")
            menuOnTop: true
            menuItems: transitionMenuVariants.instances
            fallbackText: Skwd.transitionEffect || qsTr("Fade")
            active: {
                const items = transitionMenuVariants.instances;
                const cur = Skwd.transitionEffect;
                for (let i = 0; i < items.length; i++) {
                    if (items[i].value === cur)
                        return items[i];
                }
                return items.length > 0 ? items[0] : null;
            }
            onSelected: item => {
                if (item)
                    Skwd.setTransitionEffect(String(item.value));
            }
        }

        InfoRow {
            visible: root.currentMode === 0 && (Skwd.availableGpus ? Skwd.availableGpus.length > 0 : false) && !(Skwd.hasAnyDiscrete && Skwd.hasSafeIntegrated)
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Graphics Processor")
            subtext: (Skwd.availableGpus && Skwd.availableGpus.length > 1)
                ? (Skwd.hasSafeDiscrete
                    ? qsTr("Matched to active compositor display output")
                    : qsTr("Locked to compositor GPU (non-compositor dGPU excluded)"))
                : qsTr("Active compositor display GPU")
            value: Skwd.compositorGpuName || qsTr("Auto (Compositor GPU)")
        }

        SelectRow {
            visible: root.currentMode === 0 && Skwd.hasAnyDiscrete && Skwd.hasSafeIntegrated
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Graphics Processor")
            subtext: {
                if (Skwd.effectiveGpu === "discrete" && Skwd.hasOffloadDiscrete)
                    return qsTr("Scenes on %1 (SHM); videos on Intel VAAPI").arg(Skwd.discreteGpuName || "dGPU");
                if (Skwd.effectiveGpu === "discrete")
                    return qsTr("Active: %1").arg(Skwd.discreteGpuName || "dGPU");
                return qsTr("Active: %1").arg(Skwd.compositorGpuName || Skwd.integratedGpuName || "Integrated GPU");
            }
            menuOnTop: true
            menuItems: root.gpuModeItems
            active: {
                const cur = String(Skwd.gpuMode || "auto");
                for (let i = 0; i < root.gpuModeItems.length; i++) {
                    if (String(root.gpuModeItems[i].value) === cur)
                        return root.gpuModeItems[i];
                }
                return root.gpuModeItems[0];
            }
            onSelected: item => {
                if (item)
                    Skwd.setGpuMode(String(item.value));
            }
        }

        SelectRow {
            visible: root.currentMode === 0
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Scene Frame Rate")
            subtext: qsTr("Caps scene FPS; videos decode natively via VAAPI")
            menuOnTop: true
            menuItems: root.fpsItems
            active: {
                const cur = Number(Skwd.fps);
                for (let i = 0; i < root.fpsItems.length; i++) {
                    if (Number(root.fpsItems[i].value) === cur)
                        return root.fpsItems[i];
                }
                return root.fpsItems[0];
            }
            onSelected: item => {
                if (item)
                    Skwd.setFps(Number(item.value));
            }
        }

        SelectRow {
            visible: root.currentMode === 0
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Scene Resolution")
            subtext: qsTr("Active render cap: %1px (lower reduces iGPU load)").arg(Skwd.effectiveMaxDim)
            menuOnTop: true
            menuItems: root.sceneQualityItems
            active: {
                const cur = String(Skwd.sceneQuality || "auto");
                for (let i = 0; i < root.sceneQualityItems.length; i++) {
                    if (String(root.sceneQualityItems[i].value) === cur)
                        return root.sceneQualityItems[i];
                }
                return root.sceneQualityItems[0];
            }
            onSelected: item => {
                if (item)
                    Skwd.setSceneQuality(String(item.value));
            }
        }

        ToggleRow {
            visible: root.currentMode === 0
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: qsTr("Disable Particles")
            checked: Skwd.disableParticles
            onToggled: Skwd.setDisableParticles(checked)
        }

        ToggleRow {
            visible: root.currentMode === 0
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: qsTr("Limit Scene Effect Chains")
            subtext: qsTr("Caps complex scenes to 4 effect chains/passes")
            checked: Skwd.reduceEffects
            onToggled: Skwd.setReduceEffects(checked)
        }

        ToggleRow {
            visible: root.currentMode === 0
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            last: true
            text: qsTr("Compositor Blur over Wallpaper Engine")
            subtext: qsTr("Off avoids full-screen Hyprland blur passes on iGPU")
            checked: Skwd.compositorBlur
            onToggled: Skwd.setCompositorBlur(checked)
        }

        // ==========================================
        // MODE 0: INSTALLED LIBRARY
        // ==========================================
        SectionHeader {
            visible: root.currentMode === 0
            text: qsTr("Installed Wallpapers")
        }

        RowLayout {
            visible: root.currentMode === 0
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledTextField {
                id: searchInput
                Layout.fillWidth: true
                leadingIcon: "search"
                placeholderText: qsTr("Search installed wallpapers...")
                text: root.installedSearchText
                onTextEdited: root.installedSearchText = text
            }

            IconButton {
                icon: "close"
                type: IconButton.Tonal
                visible: searchInput.text !== ""
                onClicked: {
                    searchInput.text = "";
                    root.installedSearchText = "";
                }
            }

            Row {
                spacing: Tokens.spacing.extraSmall

                IconTextButton {
                    icon: "grid_view"
                    text: qsTr("All")
                    type: root.installedCategory === 0 ? IconTextButton.Filled : IconTextButton.Tonal
                    font: Tokens.font.label.medium
                    onClicked: root.installedCategory = 0
                }

                IconTextButton {
                    icon: "animation"
                    text: qsTr("Scenes")
                    type: root.installedCategory === 1 ? IconTextButton.Filled : IconTextButton.Tonal
                    font: Tokens.font.label.medium
                    onClicked: root.installedCategory = 1
                }

                IconTextButton {
                    icon: "movie"
                    text: qsTr("Videos")
                    type: root.installedCategory === 2 ? IconTextButton.Filled : IconTextButton.Tonal
                    font: Tokens.font.label.medium
                    onClicked: root.installedCategory = 2
                }
            }

            IconButton {
                icon: root.installedSortAsc ? "sort_by_alpha" : "sort"
                type: IconButton.Tonal
                onClicked: root.installedSortAsc = !root.installedSortAsc
            }

            IconButton {
                icon: "refresh"
                type: IconButton.Tonal
                onClicked: Skwd.refreshWeInstalled()
            }
        }

        // Installed Grid
        GridLayout {
            visible: root.currentMode === 0 && root.filteredInstalledItems.length > 0
            Layout.fillWidth: true
            columns: Config.nexus.wallpapersPerRow > 0 ? Config.nexus.wallpapersPerRow : 3
            rowSpacing: Tokens.spacing.large
            columnSpacing: Tokens.spacing.large

            Repeater {
                model: root.filteredInstalledItems

                delegate: Item {
                    id: installedCard
                    required property var modelData
                    required property int index

                    readonly property bool isUnsupported: Boolean(installedCard.modelData && installedCard.modelData.unsupported)
                    readonly property string itemType: installedCard.modelData ? String(installedCard.modelData.type || "scene").toLowerCase() : "scene"

                    Layout.fillWidth: true
                    implicitHeight: cardLayout.implicitHeight

                    ColumnLayout {
                        id: cardLayout
                        anchors.fill: parent
                        spacing: Tokens.spacing.small

                        ClipRect {
                            id: thumbClip
                            Layout.fillWidth: true
                            implicitHeight: Math.round(width * 0.6)
                            radius: Tokens.rounding.largeIncreased
                            color: Colours.tPalette.m3surfaceContainer

                            Image {
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize: Qt.size(480, 288)
                                opacity: installedCard.isUnsupported ? 0.45 : 1.0
                                source: {
                                    void Skwd.posterRevision;
                                    const md = installedCard.modelData;
                                    const cachedPoster = md?.path ? Skwd.getCachedPosterPath(md.path) : "";
                                    const p = cachedPoster || (md ? (md.poster || md.thumb || md.preview || "") : "");
                                    if (!p) return "";
                                    const url = p.startsWith("http") || p.startsWith("file://") ? p : "file://" + p;
                                    return cachedPoster ? `${url}?v=${Skwd.posterRevision}` : url;
                                }
                            }

                            StateLayer {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Wallpapers.setWallpaper(installedCard.modelData.path + "/project.json");
                                }
                            }

                            // Unsupported badge (bottom-left: web/application unsupported by skwd)
                            StyledRect {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.margins: Tokens.padding.small
                                visible: installedCard.isUnsupported
                                radius: Tokens.rounding.full
                                color: Colours.palette.m3errorContainer
                                implicitWidth: unsupRow.implicitWidth + Tokens.padding.small * 2
                                implicitHeight: unsupRow.implicitHeight + Tokens.padding.extraSmall * 2

                                RowLayout {
                                    id: unsupRow
                                    anchors.centerIn: parent
                                    spacing: Tokens.spacing.extraSmall

                                    MaterialIcon {
                                        text: "block"
                                        color: Colours.palette.m3onErrorContainer
                                        fontStyle: Tokens.font.icon.small
                                    }

                                    StyledText {
                                        text: qsTr("Unsupported")
                                        color: Colours.palette.m3onErrorContainer
                                        font: Tokens.font.label.small
                                    }
                                }
                            }

                            // Type chip (bottom-right: scene vs video vs web/app)
                            StyledRect {
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.margins: Tokens.padding.small
                                width: 28
                                height: 28
                                radius: Tokens.rounding.full
                                color: Qt.rgba(0, 0, 0, 0.6)

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: {
                                        if (installedCard.itemType === "video")
                                            return "movie";
                                        if (installedCard.itemType === "web")
                                            return "language";
                                        if (installedCard.itemType === "application")
                                            return "apps";
                                        return "animation";
                                    }
                                    color: Colours.palette.m3onSurface
                                    fontStyle: Tokens.font.icon.small
                                }
                            }

                            // Active checkmark badge (top-right)
                            StyledRect {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: Tokens.padding.small
                                width: 28
                                height: 28
                                radius: Tokens.rounding.full
                                color: Colours.palette.m3primary
                                visible: root.isItemCurrent(installedCard.modelData)

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: "check"
                                    color: Colours.palette.m3onPrimary
                                    fontStyle: Tokens.font.icon.small
                                }
                            }

                            // Unsubscribe button (top-left) when Steam is connected
                            IconButton {
                                z: 2
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.margins: Tokens.padding.extraSmall
                                icon: root.confirmUnsubId === String(installedCard.modelData.id) ? "delete_forever" : "cloud_off"
                                type: root.confirmUnsubId === String(installedCard.modelData.id) ? IconButton.Filled : IconButton.Tonal
                                visible: Skwd.steamConnected && Boolean(installedCard.modelData.id)
                                onClicked: {
                                    const idStr = String(installedCard.modelData.id);
                                    if (root.confirmUnsubId === idStr) {
                                        Skwd.unsubscribeWorkshopItem(idStr);
                                        root.confirmUnsubId = "";
                                    } else {
                                        root.confirmUnsubId = idStr;
                                    }
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: installedCard.modelData.title || String(installedCard.modelData.id) || ""
                            font: Tokens.font.label.medium
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            color: Colours.palette.m3onSurface
                        }
                    }
                }
            }
        }

        // Empty installed state
        StyledRect {
            visible: root.currentMode === 0 && root.filteredInstalledItems.length === 0
            Layout.fillWidth: true
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer
            implicitHeight: 120

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Tokens.spacing.small

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "hide_image"
                    color: Colours.palette.m3outline
                    fontStyle: Tokens.font.icon.large
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.installedSearchText ? qsTr("No wallpapers match \"%1\"").arg(root.installedSearchText) : qsTr("No installed Wallpaper Engine items found")
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.medium
                }
            }
        }

        // Dynamic Scene Properties Section
        RowLayout {
            visible: root.currentMode === 0 && Skwd.activeWeId !== "" && Boolean(Skwd.activeSceneSchema && Skwd.activeSceneSchema.length > 0)
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.largeIncreased - parent.spacing
            Layout.bottomMargin: Tokens.spacing.extraSmall
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: Tokens.padding.small
                text: qsTr("Scene Properties")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
                elide: Text.ElideRight
            }

            IconTextButton {
                icon: "restart_alt"
                text: qsTr("Reset")
                type: IconTextButton.Tonal
                font: Tokens.font.label.medium
                onClicked: Skwd.resetSceneProperties(Skwd.activeWeId)
            }
        }

        ColumnLayout {
            id: scenePropsCol

            visible: root.currentMode === 0 && Skwd.activeWeId !== "" && Boolean(Skwd.activeSceneSchema && Skwd.activeSceneSchema.length > 0)
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall / 2

            Repeater {
                id: scenePropsRepeater
                model: Skwd.activeSceneSchema || []

                delegate: Loader {
                    id: propRowLoader

                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    visible: item !== null
                    z: item ? item.z : 0
                    sourceComponent: {
                        const t = propRowLoader.modelData ? String(propRowLoader.modelData.type || "") : "";
                        if (t === "slider")
                            return sliderPropComp;
                        if (t === "bool")
                            return boolPropComp;
                        if (t === "combo")
                            return comboPropComp;
                        if (t === "color")
                            return colorPropComp;
                        return null;
                    }

                    Binding {
                        target: propRowLoader.item
                        property: "propData"
                        value: propRowLoader.modelData
                        when: propRowLoader.item !== null
                    }

                    Binding {
                        target: propRowLoader.item
                        property: "isFirst"
                        value: propRowLoader.index === 0
                        when: propRowLoader.item !== null
                    }

                    Binding {
                        target: propRowLoader.item
                        property: "isLast"
                        value: propRowLoader.index === (scenePropsRepeater.count - 1)
                        when: propRowLoader.item !== null
                    }
                }
            }
        }

        // ==========================================
        // MODE 1: STEAM WORKSHOP BROWSER
        // ==========================================
        SectionHeader {
            visible: root.currentMode === 1
            text: qsTr("Steam Workshop")
        }

        // Steam unavailable instructions
        StyledRect {
            visible: root.currentMode === 1 && !Skwd.steamAvailable
            Layout.fillWidth: true
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer
            implicitHeight: unavailRow.implicitHeight + Tokens.padding.large * 2

            RowLayout {
                id: unavailRow
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "info"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.large
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        text: qsTr("Steam Workshop Integration Required")
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.title.small
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("To browse, search, and download wallpapers directly from Steam Workshop, install skwd-deck-steamworks-bin:\nparu -S skwd-deck-steamworks-bin")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        wrapMode: Text.Wrap
                    }
                }
            }
        }

        // Error banner
        StyledRect {
            visible: root.currentMode === 1 && (Skwd.steamError !== "" || Skwd.workshopError !== "")
            Layout.fillWidth: true
            radius: Tokens.rounding.large
            color: Colours.palette.m3errorContainer
            implicitHeight: errRow.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: errRow
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "warning"
                    color: Colours.palette.m3onErrorContainer
                    fontStyle: Tokens.font.icon.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        if (Skwd.steamError)
                            return Skwd.steamError;
                        if (Skwd.workshopError)
                            return Skwd.workshopError;
                        return qsTr("Make sure Steam is running and logged into an account that owns Wallpaper Engine.");
                    }
                    color: Colours.palette.m3onErrorContainer
                    font: Tokens.font.body.small
                    wrapMode: Text.Wrap
                }

                IconTextButton {
                    icon: "refresh"
                    text: qsTr("Retry")
                    type: IconTextButton.Filled
                    onClicked: {
                        Skwd.refreshSteamInventory();
                        root.runWorkshopSearch(root.workshopPage);
                    }
                }
            }
        }

        // Active downloads banner
        StyledRect {
            visible: root.currentMode === 1 && root.activeDownloadsCount > 0
            Layout.fillWidth: true
            radius: Tokens.rounding.large
            color: Colours.palette.m3secondaryContainer
            implicitHeight: dlBannerRow.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: dlBannerRow
                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "cloud_download"
                    color: Colours.palette.m3onSecondaryContainer
                    fontStyle: Tokens.font.icon.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Downloading %1 wallpaper(s)...").arg(root.activeDownloadsCount)
                    color: Colours.palette.m3onSecondaryContainer
                    font: Tokens.font.body.small
                }
            }
        }

        // Search & Ranking bar
        RowLayout {
            visible: root.currentMode === 1 && Skwd.steamAvailable
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledTextField {
                id: wsSearchField
                Layout.fillWidth: true
                leadingIcon: "search"
                placeholderText: qsTr("Search Steam Workshop...")
                text: root.workshopTypedQuery
                onTextEdited: {
                    root.workshopTypedQuery = text;
                    wsSearchDebounce.restart();
                }
                onAccepted: {
                    wsSearchDebounce.stop();
                    root.workshopTypedQuery = text;
                    root.runWorkshopSearch(1);
                }
            }

            IconButton {
                icon: "close"
                type: IconButton.Tonal
                visible: wsSearchField.text !== ""
                onClicked: {
                    wsSearchField.text = "";
                    root.workshopTypedQuery = "";
                    root.runWorkshopSearch(1);
                }
            }

            IconButton {
                icon: "navigate_before"
                type: IconButton.Tonal
                disabled: root.workshopPage <= 1 || Skwd.workshopSearching
                onClicked: root.runWorkshopSearch(root.workshopPage - 1)
            }

            StyledText {
                text: qsTr("Page %1").arg(root.workshopPage)
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }

            IconButton {
                icon: "navigate_next"
                type: IconButton.Tonal
                disabled: Skwd.workshopSearching || Skwd.workshopResults.length === 0
                onClicked: root.runWorkshopSearch(root.workshopPage + 1)
            }

            IconButton {
                icon: "refresh"
                type: IconButton.Tonal
                disabled: Skwd.workshopSearching
                onClicked: {
                    Skwd.refreshSteamInventory();
                    root.runWorkshopSearch(root.workshopPage);
                }
            }
        }

        // Ranking pills
        Row {
            visible: root.currentMode === 1 && Skwd.steamAvailable
            spacing: Tokens.spacing.extraSmall

            IconTextButton {
                icon: "local_fire_department"
                text: qsTr("Trending")
                type: root.workshopSortType === 3 ? IconTextButton.Filled : IconTextButton.Tonal
                font: Tokens.font.label.medium
                onClicked: {
                    root.workshopSortType = 3;
                    root.runWorkshopSearch(1);
                }
            }

            IconTextButton {
                icon: "thumb_up"
                text: qsTr("Top Rated")
                type: root.workshopSortType === 0 ? IconTextButton.Filled : IconTextButton.Tonal
                font: Tokens.font.label.medium
                onClicked: {
                    root.workshopSortType = 0;
                    root.runWorkshopSearch(1);
                }
            }

            IconTextButton {
                icon: "fiber_new"
                text: qsTr("Newest")
                type: root.workshopSortType === 1 ? IconTextButton.Filled : IconTextButton.Tonal
                font: Tokens.font.label.medium
                onClicked: {
                    root.workshopSortType = 1;
                    root.runWorkshopSearch(1);
                }
            }

            IconTextButton {
                icon: "groups"
                text: qsTr("Most Subscribed")
                type: root.workshopSortType === 9 ? IconTextButton.Filled : IconTextButton.Tonal
                font: Tokens.font.label.medium
                onClicked: {
                    root.workshopSortType = 9;
                    root.runWorkshopSearch(1);
                }
            }

            IconTextButton {
                icon: "update"
                text: qsTr("Recently Updated")
                type: root.workshopSortType === 21 ? IconTextButton.Filled : IconTextButton.Tonal
                font: Tokens.font.label.medium
                onClicked: {
                    root.workshopSortType = 21;
                    root.runWorkshopSearch(1);
                }
            }
        }

        // Workshop Grid
        GridLayout {
            visible: root.currentMode === 1 && Skwd.workshopResults.length > 0
            Layout.fillWidth: true
            columns: Config.nexus.wallpapersPerRow > 0 ? Config.nexus.wallpapersPerRow : 3
            rowSpacing: Tokens.spacing.large
            columnSpacing: Tokens.spacing.large

            Repeater {
                model: Skwd.workshopResults

                delegate: Item {
                    id: wsCardItem
                    required property var modelData
                    required property int index

                    readonly property var dlInfo: Skwd.workshopDownloads ? Skwd.workshopDownloads[String(wsCardItem.modelData.id)] : null
                    readonly property bool isDownloading: dlInfo && (dlInfo.status === "downloading" || dlInfo.status === "starting")

                    Layout.fillWidth: true
                    implicitHeight: wsCardLayout.implicitHeight

                    ColumnLayout {
                        id: wsCardLayout
                        anchors.fill: parent
                        spacing: Tokens.spacing.small

                        ClipRect {
                            id: wsThumbClip
                            Layout.fillWidth: true
                            implicitHeight: Math.round(width * 0.6)
                            radius: Tokens.rounding.largeIncreased
                            color: Colours.tPalette.m3surfaceContainer

                            Image {
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize: Qt.size(480, 288)
                                source: wsCardItem.modelData.preview_url || ""
                            }

                            // Installed checkmark badge (top-right)
                            StyledRect {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: Tokens.padding.small
                                width: 28
                                height: 28
                                radius: Tokens.rounding.full
                                color: Colours.palette.m3primary
                                visible: root.isWorkshopItemInstalled(wsCardItem.modelData.id)

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: "check"
                                    color: Colours.palette.m3onPrimary
                                    fontStyle: Tokens.font.icon.small
                                }
                            }

                            // Subscribed cloud_done badge (top-left)
                            StyledRect {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.margins: Tokens.padding.small
                                width: 28
                                height: 28
                                radius: Tokens.rounding.full
                                color: Colours.palette.m3secondary
                                visible: root.isWorkshopItemSubscribed(wsCardItem.modelData.id) && !root.isWorkshopItemInstalled(wsCardItem.modelData.id)

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: "cloud_done"
                                    color: Colours.palette.m3onSecondary
                                    fontStyle: Tokens.font.icon.small
                                }
                            }

                            // Action buttons overlay (bottom of card)
                            RowLayout {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: Tokens.padding.small
                                spacing: Tokens.spacing.small
                                visible: !wsCardItem.isDownloading

                                IconTextButton {
                                    visible: !root.isWorkshopItemInstalled(wsCardItem.modelData.id)
                                    icon: "cloud_download"
                                    text: qsTr("Subscribe")
                                    type: IconTextButton.Filled
                                    font: Tokens.font.label.medium
                                    onClicked: Skwd.subscribeWorkshopItem(String(wsCardItem.modelData.id))
                                }

                                IconTextButton {
                                    visible: root.isWorkshopItemInstalled(wsCardItem.modelData.id)
                                    icon: "wallpaper"
                                    text: qsTr("Apply")
                                    type: IconTextButton.Filled
                                    font: Tokens.font.label.medium
                                    onClicked: {
                                        const p = root.getInstalledFolderPath(wsCardItem.modelData.id);
                                        if (p) {
                                            Wallpapers.setWallpaper(p + "/project.json");
                                        }
                                    }
                                }

                                IconButton {
                                    visible: root.isWorkshopItemSubscribed(wsCardItem.modelData.id) || root.isWorkshopItemInstalled(wsCardItem.modelData.id)
                                    icon: root.confirmWsUnsubId === String(wsCardItem.modelData.id) ? "delete_forever" : "cloud_off"
                                    type: root.confirmWsUnsubId === String(wsCardItem.modelData.id) ? IconButton.Filled : IconButton.Tonal
                                    onClicked: {
                                        const idStr = String(wsCardItem.modelData.id);
                                        if (root.confirmWsUnsubId === idStr) {
                                            Skwd.unsubscribeWorkshopItem(idStr);
                                            root.confirmWsUnsubId = "";
                                        } else {
                                            root.confirmWsUnsubId = idStr;
                                        }
                                    }
                                }
                            }

                            // Frosted downloading overlay with CircularProgress
                            StyledRect {
                                anchors.fill: parent
                                radius: parent.radius
                                color: Qt.rgba(0, 0, 0, 0.75)
                                visible: wsCardItem.isDownloading

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: Tokens.spacing.extraSmall

                                    CircularProgress {
                                        Layout.alignment: Qt.AlignHCenter
                                        implicitSize: 44
                                        strokeWidth: 4
                                        value: wsCardItem.dlInfo ? (wsCardItem.dlInfo.progress || 0.0) : 0.0

                                        StyledText {
                                            anchors.centerIn: parent
                                            text: Math.round((wsCardItem.dlInfo ? (wsCardItem.dlInfo.progress || 0) : 0) * 100) + "%"
                                            font: Tokens.font.label.small
                                            color: Colours.palette.m3onSurface
                                        }
                                    }

                                    StyledText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: wsCardItem.dlInfo ? (wsCardItem.dlInfo.message || qsTr("Downloading...")) : ""
                                        font: Tokens.font.label.small
                                        color: Colours.palette.m3onSurfaceVariant
                                    }
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: wsCardItem.modelData.title || String(wsCardItem.modelData.id) || ""
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                            color: Colours.palette.m3onSurface
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.formatFileSize(wsCardItem.modelData.file_size) + (wsCardItem.modelData.subscriptions ? " · " + root.formatSubCount(wsCardItem.modelData.subscriptions) + " " + qsTr("subscribers") : "")
                            font: Tokens.font.label.small
                            color: Colours.palette.m3outline
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // Searching workshop indicator
        StyledRect {
            visible: root.currentMode === 1 && Skwd.workshopSearching && Skwd.workshopResults.length === 0
            Layout.fillWidth: true
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer
            implicitHeight: 120

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Tokens.spacing.small

                CircularProgress {
                    Layout.alignment: Qt.AlignHCenter
                    implicitSize: 36
                    strokeWidth: 4
                    value: 0.5
                    wavy: true
                    wavePaused: !visible
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Searching Steam Workshop...")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                }
            }
        }

        // Empty workshop state
        StyledRect {
            visible: root.currentMode === 1 && !Skwd.workshopSearching && Skwd.workshopResults.length === 0 && Skwd.steamAvailable && Skwd.steamError === "" && Skwd.workshopError === ""
            Layout.fillWidth: true
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer
            implicitHeight: 120

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Tokens.spacing.small

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "travel_explore"
                    color: Colours.palette.m3outline
                    fontStyle: Tokens.font.icon.large
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.workshopQuery ? qsTr("No wallpapers match \"%1\"").arg(root.workshopQuery) : qsTr("Search the Steam Workshop to find wallpapers")
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.medium
                }
            }
        }
    }
}

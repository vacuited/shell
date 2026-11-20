pragma Singleton

import QtQuick
import M3Shapes
import Caelestia.Config
import qs.services

QtObject {
    id: root

    // Global scale clamped safely so widgets remain readable and well-proportioned.
    readonly property real scale: Math.max(0.7, Math.min(1.5, GlobalConfig.background.desktopWidgets.scale ?? 1.0))

    // Scheme-harmonized inner surface tokens (lighter than dark hard-flavour containers).
    readonly property color innerSurface: Colours.light
        ? Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.72)
        : Qt.tint(Qt.alpha(Colours.palette.m3secondaryContainer, 0.44), Qt.alpha(Colours.palette.m3surfaceBright, 0.14))
    readonly property color innerSurfaceStrong: Colours.light
        ? Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.85)
        : Qt.tint(Qt.alpha(Colours.palette.m3secondaryContainer, 0.68), Qt.alpha(Colours.palette.m3primary, 0.08))
    readonly property color innerBorder: Qt.alpha(Colours.palette.m3outlineVariant, Colours.light ? 0.35 : 0.42)
    readonly property color trackSurface: Qt.alpha(Colours.palette.m3onSurface, 0.15)
    readonly property color popoverSurface: Colours.light
        ? Colours.palette.m3surfaceContainerHigh
        : Qt.tint(Colours.palette.m3surfaceContainerHigh, Qt.alpha(Colours.palette.m3secondaryContainer, 0.42))

    // Unified grid geometry: 164px unit cell + 12px gap => 1=164, 2=340, 3=516
    readonly property int baseCell: 164
    readonly property int baseGap: 12
    readonly property int basePillHeight: 64
    readonly property int gap: Math.round(baseGap * scale)
    readonly property int gridStep: Math.round((baseCell + baseGap) * scale)

    // Gentle magnetic snap tolerance in pixels during drag (disabled when Shift is held).
    readonly property real snapThreshold: 7

    readonly property var shapeCatalog: [
        { key: "Rounded", label: "Rounded", shape: -1 },
        { key: "Cookie9Sided", label: "Cookie 9", shape: MaterialShape.Cookie9Sided },
        { key: "Cookie12Sided", label: "Cookie 12", shape: MaterialShape.Cookie12Sided },
        { key: "Cookie7Sided", label: "Cookie 7", shape: MaterialShape.Cookie7Sided },
        { key: "Cookie6Sided", label: "Cookie 6", shape: MaterialShape.Cookie6Sided },
        { key: "Cookie4Sided", label: "Cookie 4", shape: MaterialShape.Cookie4Sided },
        { key: "Puffy", label: "Puffy", shape: MaterialShape.Puffy },
        { key: "Sunny", label: "Sunny", shape: MaterialShape.Sunny },
        { key: "VerySunny", label: "Very Sunny", shape: MaterialShape.VerySunny },
        { key: "SoftBurst", label: "Soft Burst", shape: MaterialShape.SoftBurst },
        { key: "Circle", label: "Circle", shape: MaterialShape.Circle },
        { key: "Pill", label: "Pill", shape: MaterialShape.Pill },
        { key: "Clover4Leaf", label: "Clover 4", shape: MaterialShape.Clover4Leaf },
        { key: "Clover8Leaf", label: "Clover 8", shape: MaterialShape.Clover8Leaf },
        { key: "Flower", label: "Flower", shape: MaterialShape.Flower },
        { key: "Gem", label: "Gem", shape: MaterialShape.Gem },
        { key: "Heart", label: "Heart", shape: MaterialShape.Heart },
        { key: "Ghostish", label: "Ghost", shape: MaterialShape.Ghostish },
        { key: "ClamShell", label: "Shell", shape: MaterialShape.ClamShell },
        { key: "Bun", label: "Bun", shape: MaterialShape.Bun },
        { key: "Square", label: "Squircle", shape: MaterialShape.Square },
        { key: "Diamond", label: "Diamond", shape: MaterialShape.Diamond },
        { key: "Pentagon", label: "Pentagon", shape: MaterialShape.Pentagon },
        { key: "Arch", label: "Arch", shape: MaterialShape.Arch }
    ]

    readonly property var shapeEnumMap: ({
        "Rounded": -1,
        "Default": -1,
        "Custom": MaterialShape.Custom,
        "Circle": MaterialShape.Circle,
        "Square": MaterialShape.Square,
        "Slanted": MaterialShape.Slanted,
        "Arch": MaterialShape.Arch,
        "Fan": MaterialShape.Fan,
        "Arrow": MaterialShape.Arrow,
        "SemiCircle": MaterialShape.SemiCircle,
        "Oval": MaterialShape.Oval,
        "Pill": MaterialShape.Pill,
        "Triangle": MaterialShape.Triangle,
        "Diamond": MaterialShape.Diamond,
        "ClamShell": MaterialShape.ClamShell,
        "Pentagon": MaterialShape.Pentagon,
        "Gem": MaterialShape.Gem,
        "Sunny": MaterialShape.Sunny,
        "VerySunny": MaterialShape.VerySunny,
        "Cookie4Sided": MaterialShape.Cookie4Sided,
        "Cookie6Sided": MaterialShape.Cookie6Sided,
        "Cookie7Sided": MaterialShape.Cookie7Sided,
        "Cookie9Sided": MaterialShape.Cookie9Sided,
        "Cookie12Sided": MaterialShape.Cookie12Sided,
        "Ghostish": MaterialShape.Ghostish,
        "Clover4Leaf": MaterialShape.Clover4Leaf,
        "Clover8Leaf": MaterialShape.Clover8Leaf,
        "Burst": MaterialShape.Burst,
        "SoftBurst": MaterialShape.SoftBurst,
        "Boom": MaterialShape.Boom,
        "SoftBoom": MaterialShape.SoftBoom,
        "Flower": MaterialShape.Flower,
        "Puffy": MaterialShape.Puffy,
        "PuffyDiamond": MaterialShape.PuffyDiamond,
        "PixelCircle": MaterialShape.PixelCircle,
        "PixelTriangle": MaterialShape.PixelTriangle,
        "Bun": MaterialShape.Bun,
        "Heart": MaterialShape.Heart
    })

    readonly property var widgetMeta: ({
        "atAGlance": {
            label: qsTr("At a Glance"),
            icon: "view_agenda",
            defaultSize: "1x2",
            supportedSizes: ["1x2", "2x1", "2x2", "1x3", "2x3"],
            defaultShape: "Rounded",
            supportsOuterShape: false
        },
        "calendar": {
            label: qsTr("Calendar"),
            icon: "calendar_month",
            defaultSize: "1x1",
            supportedSizes: ["1x1", "1x2", "2x1", "2x2", "2x3"],
            defaultShape: "Cookie9Sided",
            supportsOuterShape: true
        },
        "weather": {
            label: qsTr("Weather"),
            icon: "partly_cloudy_day",
            defaultSize: "1x1",
            supportedSizes: ["1x1", "1x2", "2x1", "2x2", "1x3", "2x3"],
            defaultShape: "Puffy",
            supportsOuterShape: true
        },
        "weatherPill": {
            label: qsTr("Weather Pill"),
            icon: "sunny",
            defaultSize: "1x1",
            supportedSizes: ["1x1", "1x2"],
            defaultShape: "Rounded",
            supportsOuterShape: false
        },
        "timers": {
            label: qsTr("Focus & Timers"),
            icon: "timer",
            defaultSize: "1x1",
            supportedSizes: ["1x1", "1x2", "2x1", "2x2", "2x3"],
            defaultShape: "Circle",
            supportsOuterShape: true
        },
        "countdown": {
            label: qsTr("Countdown"),
            icon: "hourglass_top",
            defaultSize: "1x1",
            supportedSizes: ["1x1", "1x2", "2x1", "2x2"],
            defaultShape: "Cookie9Sided",
            supportsOuterShape: true
        },
        "resources": {
            label: qsTr("Resources"),
            icon: "memory",
            defaultSize: "2x1",
            supportedSizes: ["1x1", "1x2", "2x1", "2x2", "1x3", "2x3"],
            defaultShape: "Sunny",
            supportsOuterShape: true
        },
        "media": {
            label: qsTr("Media"),
            icon: "music_note",
            defaultSize: "1x2",
            supportedSizes: ["1x1", "1x2", "2x1", "2x2", "1x3", "2x3"],
            defaultShape: "Cookie12Sided",
            supportsOuterShape: true
        },
        "battery": {
            label: qsTr("Battery"),
            icon: "battery_charging_full",
            defaultSize: "1x1",
            supportedSizes: ["1x1", "1x2", "2x1", "2x2"],
            defaultShape: "Pill",
            supportsOuterShape: true
        },
        "usercard": {
            label: qsTr("User Card"),
            icon: "person",
            defaultSize: "1x2",
            supportedSizes: ["1x1", "1x2", "2x1", "2x2", "2x3"],
            defaultShape: "Cookie9Sided",
            supportsOuterShape: true
        },
        "todo": {
            label: qsTr("Todo"),
            icon: "checklist",
            defaultSize: "2x1",
            supportedSizes: ["1x1", "1x2", "2x1", "2x2", "2x3"],
            defaultShape: "Cookie7Sided",
            supportsOuterShape: true
        },
        "notes": {
            label: qsTr("Notes"),
            icon: "sticky_note_2",
            defaultSize: "2x1",
            supportedSizes: ["1x1", "1x2", "2x1", "2x2", "2x3"],
            defaultShape: "Cookie4Sided",
            supportsOuterShape: true
        },
        "customImage": {
            label: qsTr("Image"),
            icon: "image",
            defaultSize: "1x1",
            supportedSizes: [],
            defaultShape: "Rounded",
            supportsOuterShape: true
        },
        "sticker": {
            label: qsTr("Sticker"),
            icon: "sentiment_satisfied",
            defaultSize: "1x1",
            supportedSizes: [],
            defaultShape: "Rounded",
            supportsOuterShape: false
        },
        "customText": {
            label: qsTr("Text"),
            icon: "title",
            defaultSize: "1x1",
            supportedSizes: [],
            defaultShape: "Rounded",
            supportsOuterShape: true
        }
    })

    function normalizeType(type: string): string {
        if (type === "pomodoro")
            return "timers";
        return type || "";
    }

    function metaFor(type: string): var {
        const key = normalizeType(type);
        return widgetMeta[key] ?? {
            label: key,
            icon: "widgets",
            defaultSize: "1x1",
            supportedSizes: ["1x1"],
            defaultShape: "Rounded",
            supportsOuterShape: false
        };
    }

    function supportedSizesFor(type: string): var {
        return metaFor(type).supportedSizes;
    }

    function isAspectResizable(type: string): bool {
        const t = normalizeType(type);
        return t === "customImage" || t === "sticker" || t === "customText";
    }

    function isMultiInstance(type: string): bool {
        const t = normalizeType(type);
        return t === "resources" || t === "countdown" || t === "customImage" || t === "sticker" || t === "customText";
    }

    function defaultSizeFor(type: string): string {
        return metaFor(type).defaultSize;
    }

    function keyForShapeEnum(shapeEnum: int): string {
        const keys = Object.keys(shapeEnumMap);
        for (let i = 0; i < keys.length; i++) {
            const k = keys[i];
            if (k !== "Default" && k !== "Rounded" && shapeEnumMap[k] === shapeEnum)
                return k;
        }
        return "Cookie9Sided";
    }

    function defaultShapeFor(type: string): string {
        const key = normalizeType(type);
        if (key === "usercard")
            return keyForShapeEnum(GlobalConfig.dashboard.profilePicShape);
        return metaFor(key).defaultShape;
    }

    function supportsOuterShape(type: string): bool {
        return !!metaFor(type).supportsOuterShape;
    }

    function resolveShapeEnum(shapeKey: string, fallbackKey: string): int {
        const k = (shapeKey && shapeKey !== "" && shapeKey !== "Default") ? shapeKey : fallbackKey;
        if (!k || k === "Rounded" || shapeEnumMap[k] === undefined)
            return -1;
        return shapeEnumMap[k];
    }

    function effectiveShapeKey(type: string, sizeMode: string, optionShape: string): string {
        const key = normalizeType(type);
        if (!supportsOuterShape(key))
            return "Rounded";
        const s = optionShape ?? "";
        if (s === "Rounded")
            return "Rounded";
        // Expressive MaterialShape frames apply to 1x1 hero tiles and freeform Image/Text items.
        // Multi-cell cards stay crisp native Caelestia rounded rectangles.
        if (sizeMode === "1x1" || isAspectResizable(key)) {
            if (s !== "" && s !== "Default" && shapeEnumMap[s] !== undefined)
                return s;
            return defaultShapeFor(key);
        }
        return "Rounded";
    }

    function rowsForMode(sizeMode: string): int {
        const parts = (sizeMode || "1x1").split("x");
        const r = parseInt(parts[0], 10);
        return isNaN(r) || r < 1 ? 1 : Math.min(2, r);
    }

    function colsForMode(sizeMode: string): int {
        const parts = (sizeMode || "1x1").split("x");
        const c = parseInt(parts[1], 10);
        return isNaN(c) || c < 1 ? 1 : Math.min(3, c);
    }

    function spanPx(cells: int, customScale: real): int {
        const s = customScale > 0 ? customScale : scale;
        if (cells <= 1)
            return Math.round(baseCell * s);
        return Math.round((baseCell * cells + baseGap * (cells - 1)) * s);
    }

    function widthFor(sizeMode: string, customScale: real): int {
        return spanPx(colsForMode(sizeMode), customScale);
    }

    function heightFor(sizeMode: string, widgetType: string, customScale: real): int {
        const s = customScale > 0 ? customScale : scale;
        if (normalizeType(widgetType) === "weatherPill")
            return Math.round(basePillHeight * s);
        return spanPx(rowsForMode(sizeMode), s);
    }

    function insetsFor(sizeMode: string, shapeKey: string, customScale: real): var {
        const s = customScale > 0 ? customScale : scale;
        const isShaped = shapeKey && shapeKey !== "" && shapeKey !== "Rounded" && (shapeEnumMap[shapeKey] ?? -1) >= 0;
        if (isShaped) {
            const steep = shapeKey === "Heart" || shapeKey === "Diamond" || shapeKey === "Gem" || shapeKey === "Pentagon" || shapeKey === "Triangle";
            const mild = shapeKey === "Square" || shapeKey === "Slanted" || shapeKey === "Arch" || shapeKey === "Pill" || shapeKey === "PixelCircle";
            const base = Math.round((steep ? 25 : (mild ? 16 : 21)) * s);
            const bottomExtra = (shapeKey === "Heart") ? Math.round(5 * s) : 0;
            return { top: base, bottom: base + bottomExtra, left: base, right: base };
        }
        const rectPad = sizeMode === "1x1"
            ? Math.round(14 * s)
            : ((sizeMode === "1x2" || sizeMode === "2x1") ? Math.round(16 * s) : Math.round(18 * s));
        return { top: rectPad, bottom: rectPad, left: rectPad, right: rectPad };
    }

    function paddingFor(sizeMode: string, shapeKey: string, customScale: real): int {
        const ins = insetsFor(sizeMode, shapeKey, customScale);
        return ins.left;
    }

    function radiusFor(customScale: real): int {
        const s = customScale > 0 ? customScale : scale;
        return Math.round(28 * Math.max(0.8, Math.min(1.25, s)));
    }

    function nearestSizeMode(widthPx: real, heightPx: real, allowedModes: var, widgetType: string, customScale: real): string {
        if (!allowedModes || allowedModes.length === 0)
            return "1x1";
        let bestMode = allowedModes[0];
        let bestDist = 1e12;
        for (let i = 0; i < allowedModes.length; i++) {
            const m = allowedModes[i];
            const mw = widthFor(m, customScale);
            const mh = heightFor(m, widgetType, customScale);
            const dw = widthPx - mw;
            const dh = heightPx - mh;
            const dist = dw * dw + dh * dh;
            if (dist < bestDist) {
                bestDist = dist;
                bestMode = m;
            }
        }
        return bestMode;
    }

    function formatSizeLabel(sizeMode: string): string {
        return (sizeMode || "1x1").replace("x", "×");
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import "components"
import "lyrics"

Item {
    id: root

    required property ShellScreen screen
    required property Item wallpaper
    required property real absX
    required property real absY
    property bool editUnlocked: false
    property bool popoverOpen: false
    property int customWidth: Config.background.desktopLyrics.width

    property real lyricsScale: Config.background.desktopLyrics.scale
    readonly property string stylePreset: String(Config.background.desktopLyrics.style || "apple")
    readonly property string surfaceStyle: String(Config.background.desktopLyrics.surfaceStyle || "glass")
    readonly property var lyricsOptions: Config.background.desktopLyrics.options || ({})

    readonly property bool weActive: wallpaper?.weSurfaceActive ?? wallpaper?.weSurfaceVisible ?? false
    readonly property bool bgEnabled: Config.background.desktopLyrics.background.enabled
    readonly property bool blurEnabled: bgEnabled && Config.background.desktopLyrics.background.blur && !GameMode.enabled
    readonly property bool invertColors: Config.background.desktopLyrics.invertColors
    readonly property bool useLightSet: Colours.light ? !invertColors : invertColors
    readonly property int alignment: Config.background.desktopLyrics.alignment
    readonly property bool autoHideFullscreen: Config.background.desktopLyrics.autoHideFullscreen
    readonly property bool autoHideTiled: Config.background.desktopLyrics.autoHideTiled

    readonly property bool hasFullscreen: Hypr.monitorFor(screen)?.activeWorkspace?.toplevels?.values.some(t => Boolean(t.lastIpcObject?.mapped && t.lastIpcObject?.fullscreen)) ?? false
    readonly property bool hasTiled: Hypr.monitorFor(screen)?.activeWorkspace?.toplevels?.values.some(t => Boolean(t.lastIpcObject?.mapped) && !t.lastIpcObject?.floating && !t.lastIpcObject?.fullscreen) ?? false
    readonly property bool shouldHide: !editUnlocked && !popoverOpen && ((autoHideFullscreen && hasFullscreen) || (autoHideTiled && hasTiled))

    // --- Options & Presets ---
    readonly property int effectiveLineCount: {
        const raw = Number(lyricsOptions?.lineCount);
        if (raw === 1 || raw === 3 || raw === 5)
            return raw;
        return stylePreset === "minimal" ? 1 : 3;
    }

    readonly property string resolvedFontFamily: {
        const opt = String(lyricsOptions?.fontFamily ?? "body").trim();
        if (opt === "" || opt === "body")
            return GlobalConfig.appearance.font.body.family || "Sans Serif";
        if (opt === "display")
            return GlobalConfig.appearance.font.headline.family || "Sans Serif";
        if (opt === "clock")
            return GlobalConfig.appearance.font.clock || "Rubik";
        if (opt === "mono")
            return GlobalConfig.appearance.font.mono.family || "CaskaydiaCove NF";
        return opt;
    }

    readonly property int resolvedFontWeight: {
        const w = String(lyricsOptions?.fontWeight ?? "bold").toLowerCase();
        switch (w) {
        case "regular":
            return Font.Normal;
        case "medium":
            return Font.Medium;
        case "demibold":
            return Font.DemiBold;
        case "black":
            return Font.Black;
        default:
            return Font.Bold;
        }
    }

    readonly property bool wordLift: Boolean(lyricsOptions?.wordLift ?? true)
    readonly property bool depthBlur: Boolean(lyricsOptions?.depthBlur ?? true)
    readonly property bool fadeEdges: Boolean(lyricsOptions?.fadeEdges ?? true)
    readonly property bool showInstrumentalDots: Boolean(lyricsOptions?.showInstrumentalDots ?? true)
    readonly property bool showBackingVocals: Boolean(lyricsOptions?.showBackingVocals ?? true)
    readonly property bool duetOppositeAlign: Boolean(lyricsOptions?.duetOppositeAlign ?? true)
    readonly property string secondaryTextMode: String(lyricsOptions?.secondaryTextMode ?? "auto")
    readonly property bool lineSyncedSweep: Boolean(lyricsOptions?.lineSyncedSweep ?? false)
    readonly property string verticalAnchor: {
        const raw = String(lyricsOptions?.verticalAnchor ?? "center").toLowerCase();
        if (raw === "top" || raw === "bottom")
            return raw;
        return "center";
    }
    readonly property real focusAnchorRatio: {
        if (effectiveLineCount === 1)
            return 0.5;
        if (verticalAnchor === "top")
            return 0.28;
        if (verticalAnchor === "bottom")
            return 0.72;
        return 0.5;
    }

    readonly property real glowStrength: {
        if (lyricsOptions?.glowStrength !== undefined && lyricsOptions.glowStrength !== null)
            return Math.max(0.0, Math.min(1.0, Number(lyricsOptions.glowStrength)));
        switch (stylePreset) {
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

    // --- Colors ---
    readonly property color safePrimary: useLightSet ? Colours.palette.m3primaryContainer : Colours.palette.m3primary
    readonly property color safeSecondary: useLightSet ? Colours.palette.m3secondaryContainer : Colours.palette.m3secondary
    readonly property color safeTertiary: useLightSet ? Colours.palette.m3tertiaryContainer : Colours.palette.m3tertiary
    readonly property color safeOnSurface: invertColors ? Colours.palette.m3inverseOnSurface : Colours.palette.m3onSurface

    readonly property bool hasCustomActiveColor: String(lyricsOptions?.activeColor ?? "") !== ""
    readonly property color autoActiveColor: (stylePreset === "minimal" || stylePreset === "editorial") ? safeOnSurface : safePrimary
    readonly property color resolvedActiveColor: resolveRoleColor(String(lyricsOptions?.activeColor ?? ""), autoActiveColor)

    readonly property color autoUnsungColor: {
        if (hasCustomActiveColor)
            return Qt.alpha(resolvedActiveColor, stylePreset === "neon" ? 0.44 : 0.40);
        if (stylePreset === "neon")
            return Qt.alpha(safeTertiary, 0.48);
        if (stylePreset === "editorial")
            return Qt.alpha(safeSecondary, 0.48);
        if (stylePreset === "minimal")
            return Qt.alpha(safeOnSurface, 0.40);
        return Qt.alpha(safeOnSurface, 0.45);
    }
    readonly property color autoInactiveColor: {
        if (hasCustomActiveColor)
            return Qt.alpha(resolvedActiveColor, stylePreset === "editorial" ? 0.54 : 0.64);
        if (stylePreset === "editorial")
            return Qt.alpha(safeSecondary, 0.62);
        if (stylePreset === "minimal")
            return Qt.alpha(safeSecondary, 0.66);
        if (stylePreset === "neon")
            return Qt.alpha(safeSecondary, 0.72);
        return Qt.alpha(safeSecondary, 0.76);
    }

    readonly property color resolvedUnsungColor: resolveRoleColor(String(lyricsOptions?.unsungColor ?? ""), autoUnsungColor)
    readonly property color resolvedInactiveColor: resolveRoleColor(String(lyricsOptions?.inactiveColor ?? ""), autoInactiveColor)
    readonly property color resolvedGlowColor: (stylePreset === "minimal" || stylePreset === "editorial") ? safePrimary : resolvedActiveColor

    readonly property real activePointSize: {
        if (stylePreset === "minimal")
            return Tokens.font.title.medium.pointSize * 1.15 * lyricsScale;
        if (stylePreset === "editorial")
            return Tokens.font.headline.small.pointSize * 1.04 * lyricsScale;
        if (stylePreset === "neon")
            return Tokens.font.title.medium.pointSize * 1.32 * lyricsScale;
        return Tokens.font.title.medium.pointSize * 1.28 * lyricsScale;
    }

    readonly property real inactivePointSize: {
        if (stylePreset === "minimal")
            return Tokens.font.body.medium.pointSize * 0.95 * lyricsScale;
        if (stylePreset === "editorial")
            return Tokens.font.body.medium.pointSize * 0.92 * lyricsScale;
        if (stylePreset === "neon")
            return Tokens.font.body.large.pointSize * 0.98 * lyricsScale;
        return Tokens.font.body.large.pointSize * 1.0 * lyricsScale;
    }

    // --- 144 FPS Playback & Preview Timing ---
    property real smoothPosition: 0
    property real previewPosition: 0
    property int _lastScrolledIndex: 0
    property bool _needsSnapScroll: true
    property real _lastRawMprisPos: -1
    property string _lastTrackKey: ""
    property bool _pollingPosition: false

    readonly property real playbackRate: (typeof Players.active?.rate === "number" && isFinite(Players.active.rate)) ? Players.active.rate : 1.0
    readonly property bool showingPreview: popoverOpen && !Lyrics.hasLyrics && !Lyrics.loading
    readonly property bool showingEditPlaceholder: editUnlocked && !popoverOpen && !Lyrics.hasLyrics && !Lyrics.loading
    readonly property bool shouldDisplay: (hasDisplayContent || Lyrics.loading || showingEditPlaceholder) && !shouldHide
    readonly property real effectiveTime: showingPreview ? previewPosition : (smoothPosition - Lyrics.offset)

    readonly property var sampleRichLines: [
        {
            time: 0.0,
            endTime: 3.3,
            text: "Feel the rhythm moving through the night",
            isWordSynced: true,
            oppositeTurn: false,
            bgText: "",
            bgGroups: [],
            translation: "",
            romanization: "",
            agent: "v1",
            groups: [
                { text: "Feel", start: 0.15, end: 0.60, trailingSpace: true, syllables: [{ text: "Feel", start: 0.15, end: 0.60 }] },
                { text: "the", start: 0.60, end: 0.90, trailingSpace: true, syllables: [{ text: "the", start: 0.60, end: 0.90 }] },
                { text: "rhythm", start: 0.90, end: 1.55, trailingSpace: true, syllables: [{ text: "rhy", start: 0.90, end: 1.20 }, { text: "thm", start: 1.20, end: 1.55 }] },
                { text: "moving", start: 1.55, end: 2.35, trailingSpace: true, syllables: [{ text: "mov", start: 1.55, end: 1.85 }, { text: "ing", start: 1.85, end: 2.35 }] },
                { text: "through", start: 2.35, end: 2.75, trailingSpace: true, syllables: [{ text: "through", start: 2.35, end: 2.75 }] },
                { text: "the", start: 2.75, end: 2.95, trailingSpace: true, syllables: [{ text: "the", start: 2.75, end: 2.95 }] },
                { text: "night", start: 2.95, end: 3.25, trailingSpace: false, syllables: [{ text: "night", start: 2.95, end: 3.25 }] }
            ]
        },
        {
            time: 3.3,
            endTime: 6.7,
            text: "Every shadow starts to glow so bright",
            isWordSynced: true,
            oppositeTurn: false,
            bgText: "into the light",
            translation: "",
            romanization: "",
            agent: "v1",
            groups: [
                { text: "Every", start: 3.40, end: 3.85, trailingSpace: true, syllables: [{ text: "Ev", start: 3.40, end: 3.60 }, { text: "ery", start: 3.60, end: 3.85 }] },
                { text: "shadow", start: 3.85, end: 4.40, trailingSpace: true, syllables: [{ text: "sha", start: 3.85, end: 4.10 }, { text: "dow", start: 4.10, end: 4.40 }] },
                { text: "starts", start: 4.40, end: 4.80, trailingSpace: true, syllables: [{ text: "starts", start: 4.40, end: 4.80 }] },
                { text: "to", start: 4.80, end: 5.00, trailingSpace: true, syllables: [{ text: "to", start: 4.80, end: 5.00 }] },
                { text: "glow", start: 5.00, end: 5.45, trailingSpace: true, syllables: [{ text: "glow", start: 5.00, end: 5.45 }] },
                { text: "so", start: 5.45, end: 5.70, trailingSpace: true, syllables: [{ text: "so", start: 5.45, end: 5.70 }] },
                { text: "bright", start: 5.70, end: 6.20, trailingSpace: false, syllables: [{ text: "bright", start: 5.70, end: 6.20 }] }
            ],
            bgGroups: [
                { text: "into", start: 5.50, end: 5.85, trailingSpace: true, syllables: [{ text: "in", start: 5.50, end: 5.68 }, { text: "to", start: 5.68, end: 5.85 }] },
                { text: "the", start: 5.85, end: 6.10, trailingSpace: true, syllables: [{ text: "the", start: 5.85, end: 6.10 }] },
                { text: "light", start: 6.10, end: 6.60, trailingSpace: false, syllables: [{ text: "light", start: 6.10, end: 6.60 }] }
            ]
        },
        {
            time: 6.7,
            endTime: 9.95,
            text: "Dancing weightless in the neon skies",
            isWordSynced: true,
            oppositeTurn: true,
            bgText: "",
            bgGroups: [],
            translation: "",
            romanization: "",
            agent: "v2",
            groups: [
                { text: "Dancing", start: 6.85, end: 7.45, trailingSpace: true, syllables: [{ text: "Dan", start: 6.85, end: 7.12 }, { text: "cing", start: 7.12, end: 7.45 }] },
                { text: "weightless", start: 7.45, end: 8.15, trailingSpace: true, syllables: [{ text: "weight", start: 7.45, end: 7.80 }, { text: "less", start: 7.80, end: 8.15 }] },
                { text: "in", start: 8.15, end: 8.40, trailingSpace: true, syllables: [{ text: "in", start: 8.15, end: 8.40 }] },
                { text: "the", start: 8.40, end: 8.65, trailingSpace: true, syllables: [{ text: "the", start: 8.40, end: 8.65 }] },
                { text: "neon", start: 8.65, end: 9.25, trailingSpace: true, syllables: [{ text: "ne", start: 8.65, end: 8.92 }, { text: "on", start: 8.92, end: 9.25 }] },
                { text: "skies", start: 9.25, end: 9.85, trailingSpace: false, syllables: [{ text: "skies", start: 9.25, end: 9.85 }] }
            ]
        }
    ]

    readonly property var sourceLines: showingPreview ? sampleRichLines : (Lyrics.hasLyrics ? Lyrics.richLines : [])
    readonly property var displayLines: buildDisplayLines(sourceLines, showInstrumentalDots)
    readonly property bool hasDisplayContent: displayLines.length > 0
    readonly property int activeDisplayIndex: findIndexForTime(displayLines, effectiveTime)

    readonly property int padH: Math.round((bgEnabled ? 28 : 26) * lyricsScale)
    readonly property int padV: Math.round((bgEnabled ? 16 : 12) * lyricsScale)

    function resolveRoleColor(key: string, fallback: color): color {
        switch (key) {
        case "primary":
            return Colours.palette.m3primary;
        case "secondary":
            return Colours.palette.m3secondary;
        case "tertiary":
            return Colours.palette.m3tertiary;
        case "onSurface":
            return Colours.palette.m3onSurface;
        case "inverseSurface":
            return Colours.palette.m3inverseSurface;
        case "primaryContainer":
            return Colours.palette.m3primaryContainer;
        case "secondaryContainer":
            return Colours.palette.m3secondaryContainer;
        case "tertiaryContainer":
            return Colours.palette.m3tertiaryContainer;
        default:
            return fallback;
        }
    }

    function buildDisplayLines(rich: var, includeDots: bool): var {
        const out = [];
        if (!rich || rich.length === 0)
            return out;

        const firstItem = rich[0];
        const firstStart = (Boolean(firstItem?.isWordSynced) && (firstItem?.groups?.length ?? 0) > 0 && Number(firstItem.groups[0]?.start) > 0)
            ? Number(firstItem.groups[0].start)
            : Number(firstItem?.time ?? 0);
        if (includeDots && firstStart >= 3.5) {
            out.push({
                isInstrumental: true,
                time: 0.0,
                endTime: Math.max(0.1, firstStart - 0.15),
                text: "",
                bgText: "",
                groups: [],
                bgGroups: [],
                isWordSynced: false,
                translation: "",
                romanization: "",
                agent: "",
                oppositeTurn: false
            });
        }

        let prevLineStart = -1;
        for (let i = 0; i < rich.length; i++) {
            const cur = rich[i];
            const nxt = i + 1 < rich.length ? rich[i + 1] : null;
            const curText = String(cur?.text ?? "").trim();
            const curBg = String(cur?.bgText ?? "").trim();
            const curTime = Number(cur?.time ?? 0);
            const curEnd = Number(cur?.endTime ?? curTime);
            const nxtStart = nxt
                ? ((Boolean(nxt?.isWordSynced) && (nxt?.groups?.length ?? 0) > 0 && Number(nxt.groups[0]?.start) > 0)
                    ? Number(nxt.groups[0].start)
                    : Number(nxt.time ?? 0))
                : 0;

            if (curText === "" && curBg === "") {
                if (includeDots && nxt) {
                    const gapEnd = Math.max(curTime + 0.1, nxtStart - 0.15);
                    if (gapEnd - curTime >= 3.35) {
                        out.push({
                            isInstrumental: true,
                            time: curTime,
                            endTime: gapEnd,
                            text: "",
                            bgText: "",
                            groups: [],
                            bgGroups: [],
                            isWordSynced: false,
                            translation: "",
                            romanization: "",
                            agent: "",
                            oppositeTurn: false
                        });
                    }
                }
                continue;
            }

            const isWord = Boolean(cur?.isWordSynced ?? false) && (cur?.groups?.length ?? 0) > 0;
            const firstWordStart = isWord ? Number(cur.groups[0]?.start ?? curTime) : curTime;
            const lastWordEnd = isWord ? Number(cur.groups[cur.groups.length - 1]?.end ?? curEnd) : curEnd;
            let effStart = (isWord && isFinite(firstWordStart) && firstWordStart > 0) ? firstWordStart : curTime;
            if (prevLineStart >= 0 && effStart < prevLineStart)
                effStart = prevLineStart;
            prevLineStart = effStart;
            const effEnd = Math.max(curEnd, isFinite(lastWordEnd) ? lastWordEnd : curEnd);

            out.push({
                isInstrumental: false,
                time: effStart,
                endTime: effEnd,
                text: String(cur?.text ?? ""),
                bgText: String(cur?.bgText ?? ""),
                groups: cur?.groups ?? [],
                bgGroups: cur?.bgGroups ?? [],
                isWordSynced: Boolean(cur?.isWordSynced ?? false),
                translation: String(cur?.translation ?? ""),
                romanization: String(cur?.romanization ?? ""),
                agent: String(cur?.agent ?? ""),
                oppositeTurn: Boolean(cur?.oppositeTurn ?? false)
            });

            if (includeDots && nxt) {
                if (effEnd > effStart && nxtStart > effEnd) {
                    const gapStart = effEnd + 0.15;
                    const gapEnd = nxtStart - 0.15;
                    if (gapEnd - gapStart >= 3.5) {
                        out.push({
                            isInstrumental: true,
                            time: gapStart,
                            endTime: gapEnd,
                            text: "",
                            bgText: "",
                            groups: [],
                            bgGroups: [],
                            isWordSynced: false,
                            translation: "",
                            romanization: "",
                            agent: "",
                            oppositeTurn: false
                        });
                    }
                }
            }
        }
        return out;
    }

    function findIndexForTime(lines: var, t: real): int {
        if (!lines || lines.length === 0)
            return -1;
        const target = t + 0.02;
        let lo = 0;
        let hi = lines.length;
        while (lo < hi) {
            const mid = (lo + hi) >> 1;
            if (Number(lines[mid].time ?? 0) <= target)
                lo = mid + 1;
            else
                hi = mid;
        }
        return lo - 1;
    }

    function reloadTrack(): void {
        const p = Players.active;
        if (p) {
            const trackKey = `${p.trackArtist ?? ""}\0${p.trackTitle ?? ""}`;
            const safeLen = (typeof p.length === "number" && isFinite(p.length) && p.length >= 5) ? p.length : 0;
            Lyrics.setTrack(p.trackArtist, p.trackTitle, p.trackAlbum, safeLen);
            const pos = Number(p.position ?? 0);
            if (isFinite(pos) && (trackKey !== root._lastTrackKey || Math.abs(pos - root.smoothPosition) > 1.2)) {
                root._lastRawMprisPos = -1;
                root.smoothPosition = pos;
            }
            root._lastTrackKey = trackKey;
        } else {
            Lyrics.clearTrack();
            root.smoothPosition = 0;
            root._lastRawMprisPos = -1;
            root._lastTrackKey = "";
        }
    }

    function syncFromPlayer(allowStaleSnap: bool): void {
        if (root.showingPreview)
            return;
        const p = Players.active;
        if (!p)
            return;
        const rawPos = Number(p.position ?? 0);
        if (!isFinite(rawPos))
            return;
        if (!p.isPlaying || GameMode.enabled) {
            root._lastRawMprisPos = rawPos;
            root.smoothPosition = rawPos;
            return;
        }
        const rawChanged = root._lastRawMprisPos < 0 || Math.abs(rawPos - root._lastRawMprisPos) > 0.005;
        const drift = rawPos - root.smoothPosition;
        if (!rawChanged && !allowStaleSnap) {
            // Player hasn't pushed a new MPRIS position yet; avoid pulling smoothPosition backwards unless genuinely stalled.
            if (Math.abs(drift) > 2.0)
                root.smoothPosition = rawPos;
            return;
        }
        root._lastRawMprisPos = rawPos;
        if (Math.abs(drift) > 1.2)
            root.smoothPosition = rawPos;
        else if (drift < -0.15 && drift > -0.65)
            root.smoothPosition += drift * 0.12;
        else
            root.smoothPosition += drift * 0.25;
    }

    function computeTargetContentY(idx: int): real {
        if (!lyricsFlick || lineRepeater.count <= 0 || lyricsFlick.height <= 0 || lyricsFlick.contentHeight <= 0)
            return 0;
        const clampedIdx = Math.max(0, Math.min(lineRepeater.count - 1, idx));
        const slot = lineRepeater.itemAt(clampedIdx);
        if (!slot)
            return 0;
        const anchorPx = lyricsFlick.height * root.focusAnchorRatio;
        const rawY = slot.y + slot.height * 0.5 - anchorPx;
        const maxY = Math.max(0, lyricsFlick.contentHeight - lyricsFlick.height);
        return Math.max(0, Math.min(maxY, rawY));
    }

    function updateScrollPosition(): void {
        if (!lyricsFlick || lineRepeater.count <= 0 || lyricsFlick.height <= 0)
            return;

        const targetIdx = Math.max(0, Math.min(lineRepeater.count - 1, root.activeDisplayIndex));
        const desiredY = computeTargetContentY(targetIdx);
        const snapNow = GameMode.enabled || root._needsSnapScroll || Math.abs(targetIdx - root._lastScrolledIndex) > 4;

        if (snapNow) {
            if (scrollAnim.running)
                scrollAnim.stop();
            lyricsFlick.contentY = desiredY;
            root._needsSnapScroll = false;
        } else if (Math.abs(lyricsFlick.contentY - desiredY) <= 0.5) {
            if (scrollAnim.running)
                scrollAnim.stop();
            lyricsFlick.contentY = desiredY;
        } else if (!scrollAnim.running || Math.abs(scrollAnim.to - desiredY) > 0.5) {
            scrollAnim.stop();
            scrollAnim.from = lyricsFlick.contentY;
            scrollAnim.to = desiredY;
            scrollAnim.start();
        }
        root._lastScrolledIndex = targetIdx;
    }

    function scheduleSnapScroll(): void {
        _needsSnapScroll = true;
        Qt.callLater(() => {
            linesCol.forceLayout();
            root.updateScrollPosition();
        });
    }

    onDisplayLinesChanged: scheduleSnapScroll()

    onStylePresetChanged: scheduleSnapScroll()

    onResolvedFontFamilyChanged: scheduleSnapScroll()

    onResolvedFontWeightChanged: scheduleSnapScroll()

    onLyricsScaleChanged: scheduleSnapScroll()

    onEffectiveLineCountChanged: scheduleSnapScroll()

    onFocusAnchorRatioChanged: Qt.callLater(() => {
        linesCol.forceLayout();
        root.updateScrollPosition();
    })

    onActiveDisplayIndexChanged: {
        if (lineRepeater.count > 0)
            root.updateScrollPosition();
    }

    onVisibleChanged: {
        if (visible && !showingPreview) {
            const p = Players.active;
            if (p) {
                root._pollingPosition = true;
                p.positionChanged();
                root._pollingPosition = false;
                root._lastRawMprisPos = -1;
                root.syncFromPlayer(true);
            }
            scheduleSnapScroll();
        }
    }

    Component.onCompleted: {
        root.reloadTrack();
        root.scheduleSnapScroll();
    }

    implicitWidth: Math.max(260, Math.round(customWidth))
    implicitHeight: {
        if (effectiveLineCount === 1) {
            const itemH = lyricsFlick.activeItemH;
            return Math.max(Math.round(80 * lyricsScale), Math.round(itemH + padV * 2 + 20 * lyricsScale));
        }
        if (effectiveLineCount >= 5)
            return Math.round(340 * lyricsScale);
        return Math.round(230 * lyricsScale);
    }
    width: implicitWidth
    height: implicitHeight

    opacity: root.shouldDisplay ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        Anim {}
    }

    Behavior on lyricsScale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Behavior on implicitHeight {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    NumberAnimation {
        id: scrollAnim

        target: lyricsFlick
        property: "contentY"
        duration: Tokens.anim.durations.expressiveDefaultSpatial
        easing: Tokens.anim.emphasizedDecel
    }

    FrameAnimation {
        id: frameClock

        running: root.visible && !root.shouldHide && !GameMode.enabled
            && (root.showingPreview || ((Players.active?.isPlaying ?? false) && Lyrics.hasLyrics))

        onTriggered: {
            const dt = Math.min(0.1, Math.max(0, frameTime));
            if (root.showingPreview) {
                root.previewPosition = (root.previewPosition + dt) % 10.0;
                return;
            }
            if (Players.active?.isPlaying)
                root.smoothPosition += dt * root.playbackRate;
        }
    }

    Timer {
        id: syncTimer

        running: root.visible && !root.shouldHide && !root.showingPreview && Players.active !== null
        interval: Math.max(100, GlobalConfig.dashboard.mediaUpdateInterval)
        triggeredOnStart: true
        repeat: true

        onTriggered: {
            const p = Players.active;
            if (!p)
                return;
            root._pollingPosition = true;
            p.positionChanged();
            root._pollingPosition = false;
            root.syncFromPlayer(false);
        }
    }

    Connections {
        function onActiveChanged(): void {
            root.reloadTrack();
        }

        target: Players
    }

    Connections {
        function onPostTrackChanged(): void {
            root.reloadTrack();
        }
        function onTrackTitleChanged(): void {
            root.reloadTrack();
        }
        function onTrackArtistChanged(): void {
            root.reloadTrack();
        }
        function onIsPlayingChanged(): void {
            const pos = Number(Players.active?.position ?? 0);
            if (isFinite(pos)) {
                root._lastRawMprisPos = -1;
                root.smoothPosition = pos;
            }
        }
        function onPositionChanged(): void {
            if (root.showingPreview || root._pollingPosition)
                return;
            root.syncFromPlayer(false);
        }

        ignoreUnknownSignals: true

        target: Players.active
    }

    Connections {
        function onLyricsChanged(): void {
            const pos = Number(Players.active?.position ?? 0);
            if (isFinite(pos)) {
                root._lastRawMprisPos = -1;
                root.smoothPosition = pos;
            }
            root.scheduleSnapScroll();
        }
        function onOffsetChanged(): void {
            root.scheduleSnapScroll();
        }

        target: Lyrics
    }

    Item {
        id: lyricsContainer

        anchors.fill: parent

        WidgetSurface {
            id: backgroundPlate

            visible: root.bgEnabled
            anchors.fill: parent
            wallpaper: root.wallpaper
            weActive: root.weActive
            surfaceStyle: root.surfaceStyle
            blur: root.blurEnabled
            plateOpacity: Config.background.desktopLyrics.background.opacity
            radius: Tokens.rounding.large * root.lyricsScale
            absX: root.absX
            absY: root.absY
            shadowEnabled: Config.background.desktopLyrics.shadow.enabled
            shadowOpacity: Config.background.desktopLyrics.shadow.opacity
            shadowBlur: Math.max(0.0, Math.min(1.0, Config.background.desktopLyrics.shadow.blur / 2.0))
            shadowVerticalOffset: 0
        }

        Loader {
            id: loadingIndicator

            anchors.centerIn: parent
            asynchronous: true
            active: opacity > 0
            opacity: Lyrics.loading && !Lyrics.hasLyrics ? 1 : 0

            sourceComponent: ColumnLayout {
                spacing: Tokens.spacing.large * root.lyricsScale

                StyledRect {
                    id: loadingCircle

                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: shape.implicitSize + Tokens.padding.medium * 2 * root.lyricsScale
                    implicitHeight: shape.implicitSize + Tokens.padding.medium * 2 * root.lyricsScale
                    color: Colours.palette.m3primaryContainer
                    radius: Tokens.rounding.full

                    LoadingIndicator {
                        id: shape

                        anchors.centerIn: loadingCircle
                        implicitSize: Math.round(Tokens.sizes.dashboard.mediaSectionWidth / 5 * root.lyricsScale)
                        containsIcon: true
                        color: Colours.palette.m3primary
                    }
                }

                StyledText {
                    text: qsTr("Loading lyrics...")
                    color: root.safeSecondary
                    font.pointSize: Tokens.font.title.medium.pointSize * root.lyricsScale
                    font.family: Tokens.font.title.medium.family
                    font.weight: Tokens.font.title.medium.weight
                }
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        Loader {
            id: editPlaceholder

            anchors.centerIn: parent
            asynchronous: true
            active: root.showingEditPlaceholder
            visible: active

            sourceComponent: StyledRect {
                implicitWidth: Math.min(root.width - root.padH * 2, placeholderRow.implicitWidth + Tokens.padding.large * 2)
                implicitHeight: placeholderRow.implicitHeight + Tokens.padding.medium * 2
                radius: Tokens.rounding.large
                color: WidgetMetrics.innerSurface
                border.width: 1
                border.color: Colours.palette.m3outlineVariant

                RowLayout {
                    id: placeholderRow

                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "lyrics"
                        fontStyle: Tokens.font.icon.small
                        color: Colours.palette.m3primary
                    }

                    StyledText {
                        text: qsTr("Desktop Lyrics · Right-click to customize")
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSurface
                    }
                }
            }
        }

        Item {
            id: fadeContainer

            anchors.fill: parent
            clip: true
            opacity: root.hasDisplayContent ? 1 : 0

            layer.enabled: root.fadeEdges && root.visible && !root.shouldHide && root.hasDisplayContent && !GameMode.enabled && width > 0 && height > 0
            layer.effect: Mask {
                maskSource: fadeMask
            }

            Behavior on opacity {
                Anim {
                    type: Anim.SlowEffects
                }
            }

            Rectangle {
                id: fadeMask

                layer.enabled: fadeContainer.layer.enabled
                visible: false
                width: fadeContainer.width
                height: fadeContainer.height

                gradient: Gradient {
                    orientation: Gradient.Vertical

                    GradientStop {
                        color: Qt.alpha("black", 0)
                        position: 0.0
                    }
                    GradientStop {
                        color: Qt.alpha("black", 1)
                        position: root.effectiveLineCount === 1
                            ? 0.14
                            : (root.verticalAnchor === "top" ? 0.08 : (root.effectiveLineCount >= 5 ? 0.15 : 0.20))
                    }
                    GradientStop {
                        color: Qt.alpha("black", 1)
                        position: root.effectiveLineCount === 1
                            ? 0.86
                            : (root.verticalAnchor === "bottom" ? 0.92 : (root.effectiveLineCount >= 5 ? 0.85 : 0.80))
                    }
                    GradientStop {
                        color: Qt.alpha("black", 0)
                        position: 1.0
                    }
                }
            }

            Flickable {
                id: lyricsFlick

                readonly property Item activeSlot: (root.activeDisplayIndex >= 0 && root.activeDisplayIndex < lineRepeater.count)
                    ? lineRepeater.itemAt(root.activeDisplayIndex)
                    : (lineRepeater.count > 0 ? lineRepeater.itemAt(0) : null)
                readonly property real activeItemH: activeSlot ? activeSlot.height : Math.round(38 * root.lyricsScale)

                anchors.fill: parent
                anchors.leftMargin: root.padH
                anchors.rightMargin: root.padH
                anchors.topMargin: root.padV
                anchors.bottomMargin: root.padV

                interactive: false
                clip: false
                contentWidth: width
                contentHeight: linesCol.height

                onWidthChanged: root.scheduleSnapScroll()
                onHeightChanged: {
                    if (root.effectiveLineCount === 1 && !root._needsSnapScroll)
                        Qt.callLater(() => {
                            linesCol.forceLayout();
                            root.updateScrollPosition();
                        });
                    else
                        root.scheduleSnapScroll();
                }

                Column {
                    id: linesCol

                    width: lyricsFlick.width
                    spacing: Math.round((root.stylePreset === "editorial" ? 12 : 8) * root.lyricsScale)
                    onHeightChanged: Qt.callLater(root.updateScrollPosition)

                    Item {
                        width: linesCol.width
                        height: Math.max(0, Math.round(lyricsFlick.height * root.focusAnchorRatio))
                    }

                    Repeater {
                        id: lineRepeater

                        model: root.displayLines

                        delegate: Item {
                            id: lineSlot

                            required property var modelData
                            required property int index

                            readonly property bool isInst: Boolean(modelData?.isInstrumental ?? false)
                            readonly property int dist: index - root.activeDisplayIndex
                            readonly property int maxVisibleDist: root.effectiveLineCount >= 5 ? 2 : 1
                            readonly property bool inRenderWindow: Math.abs(dist) <= (root.effectiveLineCount >= 5 ? 5 : 4)
                            readonly property bool visibleInSlot: {
                                if (root.effectiveLineCount === 1)
                                    return index === Math.max(0, root.activeDisplayIndex);
                                if (!root.fadeEdges && Math.abs(dist) > maxVisibleDist)
                                    return false;
                                return true;
                            }

                            width: linesCol.width
                            implicitHeight: Math.max(1, isInst ? dotsLoader.implicitHeight : lineLoader.implicitHeight)
                            height: implicitHeight
                            opacity: visibleInSlot
                                ? (root.effectiveLineCount === 1 && root.activeDisplayIndex < 0 ? 0.60 : 1.0)
                                : 0.0

                            Behavior on opacity {
                                enabled: !GameMode.enabled

                                NumberAnimation {
                                    duration: Tokens.anim.durations.expressiveDefaultEffects
                                    easing: Tokens.anim.emphasizedDecel
                                }
                            }

                            Loader {
                                id: lineLoader

                                width: lineSlot.width
                                active: !lineSlot.isInst
                                visible: active && lineSlot.inRenderWindow

                                sourceComponent: KaraokeLine {
                                    width: lineSlot.width
                                    maxWidth: lineSlot.width
                                    lineData: lineSlot.modelData
                                    currentTime: root.effectiveTime
                                    distance: lineSlot.dist
                                    stylePreset: root.stylePreset
                                    alignment: root.alignment
                                    duetOppositeAlign: root.duetOppositeAlign
                                    fontFamily: root.resolvedFontFamily
                                    activePointSize: root.activePointSize
                                    inactivePointSize: root.inactivePointSize
                                    fontWeight: root.resolvedFontWeight
                                    activeColor: root.resolvedActiveColor
                                    unsungColor: root.resolvedUnsungColor
                                    inactiveColor: root.resolvedInactiveColor
                                    glowColor: root.resolvedGlowColor
                                    glowStrength: root.glowStrength
                                    wordLift: root.wordLift
                                    depthBlur: root.depthBlur
                                    showBackingVocals: root.showBackingVocals
                                    secondaryTextMode: root.secondaryTextMode
                                    lineSyncedSweep: root.lineSyncedSweep
                                    weActive: root.weActive
                                    lyricsScale: root.lyricsScale
                                    textShadowEnabled: !root.bgEnabled && Config.background.desktopLyrics.shadow.enabled
                                    textShadowOpacity: Config.background.desktopLyrics.shadow.opacity
                                    textShadowBlur: Math.max(0.0, Math.min(1.0, Config.background.desktopLyrics.shadow.blur / 2.0))
                                    inRenderWindow: lineSlot.inRenderWindow
                                }
                            }

                            Loader {
                                id: dotsLoader

                                width: lineSlot.width
                                active: lineSlot.isInst
                                visible: active && lineSlot.inRenderWindow

                                sourceComponent: InstrumentalDots {
                                    readonly property real gStart: Number(lineSlot.modelData?.time ?? 0)
                                    readonly property real gEnd: Number(lineSlot.modelData?.endTime ?? (gStart + 3.5))
                                    readonly property real gDur: Math.max(0.1, gEnd - gStart)

                                    width: lineSlot.width
                                    active: lineSlot.dist === 0
                                    progress: lineSlot.dist < 0 ? 1.0 : (lineSlot.dist > 0 ? 0.0 : Math.max(0.0, Math.min(1.0, (root.effectiveTime - gStart) / gDur)))
                                    alignment: root.alignment
                                    lyricsScale: root.lyricsScale
                                    activeColor: root.resolvedActiveColor
                                    unsungColor: root.resolvedUnsungColor
                                    glowColor: root.resolvedGlowColor
                                    glowStrength: root.glowStrength
                                    textShadowEnabled: !root.bgEnabled && Config.background.desktopLyrics.shadow.enabled
                                    textShadowOpacity: Config.background.desktopLyrics.shadow.opacity
                                    textShadowBlur: Math.max(0.0, Math.min(1.0, Config.background.desktopLyrics.shadow.blur / 2.0))
                                }
                            }
                        }
                    }

                    Item {
                        width: linesCol.width
                        height: Math.max(0, Math.round(lyricsFlick.height * (1.0 - root.focusAnchorRatio)))
                    }
                }
            }
        }
    }
}

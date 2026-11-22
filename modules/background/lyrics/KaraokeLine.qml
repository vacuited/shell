pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    property var lineData: ({})
    property real currentTime: 0
    property int distance: 0
    property string stylePreset: "apple"
    property int alignment: 1
    property bool duetOppositeAlign: true
    property string fontFamily: "Sans Serif"
    property real activePointSize: 18
    property real inactivePointSize: 13
    property int fontWeight: Font.Bold
    property color activeColor: Colours.palette.m3primary
    property color unsungColor: Qt.alpha(Colours.palette.m3onSurface, 0.45)
    property color inactiveColor: Qt.alpha(Colours.palette.m3secondary, 0.7)
    property color glowColor: activeColor
    property real glowStrength: 0.4
    property bool wordLift: true
    property bool depthBlur: true
    property bool showBackingVocals: true
    property string secondaryTextMode: "auto"
    property bool lineSyncedSweep: false
    property bool weActive: false
    property real lyricsScale: 1.0
    property real maxWidth: 440
    property bool textShadowEnabled: false
    property real textShadowOpacity: 0.45
    property real textShadowBlur: 0.5
    property bool inRenderWindow: true

    readonly property bool isActive: distance === 0
    readonly property bool isPast: distance < 0

    readonly property real lineTime: Number(lineData?.time ?? 0)
    readonly property real lineEndTime: Number(lineData?.endTime ?? (lineTime + 3.0))
    readonly property string lineText: String(lineData?.text ?? "").replace(/\u00A0/g, " ")
    readonly property var groups: lineData?.groups ?? []
    readonly property bool isWordSynced: Boolean(lineData?.isWordSynced ?? false) && groups.length > 0

    readonly property string bgText: String(lineData?.bgText ?? "").replace(/\u00A0/g, " ")
    readonly property var bgGroups: lineData?.bgGroups ?? []
    readonly property bool hasBg: showBackingVocals && bgText.trim() !== ""
    readonly property bool bgIsWordSynced: hasBg && bgGroups && bgGroups.length > 0

    readonly property string translationText: String(lineData?.translation ?? "").trim()
    readonly property string romanizationText: String(lineData?.romanization ?? "").trim()
    readonly property string secondaryText: {
        if (secondaryTextMode === "off")
            return "";
        if (secondaryTextMode === "translation")
            return translationText;
        if (secondaryTextMode === "romanization")
            return romanizationText;
        return translationText !== "" ? translationText : romanizationText;
    }

    readonly property bool oppositeTurn: Boolean(lineData?.oppositeTurn ?? false)
    readonly property int effectiveAlignment: {
        if (duetOppositeAlign && oppositeTurn) {
            if (alignment === 2)
                return 0;
            return 2;
        }
        return alignment;
    }
    readonly property int qtHorizontalAlignment: {
        switch (effectiveAlignment) {
        case 0:
            return Text.AlignLeft;
        case 2:
            return Text.AlignRight;
        default:
            return Text.AlignHCenter;
        }
    }

    readonly property real bgPointSize: Math.max(8, activePointSize * 0.68)
    readonly property real subPointSize: Math.max(8, activePointSize * 0.66)

    readonly property real mainGapPx: Math.max(3, wordMetrics.advanceWidth(" "))
    readonly property real bgGapPx: Math.max(2, bgMetrics.advanceWidth(" "))

    readonly property real lineOpacity: {
        if (isActive)
            return 1.0;
        const absDist = Math.abs(distance);
        if (stylePreset === "editorial")
            return absDist === 1 ? (isPast ? 0.42 : 0.56) : Math.max(0.22, 0.46 - 0.12 * (absDist - 1));
        if (stylePreset === "minimal")
            return absDist === 1 ? 0.50 : 0.25;
        return absDist === 1 ? (isPast ? 0.52 : 0.68) : Math.max(0.24, 0.54 - 0.14 * (absDist - 1));
    }

    readonly property real lineSweepProgress: {
        if (isPast)
            return 1.0;
        if (!isActive)
            return 0.0;
        const dur = Math.max(0.2, lineEndTime - lineTime);
        return Math.max(0.0, Math.min(1.0, (currentTime - lineTime) / dur));
    }
    readonly property bool lineShaderActive: !isWordSynced && isActive && lineSyncedSweep && !GameMode.enabled && lineSweepProgress > 0.002 && lineSweepProgress < 0.998

    readonly property var wrappedMainRows: isWordSynced
        ? computeWrappedRows(groups, wordMetrics, mainGapPx, maxWidth, fontFamily, activePointSize, fontWeight)
        : []

    readonly property var wrappedBgRows: bgIsWordSynced
        ? computeWrappedRows(bgGroups, bgMetrics, bgGapPx, maxWidth, fontFamily, bgPointSize, fontWeight)
        : []

    function mixColor(c1: color, c2: color, t: real): color {
        const k = Math.max(0.0, Math.min(1.0, t));
        return Qt.rgba(
            c1.r + (c2.r - c1.r) * k,
            c1.g + (c2.g - c1.g) * k,
            c1.b + (c2.b - c1.b) * k,
            c1.a + (c2.a - c1.a) * k
        );
    }

    function computeWrappedRows(groupList: var, metrics: FontMetrics, gapPx: real, availWidth: real, fam: string, pt: real, wt: int): var {
        // Reference font parameters explicitly so QML re-evaluates wrapping on font changes.
        if (!groupList || groupList.length === 0 || !fam || pt <= 0 || wt < 0 || availWidth <= 0)
            return [];

        const avail = Math.max(60, availWidth - Math.round(10 * root.lyricsScale));
        const rows = [];
        let curRow = [];
        let curWidth = 0;

        for (let i = 0; i < groupList.length; i++) {
            const g = groupList[i];
            const txt = String(g?.text ?? "");
            if (txt === "")
                continue;
            const advW = metrics.advanceWidth(txt);
            const rectW = metrics.boundingRect(txt).width;
            const w = Math.ceil(Math.max(advW, rectW) * 1.05) + 4;
            const gap = Boolean(g?.trailingSpace) ? gapPx : 0;

            if (curRow.length > 0 && curWidth + w > avail) {
                rows.push(curRow);
                curRow = [g];
                curWidth = w + gap;
            } else {
                curRow.push(g);
                curWidth += w + gap;
            }
        }
        if (curRow.length > 0)
            rows.push(curRow);

        return rows;
    }

    implicitWidth: Math.max(1, maxWidth)
    implicitHeight: contentLayer.implicitHeight
    width: implicitWidth
    height: implicitHeight

    FontMetrics {
        id: wordMetrics

        font.family: root.fontFamily
        font.pointSize: root.activePointSize
        font.weight: root.fontWeight
    }

    FontMetrics {
        id: bgMetrics

        font.family: root.fontFamily
        font.pointSize: root.bgPointSize
        font.weight: root.fontWeight
        font.italic: true
    }

    Text {
        id: lineMeasure

        visible: false
        renderType: Text.QtRendering
        text: root.lineText
        font.family: root.fontFamily
        font.pointSize: root.activePointSize
        font.weight: root.fontWeight
    }

    Item {
        id: contentLayer

        property real focusProgress: root.isActive ? 1.0 : 0.0
        property real animatedDepthBlur: (root.depthBlur && root.stylePreset === "apple" && !root.isActive && !root.weActive && !GameMode.enabled)
            ? Math.min(0.42, 0.14 * Math.abs(root.distance))
            : 0.0

        readonly property real inactiveScale1: Math.max(0.74, Math.min(0.92, root.inactivePointSize / Math.max(1, root.activePointSize)))
        readonly property real targetScale: root.isActive ? 1.0 : (Math.abs(root.distance) === 1 ? inactiveScale1 : Math.max(0.68, inactiveScale1 - 0.05))
        readonly property bool hasGlowMode: root.glowStrength > 0.05
        readonly property real targetGlowOpacity: hasGlowMode ? Math.min(0.95, root.glowStrength * (root.stylePreset === "neon" ? 0.90 : 0.65)) : 0.0
        readonly property real targetGlowBlur: hasGlowMode ? Math.min(0.92, 0.34 + root.glowStrength * 0.50) : 0.0
        readonly property real idleShadowOpacity: root.textShadowEnabled ? Math.min(0.65, root.textShadowOpacity * (root.weActive ? 0.25 : 0.65)) : 0.0
        readonly property real idleShadowBlur: root.textShadowEnabled ? Math.max(0.15, Math.min(0.75, root.textShadowBlur * 0.65)) : 0.0
        readonly property real glowBlend: hasGlowMode ? focusProgress : 0.0
        readonly property real effShadowOpacity: idleShadowOpacity * (1.0 - glowBlend) + targetGlowOpacity * glowBlend
        readonly property real effShadowBlur: idleShadowBlur * (1.0 - glowBlend) + targetGlowBlur * glowBlend
        readonly property color effShadowColor: root.mixColor(Colours.palette.m3shadow, root.glowColor, glowBlend)
        readonly property real effShadowOffsetY: Math.round(2 * root.lyricsScale) * (1.0 - glowBlend)
        readonly property color blendedActiveColor: root.mixColor(root.inactiveColor, root.activeColor, focusProgress)
        readonly property color blendedUnsungColor: root.mixColor(root.inactiveColor, root.unsungColor, focusProgress)

        y: GameMode.enabled ? 0 : (root.isActive ? 0 : (root.isPast ? -3 : 4) * root.lyricsScale)
        width: parent.width
        implicitHeight: lineCol.implicitHeight
        height: implicitHeight
        scale: targetScale
        transformOrigin: root.effectiveAlignment === 0 ? Item.Left : (root.effectiveAlignment === 2 ? Item.Right : Item.Center)
        opacity: root.lineOpacity

        layer.enabled: root.inRenderWindow && !GameMode.enabled && width > 0 && height > 0 && (animatedDepthBlur > 0.005 || effShadowOpacity > 0.005)
        layer.smooth: true
        layer.effect: MultiEffect {
            blurEnabled: contentLayer.animatedDepthBlur > 0.005
            blur: contentLayer.animatedDepthBlur
            blurMax: 20

            shadowEnabled: contentLayer.effShadowOpacity > 0.005
            shadowColor: contentLayer.effShadowColor
            shadowOpacity: contentLayer.effShadowOpacity
            shadowBlur: contentLayer.effShadowBlur
            shadowHorizontalOffset: 0
            shadowVerticalOffset: contentLayer.effShadowOffsetY
            autoPaddingEnabled: true
        }

        Behavior on focusProgress {
            enabled: !GameMode.enabled

            NumberAnimation {
                duration: Tokens.anim.durations.expressiveDefaultSpatial
                easing: Tokens.anim.emphasizedDecel
            }
        }

        Behavior on animatedDepthBlur {
            enabled: !GameMode.enabled

            NumberAnimation {
                duration: Tokens.anim.durations.expressiveDefaultSpatial
                easing: Tokens.anim.emphasizedDecel
            }
        }

        Behavior on scale {
            enabled: !GameMode.enabled

            NumberAnimation {
                duration: Tokens.anim.durations.expressiveDefaultSpatial
                easing: Tokens.anim.emphasizedDecel
            }
        }

        Behavior on y {
            enabled: !GameMode.enabled

            NumberAnimation {
                duration: Tokens.anim.durations.expressiveDefaultSpatial
                easing: Tokens.anim.emphasizedDecel
            }
        }

        Behavior on opacity {
            enabled: !GameMode.enabled

            NumberAnimation {
                duration: Tokens.anim.durations.normal
                easing: Tokens.anim.emphasizedDecel
            }
        }

        Column {
            id: lineCol

            width: parent.width
            spacing: Math.round(3 * root.lyricsScale)

            // 1a. Word-synced main lyric rows
            Column {
                id: mainWordCol

                width: parent.width
                spacing: Math.round(2 * root.lyricsScale)
                visible: root.isWordSynced

                Repeater {
                    model: root.wrappedMainRows

                    delegate: Item {
                        id: mainRowSlot

                        required property var modelData

                        width: mainWordCol.width
                        height: mainWordRow.implicitHeight

                        Row {
                            id: mainWordRow

                            readonly property real fitScale: (width > 0 && mainRowSlot.width > 0) ? Math.min(1.0, mainRowSlot.width / width) : 1.0

                            x: {
                                if (root.effectiveAlignment === 0)
                                    return 0;
                                if (root.effectiveAlignment === 2)
                                    return mainRowSlot.width - width;
                                return (mainRowSlot.width - width) / 2;
                            }
                            scale: fitScale
                            transformOrigin: root.effectiveAlignment === 0 ? Item.Left : (root.effectiveAlignment === 2 ? Item.Right : Item.Center)
                            spacing: 0

                            Repeater {
                                model: mainRowSlot.modelData

                                delegate: KaraokeWord {
                                    required property var modelData
                                    required property int index

                                    groupData: modelData
                                    currentTime: root.currentTime
                                    isLineActive: root.isActive
                                    isLinePast: root.isPast
                                    fontFamily: root.fontFamily
                                    fontPointSize: root.activePointSize
                                    fontWeight: root.fontWeight
                                    activeColor: contentLayer.blendedActiveColor
                                    unsungColor: contentLayer.blendedUnsungColor
                                    glowColor: root.glowColor
                                    glowBoost: root.glowStrength
                                    wordLiftEnabled: root.wordLift
                                    lyricsScale: root.lyricsScale
                                    trailingGapPx: index < mainRowSlot.modelData.length - 1 ? root.mainGapPx : 0
                                    isBackground: false
                                }
                            }
                        }
                    }
                }
            }

            // 1b. Line-synced fallback
            Item {
                id: lineFallbackSlot

                width: lineCol.width
                height: lineFallbackText.implicitHeight
                visible: !root.isWordSynced && root.lineText.trim() !== ""

                StyledText {
                    id: lineFallbackText

                    width: Math.min(lineFallbackSlot.width, Math.max(1, Math.ceil(lineMeasure.implicitWidth) + 6))
                    x: {
                        if (root.effectiveAlignment === 0)
                            return 0;
                        if (root.effectiveAlignment === 2)
                            return Math.max(0, lineFallbackSlot.width - width);
                        return (lineFallbackSlot.width - width) / 2;
                    }

                    text: root.lineText
                    renderType: Text.QtRendering
                    wrapMode: Text.WordWrap
                    horizontalAlignment: root.qtHorizontalAlignment
                    font.family: root.fontFamily
                    font.pointSize: root.activePointSize
                    font.weight: root.fontWeight
                    color: {
                        if (root.lineShaderActive)
                            return "white";
                        if (root.lineSyncedSweep && !GameMode.enabled && root.isActive && root.lineSweepProgress < 0.998)
                            return contentLayer.blendedUnsungColor;
                        return contentLayer.blendedActiveColor;
                    }

                    layer.enabled: root.lineShaderActive && lineFallbackText.width > 0 && lineFallbackText.height > 0
                    layer.smooth: true
                    layer.effect: ShaderEffect {
                        property var source: null
                        property real progress: root.lineSweepProgress
                        property real feather: Math.max(0.03, Math.min(0.18, 18.0 / Math.max(40.0, lineFallbackText.width)))
                        property real glowBoost: root.glowStrength * 0.75
                        property color activeColor: contentLayer.blendedActiveColor
                        property color unsungColor: contentLayer.blendedUnsungColor
                        property color glowColor: root.glowColor

                        blending: true
                        fragmentShader: Qt.resolvedUrl("../../../assets/shaders/karaokeword.frag.qsb")
                    }

                    Behavior on color {
                        enabled: false
                    }
                }
            }

            // 2. Backing vocals (word-synced or plain fallback)
            Column {
                id: bgWordCol

                width: lineCol.width
                spacing: Math.round(2 * root.lyricsScale)
                visible: root.bgIsWordSynced

                Repeater {
                    model: root.wrappedBgRows

                    delegate: Item {
                        id: bgRowSlot

                        required property var modelData

                        width: bgWordCol.width
                        height: bgWordRow.implicitHeight

                        Row {
                            id: bgWordRow

                            readonly property real fitScale: (width > 0 && bgRowSlot.width > 0) ? Math.min(1.0, bgRowSlot.width / width) : 1.0

                            x: {
                                if (root.effectiveAlignment === 0)
                                    return 0;
                                if (root.effectiveAlignment === 2)
                                    return bgRowSlot.width - width;
                                return (bgRowSlot.width - width) / 2;
                            }
                            scale: fitScale
                            transformOrigin: root.effectiveAlignment === 0 ? Item.Left : (root.effectiveAlignment === 2 ? Item.Right : Item.Center)
                            spacing: 0

                            Repeater {
                                model: bgRowSlot.modelData

                                delegate: KaraokeWord {
                                    required property var modelData
                                    required property int index

                                    groupData: modelData
                                    currentTime: root.currentTime
                                    isLineActive: root.isActive
                                    isLinePast: root.isPast
                                    fontFamily: root.fontFamily
                                    fontPointSize: root.bgPointSize
                                    fontWeight: root.fontWeight
                                    activeColor: Qt.alpha(contentLayer.blendedActiveColor, 0.85)
                                    unsungColor: Qt.alpha(contentLayer.blendedUnsungColor, 0.74)
                                    glowColor: root.glowColor
                                    glowBoost: root.glowStrength * 0.5
                                    wordLiftEnabled: false
                                    lyricsScale: root.lyricsScale
                                    trailingGapPx: index < bgRowSlot.modelData.length - 1 ? root.bgGapPx : 0
                                    isBackground: true
                                }
                            }
                        }
                    }
                }
            }

            StyledText {
                id: bgFallbackText

                width: lineCol.width
                visible: root.hasBg && !root.bgIsWordSynced
                text: "(" + root.bgText + ")"
                renderType: Text.QtRendering
                wrapMode: Text.WordWrap
                horizontalAlignment: root.qtHorizontalAlignment
                font.family: root.fontFamily
                font.pointSize: root.bgPointSize
                font.weight: root.fontWeight
                font.italic: true
                color: Qt.alpha(contentLayer.blendedActiveColor, 0.80)

                Behavior on color {
                    enabled: false
                }
            }

            // 3. Secondary subtitle (translation or romanization)
            StyledText {
                id: secondarySubText

                width: lineCol.width
                visible: root.secondaryText !== ""
                text: root.secondaryText
                renderType: Text.QtRendering
                wrapMode: Text.WordWrap
                horizontalAlignment: root.qtHorizontalAlignment
                font.family: root.fontFamily
                font.pointSize: root.subPointSize
                font.weight: Font.Normal
                color: Qt.alpha(root.inactiveColor, 0.68 + 0.24 * contentLayer.focusProgress)

                Behavior on color {
                    enabled: false
                }
            }
        }
    }
}

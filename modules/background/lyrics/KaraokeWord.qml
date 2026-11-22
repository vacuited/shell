pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    property var groupData: ({})
    property real currentTime: 0
    property bool isLineActive: false
    property bool isLinePast: false
    property string fontFamily: "Sans Serif"
    property real fontPointSize: 16
    property int fontWeight: Font.Bold
    property color activeColor: Colours.palette.m3primary
    property color unsungColor: Qt.alpha(Colours.palette.m3onSurface, 0.45)
    property color glowColor: activeColor
    property real glowBoost: 0.4
    property bool wordLiftEnabled: true
    property real lyricsScale: 1.0
    property real trailingGapPx: 0
    property bool isBackground: false

    readonly property string wordStr: String(groupData?.text ?? "")
    readonly property real startTime: Number(groupData?.start ?? 0)
    readonly property real endTime: Number(groupData?.end ?? startTime)
    readonly property bool trailingSpace: Boolean(groupData?.trailingSpace ?? false)
    readonly property var syllables: groupData?.syllables ?? []

    readonly property real progress: {
        if (isLinePast)
            return 1.0;
        if (!isLineActive)
            return 0.0;
        if (currentTime <= startTime)
            return 0.0;
        if (currentTime >= endTime)
            return 1.0;

        if (syllables && syllables.length > 1) {
            let totalWeight = 0;
            let doneWeight = 0;
            for (let i = 0; i < syllables.length; i++) {
                const syl = syllables[i];
                const w = Math.max(1, String(syl?.text ?? "").length);
                const sStart = Number(syl?.start ?? startTime);
                const sEnd = Number(syl?.end ?? sStart);
                totalWeight += w;
                if (currentTime >= sEnd) {
                    doneWeight += w;
                } else if (currentTime > sStart) {
                    const sDur = sEnd - sStart;
                    const frac = sDur > 0.001 ? Math.max(0.0, Math.min(1.0, (currentTime - sStart) / sDur)) : 1.0;
                    doneWeight += w * frac;
                }
            }
            return totalWeight > 0 ? Math.max(0.0, Math.min(1.0, doneWeight / totalWeight)) : 0.0;
        }

        const dur = endTime - startTime;
        if (dur <= 0.001)
            return currentTime >= startTime ? 1.0 : 0.0;
        return Math.max(0.0, Math.min(1.0, (currentTime - startTime) / dur));
    }

    readonly property bool isSweeping: isLineActive && !GameMode.enabled && progress > 0.002 && progress < 0.998

    implicitWidth: wordText.implicitWidth + (trailingSpace ? Math.max(0, trailingGapPx - 1) : 0)
    implicitHeight: wordText.implicitHeight
    width: implicitWidth
    height: implicitHeight

    StyledText {
        id: wordText

        x: 0
        y: {
            if (!root.wordLiftEnabled || !root.isLineActive || GameMode.enabled)
                return 0;
            if (root.progress <= 0.002)
                return 0;
            if (root.progress < 0.998)
                return -2.8 * root.lyricsScale;
            return -1.0 * root.lyricsScale;
        }
        scale: (root.wordLiftEnabled && root.isSweeping && !GameMode.enabled) ? 1.032 : 1.0
        transformOrigin: Item.Center

        text: root.wordStr
        renderType: Text.QtRendering
        font.family: root.fontFamily
        font.pointSize: root.fontPointSize
        font.weight: root.fontWeight
        font.italic: root.isBackground
        leftPadding: 1
        rightPadding: root.isBackground ? 3 : 1
        topPadding: 1
        bottomPadding: 1
        color: root.isSweeping ? "white" : (root.progress >= 0.998 ? root.activeColor : root.unsungColor)

        layer.enabled: root.isSweeping && wordText.implicitWidth > 0 && wordText.implicitHeight > 0
        layer.smooth: true
        layer.effect: ShaderEffect {
            property var source: null
            property real progress: root.progress
            property real feather: Math.max(0.06, Math.min(0.24, 14.0 / Math.max(24.0, wordText.implicitWidth)))
            property real glowBoost: root.isBackground ? root.glowBoost * 0.5 : root.glowBoost
            property color activeColor: root.activeColor
            property color unsungColor: root.unsungColor
            property color glowColor: root.glowColor

            blending: true
            fragmentShader: Qt.resolvedUrl("../../../assets/shaders/karaokeword.frag.qsb")
        }

        Behavior on color {
            enabled: false
        }

        Behavior on y {
            enabled: !GameMode.enabled

            NumberAnimation {
                duration: Tokens.anim.durations.expressiveFastSpatial
                easing: Tokens.anim.expressiveDefaultSpatial
            }
        }

        Behavior on scale {
            enabled: !GameMode.enabled

            NumberAnimation {
                duration: Tokens.anim.durations.expressiveFastSpatial
                easing: Tokens.anim.emphasizedDecel
            }
        }
    }
}

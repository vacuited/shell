pragma ComponentBehavior: Bound

import QtQuick
import qs.services

Item {
    id: root

    readonly property real designWidth: 128
    readonly property real designHeight: 128

    property bool lightSurface: Colours.light
    property bool mono: false
    property color monoColour: Colours.palette.m3onSurface
    property color schemeColor: Colours.palette.m3primary

    property color topColour: mono ? monoColour : schemeColor
    property color bottomColour: mono ? monoColour : Colours.palette.m3onSurface

    readonly property bool showDetail: !root.mono && Math.min(width, height) >= 24

    readonly property string voidPath: "M 95.5 34.5 C 77.5 14.5 43.5 13.5 24.2 33.2 C 20.5 37 17.8 41.5 15.8 46.5 C 17.8 44.5 19.8 43.2 21.5 42.8 C 12.5 58.5 13.2 79.5 24.5 95.2 C 22.2 93.2 20.5 90.5 19.2 87.2 C 22.2 95.5 28.5 102.5 37.2 107.2 C 56.2 117.2 81.5 111.2 97.2 93.2 C 82.5 105.5 62.2 107.2 46.2 97.8 C 52.2 99.5 58.2 99.2 63.8 97.2 C 48.8 96.2 37.2 86.8 33.2 73.2 C 36.2 78.5 41.2 82.5 46.8 84.5 C 36.2 76.5 31.5 62.8 34.8 49.2 C 34.8 55.5 37.5 61.2 41.8 65.2 C 36.8 54.5 39.2 41.2 48.5 32.8 C 45.2 36.8 43.8 41.5 44.2 46.2 C 47.8 34.8 58.2 27.2 70.5 26.2 C 79.8 25.5 88.8 28.5 95.5 34.5 Z"
    readonly property string horizonPath: "M 92 33 C 75 17.5 44 16.5 26.5 34.5 C 23.2 38.2 20.8 42.2 19.2 46.8 C 20.8 44.8 22.4 43.8 23.8 43.5 C 15.8 58.5 16.2 78.2 26.8 92.8 C 24.8 90.8 23.2 88.2 22.2 85.2 C 24.5 92.5 30.2 99.2 38.2 103.8 C 55.5 113.5 79.5 108.2 94 92 C 80.5 103.2 61.5 104.8 46.5 95.8 C 51.5 97.2 56.8 97.2 61.5 95.5 C 47.5 94.8 36.2 86.2 31.8 73.5 C 34.5 78.2 38.8 81.8 43.8 83.8 C 33.8 76.2 29.2 63.2 32.2 50.2 C 32.2 55.8 34.5 60.8 38.2 64.5 C 33.5 54.5 35.8 42.2 44.5 34.2 C 41.8 37.8 40.5 41.8 40.8 45.8 C 44.2 35.2 54.2 27.8 66.2 26.8 C 75.5 26 84.8 28.2 92 33 Z"
    readonly property string monoCutoutPath: "M 28.5 48.5 C 27.5 52.8 28.2 57.5 30.8 61.5 C 30.2 68.5 31.2 75.5 33.8 81.8 C 38.2 92.5 47.2 100.2 58.2 103.5 C 45.2 102.2 33.8 94.8 28.2 83.8 C 22.8 72.8 23.2 59.5 28.5 48.5 Z"
    readonly property string veinsPath: "M 31.5 36.5 C 22.8 48.5 19.8 64.5 24.5 79.5 C 29.2 94.2 42.5 104.5 58.5 106.2 C 68.5 107.2 78.5 104.5 86.5 98.5 C 75.2 103.2 62.2 103.5 50.8 98.8 C 54.8 99.5 58.8 99.2 62.5 97.8 C 48.2 96.8 36.2 87.8 30.8 74.8 C 33.5 78.8 37.2 81.8 41.5 83.5 C 31.8 75.8 27.2 62.8 29.5 49.8 C 29.8 54.5 31.5 58.8 34.5 62.2 C 29.8 53.5 30.2 43.5 35.2 35.5 C 33.8 35.8 32.5 36.2 31.5 36.5 Z"
    readonly property string highlightPath: "M 74.5 24.2 C 56.5 19.2 36.8 25.8 26.8 41.2 C 21.2 49.8 19.2 60.2 20.8 70.2 C 21.2 61.5 24.2 52.8 29.8 45.8 C 27.8 50.2 26.8 54.8 27.2 59.5 C 29.5 46.8 38.2 35.5 50.5 30.2 C 46.8 32.8 43.8 36.2 41.8 40.2 C 49.5 30.5 61.8 24.8 74.5 24.2 Z"
    readonly property string p1Path: "M 96 17 Q 97 21.8 101 23 Q 97 24.2 96 29 Q 95 24.2 91 23 Q 95 21.8 96 17 Z"
    readonly property string p2Path: "M 92 77.2 Q 92.84 80.99 96 82 Q 92.84 83.01 92 86.8 Q 91.16 83.01 88 82 Q 91.16 80.99 92 77.2 Z"
    readonly property string p3Path: "M 14 29.8 Q 14.74 33.12 17.5 34 Q 14.74 34.88 14 38.2 Q 13.26 34.88 10.5 34 Q 13.26 33.12 14 29.8 Z"

    function hexRgb(c: color): string {
        const r = Math.round(c.r * 255).toString(16).padStart(2, "0");
        const g = Math.round(c.g * 255).toString(16).padStart(2, "0");
        const b = Math.round(c.b * 255).toString(16).padStart(2, "0");
        return `#${r}${g}${b}`;
    }

    function tuneHorizon(c: color): color {
        const l = Math.max(0.36, Math.min(0.68, c.hslLightness));
        return Qt.hsla(c.hslHue, c.hslSaturation, l, 1.0);
    }

    readonly property string svgSource: {
        if (root.mono) {
            const c = root.hexRgb(root.monoColour);
            const a = root.monoColour.a;
            const aSub = (a * 0.88).toFixed(3);
            const aFull = a.toFixed(3);
            return "data:image/svg+xml;utf8," + encodeURIComponent(
                `<svg xmlns="http://www.w3.org/2000/svg" viewBox="8 12 100 104">` +
                `<path fill="${c}" opacity="${aFull}" fill-rule="evenodd" d="${root.horizonPath} ${root.monoCutoutPath}"/>` +
                `<path fill="${c}" stroke="${c}" stroke-width="1.1" stroke-linejoin="round" opacity="${aFull}" d="${root.p1Path}"/>` +
                `<path fill="${c}" stroke="${c}" stroke-width="1.1" stroke-linejoin="round" opacity="${aSub}" d="${root.p2Path}"/>` +
                `<path fill="${c}" stroke="${c}" stroke-width="1.1" stroke-linejoin="round" opacity="${aSub}" d="${root.p3Path}"/>` +
                `</svg>`
            );
        }

        const base = root.tuneHorizon(root.schemeColor);
        const hTop = root.hexRgb(Qt.lighter(base, 1.18));
        const hMid = root.hexRgb(base);
        const hBot = root.hexRgb(Qt.darker(base, 1.45));

        const vTop = root.hexRgb(Qt.darker(base, 2.15));
        const vMid = root.hexRgb(Qt.darker(base, 2.85));
        const vBot = root.hexRgb(Qt.darker(base, 4.20));

        const hlMid = root.hexRgb(Qt.tint(base, "#E0FFFFFF"));
        const hlBot = root.hexRgb(Qt.tint(base, "#98FFFFFF"));

        const sTop = root.hexRgb(Qt.tint(base, "#68FFFFFF"));
        const sMid = root.hexRgb(Qt.lighter(base, 1.14));
        const sBot = hMid;

        const voidTop = root.hexRgb(Qt.darker(base, 5.5));
        const voidRim = root.hexRgb(Qt.darker(base, 2.4));

        const voidStroke = !root.lightSurface && root.showDetail
            ? `stroke="${voidRim}" stroke-width="0.6" stroke-opacity="0.55"`
            : "";
        const starBoost = !root.showDetail
            ? `stroke="${sMid}" stroke-width="1.3" stroke-linejoin="round"`
            : "";

        return "data:image/svg+xml;utf8," + encodeURIComponent(
            `<svg xmlns="http://www.w3.org/2000/svg" viewBox="8 12 100 104">` +
            `<defs>` +
            `<linearGradient id="voidGrad" gradientUnits="userSpaceOnUse" x1="16" y1="20" x2="96" y2="108">` +
            `<stop offset="0%" stop-color="${voidTop}"/><stop offset="48%" stop-color="#050507"/><stop offset="100%" stop-color="#000000"/>` +
            `</linearGradient>` +
            `<linearGradient id="horizonGrad" gradientUnits="userSpaceOnUse" x1="22" y1="22" x2="90" y2="106">` +
            `<stop offset="0%" stop-color="${hTop}"/><stop offset="48%" stop-color="${hMid}"/><stop offset="100%" stop-color="${hBot}"/>` +
            `</linearGradient>` +
            `<linearGradient id="veinsGrad" gradientUnits="userSpaceOnUse" x1="20" y1="36" x2="86" y2="106">` +
            `<stop offset="0%" stop-color="${vTop}"/><stop offset="54%" stop-color="${vMid}"/><stop offset="100%" stop-color="${vBot}"/>` +
            `</linearGradient>` +
            `<linearGradient id="highlightGrad" gradientUnits="userSpaceOnUse" x1="20" y1="22" x2="74" y2="70">` +
            `<stop offset="0%" stop-color="#FFFFFF"/><stop offset="58%" stop-color="${hlMid}"/><stop offset="100%" stop-color="${hlBot}"/>` +
            `</linearGradient>` +
            `<linearGradient id="starGrad" gradientUnits="userSpaceOnUse" x1="10" y1="16" x2="102" y2="88">` +
            `<stop offset="0%" stop-color="${sTop}"/><stop offset="50%" stop-color="${sMid}"/><stop offset="100%" stop-color="${sBot}"/>` +
            `</linearGradient>` +
            `</defs>` +
            `<path fill="url(#voidGrad)" ${voidStroke} d="${root.voidPath}"/>` +
            `<path fill="url(#horizonGrad)" d="${root.horizonPath}"/>` +
            `<path fill="url(#veinsGrad)" d="${root.veinsPath}"/>` +
            `<path fill="url(#highlightGrad)" d="${root.highlightPath}"/>` +
            `<path fill="url(#starGrad)" ${starBoost} d="${root.p1Path}"/>` +
            `<path fill="url(#starGrad)" ${starBoost} d="${root.p2Path}"/>` +
            `<path fill="url(#starGrad)" ${starBoost} d="${root.p3Path}"/>` +
            `</svg>`
        );
    }

    implicitWidth: designWidth
    implicitHeight: designHeight

    Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        source: root.svgSource
        sourceSize: Qt.size(256, 256)
        smooth: true
        mipmap: true
        asynchronous: false
    }
}

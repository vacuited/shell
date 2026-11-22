pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import "../components"

// Overlapping pixel-style clock with fringe cutout masks and surface style support.
Item {
    id: root

    required property Item wallpaper
    required property real absX
    required property real absY
    property real clockScale: 1.0
    property string surfaceStyle: "glass"
    property bool cardBackground: false
    property var options: ({})

    readonly property bool weActive: wallpaper?.weSurfaceActive ?? wallpaper?.weSurfaceVisible ?? false
    readonly property bool isMaterial: surfaceStyle === "material"
    readonly property bool isBlur: surfaceStyle === "blur"
    readonly property bool isFrosted: surfaceStyle === "frosted"
    readonly property bool isGlass: !isMaterial && !isBlur && !isFrosted

    readonly property string orientationOpt: String(options?.orientation ?? "vertical")
    readonly property string fontOpt: String(options?.font ?? "gsans")
    readonly property string softColorOpt: String(options?.softColor ?? "primary")
    readonly property string boldColorOpt: String(options?.boldColor ?? "inverseSurface")
    readonly property bool showBackground: (options?.showBackground !== undefined)
        ? Boolean(options.showBackground)
        : cardBackground
    readonly property bool showDate: Boolean(options?.showDate ?? false)

    readonly property bool isVertical: orientationOpt === "vertical"
    readonly property bool is12Hour: Units.twelveHourClock
    readonly property bool useTitan: fontOpt === "titan"
    readonly property bool useClockFont: fontOpt === "clock"

    readonly property int digitsWidth: isVertical ? 276 : 420
    readonly property int baseWidth: isVertical ? 276 : (is12Hour ? 496 : 420)
    readonly property int glyphBoxHeight: isVertical ? 252 : 150
    readonly property int baseHeight: (isVertical ? (is12Hour ? 296 : 252) : 150) + (showDate ? (isVertical ? 36 : 34) : 0)
    readonly property int padH: showBackground ? Tokens.padding.largeIncreased : 0
    readonly property int padV: showBackground ? Tokens.padding.large : 0

    readonly property int hour24: Time.hours
    readonly property string hourStr: (is12Hour ? (hour24 % 12 === 0 ? 12 : hour24 % 12) : hour24).toString().padStart(2, "0")
    readonly property string minuteStr: Time.minutes.toString().padStart(2, "0")
    readonly property string meridian: (hour24 >= 12 ? "PM" : "AM")
    readonly property string todayKey: Qt.formatDate(Time.date, "yyyy-MM-dd")
    readonly property date todayDate: FocusLedger.parseLocalDate(todayKey) ?? new Date()
    readonly property string dateString: Qt.formatDate(todayDate, "ddd, MMM d")
    readonly property string glyphTopLeft: hourStr.charAt(0)
    readonly property string glyphTopRight: hourStr.charAt(1)
    readonly property string glyphBottomLeft: minuteStr.charAt(0)
    readonly property string glyphBottomRight: minuteStr.charAt(1)

    readonly property color tintSoft: roleColor(softColorOpt, Colours.palette.m3primary)
    readonly property color tintBold: roleColor(boldColorOpt, Colours.palette.m3inverseSurface)
    readonly property string sansFont: Tokens.font.body.large.family || "GoogleSansFlex"
    readonly property string clockFont: GlobalConfig.appearance.font.clock || sansFont
    readonly property string displayFont: Qt.fontFamilies().includes("Titan One") ? "Titan One" : sansFont

    readonly property real fringeSize: isVertical ? digitsWidth * 0.026 : glyphBoxHeight * 0.03
    readonly property real tileW: isVertical ? digitsWidth * 0.66 : digitsWidth * 0.30
    readonly property real tileH: isVertical ? glyphBoxHeight * 0.66 : glyphBoxHeight * 0.9
    readonly property int glyphSize: Math.round(isVertical ? glyphBoxHeight * 0.66 : glyphBoxHeight * 0.85)
    readonly property real pos0X: 0
    readonly property real pos1X: isVertical ? digitsWidth * 0.30 : digitsWidth * 0.15
    readonly property real pos2X: isVertical ? 0 : digitsWidth * 0.46
    readonly property real pos3X: isVertical ? digitsWidth * 0.30 : digitsWidth * 0.60
    readonly property real pos0Y: isVertical ? glyphBoxHeight * -0.04 : glyphBoxHeight * 0.05
    readonly property real pos1Y: pos0Y
    readonly property real pos2Y: isVertical ? glyphBoxHeight * 0.42 : glyphBoxHeight * 0.05
    readonly property real pos3Y: pos2Y
    readonly property real colonX: pos1X + tileW + (pos2X - (pos1X + tileW)) / 2 - digitsWidth * 0.03
    readonly property real colonDotSize: glyphBoxHeight * 0.2
    readonly property real colonGap: glyphBoxHeight * 0.04

    function roleColor(key: string, fallback: color): color {
        switch (key) {
        case "primary":
            return Colours.palette.m3primary;
        case "primaryContainer":
            return Colours.palette.m3primaryContainer;
        case "secondary":
            return Colours.palette.m3secondary;
        case "secondaryContainer":
            return Colours.palette.m3secondaryContainer;
        case "tertiary":
            return Colours.palette.m3tertiary;
        case "tertiaryContainer":
            return Colours.palette.m3tertiaryContainer;
        case "error":
            return Colours.palette.m3error;
        case "surface":
            return Colours.palette.m3surface;
        case "onSurface":
            return Colours.palette.m3onSurface;
        case "inverseSurface":
            return Colours.palette.m3inverseSurface;
        default:
            return fallback;
        }
    }

    function ringSamples(count: int, radius: real): var {
        const pts = [
            {
                dx: 0,
                dy: 0
            }
        ];
        for (let i = 0; i < count; i++) {
            const a = (i / count) * Math.PI * 2;
            pts.push({
                dx: Math.cos(a) * radius,
                dy: Math.sin(a) * radius
            });
        }
        return pts;
    }

    implicitWidth: Math.round((baseWidth + padH * 2) * clockScale)
    implicitHeight: Math.round((baseHeight + padV * 2) * clockScale)
    width: implicitWidth
    height: implicitHeight

    Loader {
        anchors.fill: parent
        sourceComponent: {
            if (root.showBackground)
                return cardContainer;
            if (root.isMaterial)
                return materialContainer;
            return maskedContainer;
        }
    }

    Component {
        id: materialContainer

        Item {
            anchors.fill: parent
            layer.enabled: Config.background.desktopClock.shadow.enabled && !GameMode.enabled && !root.weActive
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Colours.palette.m3shadow
                shadowOpacity: Config.background.desktopClock.shadow.opacity
                shadowBlur: Config.background.desktopClock.shadow.blur
            }

            GlyphStage {
                transformOrigin: Item.TopLeft
                scale: root.clockScale
            }
        }
    }

    Component {
        id: cardContainer

        Item {
            anchors.fill: parent

            WidgetSurface {
                anchors.fill: parent
                wallpaper: root.wallpaper
                absX: root.absX
                absY: root.absY
                surfaceStyle: root.surfaceStyle
                blur: Config.background.desktopClock.background.blur && !GameMode.enabled
                plateOpacity: Config.background.desktopClock.background.opacity
                radius: Tokens.rounding.extraLarge * root.clockScale
                shadowEnabled: Config.background.desktopClock.shadow.enabled
                shadowOpacity: Config.background.desktopClock.shadow.opacity
                shadowBlur: Config.background.desktopClock.shadow.blur
            }

            Item {
                anchors.centerIn: parent
                width: Math.round(root.baseWidth * root.clockScale)
                height: Math.round(root.baseHeight * root.clockScale)

                GlyphStage {
                    transformOrigin: Item.TopLeft
                    scale: root.clockScale
                }
            }
        }
    }

    Component {
        id: maskedContainer

        Item {
            anchors.fill: parent

            Item {
                id: glyphMask

                anchors.fill: parent
                visible: false
                layer.enabled: true
                layer.smooth: true

                GlyphStage {
                    transformOrigin: Item.TopLeft
                    scale: root.clockScale
                }
            }

            WidgetSurface {
                anchors.fill: parent
                wallpaper: root.wallpaper
                absX: root.absX
                absY: root.absY
                surfaceStyle: root.surfaceStyle
                blur: Config.background.desktopClock.background.blur && !GameMode.enabled
                plateOpacity: Config.background.desktopClock.background.opacity
                shadowEnabled: Config.background.desktopClock.shadow.enabled
                shadowOpacity: Config.background.desktopClock.shadow.opacity
                shadowBlur: Config.background.desktopClock.shadow.blur
                shapeMask: glyphMask
            }

            GlyphStage {
                transformOrigin: Item.TopLeft
                scale: root.clockScale
                opacity: 0.72
            }
        }
    }

    component GlyphStage: Item {
        id: stage

        width: root.baseWidth
        height: root.baseHeight

        Item {
            id: tileAFace

            anchors.fill: parent
            visible: false
            layer.enabled: true

            GlyphTile {
                x: root.pos0X
                y: root.pos0Y
                text: root.glyphTopLeft
                color: root.tintBold
            }
        }

        Item {
            id: tileAPunch

            anchors.fill: parent
            visible: false
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1.0
                blurMax: Math.max(8, Math.round(root.fringeSize * 2.2))
                autoPaddingEnabled: false
            }

            GlyphTile {
                x: root.pos1X
                y: root.pos1Y
                text: root.glyphTopRight
                color: "black"
            }

            GlyphTile {
                x: root.pos2X
                y: root.pos2Y
                text: root.glyphBottomLeft
                color: "black"
            }

            GlyphTile {
                x: root.pos3X
                y: root.pos3Y
                text: root.glyphBottomRight
                color: "black"
            }
        }

        MultiEffect {
            z: 0
            anchors.fill: parent
            source: tileAFace
            maskSource: tileAPunch
            maskEnabled: true
            maskInverted: true
            maskThresholdMin: 0.08
            maskSpreadAtMin: 0.25
        }

        Item {
            id: tileBFace

            anchors.fill: parent
            visible: false
            layer.enabled: true

            GlyphTile {
                x: root.pos1X
                y: root.pos1Y
                text: root.glyphTopRight
                color: root.tintSoft
            }
        }

        Item {
            id: tileBPunch

            anchors.fill: parent
            visible: false
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1.0
                blurMax: Math.max(8, Math.round(root.fringeSize * 2.2))
                autoPaddingEnabled: false
            }

            GlyphTile {
                x: root.pos2X
                y: root.pos2Y
                text: root.glyphBottomLeft
                color: "black"
            }

            GlyphTile {
                x: root.pos3X
                y: root.pos3Y
                text: root.glyphBottomRight
                color: "black"
            }
        }

        MultiEffect {
            z: 1
            anchors.fill: parent
            source: tileBFace
            maskSource: tileBPunch
            maskEnabled: true
            maskInverted: true
            maskThresholdMin: 0.08
            maskSpreadAtMin: 0.25
        }

        Item {
            id: tileCFace

            anchors.fill: parent
            visible: false
            layer.enabled: true

            GlyphTile {
                x: root.pos2X
                y: root.pos2Y
                text: root.glyphBottomLeft
                color: root.tintBold
            }
        }

        Item {
            id: tileCPunch

            anchors.fill: parent
            visible: false
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1.0
                blurMax: Math.max(8, Math.round(root.fringeSize * 2.2))
                autoPaddingEnabled: false
            }

            GlyphTile {
                x: root.pos3X
                y: root.pos3Y
                text: root.glyphBottomRight
                color: "black"
            }
        }

        MultiEffect {
            z: 2
            anchors.fill: parent
            source: tileCFace
            maskSource: tileCPunch
            maskEnabled: true
            maskInverted: true
            maskThresholdMin: 0.08
            maskSpreadAtMin: 0.25
        }

        GlyphTile {
            z: 3
            x: root.pos3X
            y: root.pos3Y
            text: root.glyphBottomRight
            color: root.tintSoft
        }

        Column {
            z: 4
            visible: !root.isVertical
            x: root.colonX
            y: root.pos0Y + root.tileH / 2 - height / 2
            spacing: root.colonGap

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.colonDotSize
                height: root.colonDotSize
                radius: width / 2
                color: root.tintBold
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.colonDotSize
                height: root.colonDotSize
                radius: width / 2
                color: root.tintBold
            }
        }

        Text {
            z: 4
            visible: root.is12Hour
            x: root.isVertical ? root.pos2X + root.tileW * 0.75 : root.pos3X + root.tileW - 4
            y: root.isVertical ? root.glyphBoxHeight - 4 : root.pos3Y + root.tileH - height - root.glyphBoxHeight * 0.08
            text: root.meridian
            color: root.tintSoft
            font.family: root.displayFont
            font.pixelSize: Math.round(root.isVertical ? root.digitsWidth * 0.16 : root.glyphBoxHeight * 0.36)
            renderType: Text.QtRendering
        }

        Text {
            z: 4
            visible: root.showDate
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.baseHeight - height - 2
            text: root.dateString
            color: root.tintSoft
            font.family: root.sansFont
            font.pixelSize: 20
            font.weight: Font.DemiBold
            renderType: Text.QtRendering
        }
    }

    component GlyphTile: Text {
        width: root.tileW
        height: root.tileH
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        renderType: Text.QtRendering
        font.family: root.useTitan ? root.displayFont : (root.useClockFont ? root.clockFont : root.sansFont)
        font.pixelSize: root.glyphSize
        font.bold: root.useClockFont
        font.variableAxes: (root.useTitan || root.useClockFont) ? ({}) : ({
            "wght": 1000
        })
    }
}

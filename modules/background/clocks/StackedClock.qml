pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import "../components"

// Stacked clock widget: day name and ordinal date stacked above large time, optional background card.
Item {
    id: root

    required property Item wallpaper
    required property real absX
    required property real absY
    property real clockScale: 1.0
    property string surfaceStyle: "glass"
    property var options: ({})

    readonly property bool weActive: wallpaper?.weSurfaceActive ?? wallpaper?.weSurfaceVisible ?? false
    readonly property bool isMaterial: surfaceStyle === "material"
    readonly property bool isBlur: surfaceStyle === "blur"
    readonly property bool isFrosted: surfaceStyle === "frosted"
    readonly property bool isGlass: !isMaterial && !isBlur && !isFrosted

    readonly property string alignmentOpt: String(options?.alignment ?? "left")
    readonly property string fontWeightOpt: String(options?.weight ?? options?.fontWeight ?? "medium")
    readonly property string labelWeightOpt: String(options?.labelFontWeight ?? "light")
    readonly property string timeColorOpt: String(options?.timeColor ?? "primary")
    readonly property string labelColorOpt: String(options?.labelColor ?? "onSurface")
    readonly property bool showDate: Boolean(options?.showDate ?? true)
    readonly property bool showBackground: Boolean(options?.showBackground ?? false)
    readonly property int fontSize: Math.max(12, Math.round(Number(options?.fontSize ?? 84) * clockScale))
    readonly property int labelFontSize: Math.max(10, Math.round(Number(options?.labelFontSize ?? 42) * clockScale))
    readonly property int padH: showBackground ? Math.round(Tokens.padding.largeIncreased * clockScale) : 0
    readonly property int padV: showBackground ? Math.round(Tokens.padding.large * clockScale) : 0

    readonly property bool is12Hour: Units.twelveHourClock
    readonly property string displayHours: {
        const h = Time.hours;
        if (!is12Hour)
            return h.toString().padStart(2, "0");
        return (h % 12 || 12).toString().padStart(2, "0");
    }
    readonly property string displayMinutes: Time.minutes.toString().padStart(2, "0")
    readonly property string meridian: Time.amPmStr || (Time.hours >= 12 ? "PM" : "AM")
    readonly property string dayName: Time.format("ddd").toLowerCase()
    readonly property string dayNumber: ordinal(Time.date.getDate())

    readonly property color timeColor: roleColor(timeColorOpt, Colours.palette.m3primary)
    readonly property color labelColor: roleColor(labelColorOpt, Colours.palette.m3onSurface)
    readonly property string sansFont: Tokens.font.body.large.family || "GoogleSansFlex"
    readonly property real contentWidth: dummyContent.implicitWidth
    readonly property real contentHeight: dummyContent.implicitHeight

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

    function weightAxes(weight: string): var {
        if (weight === "light")
            return ({
                "wght": 300,
                "wdth": 100
            });
        if (weight === "regular")
            return ({
                "wght": 400,
                "wdth": 100
            });
        if (weight === "bold")
            return ({
                "wght": 700,
                "wdth": 100
            });
        return ({
            "wght": 500,
            "wdth": 100
        });
    }

    function layoutAlignment(): int {
        if (alignmentOpt === "center")
            return Qt.AlignHCenter;
        if (alignmentOpt === "right")
            return Qt.AlignRight;
        return Qt.AlignLeft;
    }

    function ordinal(n: int): string {
        const s = ["th", "st", "nd", "rd"];
        const v = n % 100;
        return n.toString().padStart(2, "0") + (s[(v - 20) % 10] || s[v] || s[0]);
    }

    implicitWidth: Math.round(contentWidth + padH * 2)
    implicitHeight: Math.round(contentHeight + padV * 2)
    width: implicitWidth
    height: implicitHeight

    ClockContent {
        id: dummyContent

        visible: false
    }

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

            ClockContent {
                anchors.fill: parent
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

            ClockContent {
                anchors.centerIn: parent
                width: root.contentWidth
            }
        }
    }

    Component {
        id: maskedContainer

        Item {
            anchors.fill: parent

            Item {
                id: textMask

                anchors.fill: parent
                visible: false
                layer.enabled: true
                layer.smooth: true

                ClockContent {
                    anchors.centerIn: parent
                    width: root.contentWidth
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
                shapeMask: textMask
            }
        }
    }

    component ClockContent: ColumnLayout {
        id: content

        width: content.implicitWidth
        spacing: 0

        Text {
            visible: root.showDate
            text: root.dayName
            color: root.labelColor
            opacity: 0.8
            renderType: Text.NativeRendering
            font.family: root.sansFont
            font.pixelSize: root.labelFontSize
            font.variableAxes: root.weightAxes(root.labelWeightOpt)
            Layout.alignment: root.layoutAlignment()
            Layout.topMargin: -(root.labelFontSize * 0.22)
        }

        Text {
            visible: root.showDate
            text: root.dayNumber
            color: root.labelColor
            renderType: Text.NativeRendering
            font.family: root.sansFont
            font.pixelSize: root.fontSize
            font.variableAxes: root.weightAxes(root.labelWeightOpt)
            Layout.alignment: root.layoutAlignment()
            Layout.topMargin: -(root.fontSize * 0.2)
        }

        Text {
            text: root.displayHours + ":" + root.displayMinutes
            color: root.timeColor
            renderType: Text.NativeRendering
            font.family: root.sansFont
            font.pixelSize: root.fontSize
            font.variableAxes: root.weightAxes(root.fontWeightOpt)
            Layout.alignment: root.layoutAlignment()
            Layout.topMargin: -(root.fontSize * 0.22)
            Layout.bottomMargin: root.is12Hour ? 0 : -(root.fontSize * 0.15)
        }

        Text {
            visible: root.is12Hour
            text: root.meridian
            color: root.labelColor
            opacity: 0.8
            renderType: Text.NativeRendering
            font.family: root.sansFont
            font.pixelSize: Math.round(root.labelFontSize + 6 * root.clockScale)
            font.variableAxes: root.weightAxes(root.labelWeightOpt)
            Layout.alignment: root.layoutAlignment()
            Layout.topMargin: -(root.labelFontSize * 0.3)
            Layout.bottomMargin: -(root.labelFontSize * 0.15)
        }
    }
}

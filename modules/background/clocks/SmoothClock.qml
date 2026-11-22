pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import "../components"

// Smooth clock widget with rounded typography and optional date and live weather summary.
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

    readonly property bool showDateAndWeather: Boolean(options?.showDateAndWeather ?? true)
    readonly property bool showSeconds: Boolean(options?.showSeconds ?? false)
    readonly property bool showBackground: (options?.showBackground !== undefined)
        ? Boolean(options.showBackground)
        : cardBackground
    readonly property string timeColorOpt: String(options?.timeColor ?? "onSurface")
    readonly property color timeColor: roleColor(timeColorOpt, Colours.palette.m3onSurface)
    readonly property bool hasWeather: Boolean(Weather.cc)
    readonly property string todayKey: Qt.formatDate(Time.date, "yyyy-MM-dd")
    readonly property date todayDate: FocusLedger.parseLocalDate(todayKey) ?? new Date()
    readonly property string timeString: {
        const h24 = Time.hours;
        const m = String(Time.minutes).padStart(2, "0");
        const sec = showSeconds ? (":" + String(Time.seconds).padStart(2, "0")) : "";
        if (Units.twelveHourClock) {
            const h12 = (h24 % 12) || 12;
            const ap = h24 >= 12 ? "PM" : "AM";
            return `${h12}:${m}${sec} ${ap}`;
        }
        return `${String(h24).padStart(2, "0")}:${m}${sec}`;
    }
    readonly property string dateString: Qt.formatDate(todayDate, "ddd, MMM d")
    readonly property string sansFont: Tokens.font.body.large.family || "GoogleSansFlex"

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

    readonly property int padH: showBackground ? Math.round(Tokens.padding.largeIncreased * clockScale) : 0
    readonly property int padV: showBackground ? Math.round(Tokens.padding.large * clockScale) : 0
    readonly property real contentWidth: dummyContent.implicitWidth
    readonly property real contentHeight: dummyContent.implicitHeight

    implicitWidth: Math.round(contentWidth + padH * 2)
    implicitHeight: Math.round(contentHeight + padV * 2)
    width: implicitWidth
    height: implicitHeight

    SmoothContent {
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

            SmoothContent {
                anchors.centerIn: parent
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

            SmoothContent {
                anchors.centerIn: parent
            }
        }
    }

    Component {
        id: maskedContainer

        Item {
            anchors.fill: parent

            Item {
                id: contentMask

                anchors.fill: parent
                visible: false
                layer.enabled: true
                layer.smooth: true

                SmoothContent {
                    anchors.centerIn: parent
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
                shapeMask: contentMask
            }

            SmoothContent {
                anchors.centerIn: parent
                opacity: 0.72
            }
        }
    }

    component SmoothContent: RowLayout {
        spacing: Math.round(18 * root.clockScale)

        Text {
            text: root.timeString
            color: root.timeColor
            renderType: Text.QtRendering
            font.family: root.sansFont
            font.pixelSize: Math.round(96 * root.clockScale)
            font.variableAxes: ({
                "wght": 700,
                "wdth": 100,
                "ROND": 100,
                "opsz": 144
            })
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            visible: root.showDateAndWeather
            spacing: Math.round(4 * root.clockScale)
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: root.dateString
                color: Colours.palette.m3onSurface
                horizontalAlignment: Text.AlignLeft
                renderType: Text.QtRendering
                font.family: root.sansFont
                font.pixelSize: Math.round(22 * root.clockScale)
                font.variableAxes: ({
                    "wght": 600,
                    "wdth": 100,
                    "ROND": 100
                })
                Layout.alignment: Qt.AlignLeft
            }

            RowLayout {
                visible: root.hasWeather
                spacing: Math.round(Tokens.spacing.small * root.clockScale)
                Layout.alignment: Qt.AlignLeft

                MaterialIcon {
                    text: Weather.icon
                    fill: 1
                    color: Colours.palette.m3onSurface
                    fontStyle: Tokens.font.icon.size(Math.round(17 * root.clockScale)).build()
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: Weather.temp
                    color: Colours.palette.m3onSurface
                    renderType: Text.QtRendering
                    font.family: root.sansFont
                    font.pixelSize: Math.round(22 * root.clockScale)
                    font.variableAxes: ({
                        "wght": 600,
                        "wdth": 100,
                        "ROND": 100
                    })
                    Layout.alignment: Qt.AlignVCenter
                }

                Rectangle {
                    visible: Weather.description !== ""
                    radius: Layout.preferredWidth / 2
                    color: Colours.palette.m3onSurface
                    Layout.preferredWidth: Math.max(2, Math.round(6 * root.clockScale))
                    Layout.preferredHeight: Layout.preferredWidth
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    visible: Weather.description !== ""
                    text: Weather.description
                    color: Colours.palette.m3onSurface
                    renderType: Text.QtRendering
                    font.family: root.sansFont
                    font.pixelSize: Math.round(22 * root.clockScale)
                    font.variableAxes: ({
                        "wght": 600,
                        "wdth": 100,
                        "ROND": 100
                    })
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }
}

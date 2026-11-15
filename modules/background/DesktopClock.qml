pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import "components"
import "clocks"

Item {
    id: root

    required property Item wallpaper
    required property real absX
    required property real absY

    property real clockScale: Config.background.desktopClock.scale
    readonly property string clockStyle: Config.background.desktopClock.style || "classic"
    readonly property var clockOptions: Config.background.desktopClock.options || ({})
    readonly property string surfaceStyle: {
        const optStyle = clockOptions?.surfaceStyle ?? clockOptions?.style;
        if (optStyle === "glass" || optStyle === "blur" || optStyle === "frosted" || optStyle === "material")
            return optStyle;
        return Config.background.desktopClock.surfaceStyle || "glass";
    }
    readonly property bool weActive: wallpaper?.weSurfaceActive ?? wallpaper?.weSurfaceVisible ?? false
    readonly property bool bgEnabled: Config.background.desktopClock.background.enabled
    readonly property bool blurEnabled: bgEnabled && Config.background.desktopClock.background.blur && !GameMode.enabled
    readonly property bool invertColors: Config.background.desktopClock.invertColors
    readonly property bool useLightSet: Colours.light ? !invertColors : invertColors
    readonly property color safePrimary: useLightSet ? Colours.palette.m3primaryContainer : Colours.palette.m3primary
    readonly property color safeSecondary: useLightSet ? Colours.palette.m3secondaryContainer : Colours.palette.m3secondary
    readonly property color safeTertiary: useLightSet ? Colours.palette.m3tertiaryContainer : Colours.palette.m3tertiary
    readonly property string clockFont: GlobalConfig.appearance.font.clock || "Sans Serif"
    readonly property string sansFont: GlobalConfig.appearance.font.body.family || "Sans Serif"

    implicitWidth: styleLoader.item ? styleLoader.item.implicitWidth : 0
    implicitHeight: styleLoader.item ? styleLoader.item.implicitHeight : 0

    Loader {
        id: styleLoader

        anchors.fill: parent
        sourceComponent: {
            if (root.clockStyle === "cookie")
                return cookieComponent;
            if (root.clockStyle === "pixel")
                return pixelComponent;
            if (root.clockStyle === "stacked")
                return stackedComponent;
            if (root.clockStyle === "smooth")
                return smoothComponent;
            return classicComponent;
        }
    }

    Component {
        id: cookieComponent

        CookieClock {
            wallpaper: root.wallpaper
            absX: root.absX
            absY: root.absY
            clockScale: root.clockScale
            surfaceStyle: root.surfaceStyle
            options: root.clockOptions
        }
    }

    Component {
        id: pixelComponent

        PixelClock {
            wallpaper: root.wallpaper
            absX: root.absX
            absY: root.absY
            clockScale: root.clockScale
            surfaceStyle: root.surfaceStyle
            options: root.clockOptions
        }
    }

    Component {
        id: stackedComponent

        StackedClock {
            wallpaper: root.wallpaper
            absX: root.absX
            absY: root.absY
            clockScale: root.clockScale
            surfaceStyle: root.surfaceStyle
            options: root.clockOptions
        }
    }

    Component {
        id: smoothComponent

        SmoothClock {
            wallpaper: root.wallpaper
            absX: root.absX
            absY: root.absY
            clockScale: root.clockScale
            surfaceStyle: root.surfaceStyle
            options: root.clockOptions
        }
    }

    Component {
        id: classicComponent

        Item {
            id: classicRoot

            implicitWidth: layout.implicitWidth + (Tokens.padding.large * 4 * root.clockScale)
            implicitHeight: layout.implicitHeight + (Tokens.padding.extraLargeIncreased * root.clockScale)

            WidgetSurface {
                anchors.fill: parent
                visible: root.bgEnabled
                wallpaper: root.wallpaper
                absX: root.absX
                absY: root.absY
                surfaceStyle: root.surfaceStyle
                blur: root.blurEnabled
                plateOpacity: Config.background.desktopClock.background.opacity
                radius: Tokens.rounding.extraLarge * root.clockScale
                shadowEnabled: Config.background.desktopClock.shadow.enabled
                shadowOpacity: Config.background.desktopClock.shadow.opacity
                shadowBlur: Config.background.desktopClock.shadow.blur
            }

            Item {
                id: clockContainer

                anchors.fill: parent
                layer.enabled: !root.bgEnabled && Config.background.desktopClock.shadow.enabled && !GameMode.enabled && !root.weActive
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Colours.palette.m3shadow
                    shadowOpacity: Config.background.desktopClock.shadow.opacity
                    shadowBlur: Config.background.desktopClock.shadow.blur
                }

                RowLayout {
                    id: layout

                    anchors.centerIn: parent
                    spacing: Tokens.spacing.large * root.clockScale

                    RowLayout {
                        spacing: Tokens.spacing.small

                        StyledText {
                            text: Time.hourStr
                            font: Tokens.font.clock.size(Math.round(Tokens.font.headline.medium.pointSize * 3 * root.clockScale)).weight(Font.Bold).family(root.clockFont).build()
                            color: root.safePrimary
                        }

                        StyledText {
                            text: ":"
                            font: Tokens.font.clock.size(Math.round(Tokens.font.headline.medium.pointSize * 3 * root.clockScale)).family(root.clockFont).build()
                            color: root.safeTertiary
                            opacity: 0.8
                            Layout.topMargin: -Tokens.padding.large * 1.5 * root.clockScale
                        }

                        StyledText {
                            text: Time.minuteStr
                            font: Tokens.font.clock.size(Math.round(Tokens.font.headline.medium.pointSize * 3 * root.clockScale)).weight(Font.Bold).family(root.clockFont).build()
                            color: root.safeSecondary
                        }

                        Loader {
                            active: Units.twelveHourClock
                            visible: active
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: Tokens.padding.large * 1.4 * root.clockScale

                            sourceComponent: StyledText {
                                text: Time.amPmStr
                                font: Tokens.font.clock.size(Math.round(Tokens.font.title.medium.pointSize * root.clockScale)).family(root.sansFont).build()
                                color: root.safeSecondary
                            }
                        }
                    }

                    StyledRect {
                        radius: Tokens.rounding.full
                        color: root.safePrimary
                        opacity: 0.8
                        Layout.fillHeight: true
                        Layout.preferredWidth: Math.max(1, Math.round(4 * root.clockScale))
                        Layout.topMargin: Tokens.spacing.large * root.clockScale
                        Layout.bottomMargin: Tokens.spacing.large * root.clockScale
                    }

                    ColumnLayout {
                        spacing: 0

                        StyledText {
                            text: Time.format("MMMM").toUpperCase()
                            font: Tokens.font.clock.size(Math.round(Tokens.font.title.medium.pointSize * root.clockScale)).letterSpacing(4).weight(Font.Bold).family(root.sansFont).build()
                            color: root.safeSecondary
                        }

                        StyledText {
                            text: Time.format("dd")
                            font: Tokens.font.clock.size(Math.round(Tokens.font.headline.medium.pointSize * root.clockScale)).letterSpacing(2).weight(Font.Medium).family(root.sansFont).build()
                            color: root.safePrimary
                        }

                        StyledText {
                            text: Time.format("dddd")
                            font: Tokens.font.clock.size(Math.round(Tokens.font.body.large.pointSize * root.clockScale)).letterSpacing(2).family(root.sansFont).build()
                            color: root.safeSecondary
                        }
                    }
                }
            }
        }
    }

    Behavior on clockScale {
        Anim {}
    }
}

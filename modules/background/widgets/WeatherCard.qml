pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import M3Shapes
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import "../components"

Item {
    id: root

    required property var wallpaper
    property bool weActive: false
    property bool locked: true
    property string sizeMode: "1x1"
    property real widgetScale: WidgetMetrics.scale
    property string surfaceStyle: ""
    property bool blurEnabled: Config.background.desktopWidgets.blur
    property real plateOpacity: Config.background.desktopWidgets.opacity
    property var widgetOptions: ({})

    readonly property real s: Math.max(0.55, Math.min(2.2, widgetScale > 0 ? widgetScale : WidgetMetrics.scale))
    readonly property string effectiveSize: WidgetMetrics.fallbackSizeFor("weather", sizeMode)
    readonly property var todayForecast: (Weather.forecast && Weather.forecast.length > 0) ? Weather.forecast[0] : null
    readonly property real todayHigh: todayForecast?.maxTempC ?? 0
    readonly property real todayLow: todayForecast?.minTempC ?? 0
    readonly property var nextHours: (Weather.hourlyForecast ?? []).slice(0, 6)
    readonly property var nextDays: (Weather.forecast ?? []).slice(0, 4)

    function shortDayLabel(dateStr: string, idx: int): string {
        if (idx === 0)
            return qsTr("Today");
        if (!dateStr)
            return "";
        const m = /^(\d{4})[\/-](\d{2})[\/-](\d{2})$/.exec(String(dateStr).trim());
        if (!m)
            return "";
        const d = new Date(parseInt(m[1], 10), parseInt(m[2], 10) - 1, parseInt(m[3], 10), 12, 0, 0, 0);
        return isNaN(d.getTime()) ? "" : Qt.formatDate(d, "ddd");
    }

    function formatHourLabel(hour24: int, compact: bool): string {
        if (Units.twelveHourClock) {
            const suffix = hour24 >= 12 ? "p" : "a";
            const h12 = (hour24 % 12) || 12;
            return compact ? `${h12}${suffix}` : `${h12} ${hour24 >= 12 ? "PM" : "AM"}`;
        }
        return compact ? `${String(hour24).padStart(2, "0")}h` : `${String(hour24).padStart(2, "0")}:00`;
    }

    function refresh(): void {
        Weather.reload();
    }

    implicitWidth: WidgetMetrics.widthFor(effectiveSize, s)
    implicitHeight: WidgetMetrics.heightFor(effectiveSize, "weather", s)

    WidgetCardShell {
        id: shell

        anchors.fill: parent
        widgetType: "weather"
        sizeMode: root.effectiveSize
        outerShape: root.widgetOptions?.outerShape ?? ""
        wallpaper: root.wallpaper
        weActive: root.weActive
        surfaceStyle: root.surfaceStyle
        blurEnabled: root.blurEnabled
        plateOpacity: root.plateOpacity
        scaleFactor: root.s

        Loader {
            id: layoutLoader

            anchors.fill: parent
            sourceComponent: {
                switch (root.effectiveSize) {
                case "1x2":
                    return layout1x2;
                case "2x2":
                    return layout2x2;
                case "1x3":
                    return layout1x3;
                default:
                    return layout1x1;
                }
            }
        }
    }

    // 1x1 Expressive Weather Tile
    Component {
        id: layout1x1

        Item {
            clip: true

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.max(24, parent.width - shell.sidePadding * 2)
                spacing: Math.max(1, Math.round(2 * root.s))

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: Weather.icon || "partly_cloudy_day"
                    fontStyle: Tokens.font.icon.builders.large.scale(WidgetMetrics.safeFontScale(root.s, shell.isShaped ? 0.92 : 1.0)).build()
                    color: Colours.palette.m3primary
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    horizontalAlignment: Text.AlignHCenter
                    text: Weather.cc ? Weather.temp : "--°"
                    font: Tokens.font.clock.size(Math.max(12, Math.round((shell.isShaped ? 25 : 29) * root.s))).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    horizontalAlignment: Text.AlignHCenter
                    text: Weather.cc ? (Weather.description || qsTr("Clear")) : qsTr("Loading...")
                    font: Tokens.font.label.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.86)).weight(Font.Medium).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    horizontalAlignment: Text.AlignHCenter
                    visible: root.todayForecast !== null
                    text: Weather.formatTemp(root.todayHigh, true) + " / " + Weather.formatTemp(root.todayLow, true)
                    font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.82)).build()
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            StateLayer {
                anchors.fill: parent
                anchors.topMargin: shell.topPadding
                anchors.bottomMargin: shell.bottomPadding
                anchors.leftMargin: shell.sidePadding
                anchors.rightMargin: shell.sidePadding
                enabled: root.locked
                radius: shell.isShaped ? width / 2 : shell.radius
                onClicked: Weather.reload()
            }
        }
    }

    // 1x2 Wide Weather Strip
    Component {
        id: layout1x2

        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            spacing: Math.max(6, Math.round(Tokens.spacing.medium * root.s))

            Item {
                Layout.fillWidth: false
                Layout.preferredWidth: Math.round(70 * root.s)
                Layout.preferredHeight: Math.round(70 * root.s)
                Layout.alignment: Qt.AlignVCenter

                MaterialShape {
                    anchors.fill: parent
                    implicitSize: Math.round(70 * root.s)
                    shape: MaterialShape.Puffy
                    color: shell.primaryContainerTint
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: Weather.icon || "partly_cloudy_day"
                    fontStyle: Tokens.font.icon.builders.extraLarge.scale(WidgetMetrics.safeFontScale(root.s, 1.08)).build()
                    color: Colours.palette.m3onPrimaryContainer
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter
                spacing: Math.max(1, Math.round(2 * root.s))

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: Weather.cc ? Weather.temp : "--°"
                    font: Tokens.font.clock.size(Math.max(14, Math.round(30 * root.s))).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: Weather.cc ? (Weather.description || qsTr("Clear")) : qsTr("Fetching...")
                    font: Tokens.font.label.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.96)).weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: Weather.city || qsTr("Current location")
                    font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.88)).build()
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            ColumnLayout {
                Layout.fillWidth: false
                Layout.preferredWidth: Math.round(98 * root.s)
                Layout.maximumWidth: Math.round(98 * root.s)
                Layout.alignment: Qt.AlignVCenter
                spacing: Math.max(2, Math.round(4 * root.s))

                StyledRect {
                    visible: root.todayForecast !== null
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(24 * root.s)
                    clip: true
                    radius: Math.round(12 * root.s)
                    color: shell.secondaryContainerTint

                    StyledText {
                        anchors.centerIn: parent
                        width: Math.max(0, parent.width - Math.round(10 * root.s))
                        horizontalAlignment: Text.AlignHCenter
                        text: Weather.formatTemp(root.todayHigh, true) + " / " + Weather.formatTemp(root.todayLow, true)
                        font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.86)).weight(Font.Bold).build()
                        color: Colours.palette.m3onSecondaryContainer
                        elide: Text.ElideRight
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(24 * root.s)
                    clip: true
                    radius: Math.round(12 * root.s)
                    color: shell.innerSurface
                    border.width: 1
                    border.color: shell.innerBorder

                    RowLayout {
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, Math.max(0, parent.width - Math.round(10 * root.s)))
                        spacing: Math.max(2, Math.round(4 * root.s))

                        MaterialIcon {
                            text: "water_drop"
                            fontStyle: Tokens.font.icon.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.84)).build()
                            color: Colours.palette.m3primary
                        }

                        StyledText {
                            Layout.minimumWidth: 0
                            text: (Weather.humidity ?? 0) + "%"
                            font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.88)).build()
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(24 * root.s)
                    clip: true
                    radius: Math.round(12 * root.s)
                    color: shell.innerSurface
                    border.width: 1
                    border.color: shell.innerBorder

                    RowLayout {
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, Math.max(0, parent.width - Math.round(10 * root.s)))
                        spacing: Math.max(2, Math.round(4 * root.s))

                        MaterialIcon {
                            text: "air"
                            fontStyle: Tokens.font.icon.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.84)).build()
                            color: Colours.palette.m3primary
                        }

                        StyledText {
                            Layout.minimumWidth: 0
                            text: Math.round(Weather.windSpeed ?? 0) + " km/h"
                            font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.86)).build()
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    // 2x2 Balanced Weather Dashboard
    Component {
        id: layout2x2

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            spacing: Math.max(4, Math.round(Tokens.spacing.medium * root.s))

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Math.max(2, Math.round(Tokens.spacing.extraSmall * root.s))

                MaterialIcon {
                    text: "location_on"
                    fontStyle: Tokens.font.icon.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 1.0)).build()
                    color: Colours.palette.m3primary
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: Weather.city || qsTr("Weather")
                    font: Tokens.font.title.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 1.0)).weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                WidgetIconButton {
                    icon: "refresh"
                    type: WidgetIconButton.Text
                    translucent: shell.isTranslucent
                    scaleFactor: root.s
                    onClicked: Weather.reload()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Math.max(6, Math.round(Tokens.spacing.medium * root.s))

                Item {
                    Layout.fillWidth: false
                    Layout.preferredWidth: Math.round(68 * root.s)
                    Layout.preferredHeight: Math.round(68 * root.s)

                    MaterialShape {
                        anchors.fill: parent
                        implicitSize: Math.round(68 * root.s)
                        shape: MaterialShape.Puffy
                        color: shell.primaryContainerTint
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: Weather.icon || "partly_cloudy_day"
                        fontStyle: Tokens.font.icon.builders.extraLarge.scale(WidgetMetrics.safeFontScale(root.s, 1.15)).build()
                        color: Colours.palette.m3onPrimaryContainer
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 1

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: Weather.cc ? Weather.temp : "--°"
                        font: Tokens.font.clock.size(Math.max(16, Math.round(34 * root.s))).weight(Font.Bold).build()
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: Weather.description || qsTr("Clear")
                        font: Tokens.font.body.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.96)).weight(Font.Medium).build()
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    StyledText {
                        visible: root.todayForecast !== null
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: qsTr("H:%1  L:%2").arg(Weather.formatTemp(root.todayHigh, true)).arg(Weather.formatTemp(root.todayLow, true))
                        font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.9)).build()
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Math.max(4, Math.round(Tokens.spacing.small * root.s))

                StatPill {
                    compact: true
                    icon: "thermostat"
                    label: qsTr("Feels")
                    value: Weather.cc ? Weather.formatTemp(Weather.cc.feelsLikeC, true) : "--"
                }

                StatPill {
                    compact: true
                    icon: "water_drop"
                    label: qsTr("Humid")
                    value: (Weather.humidity ?? 0) + "%"
                }

                StatPill {
                    compact: true
                    icon: "air"
                    label: qsTr("Wind")
                    value: Math.round(Weather.windSpeed ?? 0) + " km/h"
                }
            }

            // 4-day bottom outlook bar
            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Math.round(64 * root.s)
                clip: true
                radius: Math.round(Tokens.rounding.large * Math.min(1.2, Math.max(0.75, root.s)))
                color: shell.innerSurface
                border.width: 1
                border.color: shell.innerBorder

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Math.max(3, Math.round(4 * root.s))
                    spacing: Math.max(2, Math.round(3 * root.s))

                    Repeater {
                        model: root.nextDays

                        delegate: StyledRect {
                            id: sqDayCol

                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumWidth: 0
                            implicitWidth: Math.round(62 * root.s)
                            clip: true
                            radius: Math.round(Tokens.rounding.medium * Math.min(1.2, Math.max(0.75, root.s)))
                            color: index === 0 ? shell.primaryContainerTint : "transparent"

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Math.max(2, Math.round(3 * root.s))
                                spacing: Math.max(1, Math.round(2 * root.s))

                                Item { Layout.fillHeight: true }

                                StyledText {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    horizontalAlignment: Text.AlignHCenter
                                    text: root.shortDayLabel(sqDayCol.modelData.date, sqDayCol.index)
                                    font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.86)).weight(sqDayCol.index === 0 ? Font.Bold : Font.Medium).build()
                                    color: sqDayCol.index === 0 ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                                    elide: Text.ElideRight
                                }

                                MaterialIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: sqDayCol.modelData.icon || "sunny"
                                    fontStyle: Tokens.font.icon.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).build()
                                    color: sqDayCol.index === 0 ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    horizontalAlignment: Text.AlignHCenter
                                    text: Weather.formatTemp(sqDayCol.modelData.maxTempC, true) + "/" + Weather.formatTemp(sqDayCol.modelData.minTempC, true)
                                    font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.82)).build()
                                    color: sqDayCol.index === 0 ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                                    elide: Text.ElideRight
                                }

                                Item { Layout.fillHeight: true }
                            }
                        }
                    }
                }
            }
        }
    }

    // 1x3 Ultra-Wide Hourly Strip
    Component {
        id: layout1x3

        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            spacing: Math.max(6, Math.round(Tokens.spacing.medium * root.s))

            RowLayout {
                Layout.fillWidth: false
                Layout.preferredWidth: Math.round(166 * root.s)
                Layout.maximumWidth: Math.round(172 * root.s)
                Layout.alignment: Qt.AlignVCenter
                spacing: Math.max(4, Math.round(Tokens.spacing.small * root.s))

                Item {
                    Layout.fillWidth: false
                    Layout.preferredWidth: Math.round(58 * root.s)
                    Layout.preferredHeight: Math.round(58 * root.s)

                    MaterialShape {
                        anchors.fill: parent
                        implicitSize: Math.round(58 * root.s)
                        shape: MaterialShape.Puffy
                        color: shell.primaryContainerTint
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: Weather.icon || "partly_cloudy_day"
                        fontStyle: Tokens.font.icon.builders.large.scale(WidgetMetrics.safeFontScale(root.s, 1.0)).build()
                        color: Colours.palette.m3onPrimaryContainer
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 1

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: Weather.cc ? Weather.temp : "--°"
                        font: Tokens.font.clock.size(Math.max(14, Math.round(27 * root.s))).weight(Font.Bold).build()
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: Weather.description || qsTr("Clear")
                        font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).build()
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: Weather.city || ""
                        font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.84)).build()
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: false
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                Layout.topMargin: Math.round(6 * root.s)
                Layout.bottomMargin: Math.round(6 * root.s)
                color: Qt.alpha(Colours.palette.m3outlineVariant, 0.45)
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.fillHeight: true
                spacing: Math.max(2, Math.round(4 * root.s))

                Repeater {
                    model: root.nextHours

                    delegate: StyledRect {
                        id: hrWideCol

                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 0
                        implicitWidth: Math.round(42 * root.s)
                        clip: true
                        radius: Math.round(Tokens.rounding.medium * Math.min(1.2, Math.max(0.75, root.s)))
                        color: index === 0 ? shell.primaryContainerTint : "transparent"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Math.max(2, Math.round(4 * root.s))
                            spacing: Math.max(1, Math.round(3 * root.s))

                            Item { Layout.fillHeight: true }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                horizontalAlignment: Text.AlignHCenter
                                text: root.formatHourLabel(hrWideCol.modelData.hour, true)
                                font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.86)).build()
                                color: hrWideCol.index === 0 ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                                elide: Text.ElideRight
                            }

                            MaterialIcon {
                                Layout.alignment: Qt.AlignHCenter
                                text: hrWideCol.modelData.icon || "sunny"
                                fontStyle: Tokens.font.icon.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).build()
                                color: hrWideCol.index === 0 ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                horizontalAlignment: Text.AlignHCenter
                                text: Weather.formatTemp(hrWideCol.modelData.tempC, true)
                                font: Tokens.font.label.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.92)).weight(Font.Bold).build()
                                color: hrWideCol.index === 0 ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                                elide: Text.ElideRight
                            }

                            Item { Layout.fillHeight: true }
                        }
                    }
                }
            }
        }
    }

    component StatPill: StyledRect {
        id: statPillRoot

        property string icon: ""
        property string label: ""
        property string value: ""
        property bool compact: false

        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredHeight: Math.round((compact ? 36 : 46) * root.s)
        clip: true
        radius: Math.round(Tokens.rounding.large * Math.min(1.2, Math.max(0.75, root.s)))
        color: shell.innerSurface
        border.width: 1
        border.color: shell.innerBorder

        RowLayout {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - Math.round((statPillRoot.compact ? 8 : Tokens.padding.small * 2) * root.s))
            spacing: Math.max(2, Math.round((statPillRoot.compact ? 3 : 6) * root.s))

            MaterialIcon {
                text: statPillRoot.icon
                fontStyle: Tokens.font.icon.builders.small.scale(WidgetMetrics.safeFontScale(root.s, statPillRoot.compact ? 0.84 : 1.0)).build()
                color: Colours.palette.m3primary
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: statPillRoot.value
                    font: Tokens.font.label.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, statPillRoot.compact ? 0.84 : 0.92)).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    visible: !statPillRoot.compact
                    text: statPillRoot.label
                    font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.82)).build()
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }
        }
    }
}

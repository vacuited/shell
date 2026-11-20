pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import M3Shapes
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import "../components"

Item {
    id: root

    required property var wallpaper
    property bool weActive: false
    property bool locked: true
    property string sizeMode: "1x1"
    property string surfaceStyle: ""
    property bool blurEnabled: Config.background.desktopWidgets.blur
    property real plateOpacity: Config.background.desktopWidgets.opacity
    property var widgetOptions: ({})

    readonly property real s: Math.max(0.7, Math.min(1.5, Config.background.desktopWidgets.scale ?? 1.0))
    readonly property var todayForecast: (Weather.forecast && Weather.forecast.length > 0) ? Weather.forecast[0] : null
    readonly property real todayHigh: todayForecast?.maxTempC ?? 0
    readonly property real todayLow: todayForecast?.minTempC ?? 0
    readonly property var nextHours: (Weather.hourlyForecast ?? []).slice(0, 6)
    readonly property var nextDays: (Weather.forecast ?? []).slice(0, 5)

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
            const suffix = hour24 >= 12 ? "PM" : "AM";
            const h12 = (hour24 % 12) || 12;
            return compact ? `${h12}${suffix.toLowerCase()}` : `${h12} ${suffix}`;
        }
        return compact ? `${String(hour24).padStart(2, "0")}h` : `${String(hour24).padStart(2, "0")}:00`;
    }

    function refresh(): void {
        Weather.reload();
    }

    implicitWidth: WidgetMetrics.widthFor(sizeMode, s)
    implicitHeight: WidgetMetrics.heightFor(sizeMode, "weather", s)

    WidgetCardShell {
        id: shell

        anchors.fill: parent
        widgetType: "weather"
        sizeMode: root.sizeMode
        outerShape: root.widgetOptions?.outerShape ?? ""
        wallpaper: root.wallpaper
        weActive: root.weActive
        surfaceStyle: root.surfaceStyle
        blurEnabled: root.blurEnabled
        plateOpacity: root.plateOpacity
        scaleFactor: root.s

        // 1x1 Puffy / Expressive Weather Tile
        Item {
            anchors.fill: parent
            anchors.topMargin: shell.topPadding
            anchors.bottomMargin: shell.bottomPadding
            anchors.leftMargin: shell.sidePadding
            anchors.rightMargin: shell.sidePadding
            visible: root.sizeMode === "1x1"

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width
                spacing: Math.round(2 * root.s)

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 4

                    MaterialIcon {
                        text: Weather.icon || "partly_cloudy_day"
                        fontStyle: Tokens.font.icon.builders.large.scale(root.s).build()
                        color: Colours.palette.m3primary
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Weather.cc ? Weather.temp : "--°"
                    font: Tokens.font.clock.size(Math.round(30 * root.s)).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Weather.cc ? (Weather.description || qsTr("Clear")) : qsTr("Loading...")
                    font: Tokens.font.label.builders.medium.scale(Math.max(0.85, root.s * 0.9)).weight(Font.Medium).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.todayForecast !== null
                    text: Weather.formatTemp(root.todayHigh, true) + " / " + Weather.formatTemp(root.todayLow, true)
                    font: Tokens.font.label.builders.small.scale(Math.max(0.8, root.s * 0.85)).build()
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            StateLayer {
                enabled: root.locked
                radius: shell.isShaped ? width / 2 : shell.radius
                onClicked: Weather.reload()
            }
        }

        // 1x2 Wide Weather Strip
        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "1x2"
            spacing: Math.round(Tokens.spacing.medium * root.s)

            Item {
                Layout.preferredWidth: Math.round(74 * root.s)
                Layout.preferredHeight: Math.round(74 * root.s)
                Layout.alignment: Qt.AlignVCenter

                MaterialShape {
                    anchors.fill: parent
                    shape: MaterialShape.Puffy
                    color: Colours.palette.m3primaryContainer
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: Weather.icon || "partly_cloudy_day"
                    fontStyle: Tokens.font.icon.builders.extraLarge.scale(1.15 * root.s).build()
                    color: Colours.palette.m3onPrimaryContainer
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: Math.round(2 * root.s)

                StyledText {
                    text: Weather.cc ? Weather.temp : "--°"
                    font: Tokens.font.clock.size(Math.round(32 * root.s)).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Weather.cc ? (Weather.description || qsTr("Clear")) : qsTr("Fetching...")
                    font: Tokens.font.label.builders.medium.scale(root.s).weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Weather.city || qsTr("Current location")
                    font: Tokens.font.label.builders.small.scale(Math.max(0.85, root.s * 0.9)).build()
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            ColumnLayout {
                Layout.preferredWidth: Math.round(104 * root.s)
                Layout.alignment: Qt.AlignVCenter
                spacing: Math.round(4 * root.s)

                StyledRect {
                    visible: root.todayForecast !== null
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(24 * root.s)
                    radius: Math.round(12 * root.s)
                    color: Colours.palette.m3secondaryContainer

                    StyledText {
                        anchors.centerIn: parent
                        text: Weather.formatTemp(root.todayHigh, true) + " / " + Weather.formatTemp(root.todayLow, true)
                        font: Tokens.font.label.builders.small.scale(Math.max(0.82, root.s * 0.88)).weight(Font.Bold).build()
                        color: Colours.palette.m3onSecondaryContainer
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(24 * root.s)
                    radius: Math.round(12 * root.s)
                    color: WidgetMetrics.innerSurface
                    border.width: 1
                    border.color: WidgetMetrics.innerBorder

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialIcon {
                            text: "water_drop"
                            fontStyle: Tokens.font.icon.builders.small.scale(0.85 * root.s).build()
                            color: Colours.palette.m3primary
                        }

                        StyledText {
                            text: (Weather.humidity ?? 0) + "%"
                            font: Tokens.font.label.small
                            color: Colours.palette.m3onSurface
                        }
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(24 * root.s)
                    radius: Math.round(12 * root.s)
                    color: WidgetMetrics.innerSurface
                    border.width: 1
                    border.color: WidgetMetrics.innerBorder

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialIcon {
                            text: "air"
                            fontStyle: Tokens.font.icon.builders.small.scale(0.85 * root.s).build()
                            color: Colours.palette.m3primary
                        }

                        StyledText {
                            text: Math.round(Weather.windSpeed ?? 0) + " km/h"
                            font: Tokens.font.label.small
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // 2x1 Tall Column + 3-Day Mini Forecast
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "2x1"
            spacing: Math.round(Tokens.spacing.small * root.s)

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    text: Weather.city || qsTr("Weather")
                    font: Tokens.font.label.builders.small.scale(root.s).weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }

                IconButton {
                    icon: "refresh"
                    type: IconButton.Text
                    onClicked: Weather.reload()
                }
            }

            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.round(74 * root.s)
                Layout.preferredHeight: Math.round(74 * root.s)

                MaterialShape {
                    anchors.fill: parent
                    shape: MaterialShape.Puffy
                    color: Colours.palette.m3primaryContainer
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: Weather.icon || "partly_cloudy_day"
                    fontStyle: Tokens.font.icon.builders.extraLarge.scale(1.15 * root.s).build()
                    color: Colours.palette.m3onPrimaryContainer
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Weather.cc ? Weather.temp : "--°"
                font: Tokens.font.clock.size(Math.round(34 * root.s)).weight(Font.Bold).build()
                color: Colours.palette.m3onSurface
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Weather.description || qsTr("Clear")
                font: Tokens.font.label.builders.medium.scale(root.s).build()
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }

            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Tokens.rounding.large
                color: WidgetMetrics.innerSurface
                border.width: 1
                border.color: WidgetMetrics.innerBorder

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Math.round(Tokens.padding.small * root.s)
                    spacing: Math.round(4 * root.s)

                    Repeater {
                        model: root.nextDays.slice(0, 3)

                        delegate: RowLayout {
                            id: tallDayRow

                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 6

                            StyledText {
                                Layout.fillWidth: true
                                text: root.shortDayLabel(tallDayRow.modelData.date, tallDayRow.index)
                                font: Tokens.font.label.builders.small.weight(tallDayRow.index === 0 ? Font.Bold : Font.Medium).build()
                                color: tallDayRow.index === 0 ? Colours.palette.m3primary : Colours.palette.m3onSurface
                            }

                            MaterialIcon {
                                text: tallDayRow.modelData.icon || "sunny"
                                fontStyle: Tokens.font.icon.small
                                color: Colours.palette.m3onSurface
                            }

                            StyledText {
                                text: Weather.formatTemp(tallDayRow.modelData.maxTempC, true) + "/" + Weather.formatTemp(tallDayRow.modelData.minTempC, true)
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurfaceVariant
                            }
                        }
                    }
                }
            }
        }

        // 2x2 Balanced Weather Dashboard
        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: shell.topPadding
            anchors.bottomMargin: shell.bottomPadding
            anchors.leftMargin: shell.sidePadding
            anchors.rightMargin: shell.sidePadding
            visible: root.sizeMode === "2x2"
            spacing: Math.round((shell.isShaped ? Tokens.spacing.small : Tokens.spacing.medium) * root.s)

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                MaterialIcon {
                    text: "location_on"
                    fontStyle: Tokens.font.icon.small
                    color: Colours.palette.m3primary
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Weather.city || qsTr("Weather")
                    font: Tokens.font.title.builders.small.scale(root.s * (shell.isShaped ? 0.92 : 1.0)).weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                IconButton {
                    icon: "refresh"
                    type: IconButton.Text
                    onClicked: Weather.reload()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(Tokens.spacing.medium * root.s)

                Item {
                    Layout.preferredWidth: Math.round((shell.isShaped ? 56 : 70) * root.s)
                    Layout.preferredHeight: Math.round((shell.isShaped ? 56 : 70) * root.s)

                    MaterialShape {
                        anchors.fill: parent
                        shape: MaterialShape.Puffy
                        color: Colours.palette.m3primaryContainer
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: Weather.icon || "partly_cloudy_day"
                        fontStyle: Tokens.font.icon.builders.extraLarge.scale((shell.isShaped ? 1.0 : 1.2) * root.s).build()
                        color: Colours.palette.m3onPrimaryContainer
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    StyledText {
                        text: Weather.cc ? Weather.temp : "--°"
                        font: Tokens.font.clock.size(Math.round((shell.isShaped ? 30 : 36) * root.s)).weight(Font.Bold).build()
                        color: Colours.palette.m3onSurface
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Weather.description || qsTr("Clear")
                        font: Tokens.font.body.builders.medium.scale(root.s * (shell.isShaped ? 0.9 : 1.0)).weight(Font.Medium).build()
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    StyledText {
                        visible: root.todayForecast !== null
                        text: qsTr("H:%1  L:%2").arg(Weather.formatTemp(root.todayHigh, true)).arg(Weather.formatTemp(root.todayLow, true))
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round((shell.isShaped ? 6 : Tokens.spacing.small) * root.s)

                StatPill {
                    compact: shell.isShaped
                    icon: "thermostat"
                    label: qsTr("Feels")
                    value: Weather.cc ? Weather.formatTemp(Weather.cc.feelsLikeC, true) : "--"
                }

                StatPill {
                    compact: shell.isShaped
                    icon: "water_drop"
                    label: qsTr("Humid")
                    value: (Weather.humidity ?? 0) + "%"
                }

                StatPill {
                    compact: shell.isShaped
                    icon: "air"
                    label: qsTr("Wind")
                    value: Math.round(Weather.windSpeed ?? 0) + (shell.isShaped ? "km/h" : " km/h")
                }
            }

            // 4-day bottom outlook bar
            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Math.round(66 * root.s)
                radius: Tokens.rounding.large
                color: WidgetMetrics.innerSurface
                border.width: 1
                border.color: WidgetMetrics.innerBorder

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Math.round(4 * root.s)
                    spacing: Math.round(3 * root.s)

                    Repeater {
                        model: root.nextDays.slice(0, 4)

                        delegate: StyledRect {
                            id: sqDayCol

                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Tokens.rounding.medium
                            color: index === 0 ? Qt.alpha(Colours.palette.m3primaryContainer, 0.72) : "transparent"

                            ColumnLayout {
                                anchors.centerIn: parent
                                width: Math.max(0, parent.width - 4)
                                spacing: Math.round(2 * root.s)

                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: root.shortDayLabel(sqDayCol.modelData.date, sqDayCol.index)
                                    font: Tokens.font.label.builders.small.scale(0.88).weight(sqDayCol.index === 0 ? Font.Bold : Font.Medium).build()
                                    color: sqDayCol.index === 0 ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                                }

                                MaterialIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: sqDayCol.modelData.icon || "sunny"
                                    fontStyle: Tokens.font.icon.builders.medium.scale(shell.isShaped ? 0.9 : 1.0).build()
                                    color: sqDayCol.index === 0 ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: Weather.formatTemp(sqDayCol.modelData.maxTempC, true) + "/" + Weather.formatTemp(sqDayCol.modelData.minTempC, true)
                                    font: Tokens.font.label.builders.small.scale(0.84).build()
                                    color: sqDayCol.index === 0 ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                                }
                            }
                        }
                    }
                }
            }
        }

        // 1x3 Ultra-Wide Hourly Strip
        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "1x3"
            spacing: Math.round(Tokens.spacing.medium * root.s)

            RowLayout {
                Layout.preferredWidth: Math.round(176 * root.s)
                Layout.alignment: Qt.AlignVCenter
                spacing: Math.round(Tokens.spacing.small * root.s)

                Item {
                    Layout.preferredWidth: Math.round(60 * root.s)
                    Layout.preferredHeight: Math.round(60 * root.s)

                    MaterialShape {
                        anchors.fill: parent
                        shape: MaterialShape.Puffy
                        color: Colours.palette.m3primaryContainer
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: Weather.icon || "partly_cloudy_day"
                        fontStyle: Tokens.font.icon.builders.large.scale(root.s).build()
                        color: Colours.palette.m3onPrimaryContainer
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    StyledText {
                        text: Weather.cc ? Weather.temp : "--°"
                        font: Tokens.font.clock.size(Math.round(28 * root.s)).weight(Font.Bold).build()
                        color: Colours.palette.m3onSurface
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Weather.description || qsTr("Clear")
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Weather.city || ""
                        font: Tokens.font.label.builders.small.scale(0.85).build()
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                color: Qt.alpha(Colours.palette.m3outlineVariant, 0.45)
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Math.round(4 * root.s)

                Repeater {
                    model: root.nextHours

                    delegate: StyledRect {
                        id: hrWideCol

                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Tokens.rounding.medium
                        color: index === 0 ? Qt.alpha(Colours.palette.m3primaryContainer, 0.5) : "transparent"

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: Math.round(4 * root.s)

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.formatHourLabel(hrWideCol.modelData.hour, false)
                                font: Tokens.font.label.builders.small.scale(0.9).build()
                                color: Colours.palette.m3onSurfaceVariant
                            }

                            MaterialIcon {
                                Layout.alignment: Qt.AlignHCenter
                                text: hrWideCol.modelData.icon || "sunny"
                                fontStyle: Tokens.font.icon.medium
                                color: Colours.palette.m3onSurface
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Weather.formatTemp(hrWideCol.modelData.tempC, true)
                                font: Tokens.font.label.builders.medium.weight(Font.Bold).build()
                                color: Colours.palette.m3onSurface
                            }
                        }
                    }
                }
            }
        }

        // 2x3 Spacious Panorama Weather Hub
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "2x3"
            spacing: Math.round(Tokens.spacing.medium * root.s)

            // Top: City header + Hero left + 3 clean metrics right (never squeezing temp)
            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(Tokens.spacing.large * root.s)

                RowLayout {
                    Layout.preferredWidth: Math.round(212 * root.s)
                    spacing: Math.round(Tokens.spacing.medium * root.s)

                    Item {
                        Layout.preferredWidth: Math.round(68 * root.s)
                        Layout.preferredHeight: Math.round(68 * root.s)

                        MaterialShape {
                            anchors.fill: parent
                            shape: MaterialShape.Puffy
                            color: Colours.palette.m3primaryContainer
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: Weather.icon || "partly_cloudy_day"
                            fontStyle: Tokens.font.icon.builders.extraLarge.scale(1.15 * root.s).build()
                            color: Colours.palette.m3onPrimaryContainer
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        StyledText {
                            text: Weather.cc ? Weather.temp : "--°"
                            font: Tokens.font.clock.size(Math.round(38 * root.s)).weight(Font.Bold).build()
                            color: Colours.palette.m3onSurface
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Weather.description || qsTr("Clear")
                            font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: (Weather.city || qsTr("Weather")) + (root.todayForecast ? (" · " + Weather.formatTemp(root.todayHigh, true) + "/" + Weather.formatTemp(root.todayLow, true)) : "")
                            font: Tokens.font.label.small
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(6 * root.s)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        StatPill {
                            icon: "thermostat"
                            label: qsTr("Feels")
                            value: Weather.cc ? Weather.formatTemp(Weather.cc.feelsLikeC, true) : "--"
                            compact: true
                        }

                        StatPill {
                            icon: "water_drop"
                            label: qsTr("Humid")
                            value: (Weather.humidity ?? 0) + "%"
                            compact: true
                        }

                        IconButton {
                            icon: "refresh"
                            type: IconButton.Tonal
                            onClicked: Weather.reload()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        StatPill {
                            icon: "air"
                            label: qsTr("Wind")
                            value: Math.round(Weather.windSpeed ?? 0) + " km/h"
                            compact: true
                        }

                        StatPill {
                            icon: "wb_twilight"
                            label: qsTr("Sun")
                            value: Weather.sunset
                            compact: true
                        }
                    }
                }
            }

            // Middle: Hourly timeline bar
            StyledRect {
                visible: root.nextHours.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(78 * root.s)
                radius: Tokens.rounding.large
                color: WidgetMetrics.innerSurface
                border.width: 1
                border.color: WidgetMetrics.innerBorder

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Math.round(Tokens.padding.small * root.s)
                    spacing: 4

                    Repeater {
                        model: root.nextHours

                        delegate: ColumnLayout {
                            id: panoHr

                            required property var modelData

                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.formatHourLabel(panoHr.modelData.hour, true)
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurfaceVariant
                            }

                            MaterialIcon {
                                Layout.alignment: Qt.AlignHCenter
                                text: panoHr.modelData.icon || "sunny"
                                fontStyle: Tokens.font.icon.small
                                color: Colours.palette.m3primary
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Weather.formatTemp(panoHr.modelData.tempC, true)
                                font: Tokens.font.label.builders.small.weight(Font.Bold).build()
                                color: Colours.palette.m3onSurface
                            }
                        }
                    }
                }
            }

            // Bottom: 5-day forecast cards
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Math.round(Tokens.spacing.small * root.s)

                Repeater {
                    model: root.nextDays

                    delegate: StyledRect {
                        id: panoDay

                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Tokens.rounding.large
                        color: index === 0
                            ? Colours.palette.m3primaryContainer
                            : WidgetMetrics.innerSurface
                        border.width: index === 0 ? 0 : 1
                        border.color: WidgetMetrics.innerBorder

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.shortDayLabel(panoDay.modelData.date, panoDay.index)
                                font: Tokens.font.label.builders.small.weight(panoDay.index === 0 ? Font.Bold : Font.Medium).build()
                                color: panoDay.index === 0 ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                            }

                            MaterialIcon {
                                Layout.alignment: Qt.AlignHCenter
                                text: panoDay.modelData.icon || "sunny"
                                fontStyle: Tokens.font.icon.medium
                                color: panoDay.index === 0 ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Weather.formatTemp(panoDay.modelData.maxTempC, true) + "/" + Weather.formatTemp(panoDay.modelData.minTempC, true)
                                font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
                                color: panoDay.index === 0 ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                            }
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
        radius: Tokens.rounding.large
        color: WidgetMetrics.innerSurface
        border.width: 1
        border.color: WidgetMetrics.innerBorder

        RowLayout {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - Math.round((statPillRoot.compact ? 8 : Tokens.padding.small * 2) * root.s))
            spacing: Math.round((statPillRoot.compact ? 3 : 6) * root.s)

            MaterialIcon {
                text: statPillRoot.icon
                fontStyle: Tokens.font.icon.builders.small.scale((statPillRoot.compact ? 0.85 : 1.0) * root.s).build()
                color: Colours.palette.m3primary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: statPillRoot.value
                    font: Tokens.font.label.builders.medium.scale(Math.max(0.78, root.s * (statPillRoot.compact ? 0.84 : 0.92))).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: !statPillRoot.compact
                    text: statPillRoot.label
                    font: Tokens.font.label.builders.small.scale(Math.max(0.8, root.s * 0.82)).build()
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }
        }
    }
}

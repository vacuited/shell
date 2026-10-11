import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    readonly property var today: Weather.forecast && Weather.forecast.length > 0 ? Weather.forecast[0] : null
    readonly property var allHourly: Weather.hourlyForecast ?? []
    readonly property int windowSize: 12
    readonly property int step: 6
    readonly property int maxOffset: Math.max(0, allHourly.length - windowSize)

    property int hourOffset: 0
    property real scrollPos: hourOffset
    property int selectedView: 0 // 0: Hourly, 1: 7-Day
    property bool initialized: false

    Component.onCompleted: Qt.callLater(() => root.initialized = true)

    onMaxOffsetChanged: {
        if (hourOffset > maxOffset)
            hourOffset = maxOffset;
    }

    Behavior on scrollPos {
        Anim {
            type: Anim.EmphasizedLarge
        }
    }

    // One sentence for the day, built from data we already fetch.
    function summary(): string {
        const today = Weather.forecast && Weather.forecast.length > 0 ? Weather.forecast[0] : null;
        const hours = (Weather.hourlyForecast ?? []).slice(0, 12);
        if (!Weather.cc || !today || hours.length === 0)
            return "";

        const snowCodes = [71, 73, 75, 77, 85, 86];
        const wetCodes = [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99].concat(snowCodes);
        const timeOf = h => Qt.formatDateTime(new Date(h.timestamp.replace("T", " ").replace(/-/g, "/")), Units.twelveHourClock ? "h A" : "HH:mm");

        const parts = [Tr.tr("%1 now").arg(Weather.description)];

        if (wetCodes.includes(Weather.cc.weatherCode)) {
            const dry = hours.find(h => h.precipChance < 30);
            parts.push(dry ? Tr.tr("easing around %1").arg(timeOf(dry)) : Tr.tr("staying wet for hours"));
        } else {
            const wet = hours.find(h => h.precipChance >= 50);
            if (wet)
                parts.push((snowCodes.includes(wet.weatherCode) ? Tr.tr("snow from %1") : Tr.tr("rain from %1")).arg(timeOf(wet)));
            else
                parts.push(Tr.tr("staying dry"));
        }

        if (new Date().getHours() < 17)
            parts.push(Tr.tr("high of %1").arg(Weather.formatTemp(today.maxTempC, true)));
        else
            parts.push(Tr.tr("down to %1 overnight").arg(Weather.formatTemp(Math.min(...hours.map(h => h.tempC)), true)));

        return parts.join(", ") + ".";
    }

    implicitWidth: layout.implicitWidth > 800 ? layout.implicitWidth : 840
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Tokens.spacing.medium

        // 1. City & Date & Sun Stats (Original Sizing & Styling)
        RowLayout {
            Layout.leftMargin: Tokens.padding.large
            Layout.rightMargin: Tokens.padding.large
            Layout.fillWidth: true

            Column {
                spacing: Tokens.spacing.extraSmall

                StyledText {
                    text: Weather.city || Tr.tr("Loading...")
                    font: Tokens.font.body.builders.large.size(28).weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    text: new Date().toLocaleDateString(Qt.locale(), "dddd, MMMM d")
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Row {
                spacing: Tokens.spacing.largeIncreased

                WeatherStat {
                    icon: "wb_twilight"
                    label: Tr.tr("Sunrise")
                    value: Weather.sunrise
                    colour: Colours.palette.m3tertiary
                }

                WeatherStat {
                    icon: "bedtime"
                    label: Tr.tr("Sunset")
                    value: Weather.sunset
                    colour: Colours.palette.m3tertiary
                }
            }
        }

        // 2. Big Info Card (Original Sizing & Styling)
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: bigInfoRow.implicitHeight + Tokens.padding.small

            radius: Tokens.rounding.extraLarge * 2
            color: Colours.tPalette.m3surfaceContainer

            RowLayout {
                id: bigInfoRow

                anchors.centerIn: parent
                spacing: Tokens.spacing.largeIncreased

                MaterialIcon {
                    Layout.alignment: Qt.AlignVCenter
                    text: Weather.icon
                    fontStyle: Tokens.font.icon.builders.extraLarge.scale(3).build()
                    color: Colours.palette.m3secondary
                    animate: true
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: -Tokens.spacing.small

                    StyledText {
                        text: Weather.temp
                        font: Tokens.font.body.builders.large.size(28 * 2).weight(Font.Medium).build()
                        color: Colours.palette.m3primary
                    }

                    StyledText {
                        Layout.leftMargin: Tokens.padding.extraSmall
                        text: Weather.description
                        font: Tokens.font.body.medium
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }
        }

        // 3. Summary Text (Original Sizing & Styling)
        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.large
            Layout.rightMargin: Tokens.padding.large
            visible: text.length > 0
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.summary()
            font: Tokens.font.body.medium
            color: Colours.palette.m3onSurfaceVariant
        }

        // 4. Detail Cards: Humidity, Feels Like, Wind (Original Sizing & Styling)
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            DetailCard {
                icon: "water_drop"
                label: Tr.tr("Humidity")
                value: Strings.percent(Weather.humidity)
                colour: Colours.palette.m3secondary
            }
            DetailCard {
                icon: "thermostat"
                label: Tr.trCtx("Feels like", "apparent temperature")
                value: Weather.feelsLike
                colour: Colours.palette.m3primary
            }
            DetailCard {
                icon: "air"
                label: Tr.tr("Wind")
                value: Weather.windSpeed ? Tr.tr("%1 km/h").arg(Weather.windSpeed) : "--"
                colour: Colours.palette.m3tertiary
            }
        }

        // 5. Forecast Header with Animated Sliding Pill Toggle
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            Layout.leftMargin: Tokens.padding.medium
            Layout.rightMargin: Tokens.padding.medium
            spacing: Tokens.spacing.small

            StyledText {
                text: root.selectedView === 0 ? Tr.tr("Hourly forecast") : Tr.tr("7-day forecast")
                font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                color: Colours.palette.m3onSurface
            }

            IconButton {
                icon: "chevron_left"
                visible: root.selectedView === 0
                active: root.hourOffset > 0
                onClicked: root.hourOffset = Math.max(0, root.hourOffset - root.step)
            }

            IconButton {
                icon: "chevron_right"
                visible: root.selectedView === 0
                active: root.hourOffset < root.maxOffset
                onClicked: root.hourOffset = Math.min(root.maxOffset, root.hourOffset + root.step)
            }

            Item {
                Layout.fillWidth: true
            }

            // Animated Sliding Pill Selector
            StyledRect {
                id: togglePillContainer
                implicitHeight: 34
                implicitWidth: toggleRow.implicitWidth + 8
                radius: Tokens.rounding.full
                color: Colours.tPalette.m3surfaceContainerHigh

                // Sliding Active Indicator
                StyledRect {
                    id: slidingIndicator
                    x: toggleRow.x + (root.selectedView === 0 ? hourlyBtn.x : dailyBtn.x)
                    y: toggleRow.y + (root.selectedView === 0 ? hourlyBtn.y : dailyBtn.y)
                    width: root.selectedView === 0 ? hourlyBtn.width : dailyBtn.width
                    height: root.selectedView === 0 ? hourlyBtn.height : dailyBtn.height
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3primary

                    Behavior on x {
                        enabled: root.initialized
                        Anim {
                            type: Anim.EmphasizedLarge
                        }
                    }
                    Behavior on width {
                        enabled: root.initialized
                        Anim {
                            type: Anim.EmphasizedLarge
                        }
                    }
                }

                Row {
                    id: toggleRow
                    anchors.centerIn: parent
                    spacing: 4

                    ToggleBtn {
                        id: hourlyBtn
                        label: Tr.tr("Hourly")
                        icon: "schedule"
                        isSelected: root.selectedView === 0
                        onClicked: root.selectedView = 0
                    }

                    ToggleBtn {
                        id: dailyBtn
                        label: Tr.tr("7-Day")
                        icon: "calendar_today"
                        isSelected: root.selectedView === 1
                        onClicked: root.selectedView = 1
                    }
                }
            }
        }

        // 6. Forecast Content Area with Smooth Cross-Fade
        Item {
            id: forecastContainer
            Layout.fillWidth: true
            implicitHeight: root.selectedView === 0 ? hourlyCard.implicitHeight : dailyRow.implicitHeight

            Behavior on implicitHeight {
                enabled: root.initialized
                Anim {
                    type: Anim.EmphasizedLarge
                }
            }

            // Hourly Forecast Card (Exact Original Sizing, Curve, & Colors)
            StyledClippingRect {
                id: hourlyCard
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                implicitHeight: hourStrip.implicitHeight + Tokens.padding.medium * 2
                radius: Tokens.rounding.large
                color: Colours.tPalette.m3surfaceContainer
                opacity: root.selectedView === 0 ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    enabled: root.initialized
                    Anim {
                        type: Anim.EmphasizedLarge
                    }
                }

                HourStrip {
                    id: hourStrip
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Tokens.padding.medium
                    entries: root.allHourly
                    scrollPos: root.scrollPos
                    windowSize: root.windowSize
                }
            }

            // 7-Day Forecast Row (Exact Original Sizing, Cards, & Colors)
            RowLayout {
                id: dailyRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Tokens.spacing.medium
                opacity: root.selectedView === 1 ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    enabled: root.initialized
                    Anim {
                        type: Anim.EmphasizedLarge
                    }
                }

                Repeater {
                    id: forecastRepeater
                    model: Weather.forecast

                    StyledRect {
                        id: forecastItem
                        required property int index
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: forecastItemColumn.implicitHeight + Tokens.padding.medium * 2

                        radius: Tokens.rounding.large
                        color: Colours.tPalette.m3surfaceContainer

                        ColumnLayout {
                            id: forecastItemColumn
                            anchors.centerIn: parent
                            spacing: Tokens.spacing.small

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: forecastItem.index === 0 ? Tr.trCtx("Today", "forecast column") : new Date(forecastItem.modelData.date).toLocaleDateString(Qt.locale(), "ddd")
                                font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                                color: Colours.palette.m3primary
                            }

                            StyledText {
                                Layout.topMargin: -Tokens.spacing.extraSmall
                                Layout.alignment: Qt.AlignHCenter
                                text: new Date(forecastItem.modelData.date).toLocaleDateString(Qt.locale(), "MMM d")
                                font: Tokens.font.body.small
                                opacity: 0.7
                                color: Colours.palette.m3onSurfaceVariant
                            }

                            MaterialIcon {
                                Layout.alignment: Qt.AlignHCenter
                                text: forecastItem.modelData.icon
                                fontStyle: Tokens.font.icon.extraLarge
                                color: Colours.palette.m3secondary
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: {
                                    const min = Weather.formatTemp(forecastItem.modelData.minTempC, true);
                                    const max = Weather.formatTemp(forecastItem.modelData.maxTempC, true);
                                    return Tr.trCtx("%1 / %2", "min/max temperature").arg(min).arg(max);
                                }
                                font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                                color: Colours.palette.m3tertiary
                            }
                        }
                    }
                }
            }
        }
    }

    // Toggle Button Component
    component ToggleBtn: Item {
        id: btn
        property string label
        property string icon
        property bool isSelected: false
        signal clicked

        implicitWidth: btnRow.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: 26

        Row {
            id: btnRow
            anchors.centerIn: parent
            spacing: 5

            MaterialIcon {
                text: btn.icon
                fontStyle: Tokens.font.icon.small
                color: btn.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                anchors.verticalCenter: parent.verticalCenter

                Behavior on color {
                    ColorAnimation { duration: 180 }
                }
            }

            StyledText {
                text: btn.label
                font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                color: btn.isSelected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                anchors.verticalCenter: parent.verticalCenter

                Behavior on color {
                    ColorAnimation { duration: 180 }
                }
            }
        }

        StateLayer {
            radius: Tokens.rounding.full
            color: Colours.palette.m3onSurface
            onClicked: btn.clicked()
        }
    }

    // Every hour as one continuous strip. Only columns near the viewport are built.
    component HourStrip: ColumnLayout {
        id: strip

        required property var entries
        required property real scrollPos
        required property int windowSize

        readonly property real colW: chart.width / windowSize
        readonly property int firstIdx: Math.max(0, Math.floor(scrollPos) - 1)
        readonly property int slotCount: Math.max(0, Math.min(windowSize + 3, entries.length - firstIdx))

        // Temperature range of the dots currently in view.
        readonly property var visibleRange: {
            const n = entries.length;
            if (n === 0)
                return {
                    lo: 0,
                    hi: 0
                };
            const a = Math.max(0, Math.min(n - 1, Math.ceil(scrollPos - 0.5)));
            const b = Math.max(0, Math.min(n - 1, Math.floor(scrollPos + windowSize - 0.5)));
            let lo = Infinity;
            let hi = -Infinity;
            for (let i = a; i <= b; i++) {
                lo = Math.min(lo, entries[i].tempC);
                hi = Math.max(hi, entries[i].tempC);
            }
            return lo <= hi ? {
                lo: lo,
                hi: hi
            } : {
                lo: 0,
                hi: 0
            };
        }

        readonly property int scaleSpan: 3
        readonly property var scaleRange: {
            const n = entries.length;
            if (n === 0)
                return {
                    lo: 0,
                    hi: 0
                };
            const pagesBefore = Math.floor((scaleSpan - 1) / 2);
            const a = Math.max(0, Math.min(n - 1, Math.floor(scrollPos) - pagesBefore * windowSize));
            const b = Math.max(0, Math.min(n - 1, Math.ceil(scrollPos) + (scaleSpan - pagesBefore) * windowSize - 1));
            let lo = Infinity;
            let hi = -Infinity;
            for (let i = a; i <= b; i++) {
                lo = Math.min(lo, entries[i].tempC);
                hi = Math.max(hi, entries[i].tempC);
            }
            return lo <= hi ? {
                lo: lo,
                hi: hi
            } : {
                lo: 0,
                hi: 0
            };
        }

        readonly property real viewMin: scaleRange.lo
        readonly property real viewMax: scaleRange.hi

        function xAt(i: int): real {
            return colW * (i + 0.5);
        }

        function yAt(temp: real): real {
            const range = viewMax - viewMin;
            const t = range > 0 ? (temp - viewMin) / range : 0.5;
            return chart.padTop + chart.plotH * (1 - t);
        }

        function formatHour(h: int): string {
            if (Units.twelveHourClock) {
                const suffix = h >= 12 ? "PM" : "AM";
                const hr = h % 12 === 0 ? 12 : h % 12;
                return `${hr}${suffix}`;
            }
            return `${String(h).padStart(2, "0")}:00`;
        }

        function hourLabel(entry: var): string {
            if (entry.hour === 0) {
                const d = new Date(entry.timestamp.replace("T", " ").replace(/-/g, "/"));
                return d.toLocaleDateString(Qt.locale(), "ddd");
            }
            return formatHour(entry.hour);
        }

        spacing: 0

        Item {
            id: chart

            readonly property real padTop: 26
            readonly property real padBottom: 12
            readonly property real plotH: height - padTop - padBottom

            readonly property string curvePath: {
                const n = strip.slotCount;
                if (n < 2)
                    return "";
                const first = strip.firstIdx;
                let d = `M ${strip.xAt(first)} ${strip.yAt(strip.entries[first].tempC)}`;
                for (let i = first + 1; i < first + n; i++) {
                    const x0 = strip.xAt(i - 1);
                    const y0 = strip.yAt(strip.entries[i - 1].tempC);
                    const x1 = strip.xAt(i);
                    const y1 = strip.yAt(strip.entries[i].tempC);
                    const cx = (x0 + x1) / 2;
                    d += ` C ${cx} ${y0}, ${cx} ${y1}, ${x1} ${y1}`;
                }
                return d;
            }
            readonly property real firstX: strip.xAt(strip.firstIdx)
            readonly property real lastX: strip.xAt(strip.firstIdx + strip.slotCount - 1)

            Layout.fillWidth: true
            Layout.preferredHeight: 120

            Item {
                id: chartContent

                x: -strip.scrollPos * strip.colW
                width: strip.entries.length * strip.colW
                height: chart.height

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.GeometryRenderer

                    ShapePath {
                        strokeWidth: 0
                        fillGradient: LinearGradient {
                            x1: 0
                            y1: 0
                            x2: 0
                            y2: chart.height

                            GradientStop {
                                position: 0
                                color: Qt.alpha(Colours.palette.m3primary, 0.28)
                            }
                            GradientStop {
                                position: 1
                                color: Qt.alpha(Colours.palette.m3primary, 0)
                            }
                        }

                        PathSvg {
                            path: chart.curvePath ? `${chart.curvePath} L ${chart.lastX} ${chart.height} L ${chart.firstX} ${chart.height} Z` : ""
                        }
                    }
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.GeometryRenderer

                    ShapePath {
                        strokeWidth: 3
                        strokeColor: Colours.palette.m3primary
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin

                        PathSvg {
                            path: chart.curvePath
                        }
                    }
                }

                Repeater {
                    model: strip.slotCount

                    Item {
                        id: dot

                        required property int index

                        readonly property int dataIndex: strip.firstIdx + index
                        readonly property var entry: strip.entries[dataIndex]
                        readonly property bool isNow: dataIndex === 0
                        readonly property bool isExtreme: (entry?.tempC ?? 0) === strip.visibleRange.hi || (entry?.tempC ?? 0) === strip.visibleRange.lo

                        visible: entry !== undefined
                        x: strip.xAt(dataIndex)
                        y: strip.yAt(entry?.tempC ?? 0)

                        StyledRect {
                            anchors.centerIn: parent
                            implicitWidth: dot.isExtreme ? 12 : 8
                            implicitHeight: implicitWidth
                            radius: Tokens.rounding.full
                            color: dot.isNow ? Colours.palette.m3tertiary : Colours.palette.m3primary
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: -height - 8
                            text: Weather.formatTemp(dot.entry?.tempC, true)
                            font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                            color: dot.isNow ? Colours.palette.m3tertiary : Colours.palette.m3onSurface
                        }
                    }
                }
            }
        }

        Item {
            id: hourRow

            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            implicitHeight: sizer.implicitHeight

            HourCell {
                id: sizer

                opacity: 0
                enabled: false
                label: "00:00"
                icon: "cloud"
                precip: 100
            }

            Item {
                x: -strip.scrollPos * strip.colW

                Repeater {
                    model: strip.slotCount

                    HourCell {
                        id: cell

                        required property int index

                        readonly property int dataIndex: strip.firstIdx + index
                        readonly property var entry: strip.entries[dataIndex]
                        readonly property bool isNow: dataIndex === 0

                        x: strip.xAt(dataIndex) - width / 2
                        width: strip.colW

                        now: isNow
                        midnight: (entry?.hour ?? -1) === 0 && !isNow
                        label: isNow ? Tr.trCtx("Now", "hourly forecast, current hour") : (entry ? strip.hourLabel(entry) : "")
                        icon: entry?.icon ?? ""
                        precip: entry?.precipChance ?? 0
                    }
                }
            }
        }
    }

    component HourCell: ColumnLayout {
        id: cell

        property string label
        property string icon
        property int precip
        property bool now
        property bool midnight

        spacing: Tokens.spacing.extraSmall

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: cell.label
            font: Tokens.font.body.builders.small.weight(cell.now || cell.midnight ? Font.DemiBold : Font.Normal).build()
            color: cell.now ? Colours.palette.m3tertiary : (cell.midnight ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant)
        }

        MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            text: cell.icon
            fontStyle: Tokens.font.icon.large
            color: Colours.palette.m3secondary
        }

        StyledRect {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: rainLabel.implicitWidth + Tokens.padding.small * 2
            implicitHeight: rainLabel.implicitHeight + Tokens.padding.extraSmall * 2
            radius: Tokens.rounding.full
            color: Qt.alpha(Colours.palette.m3secondary, 0.1 + 0.3 * (cell.precip / 100))
            opacity: cell.precip >= 20 ? 1 : 0

            StyledText {
                id: rainLabel

                anchors.centerIn: parent
                text: Strings.percent(cell.precip)
                font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                color: Colours.palette.m3secondary
            }
        }
    }

    component IconButton: StyledRect {
        id: arrow

        required property string icon
        property bool active: true

        signal clicked

        implicitWidth: 36
        implicitHeight: 36
        radius: Tokens.rounding.full
        color: Colours.tPalette.m3surfaceContainerHigh
        opacity: active ? 1 : 0.38

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }

        StateLayer {
            radius: Tokens.rounding.full
            disabled: !arrow.active
            color: Colours.palette.m3onSurface
            onClicked: arrow.clicked()
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: arrow.icon
            color: Colours.palette.m3onSurface
            fontStyle: Tokens.font.icon.medium
        }
    }

    component DetailCard: StyledRect {
        id: detailRoot

        property string icon
        property string label
        property string value
        property color colour

        Layout.fillWidth: true
        Layout.preferredHeight: 60
        radius: Tokens.rounding.medium
        color: Colours.tPalette.m3surfaceContainer

        Row {
            anchors.centerIn: parent
            spacing: Tokens.spacing.medium

            MaterialIcon {
                text: detailRoot.icon
                color: detailRoot.colour
                fontStyle: Tokens.font.icon.large
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                StyledText {
                    text: detailRoot.label
                    font: Tokens.font.body.small
                    opacity: 0.7
                    horizontalAlignment: Text.AlignLeft
                }
                StyledText {
                    text: detailRoot.value
                    font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                    horizontalAlignment: Text.AlignLeft
                }
            }
        }
    }

    component WeatherStat: Row {
        id: weatherStat

        property string icon
        property string label
        property string value
        property color colour

        spacing: Tokens.spacing.small

        MaterialIcon {
            text: weatherStat.icon
            fontStyle: Tokens.font.icon.extraLarge
            color: weatherStat.colour
        }

        Column {
            StyledText {
                text: weatherStat.label
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurfaceVariant
            }
            StyledText {
                text: weatherStat.value
                font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                color: Colours.palette.m3onSurface
            }
        }
    }
}

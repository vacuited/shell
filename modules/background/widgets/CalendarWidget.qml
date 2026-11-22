pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import M3Shapes
import Caelestia.Config
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
    readonly property string effectiveSize: WidgetMetrics.fallbackSizeFor("calendar", sizeMode)
    property int monthOffset: 0
    property int selectedYear: todayYear
    property int selectedMonth: todayMonth
    property int selectedDay: todayDay

    readonly property string todayKey: Qt.formatDate(Time.date, "yyyy-MM-dd")
    readonly property date nowDate: FocusLedger.parseLocalDate(todayKey) ?? new Date()
    readonly property int todayYear: nowDate.getFullYear()
    readonly property int todayMonth: nowDate.getMonth()
    readonly property int todayDay: nowDate.getDate()

    readonly property date displayDate: new Date(todayYear, todayMonth + monthOffset, 1)
    readonly property int viewYear: displayDate.getFullYear()
    readonly property int viewMonth: displayDate.getMonth()
    readonly property int firstOffset: (displayDate.getDay() + 6) % 7

    readonly property int openTodoCount: {
        void NotesStore.version;
        const list = NotesStore.todos ?? [];
        let c = 0;
        for (let i = 0; i < list.length; i++) {
            if (!list[i].done)
                c++;
        }
        return c;
    }

    readonly property var monthCells: {
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(viewYear, viewMonth, 1 - firstOffset + i);
            const y = d.getFullYear();
            const m = d.getMonth();
            const day = d.getDate();
            const dow = i % 7;
            out.push({
                year: y,
                month: m,
                day: day,
                inMonth: m === viewMonth,
                isWeekend: dow === 5 || dow === 6,
                isToday: y === todayYear && m === todayMonth && day === todayDay,
                isSelected: y === selectedYear && m === selectedMonth && day === selectedDay
            });
        }
        return out;
    }

    function jumpToToday(): void {
        monthOffset = 0;
        selectedYear = todayYear;
        selectedMonth = todayMonth;
        selectedDay = todayDay;
    }

    function weekDayCell(index: int): var {
        const monOffset = -((nowDate.getDay() + 6) % 7) + index;
        const d = new Date(todayYear, todayMonth, todayDay + monOffset);
        return {
            day: d.getDate(),
            isToday: monOffset === 0,
            isWeekend: index === 5 || index === 6,
            shortName: Qt.formatDate(d, "ddd").slice(0, 2)
        };
    }

    implicitWidth: WidgetMetrics.widthFor(effectiveSize, s)
    implicitHeight: WidgetMetrics.heightFor(effectiveSize, "calendar", s)

    WidgetCardShell {
        id: shell

        anchors.fill: parent
        widgetType: "calendar"
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
                default:
                    return layout1x1;
                }
            }
        }
    }

    // 1x1 Expressive Shaped Tile
    Component {
        id: layout1x1

        Item {
            clip: true

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.max(24, parent.width - shell.sidePadding * 2)
                spacing: Math.max(1, Math.round(2 * root.s))

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDate(root.nowDate, "ddd").toUpperCase()
                    font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).letterSpacing(1.3).weight(Font.Bold).build()
                    color: Colours.palette.m3primary
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    horizontalAlignment: Text.AlignHCenter
                    text: String(root.todayDay)
                    font: Tokens.font.clock.size(Math.max(18, Math.round((shell.isShaped ? 38 : 44) * root.s))).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDate(root.nowDate, "MMM yyyy")
                    font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.88)).build()
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }
        }
    }

    // 1x2 Date Hero + Non-Overlapping 7-Day Week Strip
    Component {
        id: layout1x2

        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            spacing: Math.max(6, Math.round(Tokens.spacing.medium * root.s))

            ColumnLayout {
                Layout.fillWidth: false
                Layout.preferredWidth: Math.round(80 * root.s)
                Layout.maximumWidth: Math.round(84 * root.s)
                Layout.alignment: Qt.AlignVCenter
                spacing: Math.max(1, Math.round(2 * root.s))

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: Qt.formatDate(root.nowDate, "dddd").toUpperCase()
                    font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.86)).letterSpacing(1.1).weight(Font.Bold).build()
                    color: Colours.palette.m3primary
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: String(root.todayDay)
                    font: Tokens.font.clock.size(Math.max(18, Math.round(38 * root.s))).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: Qt.formatDate(root.nowDate, "MMM yyyy")
                    font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.88)).build()
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                Layout.fillWidth: false
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                Layout.topMargin: Math.round(8 * root.s)
                Layout.bottomMargin: Math.round(8 * root.s)
                color: Qt.alpha(Colours.palette.m3outlineVariant, 0.45)
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter
                spacing: Math.max(4, Math.round(6 * root.s))

                RowLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: qsTr("This Week")
                        font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).weight(Font.DemiBold).build()
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }

                    StyledRect {
                        visible: root.openTodoCount > 0
                        Layout.fillWidth: false
                        Layout.preferredHeight: Math.round(20 * root.s)
                        Layout.preferredWidth: Math.round(weekTaskText.implicitWidth + Math.round(12 * root.s))
                        clip: true
                        radius: Math.round(10 * root.s)
                        color: shell.secondaryContainerTint

                        StyledText {
                            id: weekTaskText

                            anchors.centerIn: parent
                            text: qsTr("%1 due").arg(root.openTodoCount)
                            font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.82)).weight(Font.DemiBold).build()
                            color: Colours.palette.m3onSecondaryContainer
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    columns: 7
                    columnSpacing: Math.max(1, Math.round(2 * root.s))

                    Repeater {
                        model: 7

                        delegate: ColumnLayout {
                            id: wkCol

                            required property int index
                            readonly property var cell: root.weekDayCell(index)

                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            implicitWidth: Math.round(22 * root.s)
                            spacing: Math.max(2, Math.round(4 * root.s))

                            StyledText {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                horizontalAlignment: Text.AlignHCenter
                                text: wkCol.cell.shortName
                                font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.82)).weight(wkCol.cell.isToday ? Font.Bold : Font.Medium).build()
                                color: wkCol.cell.isToday
                                    ? Colours.palette.m3primary
                                    : (wkCol.cell.isWeekend ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant)
                                elide: Text.ElideRight
                            }

                            Item {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: Math.round(22 * root.s)
                                Layout.preferredHeight: Math.round(22 * root.s)

                                MaterialShape {
                                    anchors.fill: parent
                                    implicitSize: Math.round(22 * root.s)
                                    visible: wkCol.cell.isToday
                                    shape: MaterialShape.Sunny
                                    color: shell.primaryAccentTint
                                }

                                StyledText {
                                    anchors.centerIn: parent
                                    text: String(wkCol.cell.day)
                                    font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.86)).weight(wkCol.cell.isToday ? Font.Bold : Font.Medium).build()
                                    color: wkCol.cell.isToday
                                        ? Colours.palette.m3onPrimary
                                        : (wkCol.cell.isWeekend ? Colours.palette.m3tertiary : Colours.palette.m3onSurface)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 2x2 Full Native Dash Month Grid
    Component {
        id: layout2x2

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            spacing: Math.max(3, Math.round(Tokens.spacing.small * root.s))

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Math.max(2, Math.round(Tokens.spacing.extraSmall * root.s))

                StyledRect {
                    Layout.fillWidth: false
                    Layout.preferredWidth: Math.round(26 * root.s)
                    Layout.preferredHeight: Math.round(26 * root.s)
                    radius: Math.round(13 * root.s)
                    color: shell.innerSurfaceStrong
                    border.width: 1
                    border.color: shell.innerBorder

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "chevron_left"
                        fontStyle: Tokens.font.icon.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.96)).build()
                        color: Colours.palette.m3onSurface
                    }

                    StateLayer {
                        enabled: root.locked
                        radius: parent.radius
                        onClicked: root.monthOffset -= 1
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredHeight: Math.round(26 * root.s)
                    clip: true
                    radius: Math.round(13 * root.s)
                    color: root.monthOffset !== 0 ? shell.secondaryContainerTint : "transparent"

                    StyledText {
                        anchors.centerIn: parent
                        width: Math.max(0, parent.width - Math.round(8 * root.s))
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.formatDate(root.displayDate, "MMMM yyyy")
                        font: Tokens.font.title.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.96)).weight(Font.DemiBold).build()
                        color: root.monthOffset !== 0 ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    StateLayer {
                        enabled: root.locked
                        radius: parent.radius
                        onClicked: root.jumpToToday()
                    }
                }

                StyledRect {
                    Layout.fillWidth: false
                    Layout.preferredWidth: Math.round(26 * root.s)
                    Layout.preferredHeight: Math.round(26 * root.s)
                    radius: Math.round(13 * root.s)
                    color: shell.innerSurfaceStrong
                    border.width: 1
                    border.color: shell.innerBorder

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "chevron_right"
                        fontStyle: Tokens.font.icon.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.96)).build()
                        color: Colours.palette.m3onSurface
                    }

                    StateLayer {
                        enabled: root.locked
                        radius: parent.radius
                        onClicked: root.monthOffset += 1
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                columns: 7
                columnSpacing: 1

                Repeater {
                    model: ["M", "T", "W", "T", "F", "S", "S"]

                    delegate: StyledText {
                        id: wdHeader

                        required property string modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.92)).weight(Font.Bold).build()
                        color: (index === 5 || index === 6) ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                columns: 7
                rowSpacing: 1
                columnSpacing: 1

                Repeater {
                    model: root.monthCells

                    delegate: Item {
                        id: dayCell

                        required property var modelData

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 0
                        implicitWidth: Math.round(28 * root.s)
                        implicitHeight: Math.round(28 * root.s)
                        clip: true

                        readonly property int badgeSize: Math.max(12, Math.round(Math.min(width, height, 30 * root.s)))

                        MaterialShape {
                            anchors.centerIn: parent
                            width: dayCell.badgeSize
                            height: dayCell.badgeSize
                            implicitSize: dayCell.badgeSize
                            visible: dayCell.modelData.isToday
                            shape: MaterialShape.Sunny
                            color: shell.primaryAccentTint
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: dayCell.badgeSize
                            height: dayCell.badgeSize
                            radius: width / 2
                            visible: !dayCell.modelData.isToday && dayCell.modelData.isSelected
                            color: shell.secondaryContainerTint
                            border.width: 1
                            border.color: Colours.palette.m3secondary
                        }

                        StyledText {
                            anchors.centerIn: parent
                            text: String(dayCell.modelData.day)
                            font: Tokens.font.label.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.88)).weight(dayCell.modelData.isToday || dayCell.modelData.isSelected ? Font.Bold : Font.Medium).build()
                            color: {
                                if (dayCell.modelData.isToday)
                                    return Colours.palette.m3onPrimary;
                                if (dayCell.modelData.isSelected)
                                    return Colours.palette.m3onSecondaryContainer;
                                if (!dayCell.modelData.inMonth)
                                    return Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.38);
                                if (dayCell.modelData.isWeekend)
                                    return Colours.palette.m3tertiary;
                                return Colours.palette.m3onSurface;
                            }
                        }

                        StateLayer {
                            enabled: root.locked
                            radius: dayCell.badgeSize / 2
                            onClicked: {
                                root.selectedYear = dayCell.modelData.year;
                                root.selectedMonth = dayCell.modelData.month;
                                root.selectedDay = dayCell.modelData.day;
                            }
                        }
                    }
                }
            }
        }
    }
}

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
    property string surfaceStyle: ""
    property bool blurEnabled: Config.background.desktopWidgets.blur
    property real plateOpacity: Config.background.desktopWidgets.opacity
    property var widgetOptions: ({})

    readonly property real s: WidgetMetrics.scale
    property int monthOffset: 0
    property int selectedYear: todayYear
    property int selectedMonth: todayMonth
    property int selectedDay: todayDay

    readonly property date nowDate: Time.date
    readonly property int todayYear: nowDate.getFullYear()
    readonly property int todayMonth: nowDate.getMonth()
    readonly property int todayDay: nowDate.getDate()

    readonly property date displayDate: new Date(todayYear, todayMonth + monthOffset, 1)
    readonly property int viewYear: displayDate.getFullYear()
    readonly property int viewMonth: displayDate.getMonth()
    readonly property int firstOffset: (displayDate.getDay() + 6) % 7
    readonly property int daysInMonth: new Date(viewYear, viewMonth + 1, 0).getDate()

    readonly property date selectedDateObj: new Date(selectedYear, selectedMonth, selectedDay)
    readonly property bool selectedIsToday: selectedYear === todayYear && selectedMonth === todayMonth && selectedDay === todayDay
    readonly property int dayOfYear: Math.floor((nowDate - new Date(todayYear, 0, 0)) / 86400000)

    readonly property int openTodoCount: {
        const list = NotesStore.todos ?? [];
        let c = 0;
        for (let i = 0; i < list.length; i++) {
            if (!list[i].done)
                c++;
        }
        return c;
    }

    readonly property var topTodos: {
        const list = NotesStore.getSortedTodos ? NotesStore.getSortedTodos() : (NotesStore.todos ?? []);
        const out = [];
        for (let i = 0; i < list.length && out.length < 3; i++) {
            if (!list[i].done)
                out.push(list[i]);
        }
        return out;
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

    implicitWidth: WidgetMetrics.widthFor(sizeMode, s)
    implicitHeight: WidgetMetrics.heightFor(sizeMode, "calendar", s)

    WidgetCardShell {
        id: shell

        anchors.fill: parent
        widgetType: "calendar"
        sizeMode: root.sizeMode
        outerShape: root.widgetOptions?.outerShape ?? ""
        wallpaper: root.wallpaper
        weActive: root.weActive
        surfaceStyle: root.surfaceStyle
        blurEnabled: root.blurEnabled
        plateOpacity: root.plateOpacity
        scaleFactor: root.s

        // 1x1 Expressive Shaped Tile
        Item {
            anchors.fill: parent
            anchors.topMargin: shell.topPadding
            anchors.bottomMargin: shell.bottomPadding
            anchors.leftMargin: shell.sidePadding
            anchors.rightMargin: shell.sidePadding
            visible: root.sizeMode === "1x1"

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Math.round(2 * root.s)

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDate(root.nowDate, "ddd").toUpperCase()
                    font: Tokens.font.label.builders.small.scale(root.s).letterSpacing(1.5).weight(Font.Bold).build()
                    color: Colours.palette.m3primary
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: String(root.todayDay)
                    font: Tokens.font.clock.size(Math.round(46 * root.s)).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDate(root.nowDate, "MMM yyyy")
                    font: Tokens.font.label.builders.small.scale(Math.max(0.85, root.s * 0.92)).build()
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }

        // 1x2 Date Hero + Non-Overlapping 7-Day Week Strip
        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "1x2"
            spacing: Math.round(Tokens.spacing.medium * root.s)

            ColumnLayout {
                Layout.preferredWidth: Math.round(82 * root.s)
                Layout.alignment: Qt.AlignVCenter
                spacing: Math.round(2 * root.s)

                StyledText {
                    text: Qt.formatDate(root.nowDate, "dddd").toUpperCase()
                    font: Tokens.font.label.builders.small.scale(Math.max(0.82, root.s * 0.9)).letterSpacing(1.2).weight(Font.Bold).build()
                    color: Colours.palette.m3primary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                StyledText {
                    text: String(root.todayDay)
                    font: Tokens.font.clock.size(Math.round(40 * root.s)).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    text: Qt.formatDate(root.nowDate, "MMM yyyy")
                    font: Tokens.font.label.builders.small.scale(Math.max(0.85, root.s * 0.92)).build()
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                Layout.topMargin: Math.round(8 * root.s)
                Layout.bottomMargin: Math.round(8 * root.s)
                color: Qt.alpha(Colours.palette.m3outlineVariant, 0.45)
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: Math.round(6 * root.s)

                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        text: qsTr("This Week")
                        font: Tokens.font.label.builders.small.scale(root.s).weight(Font.DemiBold).build()
                        color: Colours.palette.m3onSurfaceVariant
                        Layout.fillWidth: true
                    }

                    StyledRect {
                        visible: root.openTodoCount > 0
                        Layout.preferredHeight: Math.round(20 * root.s)
                        Layout.preferredWidth: Math.round(weekTaskText.implicitWidth + 14 * root.s)
                        radius: Math.round(10 * root.s)
                        color: Colours.palette.m3secondaryContainer

                        StyledText {
                            id: weekTaskText

                            anchors.centerIn: parent
                            text: qsTr("%1 due").arg(root.openTodoCount)
                            font: Tokens.font.label.builders.small.scale(Math.max(0.8, root.s * 0.85)).weight(Font.DemiBold).build()
                            color: Colours.palette.m3onSecondaryContainer
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: Math.round(2 * root.s)

                    Repeater {
                        model: 7

                        delegate: ColumnLayout {
                            id: wkCol

                            required property int index
                            readonly property var cell: root.weekDayCell(index)

                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: Math.round(4 * root.s)

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: wkCol.cell.shortName
                                font: Tokens.font.label.builders.small.scale(Math.max(0.8, root.s * 0.85)).weight(wkCol.cell.isToday ? Font.Bold : Font.Medium).build()
                                color: wkCol.cell.isToday
                                    ? Colours.palette.m3primary
                                    : (wkCol.cell.isWeekend ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant)
                            }

                            Item {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: Math.round(24 * root.s)
                                Layout.preferredHeight: Math.round(24 * root.s)

                                MaterialShape {
                                    anchors.fill: parent
                                    visible: wkCol.cell.isToday
                                    shape: MaterialShape.Sunny
                                    color: Colours.palette.m3primary
                                }

                                StyledText {
                                    anchors.centerIn: parent
                                    text: String(wkCol.cell.day)
                                    font: Tokens.font.label.builders.small.scale(Math.max(0.82, root.s * 0.9)).weight(wkCol.cell.isToday ? Font.Bold : Font.Medium).build()
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

        // 2x1 Tall Date Pillar + Agenda Glance
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "2x1"
            spacing: Math.round(Tokens.spacing.medium * root.s)

            WidgetHeader {
                Layout.fillWidth: true
                title: Qt.formatDate(root.nowDate, "MMM yyyy")
                icon: "calendar_today"
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(108 * root.s)

                MaterialShape {
                    anchors.centerIn: parent
                    width: Math.round(104 * root.s)
                    height: Math.round(104 * root.s)
                    shape: MaterialShape.Cookie9Sided
                    color: Colours.palette.m3primaryContainer
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.formatDate(root.nowDate, "ddd").toUpperCase()
                        font: Tokens.font.label.builders.small.scale(Math.max(0.85, root.s * 0.9)).letterSpacing(1.2).weight(Font.Bold).build()
                        color: Colours.palette.m3onPrimaryContainer
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: String(root.todayDay)
                        font: Tokens.font.clock.size(Math.round(36 * root.s)).weight(Font.Bold).build()
                        color: Colours.palette.m3onPrimaryContainer
                    }
                }
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
                    anchors.margins: Math.round(Tokens.padding.medium * root.s)
                    spacing: Math.round(4 * root.s)

                    StyledText {
                        text: root.openTodoCount > 0 ? qsTr("%1 Open Tasks").arg(root.openTodoCount) : qsTr("All Clear")
                        font: Tokens.font.label.builders.small.scale(root.s).weight(Font.DemiBold).build()
                        color: root.openTodoCount > 0 ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                    }

                    Repeater {
                        model: root.topTodos

                        delegate: RowLayout {
                            id: tallTodoRow

                            required property var modelData

                            Layout.fillWidth: true
                            spacing: 6

                            MaterialIcon {
                                text: "radio_button_unchecked"
                                fontStyle: Tokens.font.icon.builders.small.scale(0.85 * root.s).build()
                                color: Colours.palette.m3primary
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: tallTodoRow.modelData.text ?? ""
                                font: Tokens.font.body.builders.small.scale(Math.max(0.85, root.s * 0.9)).build()
                                color: Colours.palette.m3onSurface
                                elide: Text.ElideRight
                            }
                        }
                    }

                    StyledText {
                        visible: root.topTodos.length === 0
                        text: qsTr("Day %1 of %2").arg(root.dayOfYear).arg(root.todayYear)
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurfaceVariant
                        Layout.fillWidth: true
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
        }

        // 2x2 Full Native Dash Month Grid + 2x3 Split Agenda Panel
        RowLayout {
            anchors.fill: parent
            anchors.topMargin: shell.topPadding
            anchors.bottomMargin: shell.bottomPadding
            anchors.leftMargin: shell.sidePadding
            anchors.rightMargin: shell.sidePadding
            visible: root.sizeMode === "2x2" || root.sizeMode === "2x3"
            spacing: Math.round(Tokens.spacing.large * root.s)

            ColumnLayout {
                id: monthGridPane

                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Math.round((shell.isShaped ? Tokens.spacing.extraSmall : Tokens.spacing.small) * root.s)

                // Month header with directional nav + tap-to-Today pill
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    StyledRect {
                        Layout.preferredWidth: Math.round((shell.isShaped ? 24 : 28) * root.s)
                        Layout.preferredHeight: Math.round((shell.isShaped ? 24 : 28) * root.s)
                        radius: Math.round((shell.isShaped ? 12 : 14) * root.s)
                        color: WidgetMetrics.innerSurfaceStrong
                        border.width: 1
                        border.color: WidgetMetrics.innerBorder

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "chevron_left"
                            fontStyle: Tokens.font.icon.builders.small.scale(root.s * (shell.isShaped ? 0.9 : 1.0)).build()
                            color: Colours.palette.m3onSurface
                        }

                        StateLayer {
                            enabled: root.locked
                            onClicked: root.monthOffset -= 1
                        }
                    }

                    StyledRect {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round((shell.isShaped ? 24 : 28) * root.s)
                        radius: Math.round((shell.isShaped ? 12 : 14) * root.s)
                        color: root.monthOffset !== 0 ? Colours.palette.m3secondaryContainer : "transparent"

                        StyledText {
                            anchors.centerIn: parent
                            width: parent.width - 8
                            horizontalAlignment: Text.AlignHCenter
                            text: Qt.formatDate(root.displayDate, shell.isShaped ? "MMM yyyy" : "MMMM yyyy")
                            font: Tokens.font.title.builders.small.scale(root.s * (shell.isShaped ? 0.88 : 1.0)).weight(Font.DemiBold).build()
                            color: root.monthOffset !== 0 ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        StateLayer {
                            enabled: root.locked
                            onClicked: root.jumpToToday()
                        }
                    }

                    StyledRect {
                        Layout.preferredWidth: Math.round((shell.isShaped ? 24 : 28) * root.s)
                        Layout.preferredHeight: Math.round((shell.isShaped ? 24 : 28) * root.s)
                        radius: Math.round((shell.isShaped ? 12 : 14) * root.s)
                        color: WidgetMetrics.innerSurfaceStrong
                        border.width: 1
                        border.color: WidgetMetrics.innerBorder

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "chevron_right"
                            fontStyle: Tokens.font.icon.builders.small.scale(root.s * (shell.isShaped ? 0.9 : 1.0)).build()
                            color: Colours.palette.m3onSurface
                        }

                        StateLayer {
                            enabled: root.locked
                            onClicked: root.monthOffset += 1
                        }
                    }
                }

                // Weekday headers
                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: 1

                    Repeater {
                        model: ["M", "T", "W", "T", "F", "S", "S"]

                        delegate: StyledText {
                            id: wdHeader

                            required property string modelData
                            required property int index

                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            font: Tokens.font.label.builders.small.scale(root.s * (shell.isShaped ? 0.86 : 1.0)).weight(Font.Bold).build()
                            color: (index === 5 || index === 6) ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant
                        }
                    }
                }

                // 6x7 day matrix with MaterialShape.Sunny Today highlight
                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
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

                            readonly property real badgeSize: Math.min(width, height, Math.round((shell.isShaped ? 26 : 32) * root.s))

                            MaterialShape {
                                anchors.centerIn: parent
                                width: dayCell.badgeSize
                                height: dayCell.badgeSize
                                visible: dayCell.modelData.isToday
                                shape: MaterialShape.Sunny
                                color: Colours.palette.m3primary
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: dayCell.badgeSize
                                height: dayCell.badgeSize
                                radius: width / 2
                                visible: !dayCell.modelData.isToday && dayCell.modelData.isSelected
                                color: Colours.palette.m3secondaryContainer
                                border.width: 1
                                border.color: Colours.palette.m3secondary
                            }

                            StyledText {
                                anchors.centerIn: parent
                                text: String(dayCell.modelData.day)
                                font: Tokens.font.label.builders.medium.scale(Math.max(0.78, root.s * (shell.isShaped ? 0.84 : 0.92))).weight(dayCell.modelData.isToday || dayCell.modelData.isSelected ? Font.Bold : Font.Medium).build()
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

            // 2x3 Right Agenda & Selected Day Detail Panel
            StyledRect {
                visible: root.sizeMode === "2x3"
                Layout.preferredWidth: Math.round(166 * root.s)
                Layout.fillHeight: true
                radius: Tokens.rounding.extraLarge
                color: WidgetMetrics.innerSurface
                border.width: 1
                border.color: WidgetMetrics.innerBorder

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Math.round(Tokens.padding.medium * root.s)
                    spacing: Math.round(Tokens.spacing.small * root.s)

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Math.round(80 * root.s)
                        Layout.preferredHeight: Math.round(80 * root.s)

                        MaterialShape {
                            anchors.fill: parent
                            shape: root.selectedIsToday ? MaterialShape.Sunny : MaterialShape.Cookie9Sided
                            color: root.selectedIsToday ? Colours.palette.m3primaryContainer : Colours.palette.m3secondaryContainer
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 0

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Qt.formatDate(root.selectedDateObj, "ddd").toUpperCase()
                                font: Tokens.font.label.builders.small.scale(Math.max(0.8, root.s * 0.85)).weight(Font.Bold).build()
                                color: root.selectedIsToday ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSecondaryContainer
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: String(root.selectedDay)
                                font: Tokens.font.clock.size(Math.round(28 * root.s)).weight(Font.Bold).build()
                                color: root.selectedIsToday ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSecondaryContainer
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.selectedIsToday ? qsTr("Today") : Qt.formatDate(root.selectedDateObj, "MMM d, yyyy")
                        font: Tokens.font.label.builders.medium.scale(root.s).weight(Font.DemiBold).build()
                        color: root.selectedIsToday ? Colours.palette.m3primary : Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.alpha(Colours.palette.m3outlineVariant, 0.45)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        StyledText {
                            text: qsTr("Open tasks")
                            font: Tokens.font.label.small
                            color: Colours.palette.m3onSurfaceVariant
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: String(root.openTodoCount)
                            font: Tokens.font.label.builders.small.weight(Font.Bold).build()
                            color: Colours.palette.m3primary
                        }
                    }

                    Repeater {
                        model: root.topTodos

                        delegate: RowLayout {
                            id: splitTodoRow

                            required property var modelData

                            Layout.fillWidth: true
                            spacing: 6

                            MaterialIcon {
                                text: "check_circle"
                                fontStyle: Tokens.font.icon.builders.small.scale(0.85).build()
                                color: Colours.palette.m3primary
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: splitTodoRow.modelData.text ?? ""
                                font: Tokens.font.body.small
                                color: Colours.palette.m3onSurface
                                elide: Text.ElideRight
                            }
                        }
                    }

                    StyledText {
                        visible: root.topTodos.length === 0
                        Layout.fillWidth: true
                        text: qsTr("No pending tasks")
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    StyledRect {
                        visible: !root.selectedIsToday || root.monthOffset !== 0
                        Layout.fillWidth: true
                        height: 28
                        radius: 14
                        color: Colours.palette.m3primaryContainer

                        StyledText {
                            anchors.centerIn: parent
                            text: qsTr("Back to today")
                            font: Tokens.font.label.small
                            color: Colours.palette.m3onPrimaryContainer
                        }

                        StateLayer {
                            enabled: root.locked
                            onClicked: root.jumpToToday()
                        }
                    }
                }
            }
        }
    }
}

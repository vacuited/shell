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
    property string surfaceStyle: ""
    property bool blurEnabled: Config.background.desktopWidgets.blur
    property real plateOpacity: Config.background.desktopWidgets.opacity
    property var widgetOptions: ({})

    readonly property real s: Math.max(0.7, Math.min(1.5, Config.background.desktopWidgets.scale ?? 1.0))
    readonly property string todayKey: Qt.formatDate(Time.date, "yyyy-MM-dd")
    property int cycleOffset: 0

    onWidgetOptionsChanged: cycleOffset = 0

    readonly property var countdownList: {
        void FocusLedger.revision;
        return FocusLedger.countdowns || [];
    }

    readonly property bool hasCustom: {
        const d = String(widgetOptions?.customDate ?? "").trim();
        return d !== "" && FocusLedger.parseLocalDate(d) !== null;
    }

    readonly property var activeItem: {
        if (hasCustom) {
            const ttl = String(widgetOptions?.customTitle ?? "").trim();
            return {
                id: "custom",
                title: ttl !== "" ? ttl : Tr.tr("Countdown"),
                date: String(widgetOptions.customDate).trim()
            };
        }
        const list = countdownList;
        if (list.length === 0)
            return { id: "", title: Tr.tr("No countdowns"), date: "" };
        let baseIdx = 0;
        const wantedId = String(widgetOptions?.countdownId ?? "");
        if (wantedId !== "") {
            for (let i = 0; i < list.length; i++) {
                if (list[i] && list[i].id === wantedId) {
                    baseIdx = i;
                    break;
                }
            }
        }
        return list[(baseIdx + cycleOffset) % list.length];
    }

    readonly property string targetTitle: activeItem?.title ?? Tr.tr("Countdown")
    readonly property string targetDate: activeItem?.date ?? ""
    readonly property bool hasValidDate: targetDate !== "" && FocusLedger.parseLocalDate(targetDate) !== null
    readonly property int daysLeft: {
        void root.todayKey;
        return hasValidDate ? FocusLedger.daysUntil(targetDate) : 0;
    }
    readonly property int absDays: Math.abs(daysLeft)
    readonly property int weeksPart: Math.floor(absDays / 7)
    readonly property int remPart: absDays % 7
    readonly property string formattedDate: hasValidDate ? FocusLedger.formatDateShort(targetDate) : Tr.tr("Set date in options")
    readonly property string daysDisplay: {
        if (!hasValidDate) return "--";
        if (daysLeft === 0) return Tr.tr("Today");
        return daysLeft > 0 ? `${daysLeft}d` : `-${absDays}d`;
    }
    readonly property string subCountdownText: {
        if (!hasValidDate) return "";
        if (daysLeft === 0) return Tr.tr("Day of milestone");
        const prefix = daysLeft > 0 ? "" : "-";
        return weeksPart > 0 ? `${prefix}${weeksPart}w ${remPart}d` : `${prefix}${remPart}d`;
    }

    readonly property var allDisplayItems: {
        const list = countdownList ? countdownList.slice() : [];
        const wantedId = String(widgetOptions?.countdownId ?? "");
        if (wantedId !== "" && list.length > 1) {
            const idx = list.findIndex(c => c && c.id === wantedId);
            if (idx > 0) {
                const pinned = list.splice(idx, 1)[0];
                list.unshift(pinned);
            }
        }
        if (hasCustom)
            return [activeItem, ...list];
        return list;
    }

    function cycleNext(): void {
        if (hasCustom || countdownList.length <= 1)
            return;
        cycleOffset = (cycleOffset + 1) % countdownList.length;
    }

    implicitWidth: WidgetMetrics.widthFor(sizeMode, s)
    implicitHeight: WidgetMetrics.heightFor(sizeMode, "countdown", s)

    WidgetCardShell {
        id: shell

        anchors.fill: parent
        widgetType: "countdown"
        sizeMode: root.sizeMode
        outerShape: root.widgetOptions?.outerShape ?? ""
        wallpaper: root.wallpaper
        weActive: root.weActive
        surfaceStyle: root.surfaceStyle
        blurEnabled: root.blurEnabled
        plateOpacity: root.plateOpacity
        scaleFactor: root.s

        // 1x1 Expressive Countdown Tile (tap to cycle when multiple shared countdowns exist)
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
                spacing: Math.round(3 * root.s)

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.targetTitle
                    font: Tokens.font.label.builders.small.scale(Math.max(0.85, root.s * 0.92)).weight(Font.DemiBold).build()
                    color: Colours.palette.m3primary
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.daysDisplay
                    font: Tokens.font.clock.size(Math.round((shell.isShaped ? 24 : 30) * root.s)).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                }

                StyledRect {
                    visible: root.hasValidDate
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: Math.round(18 * root.s)
                    Layout.preferredWidth: Math.min(parent.width, Math.round(tileSubTxt.implicitWidth + 12 * root.s))
                    radius: Math.round(9 * root.s)
                    color: WidgetMetrics.innerSurfaceStrong

                    StyledText {
                        id: tileSubTxt

                        anchors.centerIn: parent
                        width: Math.max(0, parent.width - Math.round(12 * root.s))
                        horizontalAlignment: Text.AlignHCenter
                        text: shell.isShaped ? root.subCountdownText : root.formattedDate
                        font: Tokens.font.label.builders.small.scale(Math.max(0.75, root.s * 0.85)).build()
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }
            }

            StateLayer {
                enabled: root.locked && !root.hasCustom && root.countdownList.length > 1
                radius: shell.isShaped ? width / 2 : shell.radius
                onClicked: root.cycleNext()
            }
        }

        // 1x2 Wide Countdown Strip
        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "1x2"
            spacing: Math.round(Tokens.spacing.medium * root.s)

            Item {
                Layout.preferredWidth: Math.round(96 * root.s)
                Layout.preferredHeight: Math.round(96 * root.s)
                Layout.alignment: Qt.AlignVCenter

                MaterialShape {
                    anchors.fill: parent
                    shape: MaterialShape.Cookie9Sided
                    color: Colours.palette.m3primaryContainer
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.daysDisplay
                        font: Tokens.font.clock.size(Math.round(22 * root.s)).weight(Font.Bold).build()
                        color: Colours.palette.m3onPrimaryContainer
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        visible: root.subCountdownText !== ""
                        text: root.subCountdownText
                        font: Tokens.font.label.builders.small.scale(0.85).build()
                        color: Colours.palette.m3onPrimaryContainer
                    }
                }

                StateLayer {
                    enabled: root.locked && !root.hasCustom && root.countdownList.length > 1
                    radius: width / 2
                    onClicked: root.cycleNext()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Math.round(3 * root.s)

                Item {
                    Layout.fillHeight: true
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.targetTitle
                    font: Tokens.font.title.builders.small.weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.formattedDate
                    font: Tokens.font.label.medium
                    color: Colours.palette.m3primary
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.hasValidDate
                    text: root.daysLeft > 0
                        ? Tr.tr("%1 weeks, %2 days left").arg(root.weeksPart).arg(root.remPart)
                        : (root.daysLeft === 0 ? Tr.tr("Happening today") : Tr.tr("%1 days ago").arg(root.absDays))
                    font: Tokens.font.label.small
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }

                Item {
                    Layout.fillHeight: true
                }
            }
        }

        // 2x1 Tall Tower Countdown Card
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "2x1"
            spacing: Math.round(Tokens.spacing.small * root.s)

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                MaterialIcon {
                    text: "hourglass_top"
                    fontStyle: Tokens.font.icon.small
                    color: Colours.palette.m3primary
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.targetTitle
                    font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Item {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height, Math.round(112 * root.s))
                    height: width

                    MaterialShape {
                        anchors.fill: parent
                        shape: MaterialShape.Sunny
                        color: Colours.palette.m3primaryContainer
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 0

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.daysDisplay
                            font: Tokens.font.clock.size(Math.round(24 * root.s)).weight(Font.Bold).build()
                            color: Colours.palette.m3onPrimaryContainer
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            visible: root.subCountdownText !== ""
                            text: root.subCountdownText
                            font: Tokens.font.label.small
                            color: Colours.palette.m3onPrimaryContainer
                        }
                    }

                    StateLayer {
                        enabled: root.locked && !root.hasCustom && root.countdownList.length > 1
                        radius: width / 2
                        onClicked: root.cycleNext()
                    }
                }
            }

            StyledRect {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(26 * root.s)
                radius: Math.round(13 * root.s)
                color: WidgetMetrics.innerSurfaceStrong

                StyledText {
                    anchors.centerIn: parent
                    text: root.formattedDate
                    font: Tokens.font.label.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }

        // 2x2 All Countdowns Bento Card
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "2x2"
            spacing: Math.round(Tokens.spacing.small * root.s)

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: "event_upcoming"
                    fontStyle: Tokens.font.icon.medium
                    color: Colours.palette.m3primary
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Countdowns")
                    font: Tokens.font.title.small
                    color: Colours.palette.m3onSurface
                }

                StyledRect {
                    visible: root.allDisplayItems.length > 0
                    implicitHeight: 22
                    implicitWidth: cdBadgeCount.implicitWidth + Tokens.padding.small * 2
                    radius: Tokens.rounding.full
                    color: WidgetMetrics.innerSurfaceStrong

                    StyledText {
                        id: cdBadgeCount
                        anchors.centerIn: parent
                        text: `${root.allDisplayItems.length}`
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                StyledText {
                    anchors.centerIn: parent
                    visible: root.allDisplayItems.length === 0
                    text: Tr.tr("Add countdowns in Nexus")
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                Flickable {
                    anchors.fill: parent
                    visible: root.allDisplayItems.length > 0
                    contentWidth: width
                    contentHeight: bentoCol.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    ColumnLayout {
                        id: bentoCol

                        width: parent.width
                        spacing: Math.round(Tokens.spacing.small * root.s)

                        Repeater {
                            model: root.allDisplayItems

                            delegate: StyledRect {
                                id: bentoItem

                                required property var modelData
                                required property int index

                                readonly property int dLeft: {
                                    void root.todayKey;
                                    return FocusLedger.daysUntil(modelData?.date ?? "");
                                }
                                readonly property int aDays: Math.abs(dLeft)
                                readonly property int wPart: Math.floor(aDays / 7)
                                readonly property int rPart: aDays % 7
                                readonly property bool isHero: index === 0

                                Layout.fillWidth: true
                                implicitHeight: Math.round(54 * root.s)
                                radius: Tokens.rounding.large
                                color: WidgetMetrics.innerSurface
                                border.width: 1
                                border.color: WidgetMetrics.innerBorder

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Tokens.padding.small
                                    anchors.rightMargin: Tokens.padding.medium
                                    spacing: Tokens.spacing.small

                                    MaterialShape {
                                        implicitSize: Math.round(34 * root.s)
                                        shape: bentoItem.isHero ? MaterialShape.Sunny : MaterialShape.Cookie6Sided
                                        color: bentoItem.isHero ? Colours.palette.m3primaryContainer : Colours.palette.m3tertiaryContainer

                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            text: bentoItem.isHero ? "school" : "flag"
                                            fontStyle: Tokens.font.icon.small
                                            color: bentoItem.isHero ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onTertiaryContainer
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: bentoItem.modelData?.title ?? ""
                                            font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                                            color: Colours.palette.m3onSurface
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: FocusLedger.formatDateShort(bentoItem.modelData?.date ?? "")
                                            font: Tokens.font.label.small
                                            color: Colours.palette.m3onSurfaceVariant
                                            elide: Text.ElideRight
                                        }
                                    }

                                    ColumnLayout {
                                        spacing: 0

                                        StyledText {
                                            Layout.alignment: Qt.AlignRight
                                            text: bentoItem.dLeft > 0
                                                ? `${bentoItem.dLeft}d`
                                                : (bentoItem.dLeft === 0 ? Tr.tr("Today") : `-${bentoItem.aDays}d`)
                                            font: Tokens.font.title.builders.small.weight(Font.Bold).build()
                                            color: bentoItem.isHero ? Colours.palette.m3primary : Colours.palette.m3tertiary
                                        }

                                        StyledText {
                                            Layout.alignment: Qt.AlignRight
                                            visible: bentoItem.dLeft > 0
                                            text: bentoItem.wPart > 0 ? `${bentoItem.wPart}w ${bentoItem.rPart}d` : `${bentoItem.rPart}d`
                                            font: Tokens.font.label.small
                                            color: Colours.palette.m3onSurfaceVariant
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

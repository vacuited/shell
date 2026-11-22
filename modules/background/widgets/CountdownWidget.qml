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
    readonly property string effectiveSize: WidgetMetrics.fallbackSizeFor("countdown", sizeMode)
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
        if (daysLeft === 0) return Tr.tr("Milestone");
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

    implicitWidth: WidgetMetrics.widthFor(effectiveSize, s)
    implicitHeight: WidgetMetrics.heightFor(effectiveSize, "countdown", s)

    WidgetCardShell {
        id: shell

        anchors.fill: parent
        widgetType: "countdown"
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

    // 1x1 Expressive Countdown Tile (tap to cycle when multiple shared countdowns exist)
    Component {
        id: layout1x1

        Item {
            clip: true

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.max(24, parent.width - shell.sidePadding * 2)
                spacing: Math.max(2, Math.round(3 * root.s))

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    horizontalAlignment: Text.AlignHCenter
                    text: root.targetTitle
                    font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.9)).weight(Font.DemiBold).build()
                    color: Colours.palette.m3primary
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    horizontalAlignment: Text.AlignHCenter
                    text: root.daysDisplay
                    font: Tokens.font.clock.size(Math.max(12, Math.round((shell.isShaped ? 23 : 29) * root.s))).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledRect {
                    visible: root.hasValidDate
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: parent.width
                    Layout.preferredHeight: Math.round(18 * root.s)
                    Layout.preferredWidth: Math.min(parent.width, Math.round(tileSubTxt.implicitWidth + Math.round(12 * root.s)))
                    clip: true
                    radius: Math.round(9 * root.s)
                    color: shell.innerSurfaceStrong

                    StyledText {
                        id: tileSubTxt

                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, Math.max(0, parent.width - Math.round(10 * root.s)))
                        horizontalAlignment: Text.AlignHCenter
                        text: shell.isShaped ? root.subCountdownText : root.formattedDate
                        font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.84)).build()
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }
            }

            StateLayer {
                anchors.fill: parent
                anchors.topMargin: shell.topPadding
                anchors.bottomMargin: shell.bottomPadding
                anchors.leftMargin: shell.sidePadding
                anchors.rightMargin: shell.sidePadding
                enabled: root.locked && !root.hasCustom && root.countdownList.length > 1
                radius: shell.isShaped ? width / 2 : shell.radius
                onClicked: root.cycleNext()
            }
        }
    }

    // 1x2 Wide Countdown Strip
    Component {
        id: layout1x2

        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            spacing: Math.max(6, Math.round(Tokens.spacing.medium * root.s))

            Item {
                id: medallionBox

                Layout.fillWidth: false
                Layout.preferredWidth: Math.round(94 * root.s)
                Layout.preferredHeight: Math.round(94 * root.s)
                Layout.alignment: Qt.AlignVCenter

                MaterialShape {
                    anchors.fill: parent
                    implicitSize: Math.round(94 * root.s)
                    shape: MaterialShape.Cookie9Sided
                    color: shell.primaryContainerTint
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.max(24, medallionBox.width - Math.round(16 * root.s))
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        horizontalAlignment: Text.AlignHCenter
                        text: root.daysDisplay
                        font: Tokens.font.clock.size(Math.max(12, Math.round(21 * root.s))).weight(Font.Bold).build()
                        color: Colours.palette.m3onPrimaryContainer
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        horizontalAlignment: Text.AlignHCenter
                        visible: root.subCountdownText !== ""
                        text: root.subCountdownText
                        font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.84)).build()
                        color: Colours.palette.m3onPrimaryContainer
                        elide: Text.ElideRight
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
                Layout.minimumWidth: 0
                Layout.fillHeight: true
                spacing: Math.max(2, Math.round(3 * root.s))

                Item {
                    Layout.fillHeight: true
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: root.targetTitle
                    font: Tokens.font.title.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.96)).weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: root.formattedDate
                    font: Tokens.font.label.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).build()
                    color: Colours.palette.m3primary
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    visible: root.hasValidDate
                    text: root.daysLeft > 0
                        ? Tr.tr("%1 weeks, %2 days left").arg(root.weeksPart).arg(root.remPart)
                        : (root.daysLeft === 0 ? Tr.tr("Happening today") : Tr.tr("%1 days ago").arg(root.absDays))
                    font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.9)).build()
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }

                Item {
                    Layout.fillHeight: true
                }
            }
        }
    }

    // 2x2 All Countdowns Bento Card
    Component {
        id: layout2x2

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            spacing: Math.max(4, Math.round(Tokens.spacing.small * root.s))

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Math.max(4, Math.round(Tokens.spacing.small * root.s))

                MaterialIcon {
                    text: "event_upcoming"
                    fontStyle: Tokens.font.icon.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.96)).build()
                    color: Colours.palette.m3primary
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: Tr.tr("Countdowns")
                    font: Tokens.font.title.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.96)).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledRect {
                    visible: root.allDisplayItems.length > 0
                    Layout.fillWidth: false
                    Layout.preferredHeight: Math.round(22 * root.s)
                    Layout.preferredWidth: Math.round(cdBadgeCount.implicitWidth + Math.round(Tokens.padding.small * 2 * root.s))
                    radius: Math.round(11 * root.s)
                    color: shell.innerSurfaceStrong

                    StyledText {
                        id: cdBadgeCount

                        anchors.centerIn: parent
                        text: `${root.allDisplayItems.length}`
                        font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.92)).build()
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                StyledText {
                    anchors.centerIn: parent
                    width: Math.max(24, parent.width - Math.round(16 * root.s))
                    horizontalAlignment: Text.AlignHCenter
                    visible: root.allDisplayItems.length === 0
                    text: Tr.tr("Add countdowns in Nexus")
                    font: Tokens.font.body.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).build()
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
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
                        spacing: Math.max(4, Math.round(Tokens.spacing.small * root.s))

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
                                clip: true
                                radius: Math.round(Tokens.rounding.large * Math.min(1.2, Math.max(0.75, root.s)))
                                color: shell.innerSurface
                                border.width: 1
                                border.color: shell.innerBorder

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Math.max(4, Math.round(Tokens.padding.small * root.s))
                                    anchors.rightMargin: Math.max(6, Math.round(Tokens.padding.medium * root.s))
                                    spacing: Math.max(4, Math.round(Tokens.spacing.small * root.s))

                                    MaterialShape {
                                        Layout.fillWidth: false
                                        Layout.preferredWidth: Math.round(34 * root.s)
                                        Layout.preferredHeight: Math.round(34 * root.s)
                                        implicitSize: Math.round(34 * root.s)
                                        shape: bentoItem.isHero ? MaterialShape.Sunny : MaterialShape.Cookie6Sided
                                        color: bentoItem.isHero ? shell.primaryContainerTint : shell.tertiaryContainerTint

                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            text: bentoItem.isHero ? "school" : "flag"
                                            fontStyle: Tokens.font.icon.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).build()
                                            color: bentoItem.isHero ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onTertiaryContainer
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        spacing: 0

                                        StyledText {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            text: bentoItem.modelData?.title ?? ""
                                            font: Tokens.font.body.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).weight(Font.DemiBold).build()
                                            color: Colours.palette.m3onSurface
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            text: FocusLedger.formatDateShort(bentoItem.modelData?.date ?? "")
                                            font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.88)).build()
                                            color: Colours.palette.m3onSurfaceVariant
                                            elide: Text.ElideRight
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: false
                                        spacing: 0

                                        StyledText {
                                            Layout.alignment: Qt.AlignRight
                                            text: bentoItem.dLeft > 0
                                                ? `${bentoItem.dLeft}d`
                                                : (bentoItem.dLeft === 0 ? Tr.tr("Today") : `-${bentoItem.aDays}d`)
                                            font: Tokens.font.title.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.92)).weight(Font.Bold).build()
                                            color: bentoItem.isHero ? Colours.palette.m3primary : Colours.palette.m3tertiary
                                        }

                                        StyledText {
                                            Layout.alignment: Qt.AlignRight
                                            visible: bentoItem.dLeft > 0
                                            text: bentoItem.wPart > 0 ? `${bentoItem.wPart}w ${bentoItem.rPart}d` : `${bentoItem.rPart}d`
                                            font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.86)).build()
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

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import M3Shapes
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.widgets
import qs.services
import "../components"

Item {
    id: root

    required property var wallpaper
    property bool weActive: false
    property bool locked: true
    property string sizeMode: "1x2"
    property string surfaceStyle: ""
    property bool blurEnabled: Config.background.desktopWidgets.blur
    property real plateOpacity: Config.background.desktopWidgets.opacity
    property var widgetOptions: ({})

    readonly property real s: Math.max(0.7, Math.min(1.5, Config.background.desktopWidgets.scale ?? 1.0))
    readonly property string todayKey: Qt.formatDate(Time.date, "yyyy-MM-dd")
    readonly property date todayDate: FocusLedger.parseLocalDate(todayKey) ?? new Date()
    readonly property bool showWeather: (widgetOptions?.showWeather ?? true) !== false
    readonly property bool showBluetooth: (widgetOptions?.showBluetooth ?? true) !== false
    readonly property var activePlayer: Players.recentPlayer ?? Players.active ?? null
    readonly property bool hasMedia: activePlayer !== null && (activePlayer.trackTitle ?? "") !== ""
    readonly property string mediaArt: activePlayer ? Players.getArtUrl(activePlayer) : ""
    readonly property bool mediaPlaying: activePlayer?.isPlaying ?? false

    readonly property var btBatteryDevice: {
        if (!showBluetooth)
            return null;
        const devs = Bluetooth.devices?.values ?? [];
        for (let i = 0; i < devs.length; i++) {
            const d = devs[i];
            if (d && d.connected && d.batteryAvailable)
                return d;
        }
        return null;
    }

    readonly property int openTasks: {
        void NotesStore.version;
        const list = NotesStore.todos ?? [];
        let n = 0;
        for (let i = 0; i < list.length; i++) {
            if (!list[i].done)
                n++;
        }
        return n;
    }

    readonly property string greeting: {
        const h = Time.hours;
        if (h >= 5 && h < 12)
            return Tr.tr("Good morning");
        if (h >= 12 && h < 17)
            return Tr.tr("Good afternoon");
        if (h >= 17 && h < 21)
            return Tr.tr("Good evening");
        return Tr.tr("Good night");
    }

    readonly property string tagline: {
        const lines = [
            Tr.tr("Stay curious, move steady."),
            Tr.tr("Small steps compound daily."),
            Tr.tr("Protect your focus today."),
            Tr.tr("Keep what matters in front of you.")
        ];
        return lines[Math.floor(Time.hours / 6) % lines.length];
    }

    Component.onCompleted: {
        if (showWeather && !Weather.cc)
            Weather.reload();
    }

    implicitWidth: WidgetMetrics.widthFor(sizeMode, s)
    implicitHeight: WidgetMetrics.heightFor(sizeMode, "atAGlance", s)

    WidgetCardShell {
        id: shell

        anchors.fill: parent
        widgetType: "atAGlance"
        sizeMode: root.sizeMode
        forceRounded: true
        wallpaper: root.wallpaper
        weActive: root.weActive
        surfaceStyle: root.surfaceStyle
        blurEnabled: root.blurEnabled
        plateOpacity: root.plateOpacity
        scaleFactor: root.s

        // 1x2 Wide Horizon Bar
        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "1x2"
            spacing: Math.round(Tokens.spacing.medium * root.s)

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    MaterialShape {
                        Layout.preferredWidth: Math.round(24 * root.s)
                        Layout.preferredHeight: Math.round(24 * root.s)
                        implicitSize: Math.round(24 * root.s)
                        shape: MaterialShape.Sunny
                        color: Colours.palette.m3primaryContainer

                        StyledText {
                            anchors.centerIn: parent
                            text: String(root.todayDate.getDate())
                            font: Tokens.font.label.builders.small.scale(0.85).weight(Font.Bold).build()
                            color: Colours.palette.m3onPrimaryContainer
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Qt.formatDate(root.todayDate, "ddd, MMM d")
                        font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
                        color: Colours.palette.m3primary
                        elide: Text.ElideRight
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.greeting
                    font: Tokens.font.title.builders.medium.scale(root.s).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.hasMedia ? ("♪ " + root.activePlayer.trackTitle) : (root.openTasks > 0 ? Tr.tr("%1 tasks waiting").arg(root.openTasks) : root.tagline)
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            StyledRect {
                visible: root.showWeather
                Layout.preferredWidth: Math.round(92 * root.s)
                Layout.fillHeight: true
                radius: Tokens.rounding.extraLarge
                color: WidgetMetrics.innerSurface
                border.width: 1
                border.color: WidgetMetrics.innerBorder

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - 12
                    spacing: 2

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: Weather.icon || "partly_cloudy_day"
                        fontStyle: Tokens.font.icon.builders.large.scale(root.s).build()
                        color: Colours.palette.m3primary
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Weather.cc ? Weather.temp : "--°"
                        font: Tokens.font.clock.size(Math.round(20 * root.s)).weight(Font.Bold).build()
                        color: Colours.palette.m3onSurface
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.btBatteryDevice
                            ? (Math.round((root.btBatteryDevice.battery ?? 0) * 100) + "% BT")
                            : (Weather.description || "")
                        font: Tokens.font.label.builders.small.scale(0.85).build()
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }

                StateLayer {
                    enabled: root.locked
                    radius: parent.radius
                    onClicked: Weather.reload()
                }
            }
        }

        // 2x1 Tall Daily Digest Pillar
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "2x1"
            spacing: Math.round(Tokens.spacing.small * root.s)

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                MaterialShape {
                    Layout.preferredWidth: Math.round(28 * root.s)
                    Layout.preferredHeight: Math.round(28 * root.s)
                    implicitSize: Math.round(28 * root.s)
                    shape: MaterialShape.Sunny
                    color: Colours.palette.m3primary

                    StyledText {
                        anchors.centerIn: parent
                        text: String(root.todayDate.getDate())
                        font: Tokens.font.label.builders.small.weight(Font.Bold).build()
                        color: Colours.palette.m3onPrimary
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Qt.formatDate(root.todayDate, "ddd, MMM d")
                    font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.greeting
                font: Tokens.font.title.builders.small.scale(root.s).weight(Font.Bold).build()
                color: Colours.palette.m3onSurface
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.fillWidth: true
                text: root.tagline
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurfaceVariant
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Item {
                Layout.fillHeight: true
            }

            StyledRect {
                visible: root.btBatteryDevice !== null
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(30 * root.s)
                radius: Math.round(15 * root.s)
                color: Colours.palette.m3secondaryContainer

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 6

                    MaterialIcon {
                        text: "bluetooth_connected"
                        fontStyle: Tokens.font.icon.small
                        color: Colours.palette.m3onSecondaryContainer
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: (root.btBatteryDevice?.name ?? "") + " " + Math.round((root.btBatteryDevice?.battery ?? 0) * 100) + "%"
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSecondaryContainer
                        elide: Text.ElideRight
                    }
                }
            }

            StyledRect {
                visible: root.showWeather
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(64 * root.s)
                radius: Tokens.rounding.large
                color: WidgetMetrics.innerSurface
                border.width: 1
                border.color: WidgetMetrics.innerBorder

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    MaterialIcon {
                        text: Weather.icon || "partly_cloudy_day"
                        fontStyle: Tokens.font.icon.large
                        color: Colours.palette.m3primary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            text: Weather.cc ? Weather.temp : "--°"
                            font: Tokens.font.clock.size(Math.round(18 * root.s)).weight(Font.Bold).build()
                            color: Colours.palette.m3onSurface
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Weather.description || Tr.tr("Weather")
                            font: Tokens.font.label.small
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // 2x2 Square Dashboard-At-A-Glance
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "2x2"
            spacing: Math.round(Tokens.spacing.small * root.s)

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialShape {
                    Layout.preferredWidth: Math.round(32 * root.s)
                    Layout.preferredHeight: Math.round(32 * root.s)
                    implicitSize: Math.round(32 * root.s)
                    shape: MaterialShape.Sunny
                    color: Colours.palette.m3primaryContainer

                    StyledText {
                        anchors.centerIn: parent
                        text: String(root.todayDate.getDate())
                        font: Tokens.font.label.builders.medium.weight(Font.Bold).build()
                        color: Colours.palette.m3onPrimaryContainer
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: Qt.formatDate(root.todayDate, "dddd, MMM d")
                        font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
                        color: Colours.palette.m3primary
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.openTasks > 0 ? Tr.tr("%1 tasks open").arg(root.openTasks) : Tr.tr("Schedule clear")
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }

                StyledRect {
                    visible: root.btBatteryDevice !== null
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: Math.round(btSqText.implicitWidth + 24)
                    radius: 12
                    color: Colours.palette.m3secondaryContainer

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialIcon {
                            text: "headphones"
                            fontStyle: Tokens.font.icon.small
                            color: Colours.palette.m3onSecondaryContainer
                        }

                        StyledText {
                            id: btSqText

                            text: Math.round((root.btBatteryDevice?.battery ?? 0) * 100) + "%"
                            font: Tokens.font.label.small
                            color: Colours.palette.m3onSecondaryContainer
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.greeting
                font: Tokens.font.headline.builders.small.scale(root.s).weight(Font.Bold).build()
                color: Colours.palette.m3onSurface
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.tagline
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurfaceVariant
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Item {
                Layout.fillHeight: true
            }

            // Now playing mini strip (always fits cleanly)
            StyledRect {
                visible: root.hasMedia
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(52 * root.s)
                radius: Tokens.rounding.large
                color: WidgetMetrics.innerSurface
                border.width: 1
                border.color: WidgetMetrics.innerBorder

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    CoverArt {
                        Layout.preferredWidth: Math.round(36 * root.s)
                        Layout.preferredHeight: Math.round(36 * root.s)
                        source: root.mediaArt
                        spinning: root.visible && root.sizeMode === "2x2" && root.mediaPlaying && !GameMode.enabled
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: root.activePlayer?.trackTitle ?? ""
                            font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.activePlayer?.trackArtist ?? ""
                            font: Tokens.font.label.small
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }

                    IconButton {
                        icon: root.mediaPlaying ? "pause" : "play_arrow"
                        type: IconButton.Tonal
                        isRound: true
                        onClicked: root.activePlayer?.togglePlaying()
                    }
                }
            }

            // Weather bar
            StyledRect {
                visible: root.showWeather
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(54 * root.s)
                radius: Tokens.rounding.large
                color: WidgetMetrics.innerSurface
                border.width: 1
                border.color: WidgetMetrics.innerBorder

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    MaterialShape {
                        Layout.preferredWidth: Math.round(34 * root.s)
                        Layout.preferredHeight: Math.round(34 * root.s)
                        implicitSize: Math.round(34 * root.s)
                        shape: MaterialShape.Puffy
                        color: Colours.palette.m3primaryContainer

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: Weather.icon || "partly_cloudy_day"
                            fontStyle: Tokens.font.icon.medium
                            color: Colours.palette.m3onPrimaryContainer
                        }
                    }

                    StyledText {
                        text: Weather.cc ? Weather.temp : "--°"
                        font: Tokens.font.clock.size(Math.round(22 * root.s)).weight(Font.Bold).build()
                        color: Colours.palette.m3onSurface
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: Weather.description || Tr.tr("Weather")
                            font: Tokens.font.label.builders.medium.weight(Font.Medium).build()
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Weather.city || ""
                            font: Tokens.font.label.small
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }
                }

                StateLayer {
                    enabled: root.locked
                    radius: parent.radius
                    onClicked: Weather.reload()
                }
            }
        }

        // 1x3 Ultra-Wide Summary Strip & 2x3 Panorama Brief
        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "1x3" || root.sizeMode === "2x3"
            spacing: Math.round(Tokens.spacing.large * root.s)

            // Left: Date badge + Greeting + Tagline + Tasks pill
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Math.round(Tokens.spacing.small * root.s)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialShape {
                        Layout.preferredWidth: Math.round(34 * root.s)
                        Layout.preferredHeight: Math.round(34 * root.s)
                        implicitSize: Math.round(34 * root.s)
                        shape: MaterialShape.Sunny
                        color: Colours.palette.m3primaryContainer

                        StyledText {
                            anchors.centerIn: parent
                            text: String(root.todayDate.getDate())
                            font: Tokens.font.label.builders.medium.weight(Font.Bold).build()
                            color: Colours.palette.m3onPrimaryContainer
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: Qt.formatDate(root.todayDate, "dddd, MMMM d")
                            font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
                            color: Colours.palette.m3primary
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.openTasks > 0 ? Tr.tr("%1 pending tasks").arg(root.openTasks) : Tr.tr("All tasks complete")
                            font: Tokens.font.label.small
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.greeting
                    font: Tokens.font.headline.builders.medium.scale(root.s).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.tagline
                    font: Tokens.font.body.medium
                    color: Colours.palette.m3onSurfaceVariant
                    wrapMode: Text.WordWrap
                    maximumLineCount: root.sizeMode === "2x3" ? 3 : 2
                    elide: Text.ElideRight
                }

                Item {
                    Layout.fillHeight: true
                }

                StyledRect {
                    visible: root.sizeMode === "2x3" && root.btBatteryDevice !== null
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(34 * root.s)
                    radius: Math.round(17 * root.s)
                    color: Colours.palette.m3secondaryContainer

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        MaterialIcon {
                            text: "bluetooth_connected"
                            fontStyle: Tokens.font.icon.small
                            color: Colours.palette.m3onSecondaryContainer
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: (root.btBatteryDevice?.name ?? "") + " · " + Math.round((root.btBatteryDevice?.battery ?? 0) * 100) + "%"
                            font: Tokens.font.label.medium
                            color: Colours.palette.m3onSecondaryContainer
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // Right: Weather + Now Playing tiles
            ColumnLayout {
                Layout.preferredWidth: Math.round(204 * root.s)
                Layout.fillHeight: true
                spacing: Math.round(Tokens.spacing.small * root.s)

                StyledRect {
                    visible: root.showWeather
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Tokens.rounding.extraLarge
                    color: WidgetMetrics.innerSurface
                    border.width: 1
                    border.color: WidgetMetrics.innerBorder

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Math.round(12 * root.s)
                        spacing: 10

                        MaterialShape {
                            Layout.preferredWidth: Math.round(42 * root.s)
                            Layout.preferredHeight: Math.round(42 * root.s)
                            implicitSize: Math.round(42 * root.s)
                            shape: MaterialShape.Puffy
                            color: Colours.palette.m3primaryContainer

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: Weather.icon || "partly_cloudy_day"
                                fontStyle: Tokens.font.icon.large
                                color: Colours.palette.m3onPrimaryContainer
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                text: Weather.cc ? Weather.temp : "--°"
                                font: Tokens.font.clock.size(Math.round(24 * root.s)).weight(Font.Bold).build()
                                color: Colours.palette.m3onSurface
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: (Weather.description || Tr.tr("Weather")) + (Weather.city ? (" · " + Weather.city) : "")
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }
                    }

                    StateLayer {
                        enabled: root.locked
                        radius: parent.radius
                        onClicked: Weather.reload()
                    }
                }

                StyledRect {
                    visible: root.sizeMode === "2x3" || (root.sizeMode === "1x3" && !root.showWeather)
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Tokens.rounding.extraLarge
                    color: WidgetMetrics.innerSurface
                    border.width: 1
                    border.color: WidgetMetrics.innerBorder

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Math.round(12 * root.s)
                        spacing: 10

                        CoverArt {
                            Layout.preferredWidth: Math.round(44 * root.s)
                            Layout.preferredHeight: Math.round(44 * root.s)
                            source: root.mediaArt
                            spinning: root.visible && (root.sizeMode === "1x3" || root.sizeMode === "2x3") && root.mediaPlaying && !GameMode.enabled
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: root.hasMedia ? root.activePlayer.trackTitle : Tr.tr("No playback")
                                font: Tokens.font.label.builders.medium.weight(Font.Bold).build()
                                color: Colours.palette.m3onSurface
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.hasMedia ? (root.activePlayer.trackArtist || Tr.tr("Artist")) : Tr.tr("Audio idle")
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }

                        IconButton {
                            visible: root.hasMedia
                            icon: root.mediaPlaying ? "pause" : "play_arrow"
                            type: IconButton.Tonal
                            isRound: true
                            onClicked: root.activePlayer?.togglePlaying()
                        }
                    }
                }
            }
        }
    }
}

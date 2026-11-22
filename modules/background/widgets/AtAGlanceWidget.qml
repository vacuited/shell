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
    property real widgetScale: WidgetMetrics.scale
    property string surfaceStyle: ""
    property bool blurEnabled: Config.background.desktopWidgets.blur
    property real plateOpacity: Config.background.desktopWidgets.opacity
    property var widgetOptions: ({})

    readonly property real s: Math.max(0.55, Math.min(2.2, widgetScale > 0 ? widgetScale : WidgetMetrics.scale))
    readonly property string effectiveSize: WidgetMetrics.fallbackSizeFor("atAGlance", sizeMode)
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

    implicitWidth: WidgetMetrics.widthFor(effectiveSize, s)
    implicitHeight: WidgetMetrics.heightFor(effectiveSize, "atAGlance", s)

    WidgetCardShell {
        id: shell

        anchors.fill: parent
        widgetType: "atAGlance"
        sizeMode: root.effectiveSize
        forceRounded: true
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
                case "2x2":
                    return layout2x2;
                case "1x3":
                    return layout1x3;
                default:
                    return layout1x2;
                }
            }
        }
    }

    // 1x2 Wide Horizon Bar
    Component {
        id: layout1x2

        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            spacing: Math.max(6, Math.round(Tokens.spacing.medium * root.s))

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter
                spacing: Math.max(2, Math.round(3 * root.s))

                RowLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: Math.max(4, Math.round(6 * root.s))

                    MaterialShape {
                        Layout.fillWidth: false
                        Layout.preferredWidth: Math.round(24 * root.s)
                        Layout.preferredHeight: Math.round(24 * root.s)
                        implicitSize: Math.round(24 * root.s)
                        shape: MaterialShape.Sunny
                        color: shell.primaryContainerTint

                        StyledText {
                            anchors.centerIn: parent
                            text: String(root.todayDate.getDate())
                            font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.85)).weight(Font.Bold).build()
                            color: Colours.palette.m3onPrimaryContainer
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: Qt.formatDate(root.todayDate, "ddd, MMM d")
                        font: Tokens.font.label.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).weight(Font.DemiBold).build()
                        color: Colours.palette.m3primary
                        elide: Text.ElideRight
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: root.greeting
                    font: Tokens.font.title.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.96)).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: root.hasMedia ? ("♪ " + root.activePlayer.trackTitle) : (root.openTasks > 0 ? Tr.tr("%1 tasks waiting").arg(root.openTasks) : root.tagline)
                    font: Tokens.font.body.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).build()
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            StyledRect {
                visible: root.showWeather
                Layout.fillWidth: false
                Layout.preferredWidth: Math.round(92 * root.s)
                Layout.maximumWidth: Math.round(96 * root.s)
                Layout.fillHeight: true
                clip: true
                radius: Math.round(Tokens.rounding.extraLarge * Math.min(1.2, Math.max(0.75, root.s)))
                color: shell.innerSurface
                border.width: 1
                border.color: shell.innerBorder

                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.max(0, parent.width - Math.round(12 * root.s))
                    spacing: Math.max(1, Math.round(2 * root.s))

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: Weather.icon || "partly_cloudy_day"
                        fontStyle: Tokens.font.icon.builders.large.scale(WidgetMetrics.safeFontScale(root.s, 0.96)).build()
                        color: Colours.palette.m3primary
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        horizontalAlignment: Text.AlignHCenter
                        text: Weather.cc ? Weather.temp : "--°"
                        font: Tokens.font.clock.size(Math.max(12, Math.round(19 * root.s))).weight(Font.Bold).build()
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        horizontalAlignment: Text.AlignHCenter
                        text: root.btBatteryDevice
                            ? (Math.round((root.btBatteryDevice.battery ?? 0) * 100) + "% BT")
                            : (Weather.description || "")
                        font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.85)).build()
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
    }

    // 2x2 Square Dashboard-At-A-Glance
    Component {
        id: layout2x2

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            spacing: Math.max(4, Math.round(Tokens.spacing.small * root.s))

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Math.max(4, Math.round(8 * root.s))

                MaterialShape {
                    Layout.fillWidth: false
                    Layout.preferredWidth: Math.round(32 * root.s)
                    Layout.preferredHeight: Math.round(32 * root.s)
                    implicitSize: Math.round(32 * root.s)
                    shape: MaterialShape.Sunny
                    color: shell.primaryContainerTint

                    StyledText {
                        anchors.centerIn: parent
                        text: String(root.todayDate.getDate())
                        font: Tokens.font.label.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).weight(Font.Bold).build()
                        color: Colours.palette.m3onPrimaryContainer
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: Qt.formatDate(root.todayDate, "dddd, MMM d")
                        font: Tokens.font.label.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.96)).weight(Font.DemiBold).build()
                        color: Colours.palette.m3primary
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: root.openTasks > 0 ? Tr.tr("%1 tasks open").arg(root.openTasks) : Tr.tr("Schedule clear")
                        font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.92)).build()
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }

                StyledRect {
                    visible: root.btBatteryDevice !== null
                    Layout.fillWidth: false
                    Layout.preferredHeight: Math.round(24 * root.s)
                    Layout.preferredWidth: Math.min(Math.round(92 * root.s), Math.round(btSqRow.implicitWidth + Math.round(14 * root.s)))
                    clip: true
                    radius: Math.round(12 * root.s)
                    color: shell.secondaryContainerTint

                    RowLayout {
                        id: btSqRow

                        anchors.centerIn: parent
                        spacing: Math.max(2, Math.round(4 * root.s))

                        MaterialIcon {
                            text: "headphones"
                            fontStyle: Tokens.font.icon.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.9)).build()
                            color: Colours.palette.m3onSecondaryContainer
                        }

                        StyledText {
                            text: Math.round((root.btBatteryDevice?.battery ?? 0) * 100) + "%"
                            font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.9)).build()
                            color: Colours.palette.m3onSecondaryContainer
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: root.greeting
                font: Tokens.font.headline.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.96)).weight(Font.Bold).build()
                color: Colours.palette.m3onSurface
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: root.tagline
                font: Tokens.font.body.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).build()
                color: Colours.palette.m3onSurfaceVariant
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Item {
                Layout.fillHeight: true
            }

            // Now playing mini strip
            StyledRect {
                visible: root.hasMedia
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(52 * root.s)
                clip: true
                radius: Math.round(Tokens.rounding.large * Math.min(1.2, Math.max(0.75, root.s)))
                color: shell.innerSurface
                border.width: 1
                border.color: shell.innerBorder

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Math.max(4, Math.round(8 * root.s))
                    spacing: Math.max(4, Math.round(8 * root.s))

                    CoverArt {
                        Layout.fillWidth: false
                        Layout.preferredWidth: Math.round(36 * root.s)
                        Layout.preferredHeight: Math.round(36 * root.s)
                        source: root.mediaArt
                        spinning: root.visible && root.effectiveSize === "2x2" && root.mediaPlaying && !GameMode.enabled
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: root.activePlayer?.trackTitle ?? ""
                            font: Tokens.font.label.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).weight(Font.DemiBold).build()
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: root.activePlayer?.trackArtist ?? ""
                            font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.88)).build()
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }

                    WidgetIconButton {
                        icon: root.mediaPlaying ? "pause" : "play_arrow"
                        type: IconButton.Tonal
                        isRound: true
                        translucent: shell.isTranslucent
                        scaleFactor: root.s
                        onClicked: root.activePlayer?.togglePlaying()
                    }
                }
            }

            // Weather bar
            StyledRect {
                visible: root.showWeather
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(54 * root.s)
                clip: true
                radius: Math.round(Tokens.rounding.large * Math.min(1.2, Math.max(0.75, root.s)))
                color: shell.innerSurface
                border.width: 1
                border.color: shell.innerBorder

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Math.max(4, Math.round(10 * root.s))
                    spacing: Math.max(6, Math.round(10 * root.s))

                    MaterialShape {
                        Layout.fillWidth: false
                        Layout.preferredWidth: Math.round(34 * root.s)
                        Layout.preferredHeight: Math.round(34 * root.s)
                        implicitSize: Math.round(34 * root.s)
                        shape: MaterialShape.Puffy
                        color: shell.primaryContainerTint

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: Weather.icon || "partly_cloudy_day"
                            fontStyle: Tokens.font.icon.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.96)).build()
                            color: Colours.palette.m3onPrimaryContainer
                        }
                    }

                    StyledText {
                        Layout.fillWidth: false
                        text: Weather.cc ? Weather.temp : "--°"
                        font: Tokens.font.clock.size(Math.max(12, Math.round(21 * root.s))).weight(Font.Bold).build()
                        color: Colours.palette.m3onSurface
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: Weather.description || Tr.tr("Weather")
                            font: Tokens.font.label.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).weight(Font.Medium).build()
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: Weather.city || ""
                            font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.88)).build()
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
    }

    // 1x3 Ultra-Wide Summary Strip
    Component {
        id: layout1x3

        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            spacing: Math.max(8, Math.round(Tokens.spacing.large * root.s))

            // Left: Date badge + Greeting + Tagline
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.fillHeight: true
                spacing: Math.max(3, Math.round(Tokens.spacing.small * root.s))

                RowLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: Math.max(4, Math.round(8 * root.s))

                    MaterialShape {
                        Layout.fillWidth: false
                        Layout.preferredWidth: Math.round(32 * root.s)
                        Layout.preferredHeight: Math.round(32 * root.s)
                        implicitSize: Math.round(32 * root.s)
                        shape: MaterialShape.Sunny
                        color: shell.primaryContainerTint

                        StyledText {
                            anchors.centerIn: parent
                            text: String(root.todayDate.getDate())
                            font: Tokens.font.label.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).weight(Font.Bold).build()
                            color: Colours.palette.m3onPrimaryContainer
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: Qt.formatDate(root.todayDate, "dddd, MMMM d")
                            font: Tokens.font.label.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.96)).weight(Font.DemiBold).build()
                            color: Colours.palette.m3primary
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: root.openTasks > 0 ? Tr.tr("%1 pending tasks").arg(root.openTasks) : Tr.tr("All tasks complete")
                            font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.92)).build()
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: root.greeting
                    font: Tokens.font.headline.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: root.hasMedia ? ("♪ " + root.activePlayer.trackTitle) : root.tagline
                    font: Tokens.font.body.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).build()
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            // Right: Fixed-width Weather / Now Playing tile
            StyledRect {
                Layout.fillWidth: false
                Layout.preferredWidth: Math.round(196 * root.s)
                Layout.maximumWidth: Math.round(204 * root.s)
                Layout.fillHeight: true
                visible: root.showWeather || root.hasMedia
                clip: true
                radius: Math.round(Tokens.rounding.extraLarge * Math.min(1.2, Math.max(0.75, root.s)))
                color: shell.innerSurface
                border.width: 1
                border.color: shell.innerBorder

                RowLayout {
                    visible: root.showWeather
                    anchors.fill: parent
                    anchors.margins: Math.max(6, Math.round(12 * root.s))
                    spacing: Math.max(6, Math.round(10 * root.s))

                    MaterialShape {
                        Layout.fillWidth: false
                        Layout.preferredWidth: Math.round(42 * root.s)
                        Layout.preferredHeight: Math.round(42 * root.s)
                        implicitSize: Math.round(42 * root.s)
                        shape: MaterialShape.Puffy
                        color: shell.primaryContainerTint

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: Weather.icon || "partly_cloudy_day"
                            fontStyle: Tokens.font.icon.builders.large.scale(WidgetMetrics.safeFontScale(root.s, 0.96)).build()
                            color: Colours.palette.m3onPrimaryContainer
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: Weather.cc ? Weather.temp : "--°"
                            font: Tokens.font.clock.size(Math.max(14, Math.round(23 * root.s))).weight(Font.Bold).build()
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: (Weather.description || Tr.tr("Weather")) + (Weather.city ? (" · " + Weather.city) : "")
                            font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.88)).build()
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }
                }

                RowLayout {
                    visible: !root.showWeather && root.hasMedia
                    anchors.fill: parent
                    anchors.margins: Math.max(6, Math.round(12 * root.s))
                    spacing: Math.max(6, Math.round(10 * root.s))

                    CoverArt {
                        Layout.fillWidth: false
                        Layout.preferredWidth: Math.round(44 * root.s)
                        Layout.preferredHeight: Math.round(44 * root.s)
                        source: root.mediaArt
                        spinning: root.visible && root.effectiveSize === "1x3" && root.mediaPlaying && !GameMode.enabled
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: root.hasMedia ? root.activePlayer.trackTitle : Tr.tr("No playback")
                            font: Tokens.font.label.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).weight(Font.Bold).build()
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: root.hasMedia ? (root.activePlayer.trackArtist || Tr.tr("Artist")) : Tr.tr("Audio idle")
                            font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.88)).build()
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }

                    WidgetIconButton {
                        visible: root.hasMedia
                        icon: root.mediaPlaying ? "pause" : "play_arrow"
                        type: IconButton.Tonal
                        isRound: true
                        translucent: shell.isTranslucent
                        scaleFactor: root.s
                        onClicked: root.activePlayer?.togglePlaying()
                    }
                }

                StateLayer {
                    enabled: root.locked && root.showWeather
                    radius: parent.radius
                    onClicked: Weather.reload()
                }
            }
        }
    }
}

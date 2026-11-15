pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.widgets
import qs.services
import "../../dashboard/dash" as Dash
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

    readonly property real s: WidgetMetrics.scale
    readonly property var player: Players.recentPlayer ?? Players.active ?? null
    readonly property bool hasPlayer: player !== null && (player.trackTitle ?? "") !== ""
    readonly property string artUrl: player ? Players.getArtUrl(player) : ""
    readonly property bool isPlaying: player?.isPlaying ?? false
    readonly property bool canSeek: hasPlayer && (player?.canSeek ?? false) && trackLength > 0
    readonly property real trackLength: player?.length ?? 0
    readonly property real trackPosition: player?.position ?? 0
    readonly property real progressRatio: trackLength > 0 ? Math.max(0, Math.min(1, trackPosition / trackLength)) : 0

    readonly property bool showVisualizer: (widgetOptions?.showVisualizer ?? true) !== false
    readonly property bool showAlbumBackdrop: (widgetOptions?.albumBackdrop ?? true) !== false
    readonly property bool needsVisualizer: showVisualizer && (sizeMode === "2x2" || sizeMode === "1x3" || sizeMode === "2x3")
    readonly property bool needsLyrics: sizeMode === "2x1" || sizeMode === "2x2" || sizeMode === "1x3" || sizeMode === "2x3"

    readonly property int lyricIndex: (needsLyrics && Lyrics.hasLyrics) ? Lyrics.indexForTime(trackPosition) : -1
    readonly property string currentLyricLine: (lyricIndex >= 0 && lyricIndex < Lyrics.lyrics.length) ? Lyrics.lyrics[lyricIndex] : ""

    function fmtTime(sec: real): string {
        if (!sec || sec < 0 || isNaN(sec))
            return "0:00";
        const total = Math.floor(sec);
        const m = Math.floor(total / 60);
        const ss = total % 60;
        return m + ":" + (ss < 10 ? "0" : "") + ss;
    }

    function seekToRatio(ratio: real): void {
        if (!player || !canSeek)
            return;
        const clamped = Math.max(0, Math.min(1, ratio));
        player.position = clamped * trackLength;
        player.positionChanged();
    }

    function syncLyrics(): void {
        if (!needsLyrics || !hasPlayer) {
            if (!hasPlayer)
                Lyrics.clearTrack();
            return;
        }
        Lyrics.setTrack(player.trackArtist ?? "", player.trackTitle ?? "", player.trackAlbum ?? "", Math.round(trackLength));
    }

    implicitWidth: WidgetMetrics.widthFor(sizeMode, s)
    implicitHeight: WidgetMetrics.heightFor(sizeMode, "media", s)
    onPlayerChanged: syncLyrics()
    onSizeModeChanged: syncLyrics()
    Component.onCompleted: syncLyrics()

    Connections {
        target: root.player
        function onTrackTitleChanged(): void {
            root.syncLyrics();
        }
    }

    // Poll position smoothly while actively playing
    Timer {
        interval: 500
        repeat: true
        running: root.visible && root.hasPlayer && root.isPlaying
        onTriggered: {
            if (root.player && root.player.positionChanged)
                root.player.positionChanged();
        }
    }

    Loader {
        active: root.visible && root.needsVisualizer && root.isPlaying
        sourceComponent: Component {
            ServiceRef {
                service: Audio.cava
            }
        }
    }

    WidgetCardShell {
        id: shell

        anchors.fill: parent
        widgetType: "media"
        sizeMode: root.sizeMode
        outerShape: root.widgetOptions?.outerShape ?? ""
        wallpaper: root.wallpaper
        weActive: root.weActive
        surfaceStyle: root.surfaceStyle
        blurEnabled: root.blurEnabled
        plateOpacity: root.plateOpacity
        scaleFactor: root.s

        backdropData: StyledClippingRect {
            anchors.fill: parent
            radius: shell.isShaped ? 0 : shell.radius
            color: "transparent"
            visible: root.showAlbumBackdrop && root.artUrl !== ""

            Image {
                anchors.fill: parent
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: 0.16
            }
        }

        // 1x1 Rotating Cookie12Sided CoverArt + Wavy Ring + Tap Play/Pause
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
                spacing: Math.round(4 * root.s)

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.round((shell.isShaped ? 72 : 84) * root.s)
                    Layout.preferredHeight: Math.round((shell.isShaped ? 72 : 84) * root.s)

                    CircularProgress {
                        anchors.fill: parent
                        value: root.hasPlayer ? root.progressRatio : 0
                        wavy: root.isPlaying
                        wavePaused: !root.isPlaying
                        strokeWidth: Math.max(3, Math.round(4 * root.s))
                        fgColour: Colours.palette.m3primary
                        bgColour: WidgetMetrics.trackSurface
                        implicitSize: width
                    }

                    CoverArt {
                        anchors.centerIn: parent
                        width: Math.round((shell.isShaped ? 54 : 62) * root.s)
                        height: Math.round((shell.isShaped ? 54 : 62) * root.s)
                        source: root.artUrl
                        spinning: root.isPlaying
                    }

                    StyledRect {
                        id: miniPlayPill

                        anchors.centerIn: parent
                        width: Math.round((shell.isShaped ? 26 : 30) * root.s)
                        height: Math.round((shell.isShaped ? 26 : 30) * root.s)
                        radius: Math.round((shell.isShaped ? 13 : 15) * root.s)
                        color: Qt.alpha(Colours.palette.m3surface, miniHover.hovered || !root.isPlaying ? 0.85 : 0.35)
                        opacity: (!root.hasPlayer || !root.isPlaying || miniHover.hovered) ? 1.0 : 0.0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Tokens.anim.durations.expressiveFastEffects
                            }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: root.isPlaying ? "pause" : "play_arrow"
                            fontStyle: Tokens.font.icon.builders.small.scale(root.s).build()
                            color: Colours.palette.m3primary
                        }
                    }

                    HoverHandler {
                        id: miniHover
                        enabled: root.locked
                    }

                    StateLayer {
                        enabled: root.locked && root.hasPlayer
                        radius: width / 2
                        onClicked: root.player?.togglePlaying()
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.hasPlayer ? root.player.trackTitle : Tr.tr("No media")
                    font: Tokens.font.label.builders.medium.scale(Math.max(0.85, root.s * 0.92)).weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }
            }
        }

        // 1x2 Wide Compact Player
        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "1x2"
            spacing: Math.round(Tokens.spacing.medium * root.s)

            CoverArt {
                Layout.preferredWidth: Math.round(92 * root.s)
                Layout.preferredHeight: Math.round(92 * root.s)
                Layout.alignment: Qt.AlignVCenter
                source: root.artUrl
                spinning: root.isPlaying
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Math.round(4 * root.s)

                StyledText {
                    Layout.fillWidth: true
                    text: root.hasPlayer ? root.player.trackTitle : Tr.tr("No media")
                    font: Tokens.font.title.builders.small.scale(root.s).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.hasPlayer ? (root.player.trackArtist || Tr.tr("Unknown artist")) : Tr.tr("Start playback")
                    font: Tokens.font.label.builders.medium.scale(root.s).build()
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }

                Item {
                    Layout.fillHeight: true
                }

                StyledSlider {
                    Layout.fillWidth: true
                    implicitHeight: Math.round(10 * root.s)
                    from: 0
                    to: 1
                    value: root.progressRatio
                    enabled: root.canSeek && root.locked
                    wavy: root.isPlaying
                    animateWave: root.isPlaying
                    waveFrequency: 5
                    interactionOnMove: false
                    onMoved: root.seekToRatio(value)
                }

                ButtonRow {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    IconButton {
                        fillWidth: true
                        icon: "skip_previous"
                        type: IconButton.Tonal
                        isRound: true
                        disabled: !root.hasPlayer || !(root.player?.canGoPrevious ?? false)
                        onClicked: root.player?.previous()
                    }

                    IconButton {
                        fillWidth: true
                        icon: root.isPlaying ? "pause" : "play_arrow"
                        type: IconButton.Filled
                        isRound: true
                        isToggle: true
                        checked: root.isPlaying
                        disabled: !root.hasPlayer
                        onClicked: root.player?.togglePlaying()
                    }

                    IconButton {
                        fillWidth: true
                        icon: "skip_next"
                        type: IconButton.Tonal
                        isRound: true
                        disabled: !root.hasPlayer || !(root.player?.canGoNext ?? false)
                        onClicked: root.player?.next()
                    }
                }
            }
        }

        // 2x1 Tall Native Dash Media Clone
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "2x1"
            spacing: Math.round(Tokens.spacing.small * root.s)

            CoverArt {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.round(114 * root.s)
                Layout.preferredHeight: Math.round(114 * root.s)
                source: root.artUrl
                spinning: root.isPlaying
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.hasPlayer ? root.player.trackTitle : Tr.tr("No media")
                    font: Tokens.font.title.builders.small.scale(root.s).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.hasPlayer ? (root.player.trackArtist || Tr.tr("Unknown artist")) : Tr.tr("Start playback")
                    font: Tokens.font.label.builders.small.scale(root.s).build()
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }

                StyledText {
                    visible: root.currentLyricLine !== ""
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.currentLyricLine
                    font: Tokens.font.body.builders.small.scale(0.88).build()
                    color: Colours.palette.m3primary
                    elide: Text.ElideRight
                }
            }

            Item {
                Layout.fillHeight: true
            }

            StyledSlider {
                Layout.fillWidth: true
                implicitHeight: Math.round(10 * root.s)
                from: 0
                to: 1
                value: root.progressRatio
                enabled: root.canSeek && root.locked
                wavy: root.isPlaying
                animateWave: root.isPlaying
                waveFrequency: 4
                interactionOnMove: false
                onMoved: root.seekToRatio(value)
            }

            ButtonRow {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                IconButton {
                    fillWidth: true
                    icon: "skip_previous"
                    type: IconButton.Tonal
                    isRound: true
                    disabled: !root.hasPlayer || !(root.player?.canGoPrevious ?? false)
                    onClicked: root.player?.previous()
                }

                IconButton {
                    fillWidth: true
                    icon: root.isPlaying ? "pause" : "play_arrow"
                    type: IconButton.Filled
                    isRound: true
                    isToggle: true
                    checked: root.isPlaying
                    disabled: !root.hasPlayer
                    onClicked: root.player?.togglePlaying()
                }

                IconButton {
                    fillWidth: true
                    icon: "skip_next"
                    type: IconButton.Tonal
                    isRound: true
                    disabled: !root.hasPlayer || !(root.player?.canGoNext ?? false)
                    onClicked: root.player?.next()
                }
            }
        }

        // 2x2 Expressive Square Player
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "2x2"
            spacing: Math.round(Tokens.spacing.medium * root.s)

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(Tokens.spacing.medium * root.s)

                Item {
                    Layout.preferredWidth: Math.round(104 * root.s)
                    Layout.preferredHeight: Math.round(104 * root.s)

                    CircularProgress {
                        anchors.fill: parent
                        value: root.hasPlayer ? root.progressRatio : 0
                        wavy: root.isPlaying
                        wavePaused: !root.isPlaying
                        strokeWidth: Math.max(4, Math.round(5 * root.s))
                        fgColour: Colours.palette.m3primary
                        bgColour: WidgetMetrics.trackSurface
                        implicitSize: width
                    }

                    CoverArt {
                        anchors.centerIn: parent
                        width: Math.round(82 * root.s)
                        height: Math.round(82 * root.s)
                        source: root.artUrl
                        spinning: root.isPlaying
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 3

                    StyledText {
                        Layout.fillWidth: true
                        text: root.hasPlayer ? root.player.trackTitle : Tr.tr("No media")
                        font: Tokens.font.title.builders.medium.scale(root.s).weight(Font.Bold).build()
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.hasPlayer ? (root.player.trackArtist || Tr.tr("Unknown artist")) : Tr.tr("Start playback")
                        font: Tokens.font.body.builders.medium.scale(root.s).build()
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }

                    StyledText {
                        visible: root.hasPlayer && (root.player?.trackAlbum ?? "") !== ""
                        Layout.fillWidth: true
                        text: root.player?.trackAlbum ?? ""
                        font: Tokens.font.label.small
                        color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.8)
                        elide: Text.ElideRight
                    }

                    Item {
                        visible: root.showVisualizer && root.isPlaying
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(28 * root.s)

                        Dash.MediaShapes {
                            anchors.fill: parent
                            visible: root.visible && root.sizeMode === "2x2" && root.showVisualizer && root.isPlaying
                        }
                    }
                }
            }

            StyledRect {
                visible: root.currentLyricLine !== ""
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(30 * root.s)
                radius: Math.round(15 * root.s)
                color: Qt.alpha(Colours.palette.m3secondaryContainer, 0.85)

                StyledText {
                    anchors.centerIn: parent
                    width: parent.width - Tokens.padding.medium * 2
                    horizontalAlignment: Text.AlignHCenter
                    text: root.currentLyricLine
                    font: Tokens.font.label.builders.medium.scale(root.s).weight(Font.Medium).build()
                    color: Colours.palette.m3onSecondaryContainer
                    elide: Text.ElideRight
                }
            }

            Item {
                Layout.fillHeight: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledSlider {
                    Layout.fillWidth: true
                    implicitHeight: Math.round(12 * root.s)
                    from: 0
                    to: 1
                    value: root.progressRatio
                    enabled: root.canSeek && root.locked
                    wavy: root.isPlaying
                    animateWave: root.isPlaying
                    waveFrequency: 6
                    interactionOnMove: false
                    onMoved: root.seekToRatio(value)
                }

                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        text: root.fmtTime(root.trackPosition)
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    StyledText {
                        text: root.fmtTime(root.trackLength)
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }

            ButtonRow {
                Layout.fillWidth: true
                Layout.minimumHeight: Math.round(34 * root.s)
                spacing: Tokens.spacing.small

                IconButton {
                    fillWidth: true
                    icon: "shuffle"
                    type: IconButton.Tonal
                    isRound: true
                    isToggle: true
                    checked: root.player?.shuffle ?? false
                    disabled: !root.hasPlayer
                    onClicked: if (root.player) root.player.shuffle = !root.player.shuffle
                }

                IconButton {
                    fillWidth: true
                    icon: "skip_previous"
                    type: IconButton.Tonal
                    isRound: true
                    disabled: !root.hasPlayer || !(root.player?.canGoPrevious ?? false)
                    onClicked: root.player?.previous()
                }

                IconButton {
                    fillWidth: true
                    icon: root.isPlaying ? "pause" : "play_arrow"
                    type: IconButton.Filled
                    isRound: true
                    isToggle: true
                    checked: root.isPlaying
                    disabled: !root.hasPlayer
                    onClicked: root.player?.togglePlaying()
                }

                IconButton {
                    fillWidth: true
                    icon: "skip_next"
                    type: IconButton.Tonal
                    isRound: true
                    disabled: !root.hasPlayer || !(root.player?.canGoNext ?? false)
                    onClicked: root.player?.next()
                }
            }
        }

        // 1x3 Cinema Wide Bar
        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "1x3"
            spacing: Math.round(Tokens.spacing.large * root.s)

            CoverArt {
                Layout.preferredWidth: Math.round(92 * root.s)
                Layout.preferredHeight: Math.round(92 * root.s)
                Layout.alignment: Qt.AlignVCenter
                source: root.artUrl
                spinning: root.isPlaying
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        StyledText {
                            Layout.fillWidth: true
                            text: root.hasPlayer ? root.player.trackTitle : Tr.tr("No media")
                            font: Tokens.font.title.builders.medium.scale(root.s).weight(Font.Bold).build()
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.hasPlayer ? ((root.player.trackArtist || Tr.tr("Unknown")) + ((root.player?.trackAlbum ?? "") !== "" ? (" · " + root.player.trackAlbum) : "")) : Tr.tr("Open a media player")
                            font: Tokens.font.label.medium
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }

                    Item {
                        visible: root.showVisualizer && root.isPlaying
                        Layout.preferredWidth: Math.round(72 * root.s)
                        Layout.preferredHeight: Math.round(32 * root.s)

                        Dash.MediaShapes {
                            anchors.fill: parent
                            visible: root.visible && root.sizeMode === "1x3" && root.showVisualizer && root.isPlaying
                        }
                    }
                }

                StyledText {
                    visible: root.currentLyricLine !== ""
                    Layout.fillWidth: true
                    text: root.currentLyricLine
                    font: Tokens.font.body.small
                    color: Colours.palette.m3primary
                    elide: Text.ElideRight
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: root.fmtTime(root.trackPosition)
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledSlider {
                        Layout.fillWidth: true
                        implicitHeight: Math.round(10 * root.s)
                        from: 0
                        to: 1
                        value: root.progressRatio
                        enabled: root.canSeek && root.locked
                        wavy: root.isPlaying
                        animateWave: root.isPlaying
                        waveFrequency: 6
                        interactionOnMove: false
                        onMoved: root.seekToRatio(value)
                    }

                    StyledText {
                        text: root.fmtTime(root.trackLength)
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }

            ButtonRow {
                Layout.fillWidth: false
                Layout.preferredWidth: Math.round(126 * root.s)
                Layout.alignment: Qt.AlignVCenter
                spacing: Tokens.spacing.extraSmall

                IconButton {
                    fillWidth: true
                    icon: "skip_previous"
                    type: IconButton.Tonal
                    isRound: true
                    disabled: !root.hasPlayer || !(root.player?.canGoPrevious ?? false)
                    onClicked: root.player?.previous()
                }

                IconButton {
                    fillWidth: true
                    icon: root.isPlaying ? "pause" : "play_arrow"
                    type: IconButton.Filled
                    isRound: true
                    isToggle: true
                    checked: root.isPlaying
                    disabled: !root.hasPlayer
                    onClicked: root.player?.togglePlaying()
                }

                IconButton {
                    fillWidth: true
                    icon: "skip_next"
                    type: IconButton.Tonal
                    isRound: true
                    disabled: !root.hasPlayer || !(root.player?.canGoNext ?? false)
                    onClicked: root.player?.next()
                }
            }
        }

        // 2x3 Split Studio Player (fits cleanly inside 516x340 with zero overflow)
        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "2x3"
            spacing: Math.round(Tokens.spacing.large * root.s)

            // Left vinyl art + progress halo + MediaShapes column
            ColumnLayout {
                Layout.preferredWidth: Math.round(176 * root.s)
                Layout.fillHeight: true
                spacing: Math.round(Tokens.spacing.small * root.s)

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.round(148 * root.s)
                    Layout.preferredHeight: Math.round(148 * root.s)

                    CircularProgress {
                        anchors.fill: parent
                        value: root.hasPlayer ? root.progressRatio : 0
                        wavy: root.isPlaying
                        wavePaused: !root.isPlaying
                        strokeWidth: Math.max(5, Math.round(6 * root.s))
                        fgColour: Colours.palette.m3primary
                        bgColour: WidgetMetrics.trackSurface
                        implicitSize: width
                    }

                    CoverArt {
                        anchors.centerIn: parent
                        width: Math.round(118 * root.s)
                        height: Math.round(118 * root.s)
                        source: root.artUrl
                        spinning: root.isPlaying
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(44 * root.s)
                    radius: Tokens.rounding.large
                    color: WidgetMetrics.innerSurface
                    visible: root.showVisualizer

                    Dash.MediaShapes {
                        anchors.fill: parent
                        anchors.margins: 4
                        visible: root.visible && root.sizeMode === "2x3" && root.showVisualizer && root.isPlaying
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: !root.isPlaying
                        text: root.hasPlayer ? Tr.tr("Paused") : Tr.tr("Idle")
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.fmtTime(root.trackPosition) + " / " + root.fmtTime(root.trackLength)
                    font: Tokens.font.label.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            // Right details + lyrics pill + wavy seekbar + full controls
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Math.round(Tokens.spacing.small * root.s)

                StyledText {
                    Layout.fillWidth: true
                    text: root.hasPlayer ? root.player.trackTitle : Tr.tr("No media playing")
                    font: Tokens.font.headline.builders.small.scale(root.s).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.hasPlayer ? (root.player.trackArtist || Tr.tr("Unknown artist")) : Tr.tr("Start playback in any player")
                    font: Tokens.font.title.builders.small.scale(root.s).weight(Font.Medium).build()
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }

                StyledText {
                    visible: root.hasPlayer && (root.player?.trackAlbum ?? "") !== ""
                    Layout.fillWidth: true
                    text: root.player?.trackAlbum ?? ""
                    font: Tokens.font.label.small
                    color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.8)
                    elide: Text.ElideRight
                }

                StyledRect {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: Math.round(44 * root.s)
                    radius: Tokens.rounding.large
                    color: WidgetMetrics.innerSurfaceStrong

                    StyledText {
                        anchors.centerIn: parent
                        width: parent.width - Tokens.padding.large * 2
                        horizontalAlignment: Text.AlignHCenter
                        text: root.currentLyricLine !== "" ? root.currentLyricLine : (root.hasPlayer ? (root.isPlaying ? Tr.tr("Now Playing") : Tr.tr("Paused")) : Tr.tr("Ready"))
                        font: Tokens.font.body.builders.medium.scale(root.s).weight(root.currentLyricLine !== "" ? Font.DemiBold : Font.Normal).build()
                        color: root.currentLyricLine !== "" ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }

                StyledSlider {
                    Layout.fillWidth: true
                    implicitHeight: Math.round(12 * root.s)
                    from: 0
                    to: 1
                    value: root.progressRatio
                    enabled: root.canSeek && root.locked
                    wavy: root.isPlaying
                    animateWave: root.isPlaying
                    waveFrequency: 6
                    interactionOnMove: false
                    onMoved: root.seekToRatio(value)
                }

                ButtonRow {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    IconButton {
                        fillWidth: true
                        icon: "shuffle"
                        type: IconButton.Tonal
                        isRound: true
                        isToggle: true
                        checked: root.player?.shuffle ?? false
                        disabled: !root.hasPlayer
                        onClicked: if (root.player) root.player.shuffle = !root.player.shuffle
                    }

                    IconButton {
                        fillWidth: true
                        icon: "skip_previous"
                        type: IconButton.Tonal
                        isRound: true
                        disabled: !root.hasPlayer || !(root.player?.canGoPrevious ?? false)
                        onClicked: root.player?.previous()
                    }

                    IconButton {
                        fillWidth: true
                        icon: root.isPlaying ? "pause" : "play_arrow"
                        type: IconButton.Filled
                        isRound: true
                        isToggle: true
                        checked: root.isPlaying
                        disabled: !root.hasPlayer
                        onClicked: root.player?.togglePlaying()
                    }

                    IconButton {
                        fillWidth: true
                        icon: "skip_next"
                        type: IconButton.Tonal
                        isRound: true
                        disabled: !root.hasPlayer || !(root.player?.canGoNext ?? false)
                        onClicked: root.player?.next()
                    }
                }
            }
        }
    }
}

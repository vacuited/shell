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
    property real widgetScale: WidgetMetrics.scale
    property string surfaceStyle: ""
    property bool blurEnabled: Config.background.desktopWidgets.blur
    property real plateOpacity: Config.background.desktopWidgets.opacity
    property var widgetOptions: ({})

    readonly property real s: Math.max(0.55, Math.min(2.2, widgetScale > 0 ? widgetScale : WidgetMetrics.scale))
    readonly property string effectiveSize: WidgetMetrics.fallbackSizeFor("media", sizeMode)
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
    readonly property bool needsLyrics: effectiveSize === "2x2" || effectiveSize === "1x3"

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
        if (!root.visible || !needsLyrics)
            return;
        if (!hasPlayer) {
            if (!Config.background.desktopLyrics.enabled)
                Lyrics.clearTrack();
            return;
        }
        Lyrics.setTrack(player.trackArtist ?? "", player.trackTitle ?? "", player.trackAlbum ?? "", player.length ?? 0);
    }

    implicitWidth: WidgetMetrics.widthFor(effectiveSize, s)
    implicitHeight: WidgetMetrics.heightFor(effectiveSize, "media", s)
    onPlayerChanged: syncLyrics()
    onEffectiveSizeChanged: syncLyrics()
    onVisibleChanged: if (visible) syncLyrics()
    Component.onCompleted: syncLyrics()

    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPostTrackChanged(): void {
            root.syncLyrics();
        }
        function onTrackTitleChanged(): void {
            root.syncLyrics();
        }
        function onTrackArtistChanged(): void {
            root.syncLyrics();
        }
    }

    // Poll position smoothly while actively playing
    Timer {
        interval: 500
        repeat: true
        running: root.visible && root.hasPlayer && root.isPlaying && !GameMode.enabled
        onTriggered: {
            if (root.player && root.player.positionChanged)
                root.player.positionChanged();
        }
    }

    WidgetCardShell {
        id: shell

        anchors.fill: parent
        widgetType: "media"
        sizeMode: root.effectiveSize
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

    // 1x1 Rotating Cookie12Sided CoverArt + Wavy Ring + Tap Play/Pause
    Component {
        id: layout1x1

        Item {
            readonly property int ringSize: Math.max(36, Math.round(Math.min((shell.isShaped ? 68 : 78) * root.s, shell.safeInnerBox - Math.round(20 * root.s))))

            clip: true

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.max(24, parent.width - shell.sidePadding * 2)
                spacing: Math.max(2, Math.round(4 * root.s))

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: ringSize
                    Layout.preferredHeight: ringSize

                    CircularProgress {
                        anchors.fill: parent
                        value: root.hasPlayer ? root.progressRatio : 0
                        wavy: root.visible && root.effectiveSize === "1x1" && root.isPlaying && !GameMode.enabled
                        wavePaused: !wavy
                        strokeWidth: Math.max(3, Math.round(4 * root.s))
                        fgColour: Colours.palette.m3primary
                        bgColour: shell.trackSurface
                        implicitSize: ringSize
                    }

                    CoverArt {
                        anchors.centerIn: parent
                        width: Math.max(22, Math.round(parent.width * 0.74))
                        height: width
                        source: root.artUrl
                        spinning: root.visible && root.effectiveSize === "1x1" && root.isPlaying && !GameMode.enabled
                    }

                    StyledRect {
                        anchors.centerIn: parent
                        width: Math.max(18, Math.round(parent.width * 0.38))
                        height: width
                        radius: Math.round(width / 2)
                        color: shell.containerTone(Colours.palette.m3secondaryContainer, miniHover.hovered || !root.isPlaying)
                        opacity: (!root.hasPlayer || !root.isPlaying || miniHover.hovered) ? 1.0 : 0.0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Tokens.anim.durations.expressiveFastEffects
                            }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: root.isPlaying ? "pause" : "play_arrow"
                            fontStyle: Tokens.font.icon.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).build()
                            color: Colours.palette.m3onSecondaryContainer
                        }
                    }

                    HoverHandler {
                        id: miniHover
                        enabled: root.locked
                    }

                    StateLayer {
                        enabled: root.locked && root.hasPlayer && (root.player?.canTogglePlaying ?? false)
                        radius: width / 2
                        onClicked: root.player?.togglePlaying()
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    horizontalAlignment: Text.AlignHCenter
                    text: root.hasPlayer ? root.player.trackTitle : Tr.tr("No media")
                    font: Tokens.font.label.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.9)).weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }
            }
        }
    }

    // 1x2 Wide Compact Player
    Component {
        id: layout1x2

        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            spacing: Math.max(6, Math.round(Tokens.spacing.medium * root.s))

            CoverArt {
                Layout.fillWidth: false
                Layout.preferredWidth: Math.round(90 * root.s)
                Layout.preferredHeight: Math.round(90 * root.s)
                Layout.alignment: Qt.AlignVCenter
                source: root.artUrl
                spinning: root.visible && root.effectiveSize === "1x2" && root.isPlaying && !GameMode.enabled
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.fillHeight: true
                spacing: Math.max(2, Math.round(4 * root.s))

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: root.hasPlayer ? root.player.trackTitle : Tr.tr("No media")
                    font: Tokens.font.title.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.96)).weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: root.hasPlayer ? (root.player.trackArtist || Tr.tr("Unknown artist")) : Tr.tr("Start playback")
                    font: Tokens.font.label.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).build()
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }

                Item {
                    Layout.fillHeight: true
                }

                StyledSlider {
                    Layout.fillWidth: true
                    implicitHeight: Math.max(6, Math.round(10 * root.s))
                    from: 0
                    to: 1
                    value: root.progressRatio
                    enabled: root.canSeek && root.locked
                    bgColour: enabled ? shell.trackSurface : Qt.alpha(Colours.palette.m3onSurface, 0.16)
                    wavy: root.visible && root.effectiveSize === "1x2" && root.isPlaying && !GameMode.enabled
                    animateWave: wavy
                    waveFrequency: 5
                    interactionOnMove: false
                    onReleased: v => root.seekToRatio(v)
                }

                ButtonRow {
                    Layout.fillWidth: true
                    spacing: Math.max(2, Math.round(Tokens.spacing.extraSmall * root.s))

                    WidgetIconButton {
                        fillWidth: true
                        icon: "skip_previous"
                        type: IconButton.Tonal
                        isRound: true
                        translucent: shell.isTranslucent
                        scaleFactor: root.s
                        disabled: !root.hasPlayer || !(root.player?.canGoPrevious ?? false)
                        onClicked: root.player?.previous()
                    }

                    WidgetIconButton {
                        fillWidth: true
                        icon: root.isPlaying ? "pause" : "play_arrow"
                        type: IconButton.Filled
                        isRound: true
                        isToggle: true
                        checked: root.isPlaying
                        translucent: shell.isTranslucent
                        scaleFactor: root.s
                        disabled: !root.hasPlayer || !(root.player?.canTogglePlaying ?? false)
                        onClicked: root.player?.togglePlaying()
                    }

                    WidgetIconButton {
                        fillWidth: true
                        icon: "skip_next"
                        type: IconButton.Tonal
                        isRound: true
                        translucent: shell.isTranslucent
                        scaleFactor: root.s
                        disabled: !root.hasPlayer || !(root.player?.canGoNext ?? false)
                        onClicked: root.player?.next()
                    }
                }
            }
        }
    }

    // 2x2 Expressive Square Player
    Component {
        id: layout2x2

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            spacing: Math.max(4, Math.round(Tokens.spacing.medium * root.s))

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Math.max(6, Math.round(Tokens.spacing.medium * root.s))

                Item {
                    Layout.fillWidth: false
                    Layout.preferredWidth: Math.round(102 * root.s)
                    Layout.preferredHeight: Math.round(102 * root.s)

                    CircularProgress {
                        anchors.fill: parent
                        value: root.hasPlayer ? root.progressRatio : 0
                        wavy: root.visible && root.effectiveSize === "2x2" && root.isPlaying && !GameMode.enabled
                        wavePaused: !wavy
                        strokeWidth: Math.max(4, Math.round(5 * root.s))
                        fgColour: Colours.palette.m3primary
                        bgColour: shell.trackSurface
                        implicitSize: Math.round(102 * root.s)
                    }

                    CoverArt {
                        anchors.centerIn: parent
                        width: Math.round(80 * root.s)
                        height: Math.round(80 * root.s)
                        source: root.artUrl
                        spinning: root.visible && root.effectiveSize === "2x2" && root.isPlaying && !GameMode.enabled
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Math.max(2, Math.round(3 * root.s))

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: root.hasPlayer ? root.player.trackTitle : Tr.tr("No media")
                        font: Tokens.font.title.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.96)).weight(Font.Bold).build()
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: root.hasPlayer ? (root.player.trackArtist || Tr.tr("Unknown artist")) : Tr.tr("Start playback")
                        font: Tokens.font.body.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).build()
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }

                    StyledText {
                        visible: root.hasPlayer && (root.player?.trackAlbum ?? "") !== ""
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: root.player?.trackAlbum ?? ""
                        font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.9)).build()
                        color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.8)
                        elide: Text.ElideRight
                    }

                    Item {
                        visible: root.showVisualizer && root.isPlaying
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(28 * root.s)

                        Loader {
                            anchors.fill: parent
                            active: root.visible && root.effectiveSize === "2x2" && root.showVisualizer && root.isPlaying && !GameMode.enabled
                            sourceComponent: Dash.MediaShapes {
                                anchors.fill: parent
                                forceEnabled: true
                            }
                        }
                    }
                }
            }

            StyledRect {
                visible: root.currentLyricLine !== ""
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(30 * root.s)
                clip: true
                radius: Math.round(15 * root.s)
                color: shell.secondaryContainerTint

                StyledText {
                    anchors.centerIn: parent
                    width: Math.max(0, parent.width - Math.round(Tokens.padding.medium * 2 * root.s))
                    horizontalAlignment: Text.AlignHCenter
                    text: root.currentLyricLine
                    font: Tokens.font.label.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).weight(Font.Medium).build()
                    color: Colours.palette.m3onSecondaryContainer
                    elide: Text.ElideRight
                }
            }

            Item {
                Layout.fillHeight: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Math.max(1, Math.round(2 * root.s))

                StyledSlider {
                    Layout.fillWidth: true
                    implicitHeight: Math.max(6, Math.round(12 * root.s))
                    from: 0
                    to: 1
                    value: root.progressRatio
                    enabled: root.canSeek && root.locked
                    bgColour: enabled ? shell.trackSurface : Qt.alpha(Colours.palette.m3onSurface, 0.16)
                    wavy: root.visible && root.effectiveSize === "2x2" && root.isPlaying && !GameMode.enabled
                    animateWave: wavy
                    waveFrequency: 6
                    interactionOnMove: false
                    onReleased: v => root.seekToRatio(v)
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0

                    StyledText {
                        Layout.minimumWidth: 0
                        text: root.fmtTime(root.trackPosition)
                        font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.92)).build()
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    StyledText {
                        Layout.minimumWidth: 0
                        text: root.fmtTime(root.trackLength)
                        font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.92)).build()
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }
            }

            ButtonRow {
                Layout.fillWidth: true
                Layout.minimumHeight: Math.round(34 * root.s)
                spacing: Math.max(4, Math.round(Tokens.spacing.small * root.s))

                WidgetIconButton {
                    fillWidth: true
                    icon: "shuffle"
                    type: IconButton.Tonal
                    isRound: true
                    isToggle: true
                    checked: (root.player?.shuffleSupported ?? false) && (root.player?.shuffle ?? false)
                    translucent: shell.isTranslucent
                    scaleFactor: root.s
                    disabled: !root.hasPlayer || !(root.player?.shuffleSupported ?? false)
                    onClicked: if (root.player && root.player.shuffleSupported) root.player.shuffle = !root.player.shuffle
                }

                WidgetIconButton {
                    fillWidth: true
                    icon: "skip_previous"
                    type: IconButton.Tonal
                    isRound: true
                    translucent: shell.isTranslucent
                    scaleFactor: root.s
                    disabled: !root.hasPlayer || !(root.player?.canGoPrevious ?? false)
                    onClicked: root.player?.previous()
                }

                WidgetIconButton {
                    fillWidth: true
                    icon: root.isPlaying ? "pause" : "play_arrow"
                    type: IconButton.Filled
                    isRound: true
                    isToggle: true
                    checked: root.isPlaying
                    translucent: shell.isTranslucent
                    scaleFactor: root.s
                    disabled: !root.hasPlayer || !(root.player?.canTogglePlaying ?? false)
                    onClicked: root.player?.togglePlaying()
                }

                WidgetIconButton {
                    fillWidth: true
                    icon: "skip_next"
                    type: IconButton.Tonal
                    isRound: true
                    translucent: shell.isTranslucent
                    scaleFactor: root.s
                    disabled: !root.hasPlayer || !(root.player?.canGoNext ?? false)
                    onClicked: root.player?.next()
                }
            }
        }
    }

    // 1x3 Cinema Wide Bar
    Component {
        id: layout1x3

        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            spacing: Math.max(8, Math.round(Tokens.spacing.large * root.s))

            CoverArt {
                Layout.fillWidth: false
                Layout.preferredWidth: Math.round(90 * root.s)
                Layout.preferredHeight: Math.round(90 * root.s)
                Layout.alignment: Qt.AlignVCenter
                source: root.artUrl
                spinning: root.visible && root.effectiveSize === "1x3" && root.isPlaying && !GameMode.enabled
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter
                spacing: Math.max(2, Math.round(4 * root.s))

                RowLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: Math.max(4, Math.round(Tokens.spacing.small * root.s))

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 1

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: root.hasPlayer ? root.player.trackTitle : Tr.tr("No media")
                            font: Tokens.font.title.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.96)).weight(Font.Bold).build()
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: root.hasPlayer ? ((root.player.trackArtist || Tr.tr("Unknown")) + ((root.player?.trackAlbum ?? "") !== "" ? (" · " + root.player.trackAlbum) : "")) : Tr.tr("Open a media player")
                            font: Tokens.font.label.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.92)).build()
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }

                    Item {
                        visible: root.showVisualizer && root.isPlaying
                        Layout.fillWidth: false
                        Layout.preferredWidth: Math.round(68 * root.s)
                        Layout.preferredHeight: Math.round(30 * root.s)

                        Loader {
                            anchors.fill: parent
                            active: root.visible && root.effectiveSize === "1x3" && root.showVisualizer && root.isPlaying && !GameMode.enabled
                            sourceComponent: Dash.MediaShapes {
                                anchors.fill: parent
                                forceEnabled: true
                            }
                        }
                    }
                }

                StyledText {
                    visible: root.currentLyricLine !== ""
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: root.currentLyricLine
                    font: Tokens.font.body.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.92)).build()
                    color: Colours.palette.m3primary
                    elide: Text.ElideRight
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: Math.max(4, Math.round(Tokens.spacing.small * root.s))

                    StyledText {
                        Layout.minimumWidth: 0
                        text: root.fmtTime(root.trackPosition)
                        font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.9)).build()
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledSlider {
                        Layout.fillWidth: true
                        implicitHeight: Math.max(6, Math.round(10 * root.s))
                        from: 0
                        to: 1
                        value: root.progressRatio
                        enabled: root.canSeek && root.locked
                        bgColour: enabled ? shell.trackSurface : Qt.alpha(Colours.palette.m3onSurface, 0.16)
                        wavy: root.visible && root.effectiveSize === "1x3" && root.isPlaying && !GameMode.enabled
                        animateWave: wavy
                        waveFrequency: 6
                        interactionOnMove: false
                        onReleased: v => root.seekToRatio(v)
                    }

                    StyledText {
                        Layout.minimumWidth: 0
                        text: root.fmtTime(root.trackLength)
                        font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.9)).build()
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }

            ButtonRow {
                Layout.fillWidth: false
                Layout.preferredWidth: Math.round(124 * root.s)
                Layout.maximumWidth: Math.round(128 * root.s)
                Layout.alignment: Qt.AlignVCenter
                spacing: Math.max(2, Math.round(Tokens.spacing.extraSmall * root.s))

                WidgetIconButton {
                    fillWidth: true
                    icon: "skip_previous"
                    type: IconButton.Tonal
                    isRound: true
                    translucent: shell.isTranslucent
                    scaleFactor: root.s
                    disabled: !root.hasPlayer || !(root.player?.canGoPrevious ?? false)
                    onClicked: root.player?.previous()
                }

                WidgetIconButton {
                    fillWidth: true
                    icon: root.isPlaying ? "pause" : "play_arrow"
                    type: IconButton.Filled
                    isRound: true
                    isToggle: true
                    checked: root.isPlaying
                    translucent: shell.isTranslucent
                    scaleFactor: root.s
                    disabled: !root.hasPlayer || !(root.player?.canTogglePlaying ?? false)
                    onClicked: root.player?.togglePlaying()
                }

                WidgetIconButton {
                    fillWidth: true
                    icon: "skip_next"
                    type: IconButton.Tonal
                    isRound: true
                    translucent: shell.isTranslucent
                    scaleFactor: root.s
                    disabled: !root.hasPlayer || !(root.player?.canGoNext ?? false)
                    onClicked: root.player?.next()
                }
            }
        }
    }
}

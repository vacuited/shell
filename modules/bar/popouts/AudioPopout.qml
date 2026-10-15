pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.utils

ColumnLayout {
    id: root

    required property PopoutState popouts

    property bool _isSidebarOpen: popouts.sidebarOpen && popouts.isHorizontal && popouts.currentSection === "end"

    implicitWidth: Math.max(340, _isSidebarOpen ? Tokens.sizes.sidebar.width - Tokens.padding.extraLargeIncreased : 0)
    spacing: Tokens.spacing.medium

    function getStreamIcon(stream: PwNode): string {
        if (!stream)
            return Quickshell.iconPath("audio-x-generic");
        const iconName = stream.properties["application.icon-name"];
        if (iconName) {
            const p = Quickshell.iconPath(iconName);
            if (p)
                return p;
        }
        const binary = stream.properties["application.process.binary"];
        if (binary) {
            const entry = DesktopEntries.heuristicLookup(binary);
            if (entry?.icon) {
                const p = Quickshell.iconPath(entry.icon);
                if (p)
                    return p;
            }
        }
        const appName = stream.properties["application.name"] || stream.description || stream.name || "";
        if (appName.toLowerCase().includes("wallpaper"))
            return Quickshell.iconPath("preferences-desktop-wallpaper");
        const entry = DesktopEntries.heuristicLookup(appName);
        if (entry?.icon) {
            const p = Quickshell.iconPath(entry.icon);
            if (p)
                return p;
        }
        return Quickshell.iconPath("audio-x-generic");
    }

    ButtonGroup {
        id: sinks
    }

    ButtonGroup {
        id: sources
    }

    StyledText {
        Layout.topMargin: Tokens.padding.medium
        Layout.leftMargin: Tokens.padding.small
        text: qsTr("Audio")
        font.weight: 500
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.medium

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            StyledRect {
                Layout.fillWidth: true
                implicitWidth: outputLayout.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: outputLayout.implicitHeight + Tokens.padding.medium * 2
                radius: Tokens.rounding.medium
                color: Colours.tPalette.m3surfaceContainer
                clip: true

                ColumnLayout {
                    id: outputLayout

                    width: parent.width - Tokens.padding.medium * 2
                    x: Tokens.padding.medium
                    y: Tokens.padding.medium
                    spacing: Tokens.spacing.medium

                    StyledText {
                        text: qsTr("Output device")
                        font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                    }

                    Repeater {
                        model: Audio.sinks

                        StyledRadioButton {
                            id: outputControl

                            required property PwNode modelData

                            Layout.fillWidth: true
                            ButtonGroup.group: sinks
                            checked: Audio.sink?.id === modelData.id
                            onClicked: Audio.setAudioSink(modelData)
                            text: modelData.description
                        }
                    }
                }
            }

            StyledRect {
                Layout.fillWidth: true
                implicitWidth: inputLayout.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: inputLayout.implicitHeight + Tokens.padding.medium * 2
                radius: Tokens.rounding.medium
                color: Colours.tPalette.m3surfaceContainer
                clip: true

                ColumnLayout {
                    id: inputLayout

                    width: parent.width - Tokens.padding.medium * 2
                    x: Tokens.padding.medium
                    y: Tokens.padding.medium
                    spacing: Tokens.spacing.medium

                    StyledText {
                        text: qsTr("Input device")
                        font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                    }

                    Repeater {
                        model: Audio.sources

                        StyledRadioButton {
                            id: inputControl

                            required property PwNode modelData

                            Layout.fillWidth: true
                            ButtonGroup.group: sources
                            checked: Audio.source?.id === modelData.id
                            onClicked: Audio.setAudioSource(modelData)
                            text: modelData.description
                        }
                    }
                }
            }
        }

        CustomMouseArea {
            Layout.fillHeight: true
            Layout.preferredWidth: Tokens.sizes.osd.sliderWidth
            implicitWidth: Tokens.sizes.osd.sliderWidth

            onWheel: event => {
                if (event.angleDelta.y > 0)
                    Audio.incrementVolume();
                else if (event.angleDelta.y < 0)
                    Audio.decrementVolume();
            }

            FilledSlider {
                anchors.fill: parent

                icon: Icons.getVolumeIcon(value, Audio.muted)
                value: Audio.volume
                to: GlobalConfig.services.maxVolume
                enableIconTap: true

                onIconTapped: Audio.setStreamMuted(Audio.sink, !Audio.muted)
                onMoved: Audio.setVolume(value)
                onPressedChanged: {
                    if (!pressed)
                        Audio.playEffectTick();
                }
            }
        }
    }

    StyledRect {
        Layout.fillWidth: true
        visible: streamRepeater.count > 0
        implicitWidth: appLayout.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: appLayout.implicitHeight + Tokens.padding.medium * 2
        radius: Tokens.rounding.medium
        color: Colours.tPalette.m3surfaceContainer
        clip: true

        ColumnLayout {
            id: appLayout

            width: parent.width - Tokens.padding.medium * 2
            x: Tokens.padding.medium
            y: Tokens.padding.medium
            spacing: Tokens.spacing.medium

            Repeater {
                id: streamRepeater

                model: ScriptModel {
                    values: Audio.streams.filter(stream => {
                        const name = Audio.getStreamName(stream).toLowerCase();
                        const appName = (stream.properties["application.name"] ?? "").toLowerCase();
                        const nodeName = (stream.name ?? "").toLowerCase();
                        const binary = (stream.properties["application.process.binary"] ?? "").toLowerCase();
                        const mediaName = (stream.properties["media.name"] ?? "").toLowerCase();

                        const isInternal = name.includes("quickshell") || name.includes("caelestia")
                            || appName.includes("quickshell") || appName.includes("caelestia")
                            || nodeName.includes("quickshell") || nodeName.includes("caelestia");

                        const isWallpaper = name.includes("wallpaper") || appName.includes("wallpaper")
                            || nodeName.includes("wallpaper") || binary.includes("wallpaper")
                            || mediaName.includes(" - mpv") || (nodeName === "mpv" && binary !== "mpv");

                        return !isInternal && !isWallpaper;
                    })
                }

                RowLayout {
                    id: streamRow

                    required property PwNode modelData
                    required property int index

                    Layout.fillWidth: true
                    spacing: Tokens.spacing.medium

                    ColouredIcon {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        source: root.getStreamIcon(streamRow.modelData)
                        colour: Colours.palette.m3secondary
                        layer.enabled: Config.bar.tray.recolour
                        opacity: (streamRow.modelData?.audio?.muted ?? false) ? 0.38 : 1.0

                        TapHandler {
                            onTapped: Audio.setStreamMuted(streamRow.modelData, !(streamRow.modelData?.audio?.muted ?? false))
                        }
                    }

                    CustomMouseArea {
                        Layout.fillWidth: true
                        implicitHeight: Tokens.padding.medium * 2
                        acceptedButtons: Qt.NoButton

                        function onWheel(event: WheelEvent): void {
                            const step = GlobalConfig.services.audioIncrement;
                            const cur = streamRow.modelData?.audio?.volume ?? 0;
                            if (event.angleDelta.y > 0)
                                Audio.setStreamVolume(streamRow.modelData, Math.min(GlobalConfig.services.maxVolume, cur + step));
                            else if (event.angleDelta.y < 0)
                                Audio.setStreamVolume(streamRow.modelData, Math.max(0, cur - step));
                        }

                        StyledSlider {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            implicitHeight: parent.implicitHeight

                            radius: Tokens.rounding.small
                            value: streamRow.modelData?.audio?.volume ?? 0
                            enabled: !(streamRow.modelData?.audio?.muted ?? false)
                            onInteraction: v => Audio.setStreamVolume(streamRow.modelData, v)
                            onReleased: v => Audio.playEffectTick()
                        }
                    }
                }
            }
        }
    }

    IconTextButton {
        Layout.fillWidth: true
        inactiveColour: Colours.palette.m3primaryContainer
        inactiveOnColour: Colours.palette.m3onPrimaryContainer
        verticalPadding: Tokens.padding.small
        text: qsTr("Open settings")
        icon: "settings"

        onClicked: root.popouts.detachRequested("audio")
    }
}

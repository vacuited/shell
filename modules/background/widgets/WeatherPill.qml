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

    readonly property real s: Math.max(0.7, Math.min(1.5, Config.background.desktopWidgets.scale ?? 1.0))
    readonly property var todayForecast: (Weather.forecast && Weather.forecast.length > 0) ? Weather.forecast[0] : null
    readonly property real maxTemp: todayForecast?.maxTempC ?? 0
    readonly property real minTemp: todayForecast?.minTempC ?? 0

    implicitWidth: WidgetMetrics.widthFor(sizeMode, s)
    implicitHeight: WidgetMetrics.heightFor(sizeMode, "weatherPill", s)

    WidgetCardShell {
        id: shell

        anchors.fill: parent
        widgetType: "weatherPill"
        sizeMode: root.sizeMode
        forceRounded: true
        radius: Math.round(height / 2)
        wallpaper: root.wallpaper
        weActive: root.weActive
        surfaceStyle: root.surfaceStyle
        blurEnabled: root.blurEnabled
        plateOpacity: root.plateOpacity
        scaleFactor: root.s

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Math.round(12 * root.s)
            anchors.rightMargin: Math.round(16 * root.s)
            spacing: Math.round(Tokens.spacing.small * root.s)

            Item {
                Layout.preferredWidth: Math.round(42 * root.s)
                Layout.preferredHeight: Math.round(42 * root.s)
                Layout.alignment: Qt.AlignVCenter

                MaterialShape {
                    anchors.fill: parent
                    shape: MaterialShape.Puffy
                    color: Colours.palette.m3primaryContainer
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: Weather.icon || "partly_cloudy_day"
                    fontStyle: Tokens.font.icon.builders.medium.scale(root.s).build()
                    color: Colours.palette.m3onPrimaryContainer
                }
            }

            StyledText {
                text: Weather.cc ? Weather.temp : "--°"
                font: Tokens.font.clock.size(Math.round(Tokens.font.headline.small.pointSize * root.s)).weight(Font.Bold).build()
                fontSizeMode: root.sizeMode === "1x1" ? Text.Fit : Text.FixedSize
                minimumPointSize: Math.max(8, Math.round(10 * root.s))
                horizontalAlignment: root.sizeMode === "1x1" ? Text.AlignHCenter : Text.AlignLeft
                elide: Text.ElideRight
                color: Colours.palette.m3onSurface
                Layout.fillWidth: root.sizeMode === "1x1"
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                visible: root.sizeMode !== "1x1"
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: Weather.cc ? (Weather.description || qsTr("Weather")) : qsTr("Loading...")
                    font: Tokens.font.label.builders.medium.scale(root.s).weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.todayForecast !== null
                    text: Weather.formatTemp(root.maxTemp, true) + " / " + Weather.formatTemp(root.minTemp, true)
                    font: Tokens.font.label.builders.small.scale(Math.max(0.85, root.s * 0.9)).build()
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }
        }

        StateLayer {
            enabled: root.locked
            radius: shell.radius
            onClicked: Weather.reload()
        }
    }
}

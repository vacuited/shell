pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    property bool chargingMode: false
    property var toast: null
    property bool compact: false
    property int maxWidth: 260

    readonly property bool onBattery: UPower.onBattery
    readonly property real batPct: UPower.displayDevice.ready ? UPower.displayDevice.percentage : 0
    readonly property color chargingColor: {
        if (onBattery)
            return batPct <= 0.2 ? Colours.palette.m3error : Colours.palette.m3secondary;
        return Colours.palette.m3primary;
    }

    readonly property color toastColor: {
        if (!toast)
            return Colours.palette.m3secondary;
        if (toast.type === Toast.Error)
            return Colours.palette.m3error;
        if (toast.type === Toast.Warning)
            return Colours.palette.m3tertiary;
        if (toast.type === Toast.Success)
            return Colours.palette.m3primary;
        return Colours.palette.m3secondary;
    }

    readonly property string etaText: {
        if (!UPower.displayDevice.ready)
            return "";
        const secs = onBattery ? UPower.displayDevice.timeToEmpty : UPower.displayDevice.timeToFull;
        if (!secs || secs <= 0)
            return "";
        const mins = Math.round(secs / 60);
        const h = Math.floor(mins / 60);
        const m = mins % 60;
        return h > 0 ? `${h}h ${m}m` : `${m}m`;
    }

    implicitWidth: chargingMode ? chargingRow.implicitWidth : toastRow.implicitWidth
    implicitHeight: chargingMode ? chargingRow.implicitHeight : toastRow.implicitHeight

    // Charging transition pill
    RowLayout {
        id: chargingRow

        anchors.centerIn: parent
        visible: root.chargingMode
        spacing: Tokens.spacing.small

        CircularProgress {
            Layout.alignment: Qt.AlignVCenter
            implicitSize: root.compact ? 20 : 22
            strokeWidth: 3
            value: root.batPct
            fgColour: root.chargingColor

            MaterialIcon {
                anchors.centerIn: parent
                text: root.onBattery ? "power_off" : "bolt"
                color: root.chargingColor
                fontStyle: Tokens.font.icon.size(root.compact ? 11 : 12).build()
                fill: 1
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: root.onBattery
                ? Tr.tr("On battery")
                : (root.batPct >= 0.99 ? Tr.tr("Charged") : Tr.tr("Charging"))
            color: root.chargingColor
            font: root.compact
                ? Tokens.font.label.builders.large.weight(Font.DemiBold).build()
                : Tokens.font.title.builders.small.weight(Font.DemiBold).build()
        }

        StyledRect {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: pctLabel.implicitWidth + Tokens.padding.small * 2
            implicitHeight: root.compact ? 18 : 20
            radius: Tokens.rounding.full
            color: Qt.alpha(root.chargingColor, 0.16)

            StyledText {
                id: pctLabel

                anchors.centerIn: parent
                text: Strings.percent(root.batPct)
                color: root.chargingColor
                font: Tokens.font.mono.small
            }
        }

        StyledText {
            visible: root.etaText.length > 0
            Layout.alignment: Qt.AlignVCenter
            text: root.etaText
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
        }
    }

    // System toast pill
    RowLayout {
        id: toastRow

        anchors.centerIn: parent
        visible: !root.chargingMode && root.toast !== null
        spacing: Tokens.spacing.small

        StyledRect {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: root.compact ? 20 : 22
            implicitHeight: root.compact ? 20 : 22
            radius: Tokens.rounding.full
            color: Qt.alpha(root.toastColor, 0.18)

            MaterialIcon {
                anchors.centerIn: parent
                text: {
                    if (root.toast?.icon && root.toast.icon.length > 0)
                        return root.toast.icon;
                    if (root.toast?.type === Toast.Error)
                        return "error";
                    if (root.toast?.type === Toast.Warning)
                        return "warning";
                    if (root.toast?.type === Toast.Success)
                        return "check_circle";
                    return "info";
                }
                color: root.toastColor
                fontStyle: Tokens.font.icon.size(root.compact ? 12 : 14).build()
                fill: 1
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: root.maxWidth
            text: root.toast?.title ?? ""
            color: Colours.palette.m3onSurface
            font: root.compact
                ? Tokens.font.label.builders.large.weight(Font.DemiBold).build()
                : Tokens.font.title.builders.small.weight(Font.DemiBold).build()
            elide: Text.ElideRight
        }

        StyledText {
            visible: (root.toast?.message ?? "").length > 0
            Layout.alignment: Qt.AlignVCenter
            text: "•"
            color: Colours.palette.m3outline
            font: Tokens.font.label.medium
        }

        StyledText {
            visible: (root.toast?.message ?? "").length > 0
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: Math.max(80, Math.round(root.maxWidth * 0.55))
            text: (root.toast?.message ?? "").replace(/\s+/g, " ").trim()
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
            elide: Text.ElideRight
        }
    }
}

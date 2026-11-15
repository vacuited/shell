pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    property NotifData notif
    property bool holdActive: false
    property bool compact: false
    property int maxWidth: 260

    property NotifData heldNotif

    readonly property int iconSize: compact ? 20 : 22
    readonly property bool isCritical: (notif?.urgency ?? NotificationUrgency.Normal) === NotificationUrgency.Critical
    readonly property bool isLow: (notif?.urgency ?? NotificationUrgency.Normal) === NotificationUrgency.Low

    readonly property color badgeBg: isCritical
        ? Colours.palette.m3error
        : (isLow ? Colours.palette.m3surfaceContainerHigh : Colours.palette.m3secondaryContainer)

    readonly property color badgeFg: isCritical
        ? Colours.palette.m3onError
        : (isLow ? Colours.palette.m3onSurface : Colours.palette.m3onSecondaryContainer)

    readonly property string bodyPreview: {
        const raw = notif?.body ?? "";
        if (raw.length === 0)
            return "";
        return raw.replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    function releaseHold(): void {
        if (!heldNotif)
            return;
        heldNotif.locks.delete(root);
        if (!heldNotif.closed && !heldNotif.resident)
            heldNotif.timer.restart();
        heldNotif = null;
    }

    function syncHold(): void {
        const target = (holdActive && notif && !notif.closed) ? notif : null;
        if (heldNotif === target)
            return;
        releaseHold();
        if (target) {
            heldNotif = target;
            heldNotif.locks.add(root);
            heldNotif.timer.stop();
        }
    }

    onNotifChanged: syncHold()
    onHoldActiveChanged: syncHold()
    Component.onDestruction: releaseHold()

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        StyledRect {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: root.iconSize
            implicitHeight: root.iconSize
            radius: Tokens.rounding.full
            color: root.badgeBg

            ClippingRectangle {
                anchors.fill: parent
                visible: (root.notif?.image ?? "").length > 0
                radius: Tokens.rounding.full
                color: "transparent"

                Image {
                    anchors.fill: parent
                    source: root.notif?.image ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }
            }

            ColouredIcon {
                anchors.centerIn: parent
                visible: (root.notif?.image ?? "").length === 0 && (root.notif?.appIcon ?? "").length > 0
                width: Math.round(parent.width * 0.65)
                height: Math.round(parent.height * 0.65)
                source: (root.notif?.appIcon ?? "").length > 0 ? Quickshell.iconPath(root.notif.appIcon) : ""
                colour: root.badgeFg
                layer.enabled: (root.notif?.appIcon ?? "").endsWith("symbolic")
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: (root.notif?.image ?? "").length === 0 && (root.notif?.appIcon ?? "").length === 0
                text: Icons.getNotifIcon(root.notif?.summary ?? "", root.notif?.urgency ?? NotificationUrgency.Normal)
                color: root.badgeFg
                fontStyle: Tokens.font.icon.size(root.compact ? 12 : 13).build()
                fill: root.isCritical ? 1 : 0
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: root.maxWidth
            text: root.notif?.summary ?? ""
            color: root.isCritical ? Colours.palette.m3error : Colours.palette.m3onSurface
            font: root.compact
                ? Tokens.font.label.builders.large.weight(Font.DemiBold).build()
                : Tokens.font.title.builders.small.weight(Font.DemiBold).build()
            elide: Text.ElideRight
        }

        StyledText {
            visible: root.bodyPreview.length > 0
            Layout.alignment: Qt.AlignVCenter
            text: "•"
            color: Colours.palette.m3outline
            font: Tokens.font.label.medium
        }

        StyledText {
            visible: root.bodyPreview.length > 0
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: Math.max(90, Math.round(root.maxWidth * 0.55))
            text: root.bodyPreview
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
            elide: Text.ElideRight
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    property string thoughtText: ""
    property bool isFinished: true
    property bool expanded: false

    visible: thoughtText.length > 0 || !isFinished
    implicitHeight: visible ? mainCol.implicitHeight + Tokens.padding.small * 2 : 0
    radius: Tokens.rounding.medium
    color: Colours.tPalette.m3surfaceContainer
    border.width: 1
    border.color: !isFinished
        ? Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.45)
        : Colours.tPalette.m3outlineVariant

    Behavior on implicitHeight {
        Anim { type: Anim.DefaultSpatial }
    }

    ColumnLayout {
        id: mainCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.padding.small
        spacing: root.expanded ? Tokens.spacing.small : 0

        // Header Row (Toggle)
        Item {
            Layout.fillWidth: true
            implicitHeight: 26

            StateLayer {
                anchors.fill: parent
                radius: Tokens.rounding.small
                color: Colours.palette.m3onSurface
                enabled: root.thoughtText.length > 0
                onClicked: root.expanded = !root.expanded
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.extraSmall
                anchors.rightMargin: Tokens.padding.extraSmall
                spacing: Tokens.spacing.small

                MaterialIcon {
                    id: pulseIcon
                    text: root.isFinished ? "psychology" : "autorenew"
                    fontStyle: Tokens.font.icon.small
                    color: root.isFinished ? Colours.palette.m3secondary : Colours.palette.m3primary

                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 1400
                        loops: Animation.Infinite
                        running: !root.isFinished
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: !root.isFinished
                        ? qsTr("Reasoning...")
                        : qsTr("Thought process (%1 chars)").arg(root.thoughtText.length)
                    font: Tokens.font.label.medium
                    color: root.isFinished ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3primary
                    elide: Text.ElideRight
                }

                MaterialIcon {
                    visible: root.thoughtText.length > 0
                    text: root.expanded ? "expand_less" : "expand_more"
                    fontStyle: Tokens.font.icon.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }

        // Collapsible Thought Content
        StyledRect {
            Layout.fillWidth: true
            visible: root.expanded && root.thoughtText.length > 0
            implicitHeight: visible ? Math.min(thoughtBody.implicitHeight + Tokens.padding.small * 2, 220) : 0
            radius: Tokens.rounding.small
            color: Colours.tPalette.m3surfaceContainerLowest
            clip: true

            Flickable {
                anchors.fill: parent
                anchors.margins: Tokens.padding.small
                contentWidth: width
                contentHeight: thoughtBody.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                StyledText {
                    id: thoughtBody
                    width: parent.width
                    text: root.thoughtText
                    wrapMode: Text.Wrap
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                    opacity: 0.88
                }
            }
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

ColumnLayout {
    id: root

    signal suggestionSelected(string promptText)

    spacing: Tokens.spacing.medium

    Item {
        id: logoWrap
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 76
        implicitHeight: 76
        scale: logoMouse.pressed ? 0.9 : (logoMouse.containsMouse ? 1.08 : 1.0)

        Behavior on scale { Anim { type: Anim.FastSpatial } }

        Logo {
            id: emptyStateLogo
            anchors.fill: parent
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: emptyStateLogo
            colorization: 1.0
            colorizationColor: Colours.palette.m3primary
        }

        MouseArea {
            id: logoMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: greetingText.pickPhrase()
        }
    }

    ColumnLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Tokens.spacing.extraSmall

        StyledText {
            id: greetingText
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: 360
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            font: Tokens.font.title.medium
            color: Colours.palette.m3onSurface

            readonly property var phrases: [
                "Ask away, %1!",
                "How can I help you today, %1?",
                "What's on your mind, %1?",
                "Ready when you are, %1!",
                "Let's get started, %1.",
                "What shall we explore today, %1?",
                "I'm all ears, %1!"
            ]

            function pickPhrase() {
                var user = Quickshell.env("USER") || "user";
                var userCapitalized = user.charAt(0).toUpperCase() + user.slice(1);
                var phrase = phrases[Math.floor(Math.random() * phrases.length)];
                text = phrase.replace("%1", userCapitalized);
            }

            Component.onCompleted: pickPhrase()
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Type / for quick commands")
            font: Tokens.font.body.small
            color: Colours.palette.m3onSurfaceVariant
            opacity: 0.72
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
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
        implicitWidth: 132
        implicitHeight: 132

        VoidLogo {
            id: emptyStateLogo

            anchors.fill: parent
            interactive: true
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
                "Ask away, %1.",
                "Horizon is ready, %1.",
                "What are we building, %1?",
                "What's on your mind, %1?",
                "Ready when you are, %1.",
                "Beyond the event horizon, %1."
            ]

            function pickPhrase(): void {
                const user = Quickshell.env("USER") || "user";
                const userCapitalized = user.charAt(0).toUpperCase() + user.slice(1);
                const phrase = phrases[Math.floor(Math.random() * phrases.length)];
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

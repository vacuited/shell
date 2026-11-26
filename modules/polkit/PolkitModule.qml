pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Polkit 0.1
import qs.components

Scope {
    id: root

    PolkitAgent {
        id: polkitAgent
        // PolkitAgent handles dbus registration automatically.
    }

    Variants {
        model: Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : []

        PolkitDialog {
            required property ShellScreen modelData

            agent: polkitAgent
            screen: modelData
        }
    }
}

pragma Singleton

import QtQuick
import Caelestia.I18n

QtObject {
    id: root

    function indexOfKey(key: string): int {
        return pages.findIndex(p => p.key === key || (key === "appearance" && p.key === "wallpaper"));
    }

    readonly property list<var> pages: [
        // Appearance
        {
            key: "wallpaper",
            label: Tr.tr("Wallpaper & style"),
            icon: "palette",
            description: Tr.tr("Wallpaper, fonts, colours"),
            category: "appearance"
        },
        {
            key: "background",
            label: qsTr("Background elements"),
            icon: "wallpaper",
            description: qsTr("Clock, lyrics, visualiser, shimeji"),
            category: "appearance"
        },
        {
            key: "assets",
            label: Tr.tr("Shell assets"),
            icon: "image",
            description: Tr.tr("Logo, gifs, placeholder images"),
            category: "appearance"
        },
        {
            key: "tokens",
            label: qsTr("Shell Tokens"),
            icon: "tune",
            description: qsTr("Modify interface spacing, rounding, and sizing"),
            category: "appearance",
            developerOnly: true
        },

        // Connectivity
        // TODO
        // {
        //     key: "display",
        //     label: Tr.tr("Display"),
        //     icon: "monitor",
        //     description: Tr.tr("Output configuration"),
        //     category: "connectivity"
        // },
        {
            key: "network",
            label: Tr.tr("Network"),
            icon: "wifi",
            description: Tr.tr("Wi-Fi, ethernet, VPN"),
            category: "connectivity"
        },
        {
            key: "bluetooth",
            label: Tr.tr("Connected devices"),
            icon: "devices_other",
            description: Tr.tr("Bluetooth, pairing"),
            category: "connectivity",
            noFill: true
        },
        {
            key: "audio",
            label: Tr.tr("Audio"),
            icon: "volume_up",
            description: Tr.tr("App volumes, sound devices"),
            category: "connectivity"
        },

        // System
        {
            key: "updates",
            label: Tr.tr("Updates"),
            icon: "update",
            description: Tr.tr("System updates"),
            category: "system"
        },
        {
            key: "plugins",
            label: Tr.tr("Plugins"),
            icon: "extension",
            description: Tr.tr("Manage plugins"),
            category: "system"
        },

        // Shell
        {
            key: "panels",
            label: Tr.tr("Panels"),
            icon: "dock_to_bottom",
            description: Tr.tr("Dashboard, taskbar, launcher, sidebar"),
            category: "shell"
        },
        {
            key: "apps",
            label: Tr.tr("Apps"),
            icon: "apps",
            description: Tr.tr("Default apps, favourites, hidden apps"),
            category: "shell"
        },
        {
            key: "hyprland",
            label: qsTr("Hyprland"),
            icon: "layers",
            description: qsTr("Window manager configuration"),
            category: "shell"
        },
        {
            key: "services",
            label: qsTr("Services"),
            icon: "build",
            description: Tr.tr("Poll intervals, lyrics backend"),
            category: "shell"
        },
        {
            key: "language",
            label: Tr.tr("Language & region"),
            icon: "globe",
            description: Tr.tr("UI language, weather location, display units"),
            category: "shell"
        },

        // About
        {
            key: "about",
            label: Tr.tr("About"),
            icon: "info",
            description: Tr.tr("System information, credits"),
            category: "about"
        },
    ]
}

<div align="center">

# Vacuited Shell

<sub>My personal Quickshell setup for Caelestia, originally forked from [caelestia-dots/shell](https://github.com/caelestia-dots/shell) via [midnight-shell](https://github.com/dim-ghub/midnight-shell).</sub>

<br>

[![last commit](https://img.shields.io/github/last-commit/vacuited/shell?style=flat-square&color=9ccbfb)](https://github.com/vacuited/shell)
[![repo size](https://img.shields.io/github/repo-size/vacuited/shell?style=flat-square&color=d3bfe6)](https://github.com/vacuited/shell)
[![license](https://img.shields.io/github/license/vacuited/shell?style=flat-square&color=96f1f1)](https://github.com/vacuited/shell)

</div>

> [!WARNING]
> Built for my own machine first (HP Victus 15). Hardware toggles and fan controls are tailored to my specs, so things might not work on other setups. Use at your own risk.

---

## Features & Changes

### Dynamic Island Notch & Desktop Widgets
<sub>Ported from [cykler-caelestia](https://github.com/cykler01/cykler-caelestia) and heavily reworked to fit my setup and be cleaner/minimal</sub>
- **Notch / Dynamic Island**: Morphing top pill with live Cava visualiser bars, spinning album art, clock, and active Pomodoro countdown.
- **Notch Controls Drawer**: Expands on hover or click (or disable entirely in settings) with media and focus controls. Includes misclick guards and auto-collapses cleanly.
- **Smart Compact Mode**: Auto-shrinks when windows are open to save space, or toggle `Always compact` in settings.
- **Top Edge Dashboard Access**: Fixed hit-testing so hovering the very top edge above or beside the notch still opens the dashboard smoothly without fighting the notch.
- **Desktop Widgets**: 6 snapping cards (Weather, Focus timer, Calendar, System resources, Now playing, Battery) on a 40px grid with wallpaper blur and auto-fade when tiled windows open.
- **Nexus Grid Editor**: Visual drag-and-drop miniature under `Nexus > Background elements` to reposition cards freely.
- **Shell Assets Page**: Custom profile picture (`~/.face`), system logo, GIFs (`sessionGif`, `mediaGif`), and empty notification placeholders under `Nexus > Appearance > Shell assets`.

### Focus Suite (Pomodoro)
- **Multi-Phase Timer**: Focus, short break, and long break intervals with custom cycles, daily session/time stats, and completion toasts.
- **Active-Only Notch**: Timer countdown and short controls (`Play/Pause`, `Skip`, `Reset`) only show up in the notch when a session is actively running. Stays completely hidden when idle.
- **Dashboard Focus Tab**: Dedicated tab right before Notes with circular progress ring, duration adjustments, and session history.
- **Quick Toggle & IPC**: 1-click toggle in Utilities drawer and full IPC support via `caelestia ipc call pomodoro <toggle|reset|skip|status>`.

### Wallpaper Engine & Visuals
- **Auto-Pause on Battery & Windows**: Suspends `linux-wallpaperengine` (`SIGSTOP`) when covered or unplugged so it drops to 0% CPU/GPU, resuming instantly (`SIGCONT`) on desktop exposure.
- **Zero-Flash Transitions**: Holds previous frame during startup (`holdSource`) to kill black flashes, paired with blurred fallback wash on engine crashes.
- **GPU-Cached Thumbnails (`.ktx`)**: Uses `Caelestia.Multimedia` BC3 texture cache for instant lag-free wallpaper scrolling.
- **Carousel GIF Playback**: Only animates GIF thumbnails on the centered card to keep overhead light.

### AI Assistant & Sidebar
- **Headless Background Engine (`AiEngine.qml`)**: Persistent streaming, tool calling, `<think>` reasoning extraction, and multi-turn session storage (`~/.config/caelestia/ai_chats.json`) running decoupled from the sidebar UI.
- **Dynamic Width & Expanding Pill Header**: Smoothly expands sidebar by `+18%` on the AI tab with a clean expanding pill nav (`Notifications`, `AI`, `News`).
- **Modular Cards & Tools**: Clean thinking blocks, message bubbles with 1-click copy, slash menu (`/new`, `/model`, `/tools`, `/history`), vision screen capture (`grim`), Spotify playback/search, reminders, and web search.
- **Shortcuts**: Instant toggle and autofocus via `SUPER + A` (`caelestia:aiAssistant`) or fresh session via `SUPER + SHIFT + A`.

### Hardware Controls (HP Victus)
- **Fan & Thermal Gauges**: Live spinning fan discs with RPM readouts, package/die temps, and live wattage.
- **Quick Hardware Toggles**: 1-click switching for fan mode (`Auto` / `Max Boost`), Intel Turbo Boost (`Base` / `Boost`), and display refresh rate (`60Hz` / `144Hz`).
- **Power Profiles & Cool Mode**: 4-profile switcher (`Quiet`, `Cool`, `Balanced`, `Performance`) synced with battery popout and `vacuited-cli` polkit backend. Hides automatically on unsupported machines.

### Notes, Weather & Utilities
- **Caelestia Notes**: Integrated markdown workspace with persistent store, kept at the far right of dashboard tabs.
- **Hourly Weather**: Scrollable 7-day temperature curve and rain chances tucked behind a clean animated pill (`[ Hourly | 7-Day ]`).
- **Vertical Audio Popout**: Vertical master slider next to device cards, per-app volume sliders, and dynamic M3 tinted app icons (wallpaper audio filtered out).
- **Keep Awake Inhibitor**: 3-stage toggle in Utilities (`Off`, `Prevent Sleep`, `Prevent Lock & Sleep`).
- **Google Lens Screen Search**: Regional search button in Utilities drawer.
- **Draggable Quick Toggles**: Drag-and-drop reordering editor in `Nexus > Panels > Utilities`.
- **Hyprshutdown Graceful Exits**: Session dialog showing running apps before logout, reboot, or shutdown.

---

## Global Shortcuts

Bind these in your Hyprland configuration:

```conf
# Drawers & menus
bind = SUPER, SPACE, global, caelestia:launcher
bind = SUPER, RETURN, global, caelestia:launcher
bind = SUPER, S, global, caelestia:controlCenter
bind = SUPER, D, global, caelestia:dashboard
bind = SUPER, N, global, caelestia:sidebar
bind = SUPER, A, global, caelestia:aiAssistant
bind = SUPER SHIFT, A, global, caelestia:aiAssistantNew
bind = SUPER, M, global, caelestia:utilities

# Pickers & tools
bind = SUPER, E, global, caelestia:emoji
bind = SUPER, V, global, caelestia:clipboard
bind = SUPER, W, global, caelestia:windowSwitcher
bind = SUPER, K, global, caelestia:keybinds
bind = SUPER, B, global, caelestia:wallpaper
bind = SUPER, T, global, caelestia:terminal
```

---

## Install & Build

```fish
# Build plugin and install
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/ -DINSTALL_QSCONFDIR="$HOME/.config/quickshell/caelestia"
cmake --build build
sudo cmake --install build

# Run or reload shell
caelestia shell -d -r
```

---

## Credits

| Project | Upstream | What was ported / based on |
| :--- | :--- | :--- |
| **Caelestia Shell** | [caelestia-dots/shell](https://github.com/caelestia-dots/shell) | Original Quickshell desktop environment |
| **Midnight Shell** | [dim-ghub/midnight-shell](https://github.com/dim-ghub/midnight-shell) | Initial base fork, styling, launchers, desktop gadgets |
| **Cykler Caelestia** | [cykler01/cykler-caelestia](https://github.com/cykler01/cykler-caelestia) | Dynamic Island Notch, desktop widgets grid, shell assets page |
| **Caelestia Notes** | [Denzils-repo/Caelestia_Notes](https://github.com/Denzils-repo/Caelestia_Notes) | Notes tab component and store |
| **Caelestia Hourly Weather** | [ItsXyzzy/Caelestia-Hourly-Weather](https://github.com/ItsXyzzy/Caelestia-Hourly-Weather) | Hourly forecast and spline curve |
| **Nexus Night Mode** | [AEON-mod/Scripts](https://github.com/AEON-mod/Scripts/tree/main/Nexus-NightMode) | HyprSunset service, toggle, and temp slider |

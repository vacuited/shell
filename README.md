<div align="center">

# Vacuited Shell

<sub>My personal Quickshell setup for Caelestia, derived from [midnight-shell](https://github.com/dim-ghub/midnight-shell) and built on [caelestia-dots/shell](https://github.com/caelestia-dots/shell).</sub>

<br>

[![last commit](https://img.shields.io/github/last-commit/vacuited/shell?style=flat-square&color=9ccbfb)](https://github.com/vacuited/shell)
[![repo size](https://img.shields.io/github/repo-size/vacuited/shell?style=flat-square&color=d3bfe6)](https://github.com/vacuited/shell)
[![license](https://img.shields.io/github/license/vacuited/shell?style=flat-square&color=96f1f1)](https://github.com/vacuited/shell)

<br>

[Features](#features--changes) · [Install](#install--build) · [Shortcuts](#global-shortcuts) · [Credits](#credits)

</div>

> [!WARNING]
> Built for my own machine first (HP Victus 15). Hardware toggles and fan controls are tailored to my specs, so some things might not work on other setups. Use at your own risk.

---

## Features & Changes

### Dynamic Island Notch
- **Morphing Top Pill**: Expands smoothly with live Cava bars, spinning album art, clock, and active Pomodoro timers.
- **Controls Drawer**: Opens inline media and focus controls, then tucks into the top edge when fullscreen apps or the dashboard open.
- **Smart Compact Mode**: Auto-shrinks around open windows without blocking top-edge hover for the dashboard.

### Desktop Widgets, Clocks & Visuals
- **Desktop Widgets**: 15 snapping modular widgets with duplication, quick inline editing, and customizable tile shapes.
- **Surface Modes**: 4 card styles (`Glass`, `Blur`, `Frosted`, and `Material`) that blur the wallpaper behind them and fade out when windows cover the desktop.
- **Desktop Clocks**: 5 clock styles (`Classic`, `Cookie`, `Pixel`, `Stacked`, and `Smooth`) with inline editing and automatic spin pause when covered.
- **Desktop Lyrics**: Word-synced karaoke lyrics with 4 styles (`Apple Flow`, `Minimal`, `Editorial`, `Neon Glow`), multi-provider lookup (`Boidu`, `LyricsPlus`, `LRCLIB`, `NetEase`, local), and inline controls.
- **Audio Visualiser**: GPU shader visualiser (`Aurora`, `Bars`, `Wave`, `Dots`, `Glow`) with edge or centered layouts.

### Wallpaper Engine
- **Native `skwd-paper-v2` Support**: Runs Steam Workshop `scene` and `video` wallpapers natively with built-in Workshop search, downloads, property tweaks, and live audio controls.
- **Hybrid GPU & Quality Controls**: Offloads scenes to a discrete GPU on AC while falling back to the iGPU on battery, keeps video on VAAPI, and lets you tune FPS, resolution, and effects.
- **Smart Pause & Game Mode**: Pauses in place when covered or on battery, unloads cleanly (`0 MiB` VRAM) in Game Mode, and holds a high-res poster frame while paused.
- **Smooth Transitions & Caching**: Runs GPU transitions between Workshop wallpapers, morphing reveals for images/videos, and fast cached thumbnails in the launcher carousel.

### Focus Suite (Pomodoro)
- **Timer & Stopwatch**: Focus and break timer with quick presets (`25m`–`3h`), subject tags, chimes, automatic DND, and live notch controls.
- **Study Ledger & Goals**: Tracks daily goals, streaks with rest days, a 16-week heatmap, exam countdowns, and time per subject.
- **Screen Time & IPC**: Tracks active-window usage with 7-day charts, pauses while locked/asleep, and exposes full CLI control via `caelestia ipc call pomodoro`.

### AI Assistant & Sidebar
- **Background Chat Engine**: Streams chats in the background with collapsible reasoning blocks, tool calls, history, vision screen capture, Spotify control, reminders, and web search.
- **Adaptive Sidebar**: Widens automatically on the AI tab with a pill header (`Notifications`, `AI`, `News`) and quick slash commands (`/new`, `/model`, `/tools`, `/history`).
- **Quick Shortcuts**: Jumps straight to a focused prompt (`SUPER + A`) or starts a fresh chat (`SUPER + SHIFT + A`).

### Utilities, System & Updates
- **Built-in Nexus Updater**: Checks for `vacuited/shell` and `vacuited/cli` updates under `Nexus > Updates` with changelogs, automatic QML vs. C++ rebuilds, rollback snapshots, and one-click system hook sync.
- **Notes & Weather**: Includes a built-in markdown Notes tab plus an hourly curve and 7-day forecast toggle.
- **Audio & Quick Tools**: Vertical volume popout with M3-tinted app streams (wallpaper audio hidden), Keep Awake toggle, region web search, and customizable quick toggles.
- **HP Victus Hardware Controls**: Live fan RPM gauges, `Auto`/`Max Boost` fans, Intel Turbo Boost, `60Hz`/`144Hz` refresh rate, and 4 power profiles (`Quiet`, `Cool`, `Balanced`, `Performance`)—hidden on other machines.
- **Custom Branding & Logout Screen**: Custom profile pic, logos, and GIFs under `Nexus > Appearance > Shell assets`, plus `hyprshutdown` integration showing running apps on exit.

---

## Install & Build

```fish
git clone https://github.com/vacuited/shell.git
cd shell
./install.sh
```

`./install.sh` opens a quick menu to pick Standard or [tapes](https://github.com/futurekismo-oss/tapes) install plus optional addons like Wallpaper Engine. On Arch it handles packages and [vacuited-cli](https://github.com/vacuited/cli) automatically; on other distros it tells you what's missing before building.

<details>
<summary>Installer flags</summary>

| Flag | Description |
| :--- | :--- |
| `-i`, `--interactive` | Force the interactive setup menu |
| `-y`, `--yes` | Non-interactive install (passes `--noconfirm` to package managers) |
| `--tapes` | Install into a `tapes` rice (`~/.tapes/vacuited`) instead of `~/.config` |
| `--tape-name <name>` | Use a custom tape name (implies `--tapes`) |
| `--qml-only` | Fast QML/shader update only (skips deps, CLI, plugin, and helper) |
| `--with-wallpaper-engine` | Include Wallpaper Engine backend and Steam Workshop tools (Arch AUR) |
| `--with-optional` | Include extra runtime tools (`hyprsunset`, `hyprshutdown`, recorder, media) |
| `--update-cli` / `--skip-cli` | Reinstall or skip [vacuited-cli](https://github.com/vacuited/cli) |
| `--hardware` / `--no-hardware` | Force or skip the HP Victus hardware helper |
| `--skip-deps`, `--clean`, `--no-backup` | Skip dependency checks, clean CMake cache, or skip QML backup |
| `--uninstall`, `--dry-run` | Remove installed files or preview steps without changing anything |

</details>

<details>
<summary>Manual build</summary>

```fish
# Build and install C++ plugin + extras
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DINSTALL_LIBDIR=/usr/lib/caelestia -DINSTALL_QMLDIR=/usr/lib/qt6/qml -DENABLE_MODULES="extras;plugin" -DDISTRIBUTOR=vacuited
cmake --build build
sudo cmake --install build

# Deploy QML shell (non-root)
./install.sh --qml-only

# Start or reload shell
caelestia shell -d -r
```

</details>

---

## Global Shortcuts

Add autostart and keybinds to your Hyprland config:

```conf
# Autostart
exec-once = caelestia shell -d

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

## Credits

| Project | Upstream | What was ported / based on |
| :--- | :--- | :--- |
| **Caelestia Shell** | [caelestia-dots/shell](https://github.com/caelestia-dots/shell) | Original Quickshell desktop environment |
| **MiDnight Shell** | [dim-ghub/midnight-shell](https://github.com/dim-ghub/midnight-shell) | Initial base: styling, launchers, desktop gadgets |
| **Cykler Caelestia** | [cykler01/cykler-caelestia](https://github.com/cykler01/cykler-caelestia) | Initial Dynamic Island Notch concept and shell assets (heavily rewritten) |
| **Caelestia Notes** | [Denzils-repo/Caelestia_Notes](https://github.com/Denzils-repo/Caelestia_Notes) | Notes tab component and store |
| **Caelestia Hourly Weather** | [ItsXyzzy/Caelestia-Hourly-Weather](https://github.com/ItsXyzzy/Caelestia-Hourly-Weather) | Hourly forecast and spline curve |
| **Nexus Night Mode** | [AEON-mod/Scripts](https://github.com/AEON-mod/Scripts/tree/main/Nexus-NightMode) | HyprSunset service, toggle, and temperature slider |

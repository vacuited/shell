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
- **Morphing Top Pill**: Expands with Caelestia `BlobRect` jelly physics, live Cava visualiser bars, spinning album art, clock, and active Pomodoro countdown.
- **Controls Drawer**: Opens shape-morphing media and focus controls while sliding cleanly into the top border on fullscreen or dashboard open.
- **Smart Compact Mode**: Auto-shrinks when windows are open, with an optional always-compact toggle and unobstructed top-edge hover for the dashboard.

### Desktop Widgets, Clocks & Visuals
- **Desktop Widgets**: 15 snapping modular widgets with multi-instance duplication, inline quick-edit popovers, and 24 `MaterialShape` silhouettes for `1×1` tiles.
- **Surface Modes**: 4 configurable card styles (`Glass`, `Blur`, `Frosted`, and `Material`) with padded wallpaper blur and automatic fade when windows open.
- **Desktop Clocks**: 5 clock styles (`Classic`, `Cookie`, `Pixel`, `Stacked`, and `Smooth`) with inline editing and automatic spin pause when occluded.
- **Desktop Lyrics**: Word-synced karaoke lyrics with 4 visual styles (`Apple Flow`, `Minimal`, `Editorial`, `Neon Glow`), multi-provider lookup (`Boidu`, `LyricsPlus`, `LRCLIB`, `NetEase`, local), and inline controls.
- **GPU Audio Visualiser**: Custom C++ RHI shader renderer (`Aurora`, `Bars`, `Wave`, `Dots`, `Glow`) with edge or centered placement and adaptive frame pacing.

### Wallpaper Engine
- **Hybrid `skwd-paper-v2` Engine**: Renders Workshop `scene` and `video` wallpapers natively with built-in Steam Workshop search/download, property overrides, and live audio controls.
- **Hybrid GPU & Performance Controls**: Offloads scenes to a discrete GPU on AC while falling back to the iGPU on battery, keeps video decoding on VAAPI, and exposes FPS, resolution, particle, and effect limits.
- **Pause & Game Mode**: Pauses playback in place when covered or on battery, unloads cleanly (`0 MiB` VRAM) in Game Mode, and displays captured high-res PNG posters when paused.
- **Transitions & Caching**: Runs GPU-side transitions for Workshop wallpapers, 9-shape reveal morphs for static/video walls, BC3 `.ktx` cached thumbnails, and active-only carousel GIF playback.

### Focus Suite (Pomodoro)
- **Timer & Stopwatch**: Multi-phase focus engine with inline presets (`25m`–`3h`), subject tags, chimes, automatic DND, and live notch controls.
- **Study Ledger & Goals**: Persistent study history with daily goals, streak tracking with rest-day forgiveness, a 16-week consistency heatmap, exam countdowns, and subject breakdowns.
- **Screen Time & IPC**: Passive active-window usage tracker with 7-day charts, lock/sleep awareness, and full CLI control via `caelestia ipc call pomodoro`.

### AI Assistant & Sidebar
- **Headless Streaming Engine**: Background chat engine with tool calling, collapsible reasoning blocks, multi-turn history, vision screen capture, Spotify controls, reminders, and web search.
- **Adaptive Sidebar**: Smoothly widens on the AI tab with an expanding pill header (`Notifications`, `AI`, `News`) and a slash command menu (`/new`, `/model`, `/tools`, `/history`).
- **Quick Access**: Opens focused via `SUPER + A` (`caelestia:aiAssistant`) or starts a fresh chat via `SUPER + SHIFT + A`.

### Utilities, System & Updates
- **Built-in Nexus Updater**: Commit-level update checker for `vacuited/shell` and `vacuited/cli` under `Nexus > Updates` with changelogs, fast QML vs. plugin-rebuild detection, rollback backups, and cancellation.
- **Notes & Weather**: Integrated Caelestia Notes markdown workspace plus a compact hourly spline and 7-day forecast toggle.
- **Audio & Utilities**: Vertical master volume popout with M3-tinted app streams (wallpaper audio filtered out), 3-stage Keep Awake inhibitor, Google Lens region search, and draggable quick toggles.
- **HP Victus Hardware Controls**: Live RPM fan gauges, `Auto`/`Max Boost` fans, Intel Turbo Boost, `60Hz`/`144Hz` refresh rate, and 4-profile switching (`Quiet`, `Cool`, `Balanced`, `Performance`)—hidden automatically on other hardware.
- **Shell Assets & Logout UI**: Custom profile photo, logos, and GIFs under `Nexus > Appearance > Shell assets`, plus `hyprshutdown` integration showing open apps before exit.

---

## Install & Build

### Quick Install

```fish
git clone https://github.com/vacuited/shell.git
cd shell
./install.sh

# Direct flags (skip the interactive numbered menu)
./install.sh --with-wallpaper-engine
./install.sh --tapes
```

Running `./install.sh` opens an interactive numbered menu (Standard install, Tapes install, QML-only, Wallpaper Engine, and optional extras). It installs Arch dependencies (pacman + AUR, bootstrapping `yay` if needed), installs [vacuited-cli](https://github.com/vacuited/cli), configures login `PATH`, compiles the C++ plugin, deploys QML to `~/.config/quickshell/caelestia` (or `~/.tapes/<name>` with `--tapes`), and auto-detects HP Victus hardware controls. On other distros it verifies prerequisites and lists what is missing.

<details>
<summary>Installer options</summary>

| Flag | Description |
| :--- | :--- |
| `-i`, `--interactive` | Show the interactive numbered setup menu |
| `-y`, `--yes` | Non-interactive install (passes `--noconfirm` to package managers) |
| `--tapes` | Deploy QML shell as a `tapes` tape (`~/.tapes/vacuited`) |
| `--tape-name <name>` | Custom tape name (implies `--tapes`) |
| `--qml-only` | Deploy QML files and shaders only (skips deps, CLI, plugin, hardware) |
| `--with-optional` | Install optional runtime packages automatically (Arch) |
| `--with-wallpaper-engine` | Install Wallpaper Engine backend and Steam Workshop tools (Arch AUR) |
| `--update-cli` / `--skip-cli` | Force update or skip `vacuited-cli` installation |
| `--hardware` / `--no-hardware` | Force or skip HP Victus hardware helper + polkit rule |
| `--skip-deps`, `--clean`, `--no-backup` | Skip dependency checks, clean CMake cache, or skip config backup |
| `--uninstall`, `--dry-run` | Remove installed files or preview steps without modifying anything |

</details>

<details>
<summary>Manual build</summary>

```fish
# Build and install C++ plugin + extras
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DINSTALL_LIBDIR=/usr/lib/caelestia -DINSTALL_QMLDIR=/usr/lib/qt6/qml -DENABLE_MODULES="extras;plugin" -DDISTRIBUTOR=vacuited
cmake --build build
sudo cmake --install build

# Deploy QML shell to user config (non-root)
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

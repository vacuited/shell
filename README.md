<div align="center">

# Vacuited Shell

<sub>My personal Quickshell setup for Caelestia, derived from [midnight-shell](https://github.com/dim-ghub/midnight-shell) and built on [caelestia-dots/shell](https://github.com/caelestia-dots/shell).</sub>

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
- **Notch / Dynamic Island**: Morphing top pill with Caelestia `BlobRect` jelly physics, live Cava visualiser bars, spinning album art, clock, and active Pomodoro countdown.
- **Notch Controls Drawer**: Expands with shape-morphing `ButtonRow` media and focus controls, auto-collapses cleanly, and slides seamlessly into the top border when apps enter fullscreen or the dashboard opens.
- **Smart Compact Mode**: Auto-shrinks when windows are open to save space, or toggle `Always compact` in settings.
- **Top Edge Dashboard Access**: Fixed hit-testing so hovering the very top edge above or beside the notch still opens the dashboard smoothly without fighting the notch.
- **Desktop Widgets**: 15 modular snapping widgets (At a Glance, Weather card & pill, Timers, Countdown, Calendar, Resources, Media, Battery, Todo, Notes, User card, Sticker, Custom image & text) with multi-instance duplication, quick-edit popover, and `1×1` expressive `MaterialShape` silhouettes (`24` shapes).
- **Widget Surface Modes**: 4 configurable surface styles (`Glass`, `Blur`, `Frosted` via `ditherglass.frag.qsb`, and `Material`) with padded wallpaper blur and auto-fade when tiled windows open.
- **Desktop Clocks**: 5 clock styles (`Classic`, `Cookie`, `Pixel`, `Stacked`, and `Smooth`) with an inline quick-edit popover (style, surface, scale, and color controls), `Nexus > Background elements` settings, and automatic `Cookie` spin pause when covered by windows.
- **Desktop Lyrics**: Word-synced karaoke desktop lyrics (`karaokeword.frag.qsb`) with 4 visual styles (`Apple Flow`, `Minimal`, `Editorial`, `Neon Glow`), multi-provider backend (`Boidu`, `LyricsPlus`, `LRCLIB`, `NetEase`, local), and inline quick-edit popover.
- **GPU Audio Visualiser (`VisualiserView`)**: Custom C++ RHI shader renderer with 5 GLSL styles (`Aurora`, `Bars`, `Wave`, `Dots`, `Glow`), edge or centered stage placement, and adaptive frame pacing (`30 FPS` over Wallpaper Engine or open windows, `60 FPS` on desktop).
- **Shell Assets Page**: Custom profile picture (`~/.face`), system logo, GIFs (`sessionGif`, `mediaGif`), and empty notification placeholders under `Nexus > Appearance > Shell assets`.

### Focus Suite & Digital Wellbeing
- **Multi-Phase Engine**: Countdown timer and stopwatch flow modes with inline presets (`25m`–`3h`), optional `pauseOnSleep`, crash freeze recovery, subject tagging, audio chimes, and automatic DND inside a free-floating Caelestia Bento dashboard tab.
- **Study Ledger & Goals**: Permanent local history with daily goal progress, animated `StreakFlame` with rest day forgiveness, 16-week consistency heatmap, Exam Countdowns, scope-switchable subject breakdown (`All Time`, `This Week`, `Today`, or past 6 days), and tap-to-reassign `Untagged` entries.
- **Screen Time**: Passive active-window usage tracker (`~/.local/state/caelestia/screentime.json`) with a 7-day bar chart, configurable retention, and lock/DPMS/sleep awareness.
- **Active-Only Notch**: Compact display showing timer countdown and clickable subject tag cycling during focus, with drawer controls for play, +5m extension, skip, and reset.
- **Dedicated Nexus Settings**: Full configuration page under `Panels > Dashboard > Focus tab` for cycles, presets, goals, subjects, exam countdowns, transition chimes, and screen time retention.
- **Quick Toggle & IPC**: 1-click toggle in Utilities drawer and full IPC support via `caelestia ipc call pomodoro <toggle|reset|skip|extend|reduce|setMode|setSubject|cycleSubject|status>`.

### Wallpaper Engine & Visuals
- **Hybrid `skwd-paper-v2` Engine**: Renders Workshop `scene` and `video` wallpapers via `skwd-paper-v2` (`services/Skwd.qml` + `skwd_helper.py`) with built-in Steam Workshop search/download (`skwd-steam`), scene property overrides, and live audio controls.
- **Safe Hybrid dGPU Scene Offload & Performance Controls**: Offloads heavy scenes to a discrete GPU via `wl_shm` (`SKWD_VK_DEVICE=discrete` + `SKWD_VK_SCENE_SHM=1`) on AC while switching back to the iGPU on battery, keeps WE videos on native VAAPI decode, and exposes FPS caps, scene resolution scaling, particle/effect-chain limits, and dynamic Hyprland compositor blur toggling (`caelestia-bg-blur`).
- **Two-Tier Pause & Game Mode**: Pauses playback in place when covered or on battery, tears down cleanly (`0 MiB` VRAM) in Game Mode, and displays captured high-res PNG posters (`we-posters/`) when paused or switching out.
- **Seamless Transitions**: Uses GPU-side `skwd-paper-v2` transitions for Workshop wallpapers and native 9-shape `MaterialShape` reveal morphs for static and local video wallpapers.
- **GPU-Cached Thumbnails (`.ktx`)**: Uses `Caelestia.Multimedia` BC3 texture cache for instant lag-free wallpaper scrolling.
- **Carousel GIF Playback**: Only animates GIF thumbnails on the centered card to keep overhead light.

### AI Assistant & Sidebar
- **Headless Background Engine (`AiEngine.qml`)**: Persistent streaming, tool calling, `<think>` reasoning extraction, and multi-turn session storage (`~/.config/caelestia/ai_chats.json`) running decoupled from the sidebar UI.
- **Dynamic Width & Expanding Pill Header**: Smoothly expands sidebar by `+18%` on the AI tab with a clean expanding pill nav (`Notifications`, `AI`, `News`).
- **Modular Cards & Tools**: Clean thinking blocks, message bubbles with 1-click copy, slash menu (`/new`, `/model`, `/tools`, `/history`), vision screen capture (`grim`), Spotify playback/search, reminders, and web search.
- **Shortcuts**: Instant toggle and autofocus via `SUPER + A` (`caelestia:aiAssistant`) or fresh session via `SUPER + SHIFT + A`.

### Hardware Controls (HP Victus)
- **Fan & Thermal Gauges**: `CircularProgress` fan rings with live RPM-driven `FrameAnimation` spinning fans, bold RPM readouts, GPU wattage badge, and Caelestia `StyledProgressBar` levels.
- **Quick Hardware Toggles**: 1-click switching for fan mode (`Auto` / `Max Boost`), Intel Turbo Boost (`Base` / `Boost`), and display refresh rate (`60Hz` / `144Hz`) with morphing `MaterialShape` badges.
- **Power Profiles & Cool Mode**: 4-profile switcher (`Quiet`, `Cool`, `Balanced`, `Performance`) synced with battery popout and `vacuited-cli` polkit backend. Hides automatically on unsupported machines.

### Notes, Weather & Utilities
- **Caelestia Notes**: Integrated markdown workspace with persistent store, kept at the far right of dashboard tabs.
- **Hourly Weather**: Scrollable 7-day temperature curve and rain chances tucked behind a clean animated pill (`[ Hourly | 7-Day ]`).
- **Vertical Audio Popout**: Vertical master slider next to device cards, per-app volume sliders, and dynamic M3 tinted app icons (wallpaper audio filtered out).
- **Keep Awake Inhibitor**: 3-stage toggle in Utilities (`Off`, `Prevent Sleep`, `Prevent Lock & Sleep`).
- **Google Lens Screen Search**: Regional search button in Utilities drawer.
- **Draggable Quick Toggles**: Drag-and-drop reordering editor in `Nexus > Panels > Utilities`.
- **Built-in Nexus Updater**: Commit-level update checker for `vacuited/shell` and `vacuited/cli` under `Nexus > Updates` with changelog preview, fast QML-only vs. plugin-rebuild detection, rollback backups, and cancelable installs.
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

### Quick Install (Arch-based)

```fish
git clone https://github.com/vacuited/shell.git
cd shell
./install.sh
```

One command handles dependencies (Arch pacman + AUR, bootstrapping `yay` if needed), installs the [vacuited CLI](https://github.com/vacuited/cli) if missing, builds the C++ plugin, deploys QML to `~/.config/quickshell/caelestia` (backing up differing configs), and optionally sets up Wallpaper Engine (`--with-wallpaper-engine`) or HP Victus fan/profile controls (`--hardware`, auto-detected).

Options: `-y`/`--yes`, `--skip-deps`, `--skip-cli`, `--update-cli`, `--with-optional`, `--with-wallpaper-engine`, `--qml-only`, `--clean`, `--no-backup`, `--hardware`, `--no-hardware`, `--uninstall`, `--dry-run`. On other distros it verifies prerequisites and lists what is missing.

To auto-start on login, add `exec-once = caelestia shell -d` (alongside the Global Shortcuts above) to your Hyprland config.

### Manual Build

```fish
# Build and install C++ plugin + extras
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DINSTALL_LIBDIR=/usr/lib/caelestia -DINSTALL_QMLDIR=/usr/lib/qt6/qml -DENABLE_MODULES="extras;plugin" -DDISTRIBUTOR=vacuited
cmake --build build
sudo cmake --install build

# Deploy QML shell to user config (non-root)
./install.sh --qml-only

# Run or reload shell
caelestia shell -d -r
```

---

## Credits

| Project | Upstream | What was ported / based on |
| :--- | :--- | :--- |
| **Caelestia Shell** | [caelestia-dots/shell](https://github.com/caelestia-dots/shell) | Original Quickshell desktop environment |
| **MiDnight Shell** | [dim-ghub/midnight-shell](https://github.com/dim-ghub/midnight-shell) | Initial base the shell was derived from: styling, launchers, desktop gadgets |
| **Cykler Caelestia** | [cykler01/cykler-caelestia](https://github.com/cykler01/cykler-caelestia) | Initial idea and base for Dynamic Island Notch and shell assets (heavily rewritten) |
| **Caelestia Notes** | [Denzils-repo/Caelestia_Notes](https://github.com/Denzils-repo/Caelestia_Notes) | Notes tab component and store |
| **Caelestia Hourly Weather** | [ItsXyzzy/Caelestia-Hourly-Weather](https://github.com/ItsXyzzy/Caelestia-Hourly-Weather) | Hourly forecast and spline curve |
| **Nexus Night Mode** | [AEON-mod/Scripts](https://github.com/AEON-mod/Scripts/tree/main/Nexus-NightMode) | HyprSunset service, toggle, and temp slider |

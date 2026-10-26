<div align="center">

# vacuited shell

<sub>my personal quickshell setup for caelestia, originally forked from [caelestia-dots/shell](https://github.com/caelestia-dots/shell) via [midnight-shell](https://github.com/dim-ghub/midnight-shell)</sub>

<br>

[![last commit](https://img.shields.io/github/last-commit/vacuited/shell?style=flat-square&color=9ccbfb)](https://github.com/vacuited/shell)
[![repo size](https://img.shields.io/github/repo-size/vacuited/shell?style=flat-square&color=d3bfe6)](https://github.com/vacuited/shell)
[![license](https://img.shields.io/github/license/vacuited/shell?style=flat-square&color=96f1f1)](https://github.com/vacuited/shell)

</div>

> [!WARNING]
> built for my own machine first (hp victus 15). hardware toggles n fan controls r tailored to my specs so things might act cooked on other setups. use at ur own risk bro💔

---

## changes & features

### dynamic island notch & desktop widgets
<sub>ported from [cykler-caelestia](https://github.com/cykler01/cykler-caelestia) n heavily reworked to fit my setup</sub>
- **notch / dynamic island**: morphing top pill with live cava visualiser bars, spinning album art, clock, n active pomodoro countdown
- **notch controls drawer**: expands on hover or click (or disable entirely in nexus) with short media n focus controls. has misclick guards n auto-collapses cleanly
- **smart compact mode**: auto-shrinks when windows r open to save space, or toggle `always compact` in settings
- **top edge dashboard access**: fixed hit-testing so hovering the very top edge above or beside the notch still opens the dashboard smoothly without fighting the notch
- **desktop widgets**: 6 snapping cards (weather, focus timer, calendar, sys resources, now playing, battery) on a 40px grid with wallpaper blur n auto-fade when tiled windows open
- **nexus grid editor**: visual drag-and-drop miniature under `nexus > background elements` to reposition cards freely
- **shell assets page**: custom profile pic (`~/.face`), system logo, gifs (`sessionGif`, `mediaGif`), n empty notification placeholders under `nexus > appearance > shell assets`

### focus suite (pomodoro)
- **multi-phase timer**: focus, short break, n long break intervals with custom cycles, daily session/time stats, n completion toasts
- **active-only notch**: timer countdown n short controls (`play/pause`, `skip`, `reset`) only show up in the notch when a session is actually running. stays completely hidden when idle
- **dashboard focus tab**: dedicated tab right before notes with circular progress ring, duration adjustments, n session history
- **quick toggle & ipc**: 1-click toggle in utilities drawer n full ipc support via `caelestia ipc call pomodoro <toggle|reset|skip|status>`

### wallpaper engine & visuals
- **auto-pause on battery & windows**: suspends `linux-wallpaperengine` (`SIGSTOP`) when covered or unplugged so it drops to 0% cpu/gpu, resumes instantly (`SIGCONT`) on desktop exposure
- **zero-flash transitions**: holds previous frame during startup (`holdSource`) to kill black flashes, paired with blurred fallback wash on engine crashes
- **gpu-cached thumbnails (`.ktx`)**: uses `Caelestia.Multimedia` BC3 texture cache for instant lag-free wallpaper scrolling
- **carousel gif playback**: only animates gif thumbnails on the centered card to keep overhead light

### lilith ai assistant & sidebar
- **headless background engine (`AiEngine.qml`)**: persistent streaming, tool calling, `<think>` reasoning extraction, n multi-turn session storage (`~/.config/caelestia/ai_chats.json`) running decoupled from the sidebar ui
- **dynamic width & expanding pill header**: smoothly expands sidebar by `+18%` on the ai tab with a clean expanding pill nav (`notifications`, `lilith`, `news`)
- **modular cards & tools**: clean thinking blocks, message bubbles with 1-click copy, slash menu (`/new`, `/model`, `/tools`, `/history`), vision screen capture (`grim`), spotify playback/search, reminders, n web search
- **shortcuts**: instant toggle n autofocus via `SUPER + A` (`caelestia:aiAssistant`) or fresh session via `SUPER + SHIFT + A`

### hardware controls (hp victus)
- **fan & thermal gauges**: live spinning fan discs with rpm readouts, package/die temps, n live wattage
- **quick hardware toggles**: 1-click switching for fan mode (`auto` / `max boost`), intel turbo boost (`base` / `boost`), n display refresh rate (`60hz` / `144hz`)
- **power profiles & cool mode**: 4-profile switcher (`quiet`, `cool`, `balanced`, `performance`) synced with battery popout n `vacuited-cli` polkit backend. hides automatically on unsupported machines

### notes, weather & utilities
- **caelestia notes**: integrated markdown workspace with store, kept at the far right of dashboard tabs
- **hourly weather**: scrollable 7-day temperature curve n rain chances tucked behind a clean animated pill (`[ hourly | 7-day ]`)
- **vertical audio popout**: vertical master slider next to device cards, per-app volume sliders, n dynamic m3 tinted app icons (wallpaper audio filtered out)
- **keep awake inhibitor**: 3-stage toggle in utilities (`off`, `prevent sleep`, `prevent lock & sleep`)
- **google lens screen search**: regional search button in utilities drawer
- **draggable quick toggles**: drag-and-drop reordering editor in `nexus > panels > utilities`
- **hyprshutdown graceful exits**: session dialog showing running apps before logout, reboot, or shutdown

---

## global shortcuts

bind these in ur hyprland config:

```conf
# drawers & menus
bind = SUPER, SPACE, global, caelestia:launcher
bind = SUPER, RETURN, global, caelestia:launcher
bind = SUPER, S, global, caelestia:controlCenter
bind = SUPER, D, global, caelestia:dashboard
bind = SUPER, N, global, caelestia:sidebar
bind = SUPER, A, global, caelestia:aiAssistant
bind = SUPER SHIFT, A, global, caelestia:aiAssistantNew
bind = SUPER, M, global, caelestia:utilities

# pickers & tools
bind = SUPER, E, global, caelestia:emoji
bind = SUPER, V, global, caelestia:clipboard
bind = SUPER, W, global, caelestia:windowSwitcher
bind = SUPER, K, global, caelestia:keybinds
bind = SUPER, B, global, caelestia:wallpaper
bind = SUPER, T, global, caelestia:terminal
```

---

## install & build

```fish
# build plugin n install
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/ -DINSTALL_QSCONFDIR="$HOME/.config/quickshell/caelestia"
cmake --build build
sudo cmake --install build

# run or reload shell
caelestia shell -d -r
```

---

## credits

| project | upstream | what we took / based on |
| :--- | :--- | :--- |
| **caelestia shell** | [caelestia-dots/shell](https://github.com/caelestia-dots/shell) | original quickshell desktop environment |
| **midnight shell** | [dim-ghub/midnight-shell](https://github.com/dim-ghub/midnight-shell) | initial base fork, styling, launchers, desktop gadgets |
| **cykler caelestia** | [cykler01/cykler-caelestia](https://github.com/cykler01/cykler-caelestia) | dynamic island notch, desktop widgets grid, shell assets page |
| **caelestia notes** | [Denzils-repo/Caelestia_Notes](https://github.com/Denzils-repo/Caelestia_Notes) | notes tab component n store |
| **caelestia hourly weather** | [ItsXyzzy/Caelestia-Hourly-Weather](https://github.com/ItsXyzzy/Caelestia-Hourly-Weather) | hourly forecast n spline curve |
| **nexus night mode** | [AEON-mod/Scripts](https://github.com/AEON-mod/Scripts/tree/main/Nexus-NightMode) | hyprsunset service, toggle, n temp slider |
| **quickshell** | [outfoxxed/quickshell](https://quickshell.outfoxxed.me) | qt6 desktop shell framework |

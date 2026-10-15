<h1 align=center>Vacuited Shell</h1>

<div align=center>

![GitHub last commit](https://img.shields.io/github/last-commit/vacuited/shell?style=for-the-badge&labelColor=101418&color=9ccbfb)&nbsp;![GitHub repo size](https://img.shields.io/github/repo-size/vacuited/shell?style=for-the-badge&labelColor=101418&color=d3bfe6)&nbsp;![GitHub license](https://img.shields.io/github/license/vacuited/shell?style=for-the-badge&labelColor=101418&color=96f1f1)

A personal fork of [caelestia-dots/shell](https://github.com/caelestia-dots/shell) with custom features and optimizations.

</div>

> [!NOTE]
> **Active tracking & personalized build.** This is just [midnight-shell](https://github.com/dim-ghub/midnight-shell) but improved and customized to *my* personal preferences. It is actively maintained and continuously updated with upstream [caelestia-shell](https://github.com/caelestia-dots/shell).

> [!WARNING]
> **Built for my machine first.** These features and hardware controls are tailored for my own setup (HP Victus 15) and are not guaranteed to work reliably everywhere. Behavior may differ on your system. Use at your own *risk*.

## Features

### Vacuited Additions

| Feature | Description | Details |
| :--- | :--- | :--- |
| **Wallpaper Engine pause** | Suspends `linux-wallpaperengine` (`SIGSTOP`) behind windows or on battery | 0% CPU/GPU usage while hidden, instant `SIGCONT` resume |
| **Zero-flash transitions** | Holds previous frame during wallpaper engine startup | Prevents black frames, low-res flashes, and stutter |
| **Caelestia notes** | Integrated quick notes workspace into dashboard and launcher | Persistent notes store, quick editing, pinned tab |
| **Hourly weather forecast** | Animated 7-day temperature curve with rain probability | Collapsed behind a sliding `[ hourly \| 7-day ]` toggle pill |
| **AI tools & sidebar** | Multi-provider assistant with system tools and long-term memory | Screenshot, clipboard, Spotify, reminders, Tavily search |
| **Hardware controls** | Fan curves, platform profiles, refresh rate, and turbo boost | Dedicated HP Victus dashboard tab and battery popout toggle |
| **Keep awake toggle** | Tri-state idle inhibitor (`[ off \| prevent sleep \| prevent lock & sleep ]`) | Utilities card integration for presentations and downloads |
| **Vertical audio popout** | Vertical master volume alongside output/input device cards | Filtered PipeWire streams, recoloured app icons |

### Midnight & Upstream Base

| Feature | Description |
| :--- | :--- |
| **Dynamic palette extraction** | Material You M3 color schemes generated on wallpaper change |
| **Adaptive status bar** | Workspaces, clock, media indicators, and system tray |
| **System dashboard** | Quick toggles, performance graphs, weather summary, and audio controls |
| **App launcher** | Fast fuzzy application search with wallpaper picker and tools |
| **Lockscreen & OSD** | Volume, brightness, and session overlays |

## Changes

### Wallpaper engine integration
- **Pause behind windows & on battery**: Automatically suspends `linux-wallpaperengine` (`SIGSTOP`) when covered by windows or on battery power to reduce CPU/GPU usage to 0%, resuming instantly (`SIGCONT`) when visible.
- **Zero-flash transitions**: Preserves the previous wallpaper frame during engine startup to eliminate black frames and stretched low-res thumbnail flashes.
- **Smooth WE-to-WE switching**: Refined blurred placeholder transitions without high-contrast or dark snapping between live wallpapers.
- **Active carousel GIF playback**: Animated GIF thumbnails play only on the active/centered carousel item to conserve resources.
- **Crash recovery**: Automatically falls back to the previous working wallpaper if an engine crash occurs.
- **Launcher auto-focus**: Launcher opens directly to the wallpaper engine tab and focuses the currently active item on WE.

### Caelestia notes
- Integrated [Caelestia Notes](https://github.com/Denzils-repo/Caelestia_Notes) directly into the shell dashboard and launcher.

### Hourly weather forecast
- Integrated [Caelestia Hourly Weather](https://github.com/ItsXyzzy/Caelestia-Hourly-Weather) into the weather tab with a scrollable 7-day temperature curve, rain chance, and day summary.
- **Minimal view toggle**: Collapsed hourly and 7-day forecasts behind an animated toggle pill (`[ hourly | 7-day ]`) to keep the dashboard compact and clean.
- **Fixed laggy animation**: Eliminated per-frame curve re-tessellation, gated initial height animations, and cached active tabs for fluid 144 FPS swiping.

![weather preview](assets/weather.png)

### AI assistant & smart tools
- **Nexus subpage configuration**: Integrated full provider and tool configuration panels into Nexus (`Nexus > panels > sidebar > AI providers` / `AI tools`).
- **Multi-provider support**: Added custom OpenAI-compatible endpoint and OpenRouter configuration, dynamic model selection, and per-provider settings persisted to `~/.config/caelestia/ai_providers.json`.
- **System-integrated tool suite**: Native multi-turn tool calling supporting vision screenshots (`grim` + `hyprctl`), clipboard read/write (`wl-paste` / `wl-copy`), media playback controls (`playerctl`), system metrics, and Tavily web search with custom API credentials in `~/.config/caelestia/ai_tools.json`.
- **Spotify integration**: Added `spotify_search`, `spotify_play`, and `spotify_status` tools.
- **Reminders & notifications**: Scheduled reminders and immediate desktop notifications backed by `~/.config/caelestia/ai_reminders.json`.
- **Long-term memory**: Persistent user preferences and factual memory store in `~/.config/caelestia/ai_memory.json`.
- **Chat history persistence & navigation**: Reliable session storage in `~/.config/caelestia/ai_chats.json` with instant lifecycle flushes, resolved upstream file loading blocks.

### Hardware controls
- **Hero fan telemetry**: Dedicated CPU and GPU fan telemetry cards matching the performance tab sizing, featuring live spinning fan discs, RPM counters, temperature pills, and live GPU wattage.
- **3-column hardware toggles**: Instant switching for fan mode (`[ auto | max boost ]`), Intel Turbo Boost (`[ base | boost ]`), and display refresh rate (`[ 60 Hz | 144 Hz ]`).
- **4-profile power & thermal selector**: Full-width selector for `[ quiet | cool | balanced | performance ]` with instant sync across ACPI platform profiles, battery popout, and power-profiles-daemon.
- **Battery popout cool mode**: Extended the status bar battery popout with a native 4th `cool` profile button.
- **Seamless backend integration**: Backed by `vacuited-cli` (`caelestia hardware`) and a polkit-whitelisted helper for zero-password transitions.
- **Automatic hardware detection**: Tailored specifically for the **HP Victus 15** (`hp-wmi`, dual fans, `intel_pstate`, and RTX 40 series). On unsupported laptops or desktops without hp-wmi or ACPI platform profile support, the tab automatically hides itself, and backend controls safely no-op without altering system state.

### Keep awake & idle inhibitor
- **Tri-state power & lock control**: Integrated a 3-button control into the utilities card (`[ off | prevent sleep | prevent lock & sleep ]`). Prevents idle timeouts from turning displays off or suspending while optionally still permitting lock, or blocking both lock and sleep.

### Audio popout redesign
- **Vertical system volume slider**: Repositioned the primary volume slider vertically alongside the output and input device cards using a compact M3 filled pill.
- **Minimal app volume sliders**: Streamlined per-application volume controls directly above settings with dynamic M3-recolourable app icons, full-width sliders, and automatic background wallpaper stream filtering.

![audio preview](assets/audio.png)

## Credits

| Project | Upstream / Source | Contribution |
| :--- | :--- | :--- |
| **Caelestia Shell** | [caelestia-dots/shell](https://github.com/caelestia-dots/shell) | Original Quickshell desktop environment |
| **Midnight Shell** | [dim-ghub/midnight-shell](https://github.com/dim-ghub/midnight-shell) | Base fork with initial styling & extensions |
| **Caelestia Notes** | [Denzils-repo/Caelestia_Notes](https://github.com/Denzils-repo/Caelestia_Notes) | Notes tab component and store logic |
| **Caelestia Hourly Weather** | [ItsXyzzy/Caelestia-Hourly-Weather](https://github.com/ItsXyzzy/Caelestia-Hourly-Weather) | Hourly forecast and spline temperature curve |

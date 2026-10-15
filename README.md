<h1 align=center>vacuited shell</h1>

<div align=center>

![GitHub last commit](https://img.shields.io/github/last-commit/vacuited/shell?style=for-the-badge&labelColor=101418&color=9ccbfb)&nbsp;![GitHub repo size](https://img.shields.io/github/repo-size/vacuited/shell?style=for-the-badge&labelColor=101418&color=d3bfe6)&nbsp;![GitHub license](https://img.shields.io/github/license/vacuited/shell?style=for-the-badge&labelColor=101418&color=96f1f1)

a personal fork of [caelestia-dots/shell](https://github.com/caelestia-dots/shell) with custom features and optimizations.

</div>

> [!NOTE]
> **active tracking & personalized build.** based on [midnight-shell](https://github.com/dim-ghub/midnight-shell) and customized for personal use. actively maintained and synced with upstream [caelestia-shell](https://github.com/caelestia-dots/shell).

> [!WARNING]
> **tailored for hp victus 15.** hardware controls and fan curves target hp victus 15 sysfs interfaces. unsupported systems safely no-op or hide relevant modules.

## features

### vacuited additions

| feature | description | details |
| :--- | :--- | :--- |
| **wallpaper engine pause** | suspends `linux-wallpaperengine` (`SIGSTOP`) behind windows or on battery | 0% cpu/gpu usage while hidden, instant `SIGCONT` resume |
| **zero-flash transitions** | holds previous frame during wallpaper engine startup | prevents black frames, low-res flashes, and stutter |
| **caelestia notes** | integrated quick notes workspace into dashboard and launcher | persistent notes store, quick editing, pinned tab |
| **hourly weather forecast** | animated 7-day temperature curve with rain probability | collapsed behind a sliding `[ hourly \| 7-day ]` toggle pill |
| **ai tools & sidebar** | multi-provider assistant with system tools and long-term memory | screenshot, clipboard, spotify, reminders, tavily search |
| **hardware controls** | fan curves, platform profiles, refresh rate, and turbo boost | dedicated hp victus dashboard tab and battery popout toggle |
| **keep awake toggle** | tri-state idle inhibitor (`[ off \| prevent sleep \| prevent lock & sleep ]`) | utilities card integration for presentations and downloads |
| **vertical audio popout** | vertical master volume alongside output/input device cards | filtered pipewire streams, recoloured app icons |

### midnight & upstream base

| feature | description |
| :--- | :--- |
| **dynamic palette extraction** | material you m3 color schemes generated on wallpaper change |
| **adaptive status bar** | workspaces, clock, media indicators, and system tray |
| **system dashboard** | quick toggles, performance graphs, weather summary, and audio controls |
| **app launcher** | fast fuzzy application search with wallpaper picker and tools |
| **lockscreen & osd** | volume, brightness, and session overlays |

## changes

### wallpaper engine integration
- **pause behind windows & on battery**: automatically suspends `linux-wallpaperengine` (`SIGSTOP`) when covered by windows or on battery power to reduce cpu/gpu usage to 0%, resuming instantly (`SIGCONT`) when visible.
- **zero-flash transitions**: preserves the previous wallpaper frame during engine startup to eliminate black frames and stretched low-res thumbnail flashes.
- **smooth we-to-we switching**: refined blurred placeholder transitions without high-contrast or dark snapping between live wallpapers.
- **active carousel gif playback**: animated gif thumbnails play only on the active/centered carousel item to conserve resources.
- **crash recovery**: automatically falls back to the previous working wallpaper if an engine crash occurs.
- **launcher auto-focus**: launcher opens directly to the wallpaper engine tab and focuses the currently active item on we.

### caelestia notes
- integrated [caelestia notes](https://github.com/Denzils-repo/Caelestia_Notes) directly into the shell dashboard and launcher.

### hourly weather forecast
- integrated [caelestia hourly weather](https://github.com/ItsXyzzy/Caelestia-Hourly-Weather) into the weather tab with a scrollable 7-day temperature curve, rain chance, and day summary.
- **minimal view toggle**: collapsed hourly and 7-day forecasts behind an animated toggle pill (`[ hourly | 7-day ]`) to keep the dashboard compact and clean.
- **fixed laggy animation**: eliminated per-frame curve re-tessellation, gated initial height animations, and cached active tabs for fluid 144 fps swiping.

![weather preview](assets/weather.png)

### ai assistant & smart tools
- **nexus subpage configuration**: integrated full provider and tool configuration panels into nexus (`nexus > panels > sidebar > ai providers` / `ai tools`).
- **multi-provider support**: added custom openai-compatible endpoint and openrouter configuration, dynamic model selection, and per-provider settings persisted to `~/.config/caelestia/ai_providers.json`.
- **system-integrated tool suite**: native multi-turn tool calling supporting vision screenshots (`grim` + `hyprctl`), clipboard read/write (`wl-paste` / `wl-copy`), media playback controls (`playerctl`), system metrics, and tavily web search with custom api credentials in `~/.config/caelestia/ai_tools.json`.
- **spotify integration**: added `spotify_search`, `spotify_play`, and `spotify_status` tools.
- **reminders & notifications**: scheduled reminders and immediate desktop notifications backed by `~/.config/caelestia/ai_reminders.json`.
- **long-term memory**: persistent user preferences and factual memory store in `~/.config/caelestia/ai_memory.json`.
- **chat history persistence & navigation**: reliable session storage in `~/.config/caelestia/ai_chats.json` with instant lifecycle flushes, resolved upstream file loading blocks.

### hardware controls
- **hero fan telemetry**: dedicated cpu and gpu fan telemetry cards matching the performance tab sizing, featuring live spinning fan discs, rpm counters, temperature pills, and live gpu wattage.
- **3-column hardware toggles**: instant switching for fan mode (`[ auto | max boost ]`), intel turbo boost (`[ base | boost ]`), and display refresh rate (`[ 60 hz | 144 hz ]`).
- **4-profile power & thermal selector**: full-width selector for `[ quiet | cool | balanced | performance ]` with instant sync across acpi platform profiles, battery popout, and power-profiles-daemon.
- **battery popout cool mode**: extended the status bar battery popout with a native 4th `cool` profile button.
- **seamless backend integration**: backed by `vacuited-cli` (`caelestia hardware`) and a polkit-whitelisted helper for zero-password transitions.
- **automatic hardware detection**: tailored specifically for the **hp victus 15** (`hp-wmi`, dual fans, `intel_pstate`, and rtx 40 series). on unsupported laptops or desktops without hp-wmi or acpi platform profile support, the tab automatically hides itself, and backend controls safely no-op without altering system state.

### keep awake & idle inhibitor
- **tri-state power & lock control**: integrated a 3-button control into the utilities card (`[ off | prevent sleep | prevent lock & sleep ]`). prevents idle timeouts from turning displays off or suspending while optionally still permitting lock, or blocking both lock and sleep.

### audio popout redesign
- **vertical system volume slider**: repositioned the primary volume slider vertically alongside the output and input device cards using a compact m3 filled pill.
- **minimal app volume sliders**: streamlined per-application volume controls directly above settings with dynamic m3-recolourable app icons, full-width sliders, and automatic background wallpaper stream filtering.

![audio preview](assets/audio.png)

## credits

| project | upstream / source | contribution |
| :--- | :--- | :--- |
| **caelestia-shell** | [caelestia-dots/shell](https://github.com/caelestia-dots/shell) | original quickshell desktop environment |
| **midnight-shell** | [dim-ghub/midnight-shell](https://github.com/dim-ghub/midnight-shell) | base fork with initial styling & extensions |
| **caelestia notes** | [Denzils-repo/Caelestia_Notes](https://github.com/Denzils-repo/Caelestia_Notes) | notes tab component and store logic |
| **caelestia hourly weather** | [ItsXyzzy/Caelestia-Hourly-Weather](https://github.com/ItsXyzzy/Caelestia-Hourly-Weather) | hourly forecast and spline temperature curve |

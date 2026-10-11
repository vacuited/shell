my own customized build of [midnight-shell](https://github.com/dim-ghub/midnight-shell)

## changes

### wallpaper engine integration
- **pause behind windows & on battery**: automatically suspends `linux-wallpaperengine` (`SIGSTOP`) when covered by windows or on battery power to reduce CPU/GPU usage to 0%, resuming instantly (`SIGCONT`) when visible.
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
- **reminders & notifications**: scheduled reminders and immediate desktop notifications backed by `~/.config/caelestia/ai_reminders.json`.
- **long-term memory**: persistent user preferences and factual memory store in `~/.config/caelestia/ai_memory.json`.
- **chat history persistence & navigation**: reliable session storage in `~/.config/caelestia/ai_chats.json` with instant lifecycle flushes, resolved upstream file loading blocks.


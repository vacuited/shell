my own customized build of [midnight-shell](https://github.com/dim-ghub/midnight-shell)

## changes

### wallpaper engine integration
- **pause behind windows & on battery**: automatically suspends `linux-wallpaperengine` (`SIGSTOP`) when covered by windows or on battery power to reduce CPU/GPU usage to 0%, resuming instantly (`SIGCONT`) when visible.
- **zero-flash transitions**: preserves the previous wallpaper frame during engine startup to eliminate black frames and stretched low-res thumbnail flashes.
- **smooth we-to-we switching**: refined blurred placeholder transitions without high-contrast or dark snapping between live wallpapers.
- **active carousel gif playback**: animated gif thumbnails play only on the active/centered carousel item to conserve resources.
- **crash recovery**: automatically falls back to the previous working wallpaper if an engine crash occurs.
- **launcher auto-focus**: launcher opens directly to the wallpaper engine tab and focuses the currently active item.

### caelestia notes
- integrated [caelestia notes](https://github.com/Denzils-repo/Caelestia_Notes) directly into the shell dashboard and launcher.

### hourly weather forecast
- integrated [caelestia hourly weather](https://github.com/ItsXyzzy/Caelestia-Hourly-Weather) into the weather tab with a scrollable 7-day temperature curve, rain chance, and day summary.
- **minimal view toggle**: collapsed hourly and 7-day forecasts behind an animated toggle pill (`[ hourly | 7-day ]`) to keep the dashboard compact and clean.
- **zero-lag transitions**: eliminated per-frame curve re-tessellation, gated initial height animations, and cached active tabs for fluid 144 fps swiping.

![weather preview](assets/weather.png)

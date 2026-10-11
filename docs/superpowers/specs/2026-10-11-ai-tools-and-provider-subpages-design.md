# AI Tools Engine & Dedicated Settings Subpages Specification

## 1. Overview
Enhance `vacuited-shell`'s AI Assistant by replacing outdated/heavy tools with a unified on-demand Python tool runner (`assets/scripts/ai_tools.py`), incorporating fast Tavily web search, Spotify media control, Hyprland vision capture (`grim`), clipboard operations (`wl-copy`/`wl-paste`), system controls, and persistent memories. Restructure Nexus Settings (`SidebarPanel.qml`) to move AI Providers and AI Tools into dedicated, first-class subpages (`AiProvidersPanel.qml` and `AiToolsPanel.qml`).

---

## 2. Architecture & Components

### 2.1 Settings Navigation Topology
In `modules/nexus/PageCompRegistry.qml`:
- In the `Panels` `StackPage`:
  - Index 16: `Component { AiProvidersPanel {} }`
  - Index 17: `Component { AiToolsPanel {} }`

In `modules/nexus/pages/panels/SidebarPanel.qml`:
- Retains General & News sections.
- Under **AI Assistant**:
  - `ToggleRow`: "Enable Assistant" (`root.targetConfig.ai.enableOllama`)
  - `NavRow`: "AI Providers" (`>`) -> `root.nState.openSubPage(16)`
    - Subtext dynamically displays active provider and model count.
  - `NavRow`: "AI Tools" (`>`) -> `root.nState.openSubPage(17)`
    - Subtext indicates whether Celestial Mode is Enabled or Disabled.

### 2.2 `AiProvidersPanel.qml` Subpage
- Inherits `PageBase` with `title: qsTr("AI Providers")`, `isSubPage: true`.
- Renders configured providers with clean card layouts, endpoint URL, API key, model chips with delete (`x`), dedicated "+ Add model" input, and endpoint auto-discovery button.
- Clean "+ Add Provider" button at bottom.

### 2.3 `AiToolsPanel.qml` Subpage
- Inherits `PageBase` with `title: qsTr("AI Tools")`, `isSubPage: true`.
- **General**:
  - `ToggleRow`: "Enabled" (`root.targetConfig.ai.enableCelestialMode`).
- **Web Search**:
  - `ToggleRow`: "Enable Web Search" (`root.targetConfig.ai.tools.webSearch.enabled`).
  - `TextFieldRow`: "Tavily API Key" (`root.targetConfig.ai.tools.webSearch.tavilyApiKey`).
- **Spotify & Media**:
  - `ToggleRow`: "Enable Spotify Control" (`root.targetConfig.ai.tools.spotify.enabled`).
  - `TextFieldRow`: "Spotify Client ID" (`root.targetConfig.ai.tools.spotify.clientId`).
  - `TextFieldRow`: "Spotify Client Secret" (`root.targetConfig.ai.tools.spotify.clientSecret`).
- **Desktop & Vision**:
  - `ToggleRow`: "Screen Vision" (`root.targetConfig.ai.tools.vision.enabled`).
  - `ToggleRow`: "Clipboard Access" (`root.targetConfig.ai.tools.clipboard.enabled`).
- **System & Memory**:
  - `ToggleRow`: "System & Caelestia Control" (`root.targetConfig.ai.tools.system.enabled`).
  - `ToggleRow`: "Persistent Memory" (`root.targetConfig.ai.tools.memory.enabled`).

### 2.4 Tool Execution Engine (`assets/scripts/ai_tools.py`)
CLI interface invoked by `AiAssistant.qml`:
```bash
python3 assets/scripts/ai_tools.py --tool <tool_name> --args '<json_args>'
```
Implements:
1. `web_search`: Uses Tavily API (`https://api.tavily.com/search`) with API key from CLI argument or environment.
2. `take_screenshot`: Captures focused monitor via `grim` + `hyprctl monitors -j | jq`, optimizes with `magick` to `1024x1024` JPEG, returns path and base64.
3. `media_control` & `spotify_*`: Controls `playerctl` and Spotipy (search, queue, play track, liked song shuffle, volume).
4. `get_clipboard` & `set_clipboard`: `wl-paste` and `wl-copy`.
5. `save_memory` & `list_memories`: Reads/writes `~/.config/caelestia/ai_memory.json`.
6. `caelestia_command`: Runs `caelestia <subcommand>`.
7. `get_weather`: `curl wttr.in`.

### 2.5 Dynamic Filtering in `AiAssistant.qml`
- Reads tool configurations from `GlobalConfig.ai.tools`.
- When Celestial Mode is active, only populates `requestBody["tools"]` with the tool schemas that are individually enabled.
- On `take_screenshot`: if active model is vision-capable (e.g. `mimo-v2.6-flash-free`), sends base64 image data in the chat completion request.

---

## 3. Verification & Safety
- Full parity between repo and `~/.config/quickshell/caelestia`.
- Dual-branch commits to `main` and `we-fix`.
- Safe `shell.json` backup before any config adjustments.
- Log modifications in `~/SYSTEM_CHANGES.md`.

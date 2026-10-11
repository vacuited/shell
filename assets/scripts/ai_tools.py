#!/usr/bin/env python3
"""Unified AI Tools Execution Engine for Vacuited / Caelestia Shell.

Handles on-demand tool execution for the AI assistant without requiring
a persistent background daemon.
"""

import argparse
import base64
import html
from html.parser import HTMLParser
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

MAX_OUTPUT_CHARS = 4000
MEMORY_FILE = os.path.expanduser("~/.config/caelestia/ai_memory.json")


class HTMLTextExtractor(HTMLParser):

  def __init__(self):
    super().__init__()
    self.reset()
    self.strict = False
    self.convert_charrefs = True
    self.text_parts = []
    self.ignore_tags = {"script", "style", "head", "meta", "link", "noscript"}
    self.current_tag = None

  def handle_starttag(self, tag, attrs):
    self.current_tag = tag.lower()

  def handle_endtag(self, tag):
    if self.current_tag == tag.lower():
      self.current_tag = None

  def handle_data(self, data):
    if self.current_tag not in self.ignore_tags:
      cleaned = data.strip()
      if cleaned:
        self.text_parts.append(cleaned)

  def get_text(self):
    return " ".join(self.text_parts)


def run_cmd(argv, timeout=30, input_text=None):
  try:
    p = subprocess.run(
        argv,
        input=input_text.encode("utf-8") if input_text else None,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=timeout,
        check=False,
    )
    out = p.stdout.decode("utf-8", errors="replace").strip()
    err = p.stderr.decode("utf-8", errors="replace").strip()
    return p.returncode == 0, out or err
  except subprocess.TimeoutExpired:
    return False, "Command timed out"
  except Exception as e:
    return False, str(e)


# ---------------------------------------------------------------------------
# Tool Implementations
# ---------------------------------------------------------------------------


def tool_web_search(args, tavily_key):
  query = (args.get("query") or "").strip()
  if not query:
    return False, "ERROR: Search query cannot be empty."

  # Check Tavily key
  api_key = (
      tavily_key
      or os.environ.get("TAVILY_API_KEY")
      or os.environ.get("ZEN_TAVILY_API_KEY")
  )
  if api_key:
    try:
      req_data = json.dumps({
          "query": query,
          "max_results": 5,
          "search_depth": "basic",
      }).encode("utf-8")
      req = urllib.request.Request(
          "https://api.tavily.com/search",
          data=req_data,
          headers={
              "Content-Type": "application/json",
              "Authorization": f"Bearer {api_key}",
              "User-Agent": "Caelestia-Shell/1.0",
          },
      )
      with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.loads(resp.read().decode("utf-8"))

      results = data.get("results") or []
      if not results:
        return True, f"No results found for '{query}'."

      lines = [f"Search results for: {query}\n"]
      for idx, r in enumerate(results[:5], 1):
        title = r.get("title", "No Title")
        url = r.get("url", "")
        content = (r.get("content") or "").replace("\n", " ").strip()
        lines.append(f"{idx}. {title}\n   URL: {url}\n   Summary: {content}\n")
      return True, "\n".join(lines).strip()
    except urllib.error.HTTPError as e:
      return False, f"Tavily Search API error: HTTP {e.code}"
    except Exception as e:
      return False, f"Tavily Search failed: {e}"

  # Fallback to DuckDuckGo Instant Answer / HTML
  try:
    encoded = urllib.parse.quote_plus(query)
    url = f"https://html.duckduckgo.com/html/?q={encoded}"
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": (
                "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101"
                " Firefox/128.0"
            )
        },
    )
    with urllib.request.urlopen(req, timeout=12) as resp:
      html_content = resp.read().decode("utf-8", errors="replace")

    # Extract snippets
    snippets = re.findall(
        r'<a class="result__snippet[^>]*>(.*?)</a>', html_content, re.DOTALL
    )
    titles = re.findall(
        r'<a class="result__url[^>]*href="([^"]+)"[^>]*>(.*?)</a>',
        html_content,
        re.DOTALL,
    )
    if snippets:
      lines = [f"DuckDuckGo search results for '{query}':\n"]
      for i in range(min(4, len(snippets))):
        s_clean = re.sub(r"<[^>]+>", "", snippets[i]).strip()
        lines.append(f"{i+1}. {s_clean}")
      return True, "\n".join(lines)
    return (
        False,
        "No search results found. Add a Tavily API key in AI Tools settings for"
        " fast high-quality search.",
    )
  except Exception as e:
    return (
        False,
        f"Web search failed: {e}. Please configure a Tavily API key in AI"
        " Tools settings.",
    )


def tool_read_webpage(args):
  url = (args.get("url") or "").strip()
  if not url:
    return False, "ERROR: No URL provided."
  if not url.startswith("http://") and not url.startswith("https://"):
    url = "https://" + url

  try:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": (
                "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101"
                " Firefox/128.0"
            ),
            "Accept": "text/html,application/xhtml+xml,text/plain",
        },
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
      content_bytes = resp.read(MAX_OUTPUT_CHARS * 4)
      charset = resp.headers.get_content_charset() or "utf-8"
      raw_html = content_bytes.decode(charset, errors="replace")

    extractor = HTMLTextExtractor()
    extractor.feed(raw_html)
    text = extractor.get_text()
    if len(text) > MAX_OUTPUT_CHARS:
      text = text[:MAX_OUTPUT_CHARS] + "\n...[truncated]"
    return True, text or "Webpage returned no readable text."
  except Exception as e:
    return False, f"Failed to read webpage: {e}"


def tool_take_screenshot():
  raw_path = "/tmp/caelestia_ai_screen.png"
  opt_path = "/tmp/caelestia_ai_screen.jpg"

  # Capture focused monitor using grim + hyprctl
  hypr_cmd = "grim -g \"$(hyprctl monitors -j | jq -r '.[] | select(.focused) | \"\\(.x),\\(.y) \\(.width)x\\(.height)\"')\" " + raw_path
  ok, msg = run_cmd(["bash", "-c", hypr_cmd], timeout=15)
  if not ok or not os.path.exists(raw_path):
    # Fallback to simple grim
    ok, msg = run_cmd(["grim", raw_path], timeout=15)
    if not ok or not os.path.exists(raw_path):
      return False, f"Screenshot capture failed: {msg}", None, None

  # Resize & optimize with ImageMagick
  magick_cmd = f"magick {raw_path} -resize '1024x1024>' -quality 85 {opt_path}"
  ok, msg = run_cmd(["bash", "-c", magick_cmd], timeout=20)
  final_path = opt_path if os.path.exists(opt_path) else raw_path

  # Base64 encode for vision models
  b64_data = ""
  try:
    with open(final_path, "rb") as img_f:
      b64_data = base64.b64encode(img_f.read()).decode("utf-8")
  except Exception:
    pass

  return (
      True,
      f"Screenshot successfully captured to {final_path}",
      final_path,
      b64_data,
  )


def tool_get_clipboard():
  if shutil.which("wl-paste"):
    ok, out = run_cmd(["wl-paste", "-n"], timeout=8)
    return True, out if out else "(Clipboard is empty)"
  elif shutil.which("xclip"):
    ok, out = run_cmd(["xclip", "-o", "-selection", "clipboard"], timeout=8)
    return True, out if out else "(Clipboard is empty)"
  return False, "Clipboard tools (wl-paste/xclip) not available."


def tool_set_clipboard(args):
  text = args.get("text", "")
  if shutil.which("wl-copy"):
    ok, out = run_cmd(["wl-copy"], timeout=8, input_text=text)
    return ok, "Clipboard updated." if ok else out
  elif shutil.which("xclip"):
    ok, out = run_cmd(
        ["xclip", "-i", "-selection", "clipboard"], timeout=8, input_text=text
    )
    return ok, "Clipboard updated." if ok else out
  return False, "Clipboard tools (wl-copy/xclip) not available."


def tool_media_control(args):
  action = (args.get("action") or "status").lower().strip()
  if not shutil.which("playerctl"):
    return False, "playerctl is not installed."

  if action == "status":
    ok, out = run_cmd(
        ["playerctl", "metadata", "--format", "{{artist}} - {{title}} ({{status}})"],
        timeout=6,
    )
    if not ok or not out or "no players" in out.lower():
      return True, "No active media player detected."
    return True, f"Now playing: {out}"

  action_map = {
      "play": "play",
      "pause": "pause",
      "play-pause": "play-pause",
      "toggle": "play-pause",
      "next": "next",
      "prev": "previous",
      "previous": "previous",
      "stop": "stop",
  }
  cmd_action = action_map.get(action, "play-pause")
  ok, out = run_cmd(["playerctl", cmd_action], timeout=6)
  if ok:
    return True, f"Media action '{action}' executed."
  return False, f"Media command failed: {out}"


def tool_save_memory(args):
  content = (args.get("content") or "").strip()
  if not content:
    return False, "Content cannot be empty."
  category = (args.get("category") or "general").strip()

  memories = []
  if os.path.exists(MEMORY_FILE):
    try:
      with open(MEMORY_FILE, "r", encoding="utf-8") as f:
        memories = json.load(f)
    except Exception:
      memories = []

  entry = {
      "id": f"mem_{int(time.time()*1000)}",
      "category": category,
      "content": content,
      "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
  }
  memories.append(entry)

  os.makedirs(os.path.dirname(MEMORY_FILE), exist_ok=True)
  with open(MEMORY_FILE, "w", encoding="utf-8") as f:
    json.dump(memories, f, indent=2)

  return True, f"Saved memory [{category}]: {content}"


def tool_list_memories():
  if not os.path.exists(MEMORY_FILE):
    return True, "No saved memories found."
  try:
    with open(MEMORY_FILE, "r", encoding="utf-8") as f:
      memories = json.load(f)
    if not memories:
      return True, "No saved memories found."
    lines = ["Saved Memories:\n"]
    for idx, m in enumerate(memories[-15:], 1):
      cat = m.get("category", "general")
      cnt = m.get("content", "")
      lines.append(f"{idx}. [{cat}] {cnt}")
    return True, "\n".join(lines)
  except Exception as e:
    return False, f"Failed to read memories: {e}"


def tool_caelestia_command(args):
  subcmd = (args.get("subcommand") or "").strip()
  subargs = (args.get("args") or "").strip()
  if not subcmd:
    return False, "No Caelestia subcommand provided."

  cmd = ["caelestia", subcmd]
  if subargs:
    cmd.extend(subargs.split())

  ok, out = run_cmd(cmd, timeout=15)
  return ok, out or f"Executed 'caelestia {subcmd}' successfully."


def tool_get_weather(args):
  loc = (args.get("location") or "").strip()
  clean_loc = loc.replace('"', "").replace("'", "")
  url = f"https://wttr.in/{urllib.parse.quote(clean_loc)}?0T"
  ok, out = run_cmd(["curl", "-s", url], timeout=10)
  return ok, out or "Weather data unavailable."


def tool_get_system_info():
  cpu_ok, cpu = run_cmd(
      ["bash", "-c", "grep 'cpu ' /proc/stat | awk '{print ($2+$4)*100/($2+$4+$5)}'"],
      timeout=5,
  )
  cpu_str = f"CPU: {float(cpu):.1f}%" if (cpu_ok and cpu) else "CPU: Normal"
  _, mem = run_cmd(["free", "-h"], timeout=5)
  _, disk = run_cmd(["df", "-h", "/"], timeout=5)
  return True, f"{cpu_str}\n\nMemory:\n{mem}\n\nDisk:\n{disk}"


# ---------------------------------------------------------------------------
# CLI Dispatcher
# ---------------------------------------------------------------------------


def main():
  parser = argparse.ArgumentParser(description="Vacuited AI Tools Engine")
  parser.add_argument("--tool", required=True, help="Tool name to execute")
  parser.add_argument(
      "--args", default="{}", help="JSON arguments for the tool"
  )
  parser.add_argument("--tavily-key", default="", help="Tavily API key")
  parser.add_argument("--spotify-id", default="", help="Spotify client ID")
  parser.add_argument(
      "--spotify-secret", default="", help="Spotify client secret"
  )
  parsed = parser.parse_args()

  try:
    tool_args = json.loads(parsed.args)
  except Exception:
    tool_args = {}

  tname = parsed.tool
  image_path = None
  image_b64 = None

  if tname == "web_search":
    ok, result = tool_web_search(tool_args, parsed.tavily_key)
  elif tname == "read_webpage":
    ok, result = tool_read_webpage(tool_args)
  elif tname == "take_screenshot":
    ok, result, image_path, image_b64 = tool_take_screenshot()
  elif tname == "get_clipboard":
    ok, result = tool_get_clipboard()
  elif tname == "set_clipboard":
    ok, result = tool_set_clipboard(tool_args)
  elif tname == "media_control":
    ok, result = tool_media_control(tool_args)
  elif tname == "save_memory":
    ok, result = tool_save_memory(tool_args)
  elif tname == "list_memories":
    ok, result = tool_list_memories()
  elif tname == "caelestia_command":
    ok, result = tool_caelestia_command(tool_args)
  elif tname == "get_weather":
    ok, result = tool_get_weather(tool_args)
  elif tname == "get_system_info":
    ok, result = tool_get_system_info()
  else:
    ok = False
    result = f"Unknown tool: '{tname}'"

  payload = {"ok": ok, "result": result}
  if image_path:
    payload["image_path"] = image_path
  if image_b64:
    payload["image_base64"] = image_b64

  print(json.dumps(payload))


if __name__ == "__main__":
  main()

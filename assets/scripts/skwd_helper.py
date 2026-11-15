#!/usr/bin/env python3
"""Portable JSON CLI wrapper around skwd-paper-v2, skwd-helm, skwd-steam, ffmpeg, and hyprctl."""

from __future__ import annotations

import argparse
import json
import os
import random
import re
import shutil
import signal
import socket
import subprocess
import sys
import time
import uuid
from typing import Any

IMAGE_PREVIEW_CANDIDATES = (
    "preview.png",
    "preview.jpg",
    "preview.jpeg",
    "preview.webp",
    "preview.bmp",
    "preview.gif",
)
NON_IMAGE_TRANSITION_EXTS = (".gif", ".mp4", ".webm", ".mkv", ".mov", ".avi", ".m4v")


def _home() -> str:
    return os.path.expanduser("~")


def _xdg_runtime_dir() -> str:
    return os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"


def _xdg_cache_home() -> str:
    return os.environ.get("XDG_CACHE_HOME") or os.path.join(_home(), ".cache")


def _skwd_runtime_dir() -> str:
    return os.path.join(_xdg_runtime_dir(), "skwd-paper-v2")


def _skwd_cache_dir() -> str:
    return os.path.join(_xdg_cache_home(), "skwd-wall-v2")


def _emit(payload: dict[str, Any]) -> int:
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")
    sys.stdout.flush()
    return 0


def _fail(message: str, **extra: Any) -> int:
    payload: dict[str, Any] = {"ok": False, "error": message}
    payload.update(extra)
    return _emit(payload)


def _is_within(path: str, root: str) -> bool:
    real_root = os.path.realpath(root)
    real_path = os.path.realpath(path)
    return real_path == real_root or real_path.startswith(real_root + os.sep)


def _resolve_workshop_dir(custom_dir: str | None = None) -> str:
    candidates: list[str] = []
    if custom_dir:
        candidates.append(os.path.expanduser(custom_dir))

    home = _home()
    candidates.extend([
        os.path.join(home, ".local", "share", "Steam", "steamapps", "workshop", "content", "431960"),
        os.path.join(home, ".steam", "steam", "steamapps", "workshop", "content", "431960"),
        os.path.join(home, "SteamLibrary", "steamapps", "workshop", "content", "431960"),
    ])

    env_dir = os.environ.get("STEAM_WORKSHOP_DIR", "").strip()
    if env_dir:
        expanded = os.path.expanduser(env_dir)
        candidates.append(expanded)
        candidates.append(os.path.join(expanded, "431960"))

    for cand in candidates:
        if cand and os.path.isdir(cand):
            return os.path.realpath(cand)
    return ""


def _apply_hypr_rule_with_sentinel(
    hyprctl: str,
    sentinel_name: str,
    sentinel_val: str,
    attempts: tuple[tuple[list[str], ...], ...],
) -> None:
    runtime_dir = _skwd_runtime_dir()
    sentinel = os.path.join(runtime_dir, sentinel_name)
    try:
        if os.path.isfile(sentinel):
            with open(sentinel, "r", encoding="utf-8") as fh:
                if fh.read().strip() == sentinel_val and sentinel_val:
                    return
    except OSError:
        pass

    for cmds in attempts:
        all_ok = True
        for cmd in cmds:
            try:
                res = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    timeout=2,
                    check=False,
                )
                combined = f"{res.stdout}\n{res.stderr}".lower()
                if res.returncode != 0 or any(tok in combined for tok in ("unknown request", "error", "failed", "invalid")):
                    all_ok = False
                    break
            except (OSError, subprocess.SubprocessError):
                all_ok = False
                break
        if all_ok:
            if sentinel_val:
                try:
                    os.makedirs(runtime_dir, mode=0o700, exist_ok=True)
                    with open(sentinel, "w", encoding="utf-8") as fh:
                        fh.write(sentinel_val)
                except OSError:
                    pass
            return


def _ensure_hypr_bg_blur() -> None:
    hyprctl = shutil.which("hyprctl")
    if not hyprctl:
        return

    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    sentinel_val = f"v1:{sig}" if sig else ""
    lua_rule = 'hl.layer_rule({ match = { namespace = "caelestia-background" }, animation = "fade", blur = true, ignore_alpha = 0.22 })'
    attempts = (
        ([hyprctl, "eval", lua_rule],),
        (
            [hyprctl, "keyword", "layerrule", "blur 1, match:namespace caelestia-background"],
            [hyprctl, "keyword", "layerrule", "ignore_alpha 0.22, match:namespace caelestia-background"],
        ),
    )
    _apply_hypr_rule_with_sentinel(hyprctl, "caelestia_hypr_bg_blur", sentinel_val, attempts)


def _ensure_hypr_no_anim() -> None:
    _ensure_hypr_bg_blur()

    hyprctl = shutil.which("hyprctl")
    if not hyprctl:
        return

    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    sentinel_val = f"v2:{sig}" if sig else ""
    lua_rule = 'hl.layer_rule({ match = { namespace = "^skwd-(paper|wall).*" }, no_anim = true })'
    attempts = (
        ([hyprctl, "eval", lua_rule],),
        ([hyprctl, "keyword", "layerrule", "no_anim on, match:namespace ^skwd-(paper|wall).*"],),
    )
    _apply_hypr_rule_with_sentinel(hyprctl, "caelestia_hypr_no_anim", sentinel_val, attempts)


def _extract_last_json(text: str) -> Any | None:
    decoder = json.JSONDecoder()
    last_obj: Any | None = None
    idx = 0
    length = len(text)
    while idx < length:
        ch = text[idx]
        if ch in "{[":
            try:
                obj, end = decoder.raw_decode(text, idx)
                last_obj = obj
                idx = end
                continue
            except json.JSONDecodeError:
                pass
        idx += 1
    return last_obj


def _read_project_json(we_dir: str) -> tuple[dict[str, Any] | None, str | None]:
    real_dir = os.path.realpath(os.path.expanduser(we_dir))
    if not os.path.isdir(real_dir):
        return None, f"Wallpaper directory not found: {we_dir}"
    proj_path = os.path.join(real_dir, "project.json")
    if not _is_within(proj_path, real_dir) or not os.path.isfile(proj_path):
        return None, f"project.json not found in {real_dir}"
    try:
        with open(proj_path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
        if not isinstance(data, dict):
            return None, "project.json must contain a JSON object"
        return data, None
    except (OSError, json.JSONDecodeError) as exc:
        return None, f"Failed to read project.json: {exc}"


def _safe_child_file(root_dir: str, rel_path: str) -> str:
    if not rel_path:
        return ""
    candidate = os.path.join(root_dir, rel_path)
    if not _is_within(candidate, root_dir):
        return ""
    real_candidate = os.path.realpath(candidate)
    return real_candidate if os.path.isfile(real_candidate) else ""


def _resolve_preview(we_dir: str, data: dict[str, Any], prefer_static: bool = False) -> str:
    raw_preview = str(data.get("preview") or "").strip()
    resolved = _safe_child_file(we_dir, raw_preview)
    if resolved:
        if not (prefer_static and resolved.lower().endswith(".gif")):
            return resolved

    for name in IMAGE_PREVIEW_CANDIDATES:
        if prefer_static and name.endswith(".gif"):
            continue
        cand = _safe_child_file(we_dir, name)
        if cand:
            return cand

    return resolved if not prefer_static else ""


def _normalize_we_type(raw: Any) -> str:
    val = str(raw or "").strip().lower()
    if val in ("scene", "video", "web", "application"):
        return val
    return "unknown"


def _parse_properties(data: dict[str, Any]) -> list[dict[str, Any]]:
    raw_props = (data.get("general") or {}).get("properties")
    if not isinstance(raw_props, dict):
        return []

    parsed: list[tuple[float, str, dict[str, Any]]] = []
    for key, prop in raw_props.items():
        key_str = str(key).strip()
        if not key_str or len(key_str) > 64:
            continue
        if not isinstance(prop, dict):
            continue
        ptype = str(prop.get("type") or "").strip().lower()
        if ptype == "combolist":
            ptype = "combo"
        elif ptype == "checkbox":
            ptype = "bool"

        if ptype not in ("slider", "bool", "combo", "color"):
            continue

        raw_order = prop.get("order", 0)
        try:
            order_num = float(raw_order)
        except (TypeError, ValueError):
            order_num = 0.0

        options_out: list[dict[str, Any]] = []
        if ptype == "combo" and isinstance(prop.get("options"), list):
            for opt in prop["options"]:
                if isinstance(opt, dict):
                    val = opt.get("value")
                    label = str(opt.get("label") if opt.get("label") is not None else val)
                    options_out.append({"label": label, "value": val})
                else:
                    options_out.append({"label": str(opt), "value": opt})

        raw_text = str(prop.get("text") or key_str)
        clean_text = re.sub(r"<[^>]+>", "", raw_text).replace("&nbsp;", " ").strip() or key_str

        entry: dict[str, Any] = {
            "key": key_str,
            "type": ptype,
            "text": clean_text,
            "value": prop.get("value"),
            "min": prop.get("min", 0 if ptype == "slider" else None),
            "max": prop.get("max", 100 if ptype == "slider" else None),
            "step": prop.get("step", 1 if ptype == "slider" else None),
            "precision": prop.get("precision", 2 if ptype == "slider" else None),
            "fraction": bool(prop.get("fraction", False)),
            "options": options_out,
        }
        parsed.append((order_num, key_str, entry))

    parsed.sort(key=lambda item: (item[0], item[1]))
    return [item[2] for item in parsed]


def _get_transitions(paper_bin: str | None) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = [{"id": "fade", "label": "Fade", "duration_ms": 500}]
    seen = {"fade", "random"}

    if paper_bin:
        try:
            res = subprocess.run(
                [paper_bin, "transitions"],
                capture_output=True,
                text=True,
                timeout=5,
                check=False,
            )
            if res.returncode == 0:
                parsed = _extract_last_json(res.stdout)
                if isinstance(parsed, list):
                    for entry in parsed:
                        if not isinstance(entry, dict):
                            continue
                        tid = str(entry.get("id") or "").strip()
                        if not tid or tid in seen:
                            continue
                        seen.add(tid)
                        items.append({
                            "id": tid,
                            "label": str(entry.get("label") or tid),
                            "duration_ms": int(entry.get("duration_ms") or 0),
                        })
        except (OSError, ValueError, subprocess.SubprocessError):
            pass

    items.append({"id": "random", "label": "Random", "duration_ms": 0})
    return items


def _find_skwd_pids() -> list[int]:
    uid = os.getuid()
    pids: list[int] = []
    try:
        for name in ("skwd-paper-v2", "skwd-wall-vk"):
            res = subprocess.run(
                ["pgrep", "-u", str(uid), "-x", name],
                capture_output=True,
                text=True,
                timeout=2,
                check=False,
            )
            if res.returncode == 0:
                for line in res.stdout.splitlines():
                    line = line.strip()
                    if line.isdigit():
                        pids.append(int(line))
    except (OSError, subprocess.SubprocessError):
        pass
    return pids


def _is_skwd_running() -> bool:
    rt = _skwd_runtime_dir()
    if os.path.exists(os.path.join(rt, "paper.sock")) or os.path.exists(os.path.join(rt, "manager.lock")):
        if _find_skwd_pids():
            return True
    return bool(_find_skwd_pids())


def _paper_sock_rpc(method: str, params: dict[str, Any], timeout: float = 2.5) -> tuple[bool, Any]:
    sock_path = os.path.join(_skwd_runtime_dir(), "paper.sock")
    if not os.path.exists(sock_path):
        return False, "paper.sock unavailable"

    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.settimeout(timeout)
    try:
        sock.connect(sock_path)
        req = {
            "id": int(time.monotonic_ns() % 1_000_000_000),
            "method": method,
            "params": params,
        }
        sock.sendall((json.dumps(req) + "\n").encode("utf-8"))
        buf = b""
        while not buf.endswith(b"\n"):
            chunk = sock.recv(4096)
            if not chunk:
                break
            buf += chunk
        if not buf:
            return False, f"Empty response from {method}"
        resp = json.loads(buf.decode("utf-8", errors="replace").strip())
        if isinstance(resp, dict) and isinstance(resp.get("error"), dict):
            err = resp["error"]
            return False, str(err.get("message") or err.get("code") or f"{method} failed")
        if isinstance(resp, dict) and "result" in resp:
            return True, resp["result"]
        return True, resp
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        return False, str(exc)
    finally:
        try:
            sock.close()
        except OSError:
            pass


def _has_still_freeze_worker(status_result: Any) -> bool:
    if not isinstance(status_result, dict):
        return False
    assignments = status_result.get("assignments")
    if not isinstance(assignments, list):
        return False
    for item in assignments:
        if not isinstance(item, dict):
            continue
        pid = item.get("pid")
        if not isinstance(pid, int) or pid <= 0:
            continue
        try:
            with open(f"/proc/{pid}/comm", "r", encoding="utf-8") as fh:
                if fh.read().strip() == "skwd-wall-still":
                    return True
        except OSError:
            continue
    return False


def _set_paper_paused(paused: bool, paper_bin: str | None = None, env: dict[str, str] | None = None) -> tuple[bool, str]:
    ok_st, st_res = _paper_sock_rpc("paper.status", {})
    # If frozen by legacy skwd-wall-still (paper.pause), playback.pause(false) does not unfreeze it.
    if not paused and ok_st and _has_still_freeze_worker(st_res):
        if paper_bin:
            try:
                res = subprocess.run([paper_bin, "resume"], env=env, capture_output=True, text=True, timeout=5, check=False)
                if res.returncode == 0:
                    return True, ""
                return False, (res.stderr or res.stdout or "resume failed").strip()
            except (OSError, subprocess.SubprocessError) as exc:
                return False, str(exc)

    ok_rpc, rpc_res = _paper_sock_rpc("paper.playback.pause", {"paused": bool(paused)})
    if ok_rpc:
        return True, ""

    if not paper_bin:
        return False, str(rpc_res)

    action = "pause" if paused else "resume"
    try:
        res = subprocess.run([paper_bin, action], env=env, capture_output=True, text=True, timeout=5, check=False)
        if res.returncode == 0:
            return True, ""
        return False, (res.stderr or res.stdout or f"{action} failed").strip()
    except (OSError, subprocess.SubprocessError) as exc:
        return False, str(exc)


def _unload_skwd_processes(paper_bin: str | None) -> None:
    if paper_bin:
        try:
            subprocess.run([paper_bin, "stop"], capture_output=True, text=True, timeout=5, check=False)
        except (OSError, subprocess.SubprocessError):
            pass

    pids = _find_skwd_pids()
    for pid in pids:
        try:
            os.kill(pid, signal.SIGTERM)
        except OSError:
            pass

    deadline = time.monotonic() + 0.4
    while time.monotonic() < deadline:
        if not _find_skwd_pids():
            break
        time.sleep(0.05)

    for pid in _find_skwd_pids():
        try:
            os.kill(pid, signal.SIGKILL)
        except OSError:
            pass

    rt = _skwd_runtime_dir()
    sock_path = os.path.join(rt, "paper.sock")
    lock_path = os.path.join(rt, "manager.lock")
    wait_until = time.monotonic() + 0.8
    while time.monotonic() < wait_until:
        if not _find_skwd_pids() and not os.path.exists(sock_path):
            break
        time.sleep(0.05)

    if not _find_skwd_pids():
        for stale in (sock_path, lock_path):
            try:
                if os.path.exists(stale):
                    os.unlink(stale)
            except OSError:
                pass


def _skwd_log_paths() -> list[str]:
    cache_dir = _skwd_cache_dir()
    return [
        os.path.join(cache_dir, "skwd-wall-vk.log"),
        os.path.join(cache_dir, "skwd-paper.log"),
    ]


def _snapshot_log_offsets() -> dict[str, int]:
    offsets: dict[str, int] = {}
    for path in _skwd_log_paths():
        try:
            offsets[path] = os.path.getsize(path) if os.path.isfile(path) else 0
        except OSError:
            offsets[path] = 0
    return offsets


def _read_recent_skwd_error(since_offsets: dict[str, int] | None = None) -> tuple[str, bool]:
    candidates = [p for p in _skwd_log_paths() if os.path.isfile(p)]
    candidates.sort(key=lambda p: os.path.getmtime(p), reverse=True)

    lines: list[str] = []
    for path in candidates:
        try:
            size = os.path.getsize(path)
            start_pos = 0
            if since_offsets is not None:
                prev = since_offsets.get(path, 0)
                if prev <= size:
                    start_pos = prev
            with open(path, "r", encoding="utf-8", errors="replace") as fh:
                if start_pos > 0:
                    fh.seek(start_pos)
                    lines.extend(fh.readlines()[-40:])
                elif since_offsets is None:
                    lines.extend(fh.readlines()[-30:])
                else:
                    lines.extend(fh.readlines()[-40:])
        except OSError:
            continue

    text_blob = "\n".join(lines)
    rejected = bool(
        re.search(r"native-scene-gap|strict native scene startup rejected|rejected", text_blob, re.IGNORECASE)
    )

    for line in reversed(lines):
        clean = line.strip()
        if not clean:
            continue
        if any(tok in clean.lower() for tok in ("error", "rejected", "failed", "native-scene-gap")):
            if len(clean) > 260:
                clean = clean[:257] + "..."
            return clean, rejected
    return "", rejected


def _volume_percent(raw_volume: float) -> int:
    clamped = max(0.0, min(1.0, float(raw_volume)))
    return max(0, min(100, int(round(clamped * 100.0))))


_PCI_VENDOR_MAP = {
    "0x8086": "intel",
    "0x10de": "nvidia",
    "0x1002": "amd",
}
_DRM_DRIVER_VENDOR = {
    "i915": "intel",
    "xe": "intel",
    "nvidia": "nvidia",
    "nouveau": "nvidia",
    "amdgpu": "amd",
    "radeon": "amd",
}


def _read_trimmed(path: str) -> str:
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            return fh.read().strip()
    except OSError:
        return ""


def _infer_adapter_vendor(driver_str: str, name_str: str) -> str:
    blob = f"{driver_str} {name_str}".lower()
    if any(tok in blob for tok in ("nvidia", "geforce", "quadro", "rtx")):
        return "nvidia"
    if "intel" in blob:
        return "intel"
    if any(tok in blob for tok in ("amd", "radeon", "radv")):
        return "amd"
    return ""


def _scan_drm_cards() -> list[dict[str, Any]]:
    drm_root = "/sys/class/drm"
    if not os.path.isdir(drm_root):
        return []

    try:
        entries = os.listdir(drm_root)
    except OSError:
        return []

    cards: list[tuple[int, str]] = []
    for entry in entries:
        m = re.fullmatch(r"card(\d+)", entry)
        if m:
            cards.append((int(m.group(1)), entry))
    cards.sort()

    result: list[dict[str, Any]] = []
    for _, card in cards:
        card_dir = os.path.join(drm_root, card)
        dev_dir = os.path.join(card_dir, "device")
        driver_link = os.path.join(dev_dir, "driver")
        driver = os.path.basename(os.path.realpath(driver_link)).lower() if os.path.islink(driver_link) else ""
        vendor_hex = _read_trimmed(os.path.join(dev_dir, "vendor")).lower()
        vendor = _PCI_VENDOR_MAP.get(vendor_hex) or _DRM_DRIVER_VENDOR.get(driver, "")
        boot_vga = _read_trimmed(os.path.join(dev_dir, "boot_vga")) == "1"
        pci_slot = os.path.basename(os.path.realpath(dev_dir)) if os.path.exists(dev_dir) else ""
        pci_parts = pci_slot.split(":")
        is_root_bus = len(pci_parts) >= 2 and pci_parts[1] == "00"

        prefix = card + "-"
        connected_outputs: list[str] = []
        active_outputs: list[str] = []
        internal_active = False

        for entry in sorted(entries):
            if not entry.startswith(prefix):
                continue
            conn_name = entry[len(prefix):]
            conn_dir = os.path.join(drm_root, entry)
            status = _read_trimmed(os.path.join(conn_dir, "status")).lower()
            if status != "connected":
                continue
            connected_outputs.append(conn_name)
            enabled_raw = _read_trimmed(os.path.join(conn_dir, "enabled")).lower()
            is_active = (enabled_raw == "enabled") or (enabled_raw == "")
            if is_active:
                active_outputs.append(conn_name)
                if conn_name.startswith(("eDP", "LVDS")):
                    internal_active = True

        kind_hint = "unknown"
        if internal_active or boot_vga or (vendor in ("intel", "amd") and is_root_bus and driver in ("i915", "xe", "amdgpu", "radeon")):
            kind_hint = "integrated"
        elif driver == "nvidia" or vendor == "nvidia" or (not is_root_bus and driver):
            kind_hint = "discrete"

        result.append({
            "card": card,
            "driver": driver,
            "vendor": vendor,
            "kindHint": kind_hint,
            "bootVga": boot_vga,
            "internalActive": internal_active,
            "connectedOutputs": connected_outputs,
            "activeOutputs": active_outputs,
        })
    return result


def _detect_compositor_drm_card(cards: list[dict[str, Any]]) -> dict[str, Any] | None:
    if not cards:
        return None

    by_name = {c["card"]: c for c in cards}
    aq_raw = os.environ.get("AQ_DRM_DEVICES", "").strip()
    if aq_raw:
        aq_cards: list[dict[str, Any]] = []
        for item in aq_raw.split(":"):
            item = item.strip()
            if not item:
                continue
            resolved_name = os.path.basename(os.path.realpath(item))
            if resolved_name in by_name:
                aq_cards.append(by_name[resolved_name])
        if aq_cards:
            for cand in aq_cards:
                if cand["activeOutputs"]:
                    return cand
            for cand in aq_cards:
                if cand["connectedOutputs"]:
                    return cand
            if not any(c["connectedOutputs"] for c in cards):
                return aq_cards[0]

    active_cards = [c for c in cards if c["activeOutputs"]]
    if active_cards:
        active_cards.sort(
            key=lambda c: (
                1 if c["internalActive"] else 0,
                1 if c["bootVga"] else 0,
                1 if c["kindHint"] == "integrated" else 0,
            ),
            reverse=True,
        )
        return active_cards[0]

    connected_cards = [c for c in cards if c["connectedOutputs"]]
    if connected_cards:
        connected_cards.sort(
            key=lambda c: (1 if c["bootVga"] else 0, 1 if c["kindHint"] == "integrated" else 0),
            reverse=True,
        )
        return connected_cards[0]

    return cards[0]


def _probe_helm_adapters(helm_bin: str | None) -> list[dict[str, Any]]:
    if not helm_bin:
        return []
    try:
        res = subprocess.run(
            [helm_bin, "hw-probe"],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        if res.returncode == 0:
            parsed = _extract_last_json(res.stdout)
            if isinstance(parsed, dict) and isinstance(parsed.get("adapters"), list):
                return [a for a in parsed["adapters"] if isinstance(a, dict)]
    except (OSError, ValueError, subprocess.SubprocessError):
        pass
    return []


def _adapter_matches_compositor(
    adapter: dict[str, Any],
    kind: str,
    comp_card: dict[str, Any] | None,
    all_cards: list[dict[str, Any]],
) -> bool:
    if not comp_card:
        return kind == "integrated"

    comp_vendor = str(comp_card.get("vendor") or "")
    adapter_vendor = _infer_adapter_vendor(
        str(adapter.get("driver") or ""),
        str(adapter.get("name") or ""),
    )
    if comp_vendor and adapter_vendor:
        if adapter_vendor != comp_vendor:
            return False
        same_vendor_cards = [c for c in all_cards if c.get("vendor") == comp_vendor]
        if len(same_vendor_cards) > 1 and comp_card.get("kindHint") in ("integrated", "discrete"):
            return kind == comp_card["kindHint"]
        return True

    if comp_card.get("kindHint") in ("integrated", "discrete"):
        return kind == comp_card["kindHint"]
    return kind == "integrated"


def _resolve_safe_gpu(requested_gpu: str, helm_bin: str | None) -> str:
    req = requested_gpu if requested_gpu in ("auto", "integrated", "discrete") else "auto"
    if req == "auto":
        return "auto"

    cards = _scan_drm_cards()
    comp_card = _detect_compositor_drm_card(cards)
    if not comp_card:
        return "auto"

    adapters = _probe_helm_adapters(helm_bin)
    if adapters:
        for adapter in adapters:
            dt = str(adapter.get("device_type") or "").lower()
            kind = "integrated" if "integrated" in dt else ("discrete" if "discrete" in dt else "other")
            if kind == req and _adapter_matches_compositor(adapter, kind, comp_card, cards):
                return req
        return "auto"

    if comp_card.get("kindHint") == req:
        return req
    return "auto"


def _build_skwd_env(gpu: str = "auto") -> dict[str, str]:
    env = os.environ.copy()
    if gpu in ("integrated", "discrete"):
        env["SKWD_VK_DEVICE"] = gpu
    else:
        env.pop("SKWD_VK_DEVICE", None)

    # Clear legacy env vars; runtime policy is passed cleanly via --manifest JSON
    for var in (
        "SKWD_PAPER_WE_FPS",
        "SKWD_PAPER_OUTPUT_FPS",
        "SKWD_PAPER_WE_DISABLE_PARTICLES",
        "SKWD_VK_SCENE_MAX",
    ):
        env.pop(var, None)
    return env


def _resolve_max_dimension(paper_bin: str, explicit_max_dim: int) -> int:
    if explicit_max_dim > 0:
        return max(256, min(16384, int(explicit_max_dim)))
    try:
        res = subprocess.run(
            [paper_bin, "outputs"],
            capture_output=True,
            text=True,
            timeout=3,
            check=False,
        )
        if res.returncode == 0:
            parsed = _extract_last_json(res.stdout)
            outputs = parsed.get("result") if isinstance(parsed, dict) else parsed
            max_side = 0
            if isinstance(outputs, list):
                for out in outputs:
                    if isinstance(out, dict) and isinstance(out.get("size"), list) and len(out["size"]) >= 2:
                        w = int(out["size"][0] or 0)
                        h = int(out["size"][1] or 0)
                        max_side = max(max_side, w, h)
            if max_side > 0:
                return max(256, min(16384, max_side))
    except (OSError, ValueError, TypeError, subprocess.SubprocessError):
        pass
    return 0


def cmd_probe(args: argparse.Namespace) -> int:
    paper_bin = shutil.which("skwd-paper-v2")
    wall_vk_bin = shutil.which("skwd-wall-vk")
    steam_bin = shutil.which("skwd-steam")
    helm_bin = shutil.which("skwd-helm")

    _ensure_hypr_no_anim()

    cards = _scan_drm_cards()
    comp_card = _detect_compositor_drm_card(cards)

    gpus: list[dict[str, Any]] = []
    for idx, adapter in enumerate(_probe_helm_adapters(helm_bin)):
        dt = str(adapter.get("device_type") or "").lower()
        if "integrated" in dt:
            kind = "integrated"
        elif "discrete" in dt:
            kind = "discrete"
        else:
            kind = "other"
        matched = _adapter_matches_compositor(adapter, kind, comp_card, cards)
        gpus.append({
            "index": idx,
            "name": str(adapter.get("name") or ""),
            "kind": kind,
            "backend": str(adapter.get("backend") or ""),
            "driver": str(adapter.get("driver") or ""),
            "maxTextureDim": int(adapter.get("max_texture_dim") or 0),
            "compositorMatched": matched,
            "safe": matched,
        })

    has_safe_discrete = any(g["kind"] == "discrete" and g["compositorMatched"] for g in gpus)
    has_safe_integrated = any(g["kind"] == "integrated" and g["compositorMatched"] for g in gpus)
    compositor_gpu = next((g["name"] for g in gpus if g["compositorMatched"] and g["name"]), "")
    if not compositor_gpu and gpus:
        compositor_gpu = gpus[0]["name"]

    return _emit({
        "ok": True,
        "paperAvailable": bool(paper_bin and wall_vk_bin),
        "steamAvailable": bool(steam_bin),
        "helmAvailable": bool(helm_bin),
        "resolvedWorkshopDir": _resolve_workshop_dir(args.workshop_dir),
        "gpus": gpus,
        "hasSafeDiscrete": has_safe_discrete,
        "hasSafeIntegrated": has_safe_integrated if gpus else (comp_card["kindHint"] == "integrated" if comp_card else True),
        "compositorGpu": compositor_gpu,
        "drmCompositorCard": comp_card["card"] if comp_card else "",
        "drmCompositorDriver": comp_card["driver"] if comp_card else "",
    })


def cmd_transitions(_args: argparse.Namespace) -> int:
    return _emit({"ok": True, "transitions": _get_transitions(shutil.which("skwd-paper-v2"))})


def cmd_list_we(args: argparse.Namespace) -> int:
    resolved_dir = _resolve_workshop_dir(args.workshop_dir)
    if not resolved_dir:
        return _emit({"ok": True, "resolvedWorkshopDir": "", "items": []})

    poster_dir = os.path.join(_xdg_cache_home(), "caelestia", "we-posters")
    skwd_thumb_dir = os.path.join(_skwd_cache_dir(), "we-thumbs")
    items: list[dict[str, Any]] = []

    try:
        entries = sorted(os.listdir(resolved_dir))
    except OSError as exc:
        return _fail(f"Failed to scan workshop directory: {exc}", resolvedWorkshopDir=resolved_dir)

    for entry in entries:
        if not entry.isdigit():
            continue
        entry_path = os.path.join(resolved_dir, entry)
        if not _is_within(entry_path, resolved_dir):
            continue
        real_entry = os.path.realpath(entry_path)
        if not os.path.isdir(real_entry):
            continue

        data, err = _read_project_json(real_entry)
        if data is None or err is not None:
            continue

        we_type = _normalize_we_type(data.get("type"))
        proj_path = os.path.realpath(os.path.join(real_entry, "project.json"))
        preview = _resolve_preview(real_entry, data, prefer_static=False)
        if not preview:
            preview = _resolve_preview(real_entry, data, prefer_static=True)

        poster_path = os.path.join(poster_dir, f"{entry}.png")
        poster = poster_path if (os.path.isfile(poster_path) and os.path.getsize(poster_path) > 0) else ""

        skwd_thumb_path = os.path.join(skwd_thumb_dir, f"{entry}.webp")
        skwd_thumb = skwd_thumb_path if (os.path.isfile(skwd_thumb_path) and os.path.getsize(skwd_thumb_path) > 0) else ""

        thumb = poster or preview or skwd_thumb
        title = str(data.get("title") or entry).strip() or entry

        items.append({
            "id": entry,
            "title": title,
            "type": we_type,
            "path": real_entry,
            "projectPath": proj_path,
            "file": str(data.get("file") or ""),
            "unsupported": we_type in ("web", "application"),
            "preview": preview,
            "poster": poster,
            "thumb": thumb,
            "properties": _parse_properties(data),
        })

    items.sort(key=lambda it: (it["title"].lower(), it["id"]))
    return _emit({"ok": True, "resolvedWorkshopDir": resolved_dir, "items": items})


def _probe_video_duration(ffprobe_bin: str | None, video_path: str) -> float:
    if not ffprobe_bin:
        return 0.0
    try:
        res = subprocess.run(
            [
                ffprobe_bin,
                "-v",
                "error",
                "-show_entries",
                "format=duration",
                "-of",
                "default=noprint_wrappers=1:nokey=1",
                video_path,
            ],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        if res.returncode == 0:
            return float(res.stdout.strip() or 0.0)
    except (OSError, ValueError, subprocess.SubprocessError):
        pass
    return 0.0


def cmd_capture_poster(args: argparse.Namespace) -> int:
    we_dir = os.path.realpath(os.path.expanduser(args.source))
    dest = os.path.abspath(os.path.expanduser(args.dest))
    width = max(64, int(args.width))
    height = max(64, int(args.height))

    data, err = _read_project_json(we_dir)
    if data is None or err is not None:
        return _fail(err or "Invalid project.json")

    we_type = _normalize_we_type(data.get("type"))
    dest_dir = os.path.dirname(dest)
    try:
        os.makedirs(dest_dir, exist_ok=True)
    except OSError as exc:
        return _fail(f"Failed to create poster directory: {exc}")

    tmp_png = os.path.join(dest_dir, f".tmp_{os.getpid()}_{uuid.uuid4().hex[:8]}.png")

    try:
        if we_type == "scene":
            paper_bin = shutil.which("skwd-paper-v2")
            if not paper_bin:
                return _fail("skwd-paper-v2 is not installed")
            req = json.dumps({
                "source": we_dir,
                "destination": tmp_png,
                "width": width,
                "height": height,
            }) + "\n"
            res = subprocess.run(
                [paper_bin, "capture-scenes"],
                input=req,
                env=_build_skwd_env("auto"),
                capture_output=True,
                text=True,
                timeout=30,
                check=False,
            )
            if res.returncode != 0 or not os.path.isfile(tmp_png) or os.path.getsize(tmp_png) == 0:
                msg = (res.stderr or res.stdout or "capture-scenes failed").strip()
                return _fail(msg)
            os.replace(tmp_png, dest)
            return _emit({"ok": True, "source": we_dir, "poster": dest})

        ffmpeg_bin = shutil.which("ffmpeg")
        if we_type == "video":
            if not ffmpeg_bin:
                return _fail("ffmpeg is not installed")
            video_path = _safe_child_file(we_dir, str(data.get("file") or ""))
            if not video_path:
                return _fail("Video file missing in project directory")

            duration = _probe_video_duration(shutil.which("ffprobe"), video_path)
            seeks: list[float] = []
            if duration > 0.5:
                seeks.append(duration * 0.30)
            seeks.extend([1.0, 0.0])

            vf = f"scale='min({width},iw)':'min({height},ih)':force_original_aspect_ratio=decrease"
            captured = False
            last_err = "ffmpeg failed to extract video frame"
            for seek in seeks:
                res = subprocess.run(
                    [
                        ffmpeg_bin,
                        "-y",
                        "-ss",
                        f"{seek:.3f}",
                        "-i",
                        video_path,
                        "-frames:v",
                        "1",
                        "-vf",
                        vf,
                        tmp_png,
                    ],
                    capture_output=True,
                    text=True,
                    timeout=15,
                    check=False,
                )
                if res.returncode == 0 and os.path.isfile(tmp_png) and os.path.getsize(tmp_png) > 0:
                    captured = True
                    break
                if res.stderr:
                    last_err = res.stderr.strip().splitlines()[-1]

            if not captured:
                return _fail(last_err)
            os.replace(tmp_png, dest)
            return _emit({"ok": True, "source": we_dir, "poster": dest})

        static_preview = _resolve_preview(we_dir, data, prefer_static=True)
        if not static_preview:
            return _fail(f"No static preview available for '{we_type}' item")

        if ffmpeg_bin:
            res = subprocess.run(
                [ffmpeg_bin, "-y", "-i", static_preview, "-frames:v", "1", tmp_png],
                capture_output=True,
                text=True,
                timeout=10,
                check=False,
            )
            if res.returncode == 0 and os.path.isfile(tmp_png) and os.path.getsize(tmp_png) > 0:
                os.replace(tmp_png, dest)
                return _emit({"ok": True, "source": we_dir, "poster": dest})

        if static_preview.lower().endswith(".png"):
            shutil.copyfile(static_preview, tmp_png)
            os.replace(tmp_png, dest)
            return _emit({"ok": True, "source": we_dir, "poster": dest})

        return _fail("Failed to convert static preview to PNG")
    except (OSError, subprocess.SubprocessError) as exc:
        return _fail(str(exc))
    finally:
        if os.path.exists(tmp_png):
            try:
                os.unlink(tmp_png)
            except OSError:
                pass


def cmd_apply(args: argparse.Namespace) -> int:
    paper_bin = shutil.which("skwd-paper-v2")
    if not paper_bin:
        return _fail("skwd-paper-v2 is not installed", rejected=False)

    we_dir = os.path.realpath(os.path.expanduser(args.path))
    data, err = _read_project_json(we_dir)
    if data is None or err is not None:
        return _fail(err or "Invalid project.json", rejected=False)

    we_type = _normalize_we_type(data.get("type"))
    if we_type in ("web", "application"):
        return _fail(f"Wallpaper Engine '{we_type}' items are not supported by skwd", rejected=True)

    helm_bin = shutil.which("skwd-helm")
    gpu = _resolve_safe_gpu(args.gpu, helm_bin)
    fps = max(0, min(240, int(args.fps)))
    disable_particles = 1 if int(args.disable_particles) != 0 else 0
    max_dim = _resolve_max_dimension(paper_bin, int(args.max_dim))
    desired_fp = {
        "gpu": gpu,
        "fps": fps,
        "disable_particles": disable_particles,
        "max_dim": max_dim,
    }

    rt_dir = _skwd_runtime_dir()
    os.makedirs(rt_dir, mode=0o700, exist_ok=True)
    fp_path = os.path.join(rt_dir, "caelestia_env.json")

    prev_fp: dict[str, Any] | None = None
    if os.path.isfile(fp_path):
        try:
            with open(fp_path, "r", encoding="utf-8") as fh:
                loaded = json.load(fh)
            if isinstance(loaded, dict):
                prev_fp = loaded
        except (OSError, json.JSONDecodeError):
            prev_fp = None

    prev_gpu = prev_fp.get("gpu") if isinstance(prev_fp, dict) else None
    if int(args.force_restart) != 0 or (_is_skwd_running() and prev_gpu != gpu):
        _unload_skwd_processes(paper_bin)

    try:
        with open(fp_path, "w", encoding="utf-8") as fh:
            json.dump(desired_fp, fh)
    except OSError:
        pass

    env = _build_skwd_env(gpu)

    effect = (args.transition or "fade").strip().lower()
    if effect == "random":
        choices = [t["id"] for t in _get_transitions(paper_bin) if t["id"] != "random"]
        effect = random.choice(choices) if choices else "fade"

    raw_outputs = [o.strip() for o in str(args.output or "*").split(",") if o.strip()]
    outputs_list = ["*" if o.upper() in ("ALL", "*") else o for o in raw_outputs] or ["*"]
    if "*" in outputs_list:
        outputs_list = ["*"]

    source_obj: dict[str, Any] = {"kind": "we", "path": we_dir}
    if we_type == "scene" and args.properties:
        try:
            props_obj = json.loads(args.properties)
            if isinstance(props_obj, dict):
                filtered_props = {
                    str(k).strip(): v
                    for k, v in props_obj.items()
                    if 0 < len(str(k).strip()) <= 64 and v is not None
                }
                if len(filtered_props) > 0:
                    source_obj["properties"] = filtered_props
        except json.JSONDecodeError:
            return _fail("Invalid --properties JSON payload", rejected=False)

    vol_pct = _volume_percent(args.volume)
    assignment_obj: dict[str, Any] = {
        "outputs": outputs_list,
        "source": source_obj,
        "fill_mode": "fill",
        "layer": "background",
        "mute": int(args.mute) != 0,
        "volume": vol_pct,
    }

    if effect not in ("", "none", "off", "false"):
        transition_obj: dict[str, Any] = {"effect": effect}
        if args.transition_from:
            tfrom = os.path.realpath(os.path.expanduser(args.transition_from))
            if os.path.isfile(tfrom) and not tfrom.lower().endswith(NON_IMAGE_TRANSITION_EXTS):
                transition_obj["from"] = tfrom
        assignment_obj["transition"] = transition_obj
    else:
        effect = "none"

    scene_policy: dict[str, Any] = {
        "disable_particles": disable_particles == 1,
    }
    if fps > 0:
        scene_policy["fps"] = fps
    if max_dim > 0:
        scene_policy["max_dimension"] = max_dim

    policy_obj: dict[str, Any] = {"scene": scene_policy}
    if fps > 0:
        policy_obj["output_fps"] = {out: fps for out in outputs_list}

    manifest = {
        "assignments": [assignment_obj],
        "policy": policy_obj,
        "replace_all": True,
    }

    _ensure_hypr_no_anim()

    # Resume before applying so neither legacy skwd-wall-still rejects apply nor playback.pause leaks stale state
    if _is_skwd_running():
        ok_pre, res_pre = _paper_sock_rpc("paper.status", {})
        if ok_pre and isinstance(res_pre, dict) and bool(res_pre.get("paused")):
            _set_paper_paused(False, paper_bin=paper_bin, env=env)
        elif not ok_pre:
            try:
                st_pre = subprocess.run([paper_bin, "status"], env=env, capture_output=True, text=True, timeout=3, check=False)
                if st_pre.returncode == 0:
                    parsed_pre = _extract_last_json(st_pre.stdout)
                    res_pre = parsed_pre.get("result") if isinstance(parsed_pre, dict) and isinstance(parsed_pre.get("result"), dict) else parsed_pre
                    if isinstance(res_pre, dict) and bool(res_pre.get("paused")):
                        _set_paper_paused(False, paper_bin=paper_bin, env=env)
            except (OSError, subprocess.SubprocessError):
                pass

    log_offsets = _snapshot_log_offsets()

    try:
        res = subprocess.run(
            [paper_bin, "apply", "--manifest", "-"],
            input=json.dumps(manifest),
            env=env,
            capture_output=True,
            text=True,
            timeout=25,
            check=False,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        return _fail(str(exc), rejected=False)

    assignments: list[Any] = []
    if res.returncode == 0:
        try:
            st = subprocess.run([paper_bin, "status"], env=env, capture_output=True, text=True, timeout=5, check=False)
            if st.returncode == 0:
                parsed = _extract_last_json(st.stdout)
                if isinstance(parsed, dict):
                    result = parsed.get("result") if isinstance(parsed.get("result"), dict) else parsed
                    raw_assign = result.get("assignments")
                    if isinstance(raw_assign, list):
                        assignments = raw_assign
        except (OSError, subprocess.SubprocessError):
            pass

    if res.returncode != 0 or not assignments:
        log_err, log_rejected = _read_recent_skwd_error(log_offsets)
        cli_err = (res.stderr or res.stdout or "").strip()
        rejected = log_rejected or bool(
            re.search(r"native-scene-gap|rejected|unsupported", cli_err, re.IGNORECASE)
        )
        msg = cli_err if (res.returncode != 0 and cli_err) else (log_err or cli_err or "skwd-paper-v2 failed to apply wallpaper")
        return _fail(msg, rejected=rejected)

    return _emit({
        "ok": True,
        "ready": True,
        "type": we_type,
        "appliedDir": we_dir,
        "effectUsed": effect,
        "gpuUsed": gpu,
        "maxDimUsed": max_dim,
    })


def cmd_pause(_args: argparse.Namespace) -> int:
    paper_bin = shutil.which("skwd-paper-v2")
    if not paper_bin:
        return _fail("skwd-paper-v2 is not installed")
    ok, err = _set_paper_paused(True, paper_bin=paper_bin)
    if not ok:
        return _fail(err or "pause failed")
    return _emit({"ok": True})


def cmd_resume(_args: argparse.Namespace) -> int:
    paper_bin = shutil.which("skwd-paper-v2")
    if not paper_bin:
        return _fail("skwd-paper-v2 is not installed")
    ok, err = _set_paper_paused(False, paper_bin=paper_bin)
    if not ok:
        return _fail(err or "resume failed")
    return _emit({"ok": True})


def cmd_audio(args: argparse.Namespace) -> int:
    paper_bin = shutil.which("skwd-paper-v2")
    if not paper_bin:
        return _fail("skwd-paper-v2 is not installed")

    mute_flag = "true" if int(args.mute) != 0 else "false"
    volume = max(0.0, min(1.0, float(args.volume)))
    vol_pct = _volume_percent(volume)
    cmd = [paper_bin, "audio", "--mute", mute_flag, "--volume", str(vol_pct)]
    if args.output and args.output.upper() not in ("ALL", "*"):
        cmd.append(args.output)

    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=5, check=False)
        if res.returncode != 0:
            err = (res.stderr or res.stdout or "").strip()
            if "no active" not in err.lower():
                return _fail(err or "audio command failed")
        return _emit({"ok": True, "muted": mute_flag == "true", "volume": volume})
    except (OSError, subprocess.SubprocessError) as exc:
        return _fail(str(exc))


def cmd_stop(args: argparse.Namespace) -> int:
    paper_bin = shutil.which("skwd-paper-v2")
    if not paper_bin:
        return _emit({"ok": True, "unloaded": bool(args.unload)})

    if args.unload:
        _unload_skwd_processes(paper_bin)
        return _emit({"ok": True, "unloaded": True})

    try:
        subprocess.run([paper_bin, "stop"], capture_output=True, text=True, timeout=5, check=False)
    except (OSError, subprocess.SubprocessError):
        pass
    return _emit({"ok": True, "unloaded": False})


def cmd_status(_args: argparse.Namespace) -> int:
    paper_bin = shutil.which("skwd-paper-v2")
    if not paper_bin:
        return _fail("skwd-paper-v2 is not installed")
    try:
        res = subprocess.run([paper_bin, "status"], capture_output=True, text=True, timeout=5, check=False)
        if res.returncode != 0:
            return _fail((res.stderr or res.stdout or "status failed").strip())
        parsed = _extract_last_json(res.stdout)
        if isinstance(parsed, dict):
            result = parsed.get("result") if isinstance(parsed.get("result"), dict) else parsed
            return _emit({"ok": True, **result})
        return _fail("Invalid JSON from skwd-paper-v2 status")
    except (OSError, subprocess.SubprocessError) as exc:
        return _fail(str(exc))


def cmd_steam_inventory(args: argparse.Namespace) -> int:
    steam_bin = shutil.which("skwd-steam")
    if not steam_bin:
        return _fail("skwd-steam is not installed")
    cmd = [steam_bin, "inventory", *args.ids]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=8, check=False)
        parsed = _extract_last_json(res.stdout)
        if isinstance(parsed, dict) and any(k in parsed for k in ("subscribed", "installed", "account")):
            return _emit({
                "ok": True,
                "account": parsed.get("account"),
                "subscribed": parsed.get("subscribed") or [],
                "installed": parsed.get("installed") or {},
            })
        err = (res.stderr or res.stdout or "skwd-steam inventory failed").strip()
        return _fail(err.splitlines()[-1] if err else "skwd-steam inventory failed")
    except subprocess.TimeoutExpired:
        return _fail("skwd-steam inventory timed out")
    except (OSError, subprocess.SubprocessError) as exc:
        return _fail(str(exc))


def cmd_steam_search(args: argparse.Namespace) -> int:
    steam_bin = shutil.which("skwd-steam")
    if not steam_bin:
        return _fail("skwd-steam is not installed")
    try:
        res = subprocess.run([steam_bin, "search", args.payload], capture_output=True, text=True, timeout=25, check=False)
        parsed = _extract_last_json(res.stdout)
        if isinstance(parsed, list):
            return _emit({"ok": True, "results": parsed})
        if isinstance(parsed, dict):
            if "error" in parsed and "results" not in parsed:
                return _fail(str(parsed["error"]))
            results = parsed.get("results") if isinstance(parsed.get("results"), list) else []
            out = {"ok": True, "results": results}
            for k, v in parsed.items():
                if k != "results":
                    out[k] = v
            return _emit(out)
        err = (res.stderr or res.stdout or "skwd-steam search failed").strip()
        return _fail(err.splitlines()[-1] if err else "skwd-steam search failed")
    except subprocess.TimeoutExpired:
        return _fail("skwd-steam search timed out")
    except (OSError, subprocess.SubprocessError) as exc:
        return _fail(str(exc))


def cmd_steam_sub(args: argparse.Namespace) -> int:
    steam_bin = shutil.which("skwd-steam")
    wid = str(args.id)
    if not steam_bin:
        sys.stdout.write(json.dumps({
            "id": wid,
            "status": "error",
            "progress": 0,
            "message": "skwd-steam is not installed",
            "folder": "",
        }) + "\n")
        sys.stdout.flush()
        return 0

    proc = subprocess.Popen(
        [steam_bin, wid],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )
    saw_json = False
    saw_terminal = False
    deadline = time.monotonic() + 1800

    try:
        assert proc.stdout is not None
        for line in proc.stdout:
            if time.monotonic() > deadline:
                proc.kill()
                sys.stdout.write(json.dumps({
                    "id": wid,
                    "status": "error",
                    "progress": 0,
                    "message": "Download timed out after 30m",
                    "folder": "",
                }) + "\n")
                sys.stdout.flush()
                return 0
            stripped = line.strip()
            if not stripped.startswith("{"):
                continue
            try:
                obj = json.loads(stripped)
            except json.JSONDecodeError:
                continue
            saw_json = True
            if str(obj.get("status") or "").lower() in ("done", "complete", "completed", "error", "failed"):
                saw_terminal = True
            sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
            sys.stdout.flush()

        rc = proc.wait(timeout=10)
        if rc != 0 and not saw_terminal:
            stderr_txt = (proc.stderr.read() if proc.stderr else "").strip()
            msg = stderr_txt.splitlines()[-1] if stderr_txt else f"skwd-steam exited with code {rc}"
            sys.stdout.write(json.dumps({
                "id": wid,
                "status": "error",
                "progress": 0,
                "message": msg,
                "folder": "",
            }) + "\n")
            sys.stdout.flush()
        elif not saw_json:
            sys.stdout.write(json.dumps({
                "id": wid,
                "status": "error",
                "progress": 0,
                "message": "No progress output from skwd-steam",
                "folder": "",
            }) + "\n")
            sys.stdout.flush()
    except (OSError, subprocess.SubprocessError) as exc:
        try:
            proc.kill()
        except OSError:
            pass
        sys.stdout.write(json.dumps({
            "id": wid,
            "status": "error",
            "progress": 0,
            "message": str(exc),
            "folder": "",
        }) + "\n")
        sys.stdout.flush()
    return 0


def cmd_steam_unsub(args: argparse.Namespace) -> int:
    steam_bin = shutil.which("skwd-steam")
    if not steam_bin:
        return _fail("skwd-steam is not installed")
    try:
        res = subprocess.run([steam_bin, "unsub", args.id], capture_output=True, text=True, timeout=30, check=False)
        if res.returncode != 0:
            err = (res.stderr or res.stdout or "skwd-steam unsub failed").strip()
            return _fail(err.splitlines()[-1] if err else "skwd-steam unsub failed")
        return _emit({"ok": True, "id": args.id})
    except subprocess.TimeoutExpired:
        return _fail("skwd-steam unsub timed out")
    except (OSError, subprocess.SubprocessError) as exc:
        return _fail(str(exc))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="skwd_helper.py")
    sub = parser.add_subparsers(dest="command", required=True)

    p_probe = sub.add_parser("probe")
    p_probe.add_argument("--workshop-dir", default=None)
    p_probe.set_defaults(func=cmd_probe)

    p_trans = sub.add_parser("transitions")
    p_trans.set_defaults(func=cmd_transitions)

    p_list = sub.add_parser("list-we")
    p_list.add_argument("--workshop-dir", default=None)
    p_list.set_defaults(func=cmd_list_we)

    p_cap = sub.add_parser("capture-poster")
    p_cap.add_argument("--source", required=True)
    p_cap.add_argument("--dest", required=True)
    p_cap.add_argument("--width", type=int, default=1920)
    p_cap.add_argument("--height", type=int, default=1080)
    p_cap.set_defaults(func=cmd_capture_poster)

    p_apply = sub.add_parser("apply")
    p_apply.add_argument("--output", required=True)
    p_apply.add_argument("--path", required=True)
    p_apply.add_argument("--gpu", default="auto")
    p_apply.add_argument("--fps", type=int, default=0)
    p_apply.add_argument("--disable-particles", type=int, default=0)
    p_apply.add_argument("--max-dim", type=int, default=0)
    p_apply.add_argument("--mute", type=int, default=1)
    p_apply.add_argument("--volume", type=float, default=0.5)
    p_apply.add_argument("--transition", default="fade")
    p_apply.add_argument("--transition-from", default="")
    p_apply.add_argument("--properties", default="")
    p_apply.add_argument("--force-restart", type=int, default=0)
    p_apply.set_defaults(func=cmd_apply)

    p_pause = sub.add_parser("pause")
    p_pause.set_defaults(func=cmd_pause)

    p_resume = sub.add_parser("resume")
    p_resume.set_defaults(func=cmd_resume)

    p_audio = sub.add_parser("audio")
    p_audio.add_argument("--mute", type=int, required=True)
    p_audio.add_argument("--volume", type=float, required=True)
    p_audio.add_argument("--output", default="ALL")
    p_audio.set_defaults(func=cmd_audio)

    p_stop = sub.add_parser("stop")
    p_stop.add_argument("--unload", action="store_true")
    p_stop.set_defaults(func=cmd_stop)

    p_status = sub.add_parser("status")
    p_status.set_defaults(func=cmd_status)

    p_inv = sub.add_parser("steam-inventory")
    p_inv.add_argument("ids", nargs="*")
    p_inv.set_defaults(func=cmd_steam_inventory)

    p_search = sub.add_parser("steam-search")
    p_search.add_argument("payload")
    p_search.set_defaults(func=cmd_steam_search)

    p_sub = sub.add_parser("steam-sub")
    p_sub.add_argument("id")
    p_sub.set_defaults(func=cmd_steam_sub)

    p_unsub = sub.add_parser("steam-unsub")
    p_unsub.add_argument("id")
    p_unsub.set_defaults(func=cmd_steam_unsub)

    return parser


def main() -> int:
    parser = build_parser()
    try:
        args = parser.parse_args()
    except SystemExit as exc:
        if exc.code == 0:
            return 0
        return _fail("Invalid arguments")
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())

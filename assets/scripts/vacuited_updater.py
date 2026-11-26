#!/usr/bin/env python3
"""Backend service script for the Nexus Vacuited Updater."""

import argparse
import fcntl
import json
import os
import re
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# Ensure GUI-launched environments find user binaries (~/.local/bin, ~/.cargo/bin).
_HOME = Path.home()
_EXTRA_PATHS = [str(_HOME / ".local" / "bin"), str(_HOME / ".cargo" / "bin")]
_CUR_PATH = os.environ.get("PATH", "")
_PATH_PARTS = [p for p in _CUR_PATH.split(":") if p]
for _ep in reversed(_EXTRA_PATHS):
    if _ep not in _PATH_PARTS:
        _PATH_PARTS.insert(0, _ep)
os.environ["PATH"] = ":".join(_PATH_PARTS)

CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME") or (_HOME / ".config"))
CACHE_HOME = Path(os.environ.get("XDG_CACHE_HOME") or (_HOME / ".cache"))
STATE_HOME = Path(os.environ.get("XDG_STATE_HOME") or (_HOME / ".local" / "state"))

QS_DEST = CONFIG_HOME / "quickshell" / "caelestia"
STATE_DIR = STATE_HOME / "vacuited"
META_PATH = STATE_DIR / "install-meta.json"
META_LOCK_PATH = STATE_DIR / ".meta.lock"

CACHE_DIR = CACHE_HOME / "vacuited" / "updater"
SHELL_CACHE = CACHE_DIR / "shell"
CLI_CACHE = CACHE_DIR / "cli"
CHECK_CACHE_PATH = CACHE_DIR / "check-cache.json"
UPDATE_LOCK_PATH = CACHE_DIR / "update.lock"
UPDATE_PID_PATH = CACHE_DIR / "update.pid"
BUILD_DIR = CACHE_HOME / "vacuited" / "shell-build"

SHELL_REPO_SLUG = "vacuited/shell"
CLI_REPO_SLUG = "vacuited/cli"
SHELL_REPO_URL = f"https://github.com/{SHELL_REPO_SLUG}.git"
CLI_REPO_URL = f"https://github.com/{CLI_REPO_SLUG}.git"

QML_DIRS = ("assets", "components", "daemons", "modules", "services", "utils")
QML_FILES = ("shell.qml", "LICENSE")
BACKUP_NAME_RE = re.compile(r"^caelestia\.bak\.(\d{8}-\d{6})$")
BACKUP_KEEP = 3

HARDWARE_HELPER_BIN = Path("/usr/local/bin/caelestia-hardware-helper")
ABI_CHECK_BIN = Path("/usr/local/bin/vacuited-abi-check")
ABI_HOOK_FILE = Path("/etc/pacman.d/hooks/90-vacuited-shell-abi.hook")
CAELESTIA_SHIM_BIN = Path("/usr/local/bin/caelestia")
CAELESTIA_SHIM_MARKER = "# vacuited-cli-shim"
CAELESTIA_SHIM_CONTENT = (
    "#!/bin/sh\n"
    "# vacuited-cli-shim — dispatches to the invoking user's vacuited-cli install\n"
    'case ":${PATH:-}:" in\n'
    '    *:"${HOME}/.local/bin":*) ;;\n'
    '    *) export PATH="${HOME}/.local/bin${PATH:+:${PATH}}" ;;\n'
    "esac\n"
    'if [ -x "${HOME}/.local/bin/caelestia" ]; then\n'
    '    _pyver=""\n'
    "    if [ -L /usr/bin/python3 ]; then\n"
    '        _pybin="$(readlink /usr/bin/python3 2>/dev/null || true)"\n'
    '        _pybin="${_pybin##*/}"\n'
    '        case "$_pybin" in\n'
    '            python3.*) _pyver="$_pybin" ;;\n'
    "        esac\n"
    "    fi\n"
    '    if [ -n "$_pyver" ] \\\n'
    '        && [ ! -d "${HOME}/.local/lib/${_pyver}/site-packages/caelestia" ] \\\n'
    '        && [ ! -d "${HOME}/.local/lib64/${_pyver}/site-packages/caelestia" ]; then\n'
    '        for _old_sp in "${HOME}/.local/lib"/python3.*/site-packages/caelestia "${HOME}/.local/lib64"/python3.*/site-packages/caelestia; do\n'
    '            if [ -d "$_old_sp" ] && ! /usr/bin/python3 -c \'import caelestia\' >/dev/null 2>&1; then\n'
    '                printf \'%s\\n\' "caelestia: Python updated to ${_pyver}; rebuild vacuited-cli (~/.local/bin/caelestia) with ./install.sh or \'caelestia\' repo install.sh" >&2\n'
    "                exit 1\n"
    "            fi\n"
    "        done\n"
    "    fi\n"
    '    exec "${HOME}/.local/bin/caelestia" "$@"\n'
    "fi\n"
    "if [ -x /usr/bin/caelestia ]; then\n"
    '    exec /usr/bin/caelestia "$@"\n'
    "fi\n"
    'printf \'%s\\n\' "caelestia: not installed for ${USER:-user} (${HOME}/.local/bin/caelestia missing)" >&2\n'
    "exit 127\n"
)
LEGACY_LIBS = (
    "Caelestia/Components/libcaelestia-components.so",
    "Caelestia/Config/libcaelestia-config.so",
    "Caelestia/Internal/libcaelestia-internal.so",
    "Caelestia/Models/libcaelestia-models.so",
    "Caelestia/Services/libcaelestia-services.so",
    "Caelestia/Blobs/libcaelestia-blobs.so",
    "Caelestia/Images/libcaelestia-images.so",
    "Caelestia/libcaelestia.so",
)


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def short_sha(sha: str) -> str:
    return sha[:7] if sha else ""


def git_env() -> dict[str, str]:
    env = os.environ.copy()
    env["GIT_TERMINAL_PROMPT"] = "0"
    return env


def write_json_atomic(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2)
            fh.write("\n")
        os.replace(tmp_name, path)
    except Exception:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass
        raise


def read_json(path: Path, default: Any) -> Any:
    try:
        with path.open("r", encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, json.JSONDecodeError):
        return default


def default_meta() -> dict[str, Any]:
    return {
        "schema": 1,
        "shell": {
            "commit": "",
            "pluginCommit": "",
            "version": "",
            "installedAt": "",
        },
        "cli": {
            "commit": "",
            "version": "",
            "installedAt": "",
        },
        "lastCheckedAt": "",
        "justUpdated": None,
    }


def load_meta() -> dict[str, Any]:
    raw = read_json(META_PATH, {})
    meta = default_meta()
    if isinstance(raw, dict):
        if isinstance(raw.get("shell"), dict):
            meta["shell"].update({k: str(v or "") for k, v in raw["shell"].items() if k in meta["shell"]})
        if isinstance(raw.get("cli"), dict):
            meta["cli"].update({k: str(v or "") for k, v in raw["cli"].items() if k in meta["cli"]})
        if isinstance(raw.get("lastCheckedAt"), str):
            meta["lastCheckedAt"] = raw["lastCheckedAt"]
        if isinstance(raw.get("justUpdated"), dict):
            meta["justUpdated"] = raw["justUpdated"]
    return meta


def save_meta(meta: dict[str, Any]) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    with META_LOCK_PATH.open("w", encoding="utf-8") as lock_fh:
        fcntl.flock(lock_fh, fcntl.LOCK_EX)
        try:
            write_json_atomic(META_PATH, meta)
        finally:
            fcntl.flock(lock_fh, fcntl.LOCK_UN)


def update_meta(mutator) -> dict[str, Any]:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    with META_LOCK_PATH.open("w", encoding="utf-8") as lock_fh:
        fcntl.flock(lock_fh, fcntl.LOCK_EX)
        try:
            meta = load_meta()
            mutator(meta)
            write_json_atomic(META_PATH, meta)
            return meta
        finally:
            fcntl.flock(lock_fh, fcntl.LOCK_UN)


def load_check_cache() -> dict[str, Any]:
    data = read_json(CHECK_CACHE_PATH, {})
    return data if isinstance(data, dict) else {}


def save_check_cache(data: dict[str, Any]) -> None:
    write_json_atomic(CHECK_CACHE_PATH, data)


def find_qtpaths6() -> str | None:
    for cand in ("qtpaths6", "qtpaths-qt6", "/usr/lib/qt6/bin/qtpaths6", "/usr/lib64/qt6/bin/qtpaths6"):
        if "/" in cand:
            if os.path.isfile(cand) and os.access(cand, os.X_OK):
                return cand
        else:
            found = shutil.which(cand)
            if found:
                return found
    return None


def detect_qt_qml_dir() -> str:
    qtp = find_qtpaths6()
    if qtp:
        try:
            out = subprocess.check_output([qtp, "--query", "QT_INSTALL_QML"], text=True, timeout=5).strip()
            if out:
                return out
        except (OSError, subprocess.SubprocessError):
            pass
    return "/usr/lib/qt6/qml"


def find_qsb() -> str | None:
    for cand in ("qsb", "qsb-qt6", "/usr/lib/qt6/bin/qsb", "/usr/lib64/qt6/bin/qsb"):
        if "/" in cand:
            if os.path.isfile(cand) and os.access(cand, os.X_OK):
                return cand
        else:
            found = shutil.which(cand)
            if found:
                return found
    return None


def detect_tools() -> dict[str, bool]:
    return {
        "git": shutil.which("git") is not None,
        "cmake": shutil.which("cmake") is not None,
        "ninja": shutil.which("ninja") is not None,
        "pkexec": shutil.which("pkexec") is not None,
        "qsb": find_qsb() is not None,
        "rsync": shutil.which("rsync") is not None,
        "caelestia": shutil.which("caelestia") is not None,
    }


def list_backups(meta: dict[str, Any]) -> list[dict[str, Any]]:
    parent = QS_DEST.parent
    if not parent.is_dir():
        return []

    current_plugin = meta.get("shell", {}).get("pluginCommit", "")
    entries: list[tuple[str, Path]] = []
    for child in parent.iterdir():
        if child.is_dir() and not child.is_symlink():
            m = BACKUP_NAME_RE.fullmatch(child.name)
            if m:
                entries.append((m.group(1), child))

    entries.sort(key=lambda pair: pair[0], reverse=True)
    backups: list[dict[str, Any]] = []
    for stamp, bdir in entries:
        bmeta = read_json(bdir / ".vacuited-backup.json", {})
        if not isinstance(bmeta, dict):
            bmeta = {}
        shell_commit = str(bmeta.get("shellCommit") or "")
        plugin_commit = str(bmeta.get("pluginCommit") or "")
        version = str(bmeta.get("version") or "")
        reason = str(bmeta.get("reason") or "")
        created_at = str(bmeta.get("createdAt") or "")
        if not created_at:
            try:
                dt = datetime.strptime(stamp, "%Y%m%d-%H%M%S").astimezone()
                created_at = dt.isoformat(timespec="seconds")
            except ValueError:
                created_at = stamp

        if current_plugin and plugin_commit:
            abi_match: bool | None = current_plugin == plugin_commit
        else:
            abi_match = None

        backups.append(
            {
                "name": bdir.name,
                "path": str(bdir),
                "createdAt": created_at,
                "shellCommit": shell_commit,
                "shellShort": short_sha(shell_commit),
                "pluginCommit": plugin_commit,
                "pluginShort": short_sha(plugin_commit),
                "version": version,
                "reason": reason,
                "pluginAbiMatch": abi_match,
                "valid": (bdir / "shell.qml").is_file(),
            }
        )
    return backups


def prune_backups(keep: int = BACKUP_KEEP) -> list[str]:
    parent = QS_DEST.parent
    if not parent.is_dir():
        return []
    entries: list[tuple[str, Path]] = []
    for child in parent.iterdir():
        if child.is_dir() and not child.is_symlink():
            m = BACKUP_NAME_RE.fullmatch(child.name)
            if m:
                entries.append((m.group(1), child))
    entries.sort(key=lambda pair: pair[0], reverse=True)
    pruned: list[str] = []
    for _, old_dir in entries[keep:]:
        try:
            shutil.rmtree(old_dir)
            pruned.append(old_dir.name)
        except OSError:
            pass
    return pruned


def ls_remote_main(repo_url: str) -> str:
    proc = subprocess.run(
        ["git", "ls-remote", repo_url, "refs/heads/main"],
        env=git_env(),
        capture_output=True,
        text=True,
        timeout=15,
        check=False,
    )
    if proc.returncode != 0:
        err = (proc.stderr or proc.stdout or f"git ls-remote failed ({proc.returncode})").strip()
        raise RuntimeError(err)
    line = proc.stdout.strip().splitlines()[0] if proc.stdout.strip() else ""
    if not line:
        raise RuntimeError(f"No refs/heads/main returned for {repo_url}")
    return line.split()[0]


def github_get_json(url: str) -> tuple[Any | None, int, str]:
    req = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "vacuited-updater",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=12) as resp:
            return json.loads(resp.read().decode("utf-8")), resp.status, ""
    except urllib.error.HTTPError as e:
        msg = f"HTTP {e.code}"
        try:
            payload = json.loads(e.read().decode("utf-8"))
            if isinstance(payload, dict) and payload.get("message"):
                msg = f"HTTP {e.code}: {payload['message']}"
        except Exception:
            pass
        return None, e.code, msg
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError) as e:
        return None, 0, str(e)


def parse_gh_commits(raw_commits: list[dict[str, Any]], limit: int = 25) -> list[dict[str, Any]]:
    # Present newest commits first.
    out: list[dict[str, Any]] = []
    for c in reversed(raw_commits[-limit:]):
        if not isinstance(c, dict):
            continue
        sha = str(c.get("sha") or "")
        commit_obj = c.get("commit") if isinstance(c.get("commit"), dict) else {}
        msg = str(commit_obj.get("message") or "").splitlines()[0].strip() if commit_obj.get("message") else ""
        author_obj = commit_obj.get("author") if isinstance(commit_obj.get("author"), dict) else {}
        author = str(author_obj.get("name") or (c.get("author") or {}).get("login") or "")
        date = str(author_obj.get("date") or "")
        out.append(
            {
                "sha": sha,
                "shortSha": short_sha(sha),
                "title": msg or "(no message)",
                "author": author,
                "date": date,
                "url": str(c.get("html_url") or ""),
            }
        )
    return out


def classify_shell_files(files: list[dict[str, Any]], plugin_commit: str) -> dict[str, bool]:
    needs_plugin = not bool(plugin_commit)
    touches_hw = False
    touches_shaders = False
    touches_deps = False
    hw_installed = HARDWARE_HELPER_BIN.is_file() and os.access(HARDWARE_HELPER_BIN, os.X_OK)

    for f in files:
        if not isinstance(f, dict):
            continue
        name = str(f.get("filename") or "")
        if name.startswith("plugin/") or name.startswith("extras/") or name == "CMakeLists.txt":
            needs_plugin = True
        if name in ("scripts/caelestia-hardware-helper", "scripts/50-caelestia-hardware.rules") and hw_installed:
            touches_hw = True
        if name.startswith("assets/shaders/frag/"):
            touches_shaders = True
        if name == "install.sh":
            patch = str(f.get("patch") or "")
            if "PAC_REQUIRED" in patch or "AUR_REQUIRED" in patch:
                touches_deps = True

    return {
        "needsPluginRebuild": needs_plugin,
        "touchesHardwareHelper": touches_hw,
        "touchesShaders": touches_shaders,
        "touchesDeps": touches_deps,
    }


def make_component_status(
    comp_name: str,
    meta_comp: dict[str, str],
    cached_entry: dict[str, Any] | None = None,
) -> dict[str, Any]:
    installed = meta_comp.get("commit", "")
    plugin = meta_comp.get("pluginCommit", "") if comp_name == "shell" else ""
    base = {
        "installedCommit": installed,
        "installedShort": short_sha(installed),
        "pluginCommit": plugin,
        "pluginShort": short_sha(plugin),
        "version": meta_comp.get("version", ""),
        "installedAt": meta_comp.get("installedAt", ""),
        "remoteCommit": installed,
        "remoteShort": short_sha(installed),
        "baselineMissing": not bool(installed),
        "hasUpdate": False,
        "aheadBy": 0,
        "commits": [],
        "compareUrl": "",
        "needsPluginRebuild": (comp_name == "shell" and not bool(plugin)),
        "touchesHardwareHelper": False,
        "touchesShaders": False,
        "touchesDeps": False,
        "rateLimited": False,
        "checkError": "",
    }
    if isinstance(cached_entry, dict):
        same_base = cached_entry.get("installedCommit", "") == installed
        same_plugin = comp_name != "shell" or cached_entry.get("pluginCommit", "") == plugin
        if same_base and same_plugin:
            for k in (
                "remoteCommit",
                "remoteShort",
                "hasUpdate",
                "aheadBy",
                "commits",
                "compareUrl",
                "needsPluginRebuild",
                "touchesHardwareHelper",
                "touchesShaders",
                "touchesDeps",
                "rateLimited",
                "checkError",
            ):
                if k in cached_entry:
                    base[k] = cached_entry[k]
            if comp_name == "shell" and not plugin:
                base["needsPluginRebuild"] = True
    return base


def inspect_component(
    comp_name: str,
    repo_slug: str,
    repo_url: str,
    meta_comp: dict[str, str],
    cache: dict[str, Any],
    force: bool,
) -> dict[str, Any]:
    status = make_component_status(comp_name, meta_comp)
    installed = status["installedCommit"]
    plugin = status["pluginCommit"]

    remote_head = ls_remote_main(repo_url)
    status["remoteCommit"] = remote_head
    status["remoteShort"] = short_sha(remote_head)

    if not installed:
        status["baselineMissing"] = True
        status["hasUpdate"] = False
        cache_key = f"{comp_name}:baseline:{remote_head}"
        if not force and isinstance(cache.get(cache_key), dict) and not cache[cache_key].get("rateLimited"):
            status["commits"] = cache[cache_key].get("commits", [])
            status["compareUrl"] = cache[cache_key].get("compareUrl", "")
        else:
            data, code, err = github_get_json(f"https://api.github.com/repos/{repo_slug}/commits?sha=main&per_page=5")
            if isinstance(data, list):
                # API returns newest-first for /commits, while parse_gh_commits expects oldest-first.
                status["commits"] = parse_gh_commits(list(reversed(data)), limit=5)
                status["compareUrl"] = f"https://github.com/{repo_slug}/commits/main"
                cache[cache_key] = {
                    "installedCommit": installed,
                    "pluginCommit": plugin,
                    "commits": status["commits"],
                    "compareUrl": status["compareUrl"],
                    "rateLimited": False,
                }
            elif code in (403, 429):
                status["rateLimited"] = True
                status["checkError"] = err
        return status

    if installed == remote_head:
        status["hasUpdate"] = False
        status["aheadBy"] = 0
        if comp_name == "shell" and plugin and plugin != installed:
            # Check if previous QML-only updates still left unbuilt plugin changes.
            cache_key = f"{comp_name}:plugin-only:{plugin}:{remote_head}"
            cached = cache.get(cache_key)
            if not force and isinstance(cached, dict) and not cached.get("rateLimited"):
                status["needsPluginRebuild"] = bool(cached.get("needsPluginRebuild", False))
            else:
                pdata, pcode, _ = github_get_json(
                    f"https://api.github.com/repos/{repo_slug}/compare/{plugin}...{remote_head}"
                )
                if isinstance(pdata, dict) and isinstance(pdata.get("files"), list):
                    flags = classify_shell_files(pdata["files"], plugin)
                    status["needsPluginRebuild"] = flags["needsPluginRebuild"]
                    cache[cache_key] = {
                        "needsPluginRebuild": flags["needsPluginRebuild"],
                        "rateLimited": False,
                    }
                elif pcode in (403, 429):
                    status["needsPluginRebuild"] = True
        return status

    status["hasUpdate"] = True
    cache_key = f"{comp_name}:{installed}:{plugin}:{remote_head}"
    cached = cache.get(cache_key)
    if isinstance(cached, dict) and not (force and cached.get("rateLimited")):
        for k in (
            "aheadBy",
            "commits",
            "compareUrl",
            "needsPluginRebuild",
            "touchesHardwareHelper",
            "touchesShaders",
            "touchesDeps",
            "rateLimited",
            "checkError",
        ):
            if k in cached:
                status[k] = cached[k]
        return status

    comp_url = f"https://api.github.com/repos/{repo_slug}/compare/{installed}...{remote_head}"
    data, code, err = github_get_json(comp_url)
    if isinstance(data, dict) and "commits" in data:
        raw_commits = data.get("commits") if isinstance(data.get("commits"), list) else []
        status["aheadBy"] = int(data.get("ahead_by") or len(raw_commits))
        status["commits"] = parse_gh_commits(raw_commits, limit=25)
        status["compareUrl"] = str(data.get("html_url") or f"https://github.com/{repo_slug}/compare/{installed}...main")
        files = data.get("files") if isinstance(data.get("files"), list) else []

        if comp_name == "shell":
            if plugin and plugin != installed:
                pdata, pcode, perr = github_get_json(
                    f"https://api.github.com/repos/{repo_slug}/compare/{plugin}...{remote_head}"
                )
                if isinstance(pdata, dict) and isinstance(pdata.get("files"), list):
                    files = [*files, *pdata["files"]]
                elif pcode in (403, 429) or pcode == 0:
                    status["needsPluginRebuild"] = True
                    if perr:
                        status["checkError"] = perr
            flags = classify_shell_files(files, plugin)
            status["needsPluginRebuild"] = status["needsPluginRebuild"] or flags["needsPluginRebuild"]
            status["touchesHardwareHelper"] = flags["touchesHardwareHelper"]
            status["touchesShaders"] = flags["touchesShaders"]
            status["touchesDeps"] = flags["touchesDeps"]
        else:
            status["touchesDeps"] = any(
                isinstance(f, dict)
                and f.get("filename") == "install.sh"
                and ("PAC_REQUIRED" in str(f.get("patch") or "") or "AUR_REQUIRED" in str(f.get("patch") or ""))
                for f in files
            )
    else:
        # Handle rate-limit (403/429) or diverged/unknown base SHA (404) cleanly.
        if code in (403, 429):
            status["rateLimited"] = True
        status["checkError"] = err
        status["compareUrl"] = f"https://github.com/{repo_slug}/compare/{installed}...main"
        if comp_name == "shell":
            status["needsPluginRebuild"] = True

        if code == 404:
            fallback, fcode, ferr = github_get_json(
                f"https://api.github.com/repos/{repo_slug}/commits?sha=main&per_page=10"
            )
            if isinstance(fallback, list):
                status["commits"] = parse_gh_commits(list(reversed(fallback)), limit=10)
                status["aheadBy"] = len(status["commits"])
                status["compareUrl"] = f"https://github.com/{repo_slug}/commits/main"
                status["checkError"] = ""
            elif fcode in (403, 429):
                status["rateLimited"] = True
                status["checkError"] = ferr

    cache[cache_key] = {
        "installedCommit": installed,
        "pluginCommit": plugin,
        "remoteCommit": remote_head,
        "remoteShort": status["remoteShort"],
        "hasUpdate": True,
        "aheadBy": status["aheadBy"],
        "commits": status["commits"],
        "compareUrl": status["compareUrl"],
        "needsPluginRebuild": status["needsPluginRebuild"],
        "touchesHardwareHelper": status["touchesHardwareHelper"],
        "touchesShaders": status["touchesShaders"],
        "touchesDeps": status["touchesDeps"],
        "rateLimited": status["rateLimited"],
        "checkError": status["checkError"],
    }
    return status


def read_repo_meta(repo_dir: Path) -> tuple[str, str]:
    commit = subprocess.check_output(["git", "-C", str(repo_dir), "rev-parse", "HEAD"], text=True, env=git_env()).strip()
    version = ""
    try:
        tag = subprocess.check_output(
            ["git", "-C", str(repo_dir), "describe", "--tags", "--abbrev=0"],
            text=True,
            stderr=subprocess.DEVNULL,
            env=git_env(),
        ).strip()
        tag = tag.lstrip("v")
        if re.fullmatch(r"\d+(?:\.\d+){1,3}", tag):
            version = tag
    except subprocess.SubprocessError:
        pass
    return commit, version


def cmd_status(_args: argparse.Namespace) -> int:
    meta = load_meta()
    cache = load_check_cache()
    shell_status = make_component_status("shell", meta["shell"], cache.get("latest_shell"))
    cli_status = make_component_status("cli", meta["cli"], cache.get("latest_cli"))
    payload = {
        "ok": True,
        "meta": meta,
        "shell": shell_status,
        "cli": cli_status,
        "backups": list_backups(meta),
        "justUpdated": meta.get("justUpdated"),
        "tools": detect_tools(),
        "systemSync": detect_system_sync(),
    }
    print(json.dumps(payload))
    return 0


def cmd_clear_just_updated(_args: argparse.Namespace) -> int:
    update_meta(lambda m: m.__setitem__("justUpdated", None))
    print(json.dumps({"ok": True}))
    return 0


def cmd_record_install(args: argparse.Namespace) -> int:
    repo_dir = Path(args.repo_dir).resolve()
    try:
        commit, tag_ver = read_repo_meta(repo_dir)
    except (OSError, subprocess.SubprocessError) as e:
        print(json.dumps({"ok": False, "error": f"Failed to read git metadata from {repo_dir}: {e}"}))
        return 1

    version = (args.version or tag_ver or "").lstrip("v")
    stamp = now_iso()

    def mutate(meta: dict[str, Any]) -> None:
        comp = meta[args.component]
        comp["commit"] = commit
        if version:
            comp["version"] = version
        comp["installedAt"] = stamp
        if args.component == "shell" and args.plugin_rebuilt:
            comp["pluginCommit"] = commit

    meta = update_meta(mutate)
    cache = load_check_cache()
    cache.pop(f"latest_{args.component}", None)
    save_check_cache(cache)
    print(json.dumps({"ok": True, "meta": meta}))
    return 0


def cmd_mark_synced(args: argparse.Namespace) -> int:
    targets = ("shell", "cli") if args.component == "all" else (args.component,)
    remote_heads: dict[str, str] = {}
    try:
        if "shell" in targets:
            remote_heads["shell"] = ls_remote_main(SHELL_REPO_URL)
        if "cli" in targets:
            remote_heads["cli"] = ls_remote_main(CLI_REPO_URL)
    except RuntimeError as e:
        print(json.dumps({"ok": False, "error": str(e)}))
        return 1

    stamp = now_iso()

    def mutate(meta: dict[str, Any]) -> None:
        if "shell" in remote_heads:
            meta["shell"]["commit"] = remote_heads["shell"]
            meta["shell"]["pluginCommit"] = remote_heads["shell"]
            meta["shell"]["installedAt"] = stamp
        if "cli" in remote_heads:
            meta["cli"]["commit"] = remote_heads["cli"]
            meta["cli"]["installedAt"] = stamp
        meta["lastCheckedAt"] = stamp

    meta = update_meta(mutate)
    cache = load_check_cache()
    for t in targets:
        cache.pop(f"latest_{t}", None)
    save_check_cache(cache)

    payload = {
        "ok": True,
        "meta": meta,
        "shell": make_component_status("shell", meta["shell"], cache.get("latest_shell")),
        "cli": make_component_status("cli", meta["cli"], cache.get("latest_cli")),
        "backups": list_backups(meta),
        "systemSync": detect_system_sync(),
    }
    print(json.dumps(payload))
    return 0


def cmd_check(args: argparse.Namespace) -> int:
    meta = load_meta()
    cache = load_check_cache()
    try:
        shell_status = inspect_component("shell", SHELL_REPO_SLUG, SHELL_REPO_URL, meta["shell"], cache, args.force)
        cli_status = inspect_component("cli", CLI_REPO_SLUG, CLI_REPO_URL, meta["cli"], cache, args.force)
    except RuntimeError as e:
        print(json.dumps({"ok": False, "error": str(e)}))
        return 1

    checked_at = now_iso()
    cache["latest_shell"] = shell_status
    cache["latest_cli"] = cli_status
    save_check_cache(cache)
    meta = update_meta(lambda m: m.__setitem__("lastCheckedAt", checked_at))

    print(
        json.dumps(
            {
                "ok": True,
                "checkedAt": checked_at,
                "meta": meta,
                "shell": shell_status,
                "cli": cli_status,
                "backups": list_backups(meta),
                "tools": detect_tools(),
                "systemSync": detect_system_sync(),
            }
        )
    )
    return 0


def emit(event: dict[str, Any]) -> None:
    print(json.dumps(event), flush=True)


def emit_log(line: str, level: str = "info", component: str = "") -> None:
    text = line.rstrip("\r\n")
    if text:
        emit({"type": "log", "line": text, "level": level, "component": component})


def emit_progress(phase: str, percent: int, component: str = "") -> None:
    emit({"type": "progress", "phase": phase, "percent": max(0, min(100, int(percent))), "component": component})


class UpdateCancelled(Exception):
    """Raised when an active update/rollback is canceled by the user."""


_active_subproc: subprocess.Popen | None = None
_cancel_requested = False
_deploying_critical = False


def _kill_active_subproc() -> None:
    proc = _active_subproc
    if proc is None or proc.poll() is not None:
        return
    try:
        os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
    except ProcessLookupError:
        return
    except OSError:
        try:
            proc.terminate()
        except OSError:
            pass
    deadline = time.monotonic() + 1.5
    while time.monotonic() < deadline:
        if proc.poll() is not None:
            return
        time.sleep(0.05)
    try:
        os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
    except OSError:
        try:
            proc.kill()
        except OSError:
            pass


def _handle_cancel_signal(_signum: int, _frame: Any) -> None:
    global _cancel_requested
    _cancel_requested = True
    proc = _active_subproc
    if proc is not None and proc.poll() is None and not _deploying_critical:
        try:
            os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
        except OSError:
            pass


def _install_cancel_handlers() -> None:
    global _cancel_requested, _deploying_critical
    _cancel_requested = False
    _deploying_critical = False
    signal.signal(signal.SIGTERM, _handle_cancel_signal)
    signal.signal(signal.SIGINT, _handle_cancel_signal)


def _check_cancelled() -> None:
    if _cancel_requested:
        raise UpdateCancelled()


def detect_installed_cli_version() -> str:
    caelestia_bin = shutil.which("caelestia")
    if caelestia_bin:
        try:
            out = subprocess.check_output(
                [caelestia_bin, "--version"],
                stderr=subprocess.STDOUT,
                text=True,
                timeout=5,
            )
            m = re.search(r"caelestia-cli\S*\s+(\d+(?:\.\d+)*)", out)
            if m:
                return m.group(1)
        except (OSError, subprocess.SubprocessError):
            pass
    try:
        out = subprocess.check_output(
            [sys.executable, "-c", 'import importlib.metadata; print(importlib.metadata.version("caelestia"))'],
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=5,
        ).strip()
        if out and out != "0.0.0":
            return out
    except (OSError, subprocess.SubprocessError):
        pass
    return ""


def run_streamed(
    cmd: list[str],
    cwd: Path | None = None,
    env: dict[str, str] | None = None,
    component: str = "",
    on_line=None,
) -> int:
    global _active_subproc
    _check_cancelled()
    proc = subprocess.Popen(
        cmd,
        cwd=str(cwd) if cwd else None,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
        start_new_session=True,
    )
    _active_subproc = proc
    try:
        assert proc.stdout is not None
        for raw in proc.stdout:
            if _cancel_requested:
                _kill_active_subproc()
                raise UpdateCancelled()
            line = raw.rstrip("\r\n")
            if line:
                emit_log(line, "info", component)
                if on_line:
                    on_line(line)
        rc = proc.wait()
        if _cancel_requested:
            raise UpdateCancelled()
        return rc
    finally:
        if proc.poll() is None:
            _kill_active_subproc()
        _active_subproc = None


def sync_git_cache(repo_url: str, cache_dir: Path, depth: int, component: str) -> str:
    cache_dir.parent.mkdir(parents=True, exist_ok=True)
    env = git_env()

    # If a previous run left a broken directory without .git, clean it.
    if cache_dir.exists() and not (cache_dir / ".git").is_dir():
        shutil.rmtree(cache_dir)

    if not (cache_dir / ".git").is_dir():
        emit_log(f"Cloning {repo_url} into managed cache...", "info", component)
        rc = run_streamed(
            ["git", "clone", "--depth", str(depth), "--branch", "main", repo_url, str(cache_dir)],
            env=env,
            component=component,
        )
        if rc != 0:
            raise RuntimeError(f"Failed to clone {repo_url} (exit {rc})")
    else:
        emit_log(f"Fetching latest main from {repo_url}...", "info", component)
        rc = run_streamed(
            ["git", "-C", str(cache_dir), "fetch", "--depth", str(depth), "--tags", "origin", "main"],
            env=env,
            component=component,
        )
        if rc != 0:
            raise RuntimeError(f"Failed to fetch {repo_url} (exit {rc})")
        for git_args in (
            ["git", "-C", str(cache_dir), "checkout", "-B", "main", "FETCH_HEAD"],
            ["git", "-C", str(cache_dir), "reset", "--hard", "FETCH_HEAD"],
            ["git", "-C", str(cache_dir), "clean", "-fd"],
        ):
            sub = subprocess.run(git_args, env=env, capture_output=True, text=True, check=False)
            if sub.returncode != 0:
                raise RuntimeError((sub.stderr or sub.stdout or "git reset failed").strip())

    head, _ = read_repo_meta(cache_dir)
    return head


def decide_plugin_rebuild(mode: str, force_rebuild: bool, meta: dict[str, Any], check_cache: dict[str, Any]) -> bool:
    if force_rebuild or mode == "yes":
        return True
    if mode == "no":
        return False

    plugin_commit = meta.get("shell", {}).get("pluginCommit", "")
    if not plugin_commit:
        return True

    # Try exact local git diff when plugin_commit is present in shallow cache.
    env = git_env()
    has_base = subprocess.run(
        ["git", "-C", str(SHELL_CACHE), "cat-file", "-e", f"{plugin_commit}^{{commit}}"],
        env=env,
        capture_output=True,
        check=False,
    )
    if has_base.returncode == 0:
        diff = subprocess.run(
            ["git", "-C", str(SHELL_CACHE), "diff", "--name-only", f"{plugin_commit}..HEAD"],
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )
        if diff.returncode == 0:
            changed = [line.strip() for line in diff.stdout.splitlines() if line.strip()]
            return any(
                p.startswith("plugin/") or p.startswith("extras/") or p == "CMakeLists.txt"
                for p in changed
            )

    # Fall back to cached GitHub compare result if it points to the same base and current HEAD.
    head = subprocess.check_output(["git", "-C", str(SHELL_CACHE), "rev-parse", "HEAD"], env=env, text=True).strip()
    latest = check_cache.get("latest_shell")
    if (
        isinstance(latest, dict)
        and latest.get("pluginCommit") == plugin_commit
        and latest.get("remoteCommit") == head
        and not latest.get("rateLimited")
        and not latest.get("checkError")
    ):
        return bool(latest.get("needsPluginRebuild", True))

    return True


def should_update_hardware_helper(plugin_commit: str) -> bool:
    if not (HARDWARE_HELPER_BIN.is_file() and os.access(HARDWARE_HELPER_BIN, os.X_OK)):
        return False
    if not plugin_commit:
        return True
    env = git_env()
    diff = subprocess.run(
        [
            "git",
            "-C",
            str(SHELL_CACHE),
            "diff",
            "--name-only",
            f"{plugin_commit}..HEAD",
            "--",
            "scripts/caelestia-hardware-helper",
            "scripts/50-caelestia-hardware.rules",
        ],
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )
    if diff.returncode == 0:
        return bool(diff.stdout.strip())
    return True


def compile_standalone_shaders(repo_dir: Path) -> None:
    frag_dir = repo_dir / "assets" / "shaders" / "frag"
    out_dir = repo_dir / "assets" / "shaders"
    if not frag_dir.is_dir():
        return

    qsb_bin = find_qsb()
    for frag in sorted(frag_dir.glob("*.frag")):
        qsb_out = out_dir / f"{frag.name}.qsb"
        stale = (not qsb_out.is_file()) or (frag.stat().st_mtime > qsb_out.stat().st_mtime)
        if not stale:
            continue
        if not qsb_bin:
            if not qsb_out.is_file():
                raise RuntimeError(f"Missing {qsb_out.name} and Qt6 'qsb' tool was not found")
            emit_log(f"{frag.name} is newer than {qsb_out.name}, but 'qsb' was not found; keeping bundled .qsb", "warn", "shell")
            continue
        emit_log(f"Compiling shader {qsb_out.name}...", "info", "shell")
        rc = run_streamed([qsb_bin, "--qt6", "-o", str(qsb_out), str(frag)], component="shell")
        if rc != 0 or not qsb_out.is_file():
            raise RuntimeError(f"Failed to compile shader {frag.name}")


def validate_shell_source(src_dir: Path) -> None:
    if not (src_dir / "shell.qml").is_file():
        raise RuntimeError(f"Validation failed: {src_dir / 'shell.qml'} is missing")
    for d in QML_DIRS:
        if not (src_dir / d).is_dir():
            raise RuntimeError(f"Validation failed: required directory '{d}' missing in {src_dir}")
    frag_dir = src_dir / "assets" / "shaders" / "frag"
    if frag_dir.is_dir():
        for frag in frag_dir.glob("*.frag"):
            qsb_out = src_dir / "assets" / "shaders" / f"{frag.name}.qsb"
            if not qsb_out.is_file():
                raise RuntimeError(f"Validation failed: compiled shader {qsb_out.name} missing")


def deploy_qml_tree(src_dir: Path, dest_dir: Path, component: str) -> None:
    if dest_dir.is_symlink():
        target = os.readlink(dest_dir)
        emit_log(f"Unlinking {dest_dir} (was symlink -> {target}; target untouched)...", "warn", component)
        dest_dir.unlink()

    dest_dir.mkdir(parents=True, exist_ok=True)
    has_rsync = shutil.which("rsync") is not None

    for d in QML_DIRS:
        src_sub = src_dir / d
        dest_sub = dest_dir / d
        if has_rsync:
            dest_sub.mkdir(parents=True, exist_ok=True)
            rc = run_streamed(
                [
                    "rsync",
                    "-a",
                    "--delete",
                    "--exclude=__pycache__",
                    "--exclude=*.pyc",
                    "--exclude=*.orig",
                    "--exclude=*.bak",
                    f"{src_sub}/",
                    f"{dest_sub}/",
                ],
                component=component,
            )
            if rc != 0:
                raise RuntimeError(f"rsync failed for {d} (exit {rc})")
        else:
            if dest_sub.exists():
                shutil.rmtree(dest_sub)
            shutil.copytree(
                src_sub,
                dest_sub,
                ignore=shutil.ignore_patterns("__pycache__", "*.pyc", "*.orig", "*.bak"),
            )

    for f in QML_FILES:
        src_file = src_dir / f
        if src_file.is_file():
            shutil.copy2(src_file, dest_dir / f)

    wrap = dest_dir / "assets" / "wrap_term_launch.sh"
    if wrap.is_file():
        wrap.chmod(wrap.stat().st_mode | 0o111)
    scripts_dir = dest_dir / "assets" / "scripts"
    if scripts_dir.is_dir():
        for py in scripts_dir.glob("*.py"):
            py.chmod(py.stat().st_mode | 0o111)


def create_backup(meta: dict[str, Any], reason: str) -> dict[str, Any] | None:
    if not QS_DEST.exists() or QS_DEST.is_symlink():
        return None
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_dir = QS_DEST.parent / f"caelestia.bak.{stamp}"
    while backup_dir.exists():
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        backup_dir = QS_DEST.parent / f"caelestia.bak.{stamp}"

    emit_log(f"Creating backup snapshot {backup_dir.name}...", "info", "shell")
    shutil.copytree(
        QS_DEST,
        backup_dir,
        symlinks=True,
        ignore=shutil.ignore_patterns("__pycache__", "*.pyc"),
    )
    shell_meta = meta.get("shell", {})
    write_json_atomic(
        backup_dir / ".vacuited-backup.json",
        {
            "createdAt": now_iso(),
            "shellCommit": shell_meta.get("commit", ""),
            "pluginCommit": shell_meta.get("pluginCommit", ""),
            "version": shell_meta.get("version", ""),
            "reason": reason,
        },
    )
    pruned = prune_backups(BACKUP_KEEP)
    for name in pruned:
        emit_log(f"Pruned old backup {name}", "info", "shell")
    return {"name": backup_dir.name, "path": str(backup_dir)}


def spawn_detached_reload() -> None:
    # Escape Quickshell's process group/cgroup before `caelestia shell -d -r` stops the running shell.
    caelestia_bin = shutil.which("caelestia") or str(_HOME / ".local" / "bin" / "caelestia")
    qs_bin = shutil.which("qs") or "qs"
    if os.path.isfile(caelestia_bin) and os.access(caelestia_bin, os.X_OK):
        cmd_str = f"sleep 0.7; exec {shlex.quote(caelestia_bin)} shell -d -r"
    else:
        cmd_str = (
            f"sleep 0.7; {shlex.quote(qs_bin)} -c caelestia kill >/dev/null 2>&1 || true; "
            f"sleep 0.6; exec {shlex.quote(qs_bin)} -c caelestia -n -d"
        )

    systemd_run = shutil.which("systemd-run")
    if systemd_run:
        proc = subprocess.run(
            [systemd_run, "--user", "--scope", "--quiet", "--", "/bin/sh", "-c", cmd_str],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        if proc.returncode == 0:
            return

    subprocess.Popen(
        ["/bin/sh", "-c", cmd_str],
        start_new_session=True,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        close_fds=True,
    )


def detect_active_tape_name() -> str:
    try:
        tapes_root = (_HOME / ".tapes").resolve()
        resolved = QS_DEST.resolve()
        rel = resolved.relative_to(tapes_root)
    except (OSError, ValueError):
        return ""
    parts = rel.parts
    if len(parts) == 3 and parts[1] == "quickshell" and parts[2] == "caelestia":
        name = parts[0]
        if re.fullmatch(r"[a-z0-9][a-z0-9._-]*", name):
            return name
    return ""


def verify_plugin_install(qt_qml_dir: str) -> None:
    for sub in ("", "Config", "Services", "Multimedia", "Shaders"):
        qmldir = Path(qt_qml_dir) / "Caelestia" / sub / "qmldir"
        if not qmldir.is_file():
            raise RuntimeError(f"Plugin install verification failed: {qmldir} is missing")


def ensure_user_login_path() -> None:
    try:
        local_bin = _HOME / ".local" / "bin"
        if not (local_bin / "caelestia").is_file():
            return
        env_dir = CONFIG_HOME / "environment.d"
        env_file = env_dir / "10-vacuited-path.conf"
        if not env_file.exists():
            env_dir.mkdir(parents=True, exist_ok=True)
            env_file.write_text(
                f"# Managed by vacuited-cli install.sh\nPATH={local_bin}:$PATH\n",
                encoding="utf-8",
            )

        candidates: list[Path] = []
        if (_HOME / ".profile").is_file() or not (_HOME / ".bash_profile").is_file():
            candidates.append(_HOME / ".profile")
        if (_HOME / ".bash_profile").is_file():
            candidates.append(_HOME / ".bash_profile")
        if shutil.which("zsh") or (_HOME / ".zshrc").is_file() or (_HOME / ".zprofile").is_file():
            candidates.append(_HOME / ".zprofile")

        snippet = (
            "# Added by vacuited-cli install.sh\n"
            'case ":$PATH:" in\n'
            '    *:"$HOME/.local/bin":*) ;;\n'
            '    *) export PATH="$HOME/.local/bin:$PATH" ;;\n'
            "esac\n"
        )
        for pf in candidates:
            if pf.is_file():
                text = pf.read_text(encoding="utf-8", errors="ignore")
                if ".local/bin" in text:
                    continue
                sep = "" if (not text or text.endswith("\n\n")) else ("\n" if text.endswith("\n") else "\n\n")
                pf.write_text(text + sep + snippet, encoding="utf-8")
            else:
                pf.write_text(snippet, encoding="utf-8")
    except Exception:
        pass


def should_install_cli_shim() -> bool:
    try:
        if not (_HOME / ".local" / "bin" / "caelestia").is_file():
            return False
        if not CAELESTIA_SHIM_BIN.exists() and not CAELESTIA_SHIM_BIN.is_symlink():
            return True
        if CAELESTIA_SHIM_BIN.is_file() and not CAELESTIA_SHIM_BIN.is_symlink():
            text = CAELESTIA_SHIM_BIN.read_text(encoding="utf-8", errors="ignore")
            return CAELESTIA_SHIM_MARKER in text and text != CAELESTIA_SHIM_CONTENT
    except OSError:
        return False
    return False


def detect_system_sync() -> dict[str, Any]:
    need_abi_hook = False
    try:
        if shutil.which("pacman") is not None:
            if not ABI_CHECK_BIN.is_file() or not ABI_HOOK_FILE.is_file():
                need_abi_hook = True
            else:
                src_check = SHELL_CACHE / "scripts" / "vacuited-abi-check"
                src_hook = SHELL_CACHE / "scripts" / "90-vacuited-shell-abi.hook"
                if src_check.is_file() and src_check.read_bytes() != ABI_CHECK_BIN.read_bytes():
                    need_abi_hook = True
                elif src_hook.is_file() and src_hook.read_bytes() != ABI_HOOK_FILE.read_bytes():
                    need_abi_hook = True
    except OSError:
        need_abi_hook = False

    need_cli_shim = should_install_cli_shim()
    reasons: list[str] = []
    if need_abi_hook:
        reasons.append("pacman ABI guard hook")
    if need_cli_shim:
        reasons.append("login shim (/usr/local/bin/caelestia)")

    return {
        "needed": bool(reasons),
        "needAbiHook": need_abi_hook,
        "needCliShim": need_cli_shim,
        "reasons": reasons,
    }


def cmd_update(args: argparse.Namespace) -> int:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    lock_fh = UPDATE_LOCK_PATH.open("w", encoding="utf-8")
    try:
        fcntl.flock(lock_fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        emit(
            {
                "type": "error",
                "ok": False,
                "message": "Another Vacuited update is already running.",
                "canTerminalFallback": False,
                "terminalCommand": "",
            }
        )
        lock_fh.close()
        return 1

    try:
        _install_cancel_handlers()
        UPDATE_PID_PATH.write_text(str(os.getpid()), encoding="utf-8")
        meta = load_meta()
        check_cache = load_check_cache()
        do_cli = args.target in ("all", "cli")
        do_shell = args.target in ("all", "shell")
        restarted = False
        summary_parts: list[str] = []
        prefetched_shell_head: str | None = None

        if do_shell:
            if os.environ.get("VACUITED_UPDATER_REEXEC") != "1":
                _check_cancelled()
                emit_progress("Syncing Shell repository", 8 if do_cli else 12, "shell")
                prefetched_shell_head = sync_git_cache(SHELL_REPO_URL, SHELL_CACHE, depth=50, component="shell")
                new_script = SHELL_CACHE / "assets" / "scripts" / "vacuited_updater.py"
                try:
                    cur_script = Path(__file__).resolve()
                    if new_script.is_file() and new_script.resolve() != cur_script:
                        new_bytes = new_script.read_bytes()
                        if new_bytes != cur_script.read_bytes():
                            try:
                                compile(new_bytes, str(new_script), "exec")
                            except SyntaxError as exc:
                                emit_log(f"Fetched updater has syntax error ({exc}); continuing with current updater.", "warn", "shell")
                            else:
                                emit_log("Updater script changed upstream — switching to latest updater...", "info", "shell")
                                sys.stdout.flush()
                                try:
                                    UPDATE_PID_PATH.unlink()
                                except OSError:
                                    pass
                                try:
                                    fcntl.flock(lock_fh, fcntl.LOCK_UN)
                                except OSError:
                                    pass
                                lock_fh.close()
                                reexec_env = os.environ.copy()
                                reexec_env["VACUITED_UPDATER_REEXEC"] = "1"
                                reexec_env["VACUITED_SHELL_CACHE_SYNCED"] = "1"
                                os.execve(sys.executable, [sys.executable, str(new_script), *sys.argv[1:]], reexec_env)
                except OSError:
                    pass
            elif os.environ.get("VACUITED_SHELL_CACHE_SYNCED") == "1" and (SHELL_CACHE / ".git").is_dir():
                prefetched_shell_head, _ = read_repo_meta(SHELL_CACHE)

        if do_cli:
            _check_cancelled()
            emit_progress("Syncing CLI repository", 10 if do_shell else 20, "cli")
            cli_head = sync_git_cache(CLI_REPO_URL, CLI_CACHE, depth=30, component="cli")

            _check_cancelled()
            emit_progress("Building & installing Vacuited CLI", 20 if do_shell else 55, "cli")
            rc = run_streamed(
                ["bash", str(CLI_CACHE / "install.sh"), "--yes", "--skip-deps", "--no-path"],
                cwd=CLI_CACHE,
                component="cli",
            )
            if rc != 0:
                raise RuntimeError(f"CLI install failed with exit code {rc}")
            ensure_user_login_path()

            _, tag_cli_ver = read_repo_meta(CLI_CACHE)
            cli_ver = tag_cli_ver or detect_installed_cli_version()
            stamp = now_iso()

            def mutate_cli(m: dict[str, Any]) -> None:
                m["cli"]["commit"] = cli_head
                if cli_ver:
                    m["cli"]["version"] = cli_ver
                m["cli"]["installedAt"] = stamp

            meta = update_meta(mutate_cli)
            check_cache.pop("latest_cli", None)
            save_check_cache(check_cache)
            summary_parts.append(f"CLI {short_sha(cli_head)}")

        if do_shell:
            _check_cancelled()
            if prefetched_shell_head:
                shell_head = prefetched_shell_head
            else:
                emit_progress("Syncing Shell repository", 25 if do_cli else 12, "shell")
                shell_head = sync_git_cache(SHELL_REPO_URL, SHELL_CACHE, depth=50, component="shell")
            _, tag_ver = read_repo_meta(SHELL_CACHE)
            shell_ver = tag_ver or meta.get("shell", {}).get("version") or "1.0.0"

            do_plugin = decide_plugin_rebuild(args.plugin_rebuild, args.force_rebuild, meta, check_cache)
            emit_log(
                "Detected plugin/CMake changes — compiling C++ plugin."
                if do_plugin
                else "No C++ plugin changes detected — using fast QML update path.",
                "info",
                "shell",
            )

            if do_plugin:
                _check_cancelled()
                qt_qml_dir = detect_qt_qml_dir()
                cmake_cache = BUILD_DIR / "CMakeCache.txt"
                if cmake_cache.is_file():
                    try:
                        cache_text = cmake_cache.read_text(encoding="utf-8", errors="ignore")
                        expected_line = f"CMAKE_HOME_DIRECTORY:INTERNAL={SHELL_CACHE}"
                        if expected_line not in cache_text:
                            emit_log("Resetting CMake build directory for managed updater source...", "info", "shell")
                            shutil.rmtree(BUILD_DIR)
                    except OSError:
                        pass

                BUILD_DIR.mkdir(parents=True, exist_ok=True)
                emit_progress("Configuring C++ plugin (CMake)", 34, "shell")
                rc = run_streamed(
                    [
                        "cmake",
                        "-S",
                        str(SHELL_CACHE),
                        "-B",
                        str(BUILD_DIR),
                        "-G",
                        "Ninja",
                        "-DCMAKE_BUILD_TYPE=Release",
                        "-DCMAKE_INSTALL_PREFIX=/usr",
                        "-DINSTALL_LIBDIR=/usr/lib/caelestia",
                        f"-DINSTALL_QMLDIR={qt_qml_dir}",
                        "-DENABLE_MODULES=extras;plugin",
                        f"-DVERSION={shell_ver}",
                        f"-DGIT_REVISION={shell_head}",
                        "-DDISTRIBUTOR=vacuited",
                    ],
                    cwd=SHELL_CACHE,
                    component="shell",
                )
                if rc != 0:
                    raise RuntimeError(f"CMake configure failed (exit {rc})")

                _check_cancelled()
                emit_progress("Compiling C++ plugin", 40, "shell")
                nproc = str(os.cpu_count() or 4)
                ninja_re = re.compile(r"^\[(\d+)/(\d+)\]")

                def on_build_line(line: str) -> None:
                    m = ninja_re.match(line)
                    if m:
                        cur, total = int(m.group(1)), max(1, int(m.group(2)))
                        emit_progress(f"Compiling C++ plugin ({cur}/{total})", 40 + int(28 * cur / total), "shell")

                rc = run_streamed(
                    ["cmake", "--build", str(BUILD_DIR), "-j", nproc],
                    cwd=SHELL_CACHE,
                    component="shell",
                    on_line=on_build_line,
                )
                if rc != 0:
                    raise RuntimeError(f"C++ plugin build failed (exit {rc})")

                _check_cancelled()
                pkexec_bin = shutil.which("pkexec")
                tape_name = detect_active_tape_name()
                term_cmd = f"cd {shlex.quote(str(SHELL_CACHE))} && ./install.sh --skip-deps --skip-cli"
                if tape_name:
                    term_cmd += f" --tapes --tape-name {shlex.quote(tape_name)}"
                if not pkexec_bin:
                    emit(
                        {
                            "type": "error",
                            "ok": False,
                            "message": "pkexec was not found; cannot request root privileges from the GUI.",
                            "canTerminalFallback": True,
                            "terminalCommand": term_cmd,
                        }
                    )
                    return 1

                emit_progress("Waiting for administrator authentication...", 70, "shell")
                update_hw = should_update_hardware_helper(meta.get("shell", {}).get("pluginCommit", ""))
                install_shim = should_install_cli_shim()
                legacy_list = " ".join(shlex.quote(rel) for rel in LEGACY_LIBS)
                priv_script = (
                    "set -e\n"
                    'build_dir="$1"\n'
                    'qt_qml_dir="$2"\n'
                    'shell_dir="$3"\n'
                    'update_hw="$4"\n'
                    'install_shim="$5"\n'
                    f'for rel in {legacy_list}; do\n'
                    '    [ -e "$qt_qml_dir/$rel" ] && rm -f "$qt_qml_dir/$rel"\n'
                    "done\n"
                    'cmake --install "$build_dir"\n'
                    'if [ "$update_hw" = "1" ]; then\n'
                    '    install -Dm755 "$shell_dir/scripts/caelestia-hardware-helper" /usr/local/bin/caelestia-hardware-helper\n'
                    '    install -Dm644 "$shell_dir/scripts/50-caelestia-hardware.rules" /etc/polkit-1/rules.d/50-caelestia-hardware.rules\n'
                    "fi\n"
                    'if command -v pacman >/dev/null 2>&1 && [ -f "$shell_dir/scripts/vacuited-abi-check" ] && [ -f "$shell_dir/scripts/90-vacuited-shell-abi.hook" ]; then\n'
                    '    install -Dm755 "$shell_dir/scripts/vacuited-abi-check" /usr/local/bin/vacuited-abi-check\n'
                    '    install -Dm644 "$shell_dir/scripts/90-vacuited-shell-abi.hook" /etc/pacman.d/hooks/90-vacuited-shell-abi.hook\n'
                    "fi\n"
                    'if [ "$install_shim" = "1" ]; then\n'
                    f"    if {{ [ ! -e /usr/local/bin/caelestia ] && [ ! -L /usr/local/bin/caelestia ]; }} || {{ [ -f /usr/local/bin/caelestia ] && grep -qF {shlex.quote(CAELESTIA_SHIM_MARKER)} /usr/local/bin/caelestia 2>/dev/null; }}; then\n"
                    "        mkdir -p /usr/local/bin\n"
                    "        cat <<'VACUITED_SHIM_EOF' > /usr/local/bin/.caelestia.shim.tmp\n"
                    f"{CAELESTIA_SHIM_CONTENT}"
                    "VACUITED_SHIM_EOF\n"
                    "        chmod 0755 /usr/local/bin/.caelestia.shim.tmp\n"
                    "        mv -f /usr/local/bin/.caelestia.shim.tmp /usr/local/bin/caelestia\n"
                    "    fi\n"
                    "fi\n"
                )
                rc = run_streamed(
                    [
                        pkexec_bin,
                        "/bin/sh",
                        "-c",
                        priv_script,
                        "vacuited-updater-install",
                        str(BUILD_DIR),
                        qt_qml_dir,
                        str(SHELL_CACHE),
                        "1" if update_hw else "0",
                        "1" if install_shim else "0",
                    ],
                    component="shell",
                )
                if rc in (126, 127):
                    emit(
                        {
                            "type": "error",
                            "ok": False,
                            "message": "Authentication was canceled or polkit agent is unavailable.",
                            "canTerminalFallback": True,
                            "terminalCommand": term_cmd,
                        }
                    )
                    return 1
                if rc != 0:
                    raise RuntimeError(f"Privileged plugin install failed (exit {rc})")

                verify_plugin_install(qt_qml_dir)
                emit_log("C++ plugin installed and verified.", "info", "shell")

            _check_cancelled()
            emit_progress("Compiling shaders & validating files", 78, "shell")
            compile_standalone_shaders(SHELL_CACHE)
            validate_shell_source(SHELL_CACHE)

            _check_cancelled()
            emit_progress("Backing up current shell config", 85, "shell")
            create_backup(meta, reason=f"Before update to {short_sha(shell_head)}")

            _check_cancelled()
            emit_progress("Deploying QML shell files", 92, "shell")
            global _deploying_critical
            _deploying_critical = True
            try:
                deploy_qml_tree(SHELL_CACHE, QS_DEST, component="shell")
                validate_shell_source(QS_DEST)
            finally:
                _deploying_critical = False
            ensure_user_login_path()

            stamp = now_iso()

            def mutate_shell(m: dict[str, Any]) -> None:
                m["shell"]["commit"] = shell_head
                if do_plugin:
                    m["shell"]["pluginCommit"] = shell_head
                if shell_ver:
                    m["shell"]["version"] = shell_ver
                m["shell"]["installedAt"] = stamp
                prev = m.get("justUpdated") if isinstance(m.get("justUpdated"), dict) else {}
                comps = list(prev.get("components") or []) if do_cli else []
                if "shell" not in comps:
                    comps.append("shell")
                m["justUpdated"] = {
                    "rolledBack": False,
                    "components": comps,
                    "shellCommit": shell_head,
                    "shellShort": short_sha(shell_head),
                    "cliCommit": m["cli"].get("commit", ""),
                    "cliShort": short_sha(m["cli"].get("commit", "")),
                    "pluginRebuilt": do_plugin,
                    "at": stamp,
                }

            meta = update_meta(mutate_shell)
            check_cache.pop("latest_shell", None)
            save_check_cache(check_cache)
            summary_parts.append(f"Shell {short_sha(shell_head)}")
            restarted = not args.no_restart

        emit_progress("Update complete", 100, args.target)
        emit(
            {
                "type": "done",
                "ok": True,
                "restarting": restarted,
                "summary": ", ".join(summary_parts) or "Updated",
                "meta": meta,
                "backups": list_backups(meta),
                "systemSync": detect_system_sync(),
            }
        )
        sys.stdout.flush()

        if restarted:
            spawn_detached_reload()
        return 0

    except UpdateCancelled:
        _kill_active_subproc()
        emit(
            {
                "type": "cancelled",
                "ok": False,
                "message": "Update canceled.",
            }
        )
        return 130
    except Exception as e:
        emit(
            {
                "type": "error",
                "ok": False,
                "message": str(e),
                "canTerminalFallback": False,
                "terminalCommand": "",
            }
        )
        return 1
    finally:
        try:
            UPDATE_PID_PATH.unlink()
        except OSError:
            pass
        try:
            fcntl.flock(lock_fh, fcntl.LOCK_UN)
        except OSError:
            pass
        lock_fh.close()


def cmd_sync_system(_args: argparse.Namespace) -> int:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    lock_fh = UPDATE_LOCK_PATH.open("w", encoding="utf-8")
    try:
        fcntl.flock(lock_fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        emit(
            {
                "type": "error",
                "ok": False,
                "message": "Another Vacuited update is already running.",
                "canTerminalFallback": False,
                "terminalCommand": "",
            }
        )
        lock_fh.close()
        return 1

    try:
        _install_cancel_handlers()
        UPDATE_PID_PATH.write_text(str(os.getpid()), encoding="utf-8")

        sync_info = detect_system_sync()
        if not sync_info["needed"]:
            meta = load_meta()
            emit_progress("System hooks up to date", 100, "system")
            emit(
                {
                    "type": "done",
                    "ok": True,
                    "restarting": False,
                    "summary": "System hooks & login shim already up to date",
                    "systemSync": sync_info,
                    "meta": meta,
                    "backups": list_backups(meta),
                }
            )
            return 0

        if sync_info["needAbiHook"] and (
            not (SHELL_CACHE / "scripts" / "vacuited-abi-check").is_file()
            or not (SHELL_CACHE / "scripts" / "90-vacuited-shell-abi.hook").is_file()
        ):
            _check_cancelled()
            emit_progress("Fetching hook scripts", 25, "system")
            sync_git_cache(SHELL_REPO_URL, SHELL_CACHE, depth=5, component="system")

        tape_name = detect_active_tape_name()
        tape_args = f" --tapes --tape-name {shlex.quote(tape_name)}" if tape_name else ""
        if (SHELL_CACHE / "install.sh").is_file():
            term_cmd = f"cd {shlex.quote(str(SHELL_CACHE))} && ./install.sh --skip-deps --skip-cli{tape_args}"
        else:
            term_cmd = (
                f"git clone --depth 1 {shlex.quote(SHELL_REPO_URL)} /tmp/vacuited-shell "
                f"&& cd /tmp/vacuited-shell && ./install.sh --skip-deps --skip-cli{tape_args}"
            )

        pkexec_bin = shutil.which("pkexec")
        if not pkexec_bin:
            emit(
                {
                    "type": "error",
                    "ok": False,
                    "message": "pkexec was not found; cannot request root privileges from the GUI.",
                    "canTerminalFallback": True,
                    "terminalCommand": term_cmd,
                }
            )
            return 1

        _check_cancelled()
        emit_progress("Waiting for administrator authentication...", 55, "system")
        priv_script = (
            "set -e\n"
            'shell_dir="$1"\n'
            'need_abi="$2"\n'
            'need_shim="$3"\n'
            'if [ "$need_abi" = "1" ] && command -v pacman >/dev/null 2>&1 && [ -f "$shell_dir/scripts/vacuited-abi-check" ] && [ -f "$shell_dir/scripts/90-vacuited-shell-abi.hook" ]; then\n'
            '    install -Dm755 "$shell_dir/scripts/vacuited-abi-check" /usr/local/bin/vacuited-abi-check\n'
            '    install -Dm644 "$shell_dir/scripts/90-vacuited-shell-abi.hook" /etc/pacman.d/hooks/90-vacuited-shell-abi.hook\n'
            "fi\n"
            'if [ "$need_shim" = "1" ]; then\n'
            f"    if {{ [ ! -e /usr/local/bin/caelestia ] && [ ! -L /usr/local/bin/caelestia ]; }} || {{ [ -f /usr/local/bin/caelestia ] && grep -qF {shlex.quote(CAELESTIA_SHIM_MARKER)} /usr/local/bin/caelestia 2>/dev/null; }}; then\n"
            "        mkdir -p /usr/local/bin\n"
            "        cat <<'VACUITED_SHIM_EOF' > /usr/local/bin/.caelestia.shim.tmp\n"
            f"{CAELESTIA_SHIM_CONTENT}"
            "VACUITED_SHIM_EOF\n"
            "        chmod 0755 /usr/local/bin/.caelestia.shim.tmp\n"
            "        mv -f /usr/local/bin/.caelestia.shim.tmp /usr/local/bin/caelestia\n"
            "    fi\n"
            "fi\n"
        )
        rc = run_streamed(
            [
                pkexec_bin,
                "/bin/sh",
                "-c",
                priv_script,
                "vacuited-updater-sync",
                str(SHELL_CACHE),
                "1" if sync_info["needAbiHook"] else "0",
                "1" if sync_info["needCliShim"] else "0",
            ],
            component="system",
        )
        if rc in (126, 127):
            emit(
                {
                    "type": "error",
                    "ok": False,
                    "message": "Authentication was canceled or polkit agent is unavailable.",
                    "canTerminalFallback": True,
                    "terminalCommand": term_cmd,
                }
            )
            return 1
        if rc != 0:
            raise RuntimeError(f"System sync failed (exit {rc})")

        after = detect_system_sync()
        meta = load_meta()
        emit_progress("System sync complete", 100, "system")
        emit(
            {
                "type": "done",
                "ok": True,
                "restarting": False,
                "summary": "System hooks & login shim synced",
                "systemSync": after,
                "meta": meta,
                "backups": list_backups(meta),
            }
        )
        return 0

    except UpdateCancelled:
        _kill_active_subproc()
        emit(
            {
                "type": "cancelled",
                "ok": False,
                "message": "System sync canceled.",
            }
        )
        return 130
    except Exception as e:
        emit(
            {
                "type": "error",
                "ok": False,
                "message": str(e),
                "canTerminalFallback": False,
                "terminalCommand": "",
            }
        )
        return 1
    finally:
        try:
            UPDATE_PID_PATH.unlink()
        except OSError:
            pass
        try:
            fcntl.flock(lock_fh, fcntl.LOCK_UN)
        except OSError:
            pass
        lock_fh.close()


def cmd_rollback(args: argparse.Namespace) -> int:
    name = args.backup_name
    if not BACKUP_NAME_RE.fullmatch(name):
        emit(
            {
                "type": "error",
                "ok": False,
                "message": f"Invalid backup name: {name}",
                "canTerminalFallback": False,
                "terminalCommand": "",
            }
        )
        return 1

    backup_dir = QS_DEST.parent / name
    if not backup_dir.is_dir() or backup_dir.is_symlink() or not (backup_dir / "shell.qml").is_file():
        emit(
            {
                "type": "error",
                "ok": False,
                "message": f"Backup '{name}' is missing or incomplete.",
                "canTerminalFallback": False,
                "terminalCommand": "",
            }
        )
        return 1

    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    lock_fh = UPDATE_LOCK_PATH.open("w", encoding="utf-8")
    try:
        fcntl.flock(lock_fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        emit(
            {
                "type": "error",
                "ok": False,
                "message": "Another update or rollback is already in progress.",
                "canTerminalFallback": False,
                "terminalCommand": "",
            }
        )
        lock_fh.close()
        return 1

    try:
        _install_cancel_handlers()
        UPDATE_PID_PATH.write_text(str(os.getpid()), encoding="utf-8")
        emit_progress(f"Restoring {name}", 35, "shell")
        validate_shell_source(backup_dir)
        _check_cancelled()
        global _deploying_critical
        _deploying_critical = True
        try:
            deploy_qml_tree(backup_dir, QS_DEST, component="shell")
            validate_shell_source(QS_DEST)
        finally:
            _deploying_critical = False

        bmeta = read_json(backup_dir / ".vacuited-backup.json", {})
        restored_commit = str(bmeta.get("shellCommit") or "") if isinstance(bmeta, dict) else ""
        restored_ver = str(bmeta.get("version") or "") if isinstance(bmeta, dict) else ""
        stamp = now_iso()

        def mutate(m: dict[str, Any]) -> None:
            if restored_commit:
                m["shell"]["commit"] = restored_commit
            if restored_ver:
                m["shell"]["version"] = restored_ver
            m["shell"]["installedAt"] = stamp
            m["justUpdated"] = {
                "rolledBack": True,
                "backupName": name,
                "shellCommit": restored_commit,
                "shellShort": short_sha(restored_commit),
                "at": stamp,
            }

        meta = update_meta(mutate)
        cache = load_check_cache()
        cache.pop("latest_shell", None)
        save_check_cache(cache)

        restarted = not args.no_restart
        emit_progress("Rollback restored", 100, "shell")
        emit(
            {
                "type": "done",
                "ok": True,
                "restarting": restarted,
                "summary": f"Restored {name}",
                "meta": meta,
                "backups": list_backups(meta),
            }
        )
        sys.stdout.flush()

        if restarted:
            spawn_detached_reload()
        return 0
    except UpdateCancelled:
        _kill_active_subproc()
        emit(
            {
                "type": "cancelled",
                "ok": False,
                "message": "Rollback canceled.",
            }
        )
        return 130
    except Exception as e:
        emit(
            {
                "type": "error",
                "ok": False,
                "message": str(e),
                "canTerminalFallback": False,
                "terminalCommand": "",
            }
        )
        return 1
    finally:
        try:
            UPDATE_PID_PATH.unlink()
        except OSError:
            pass
        try:
            fcntl.flock(lock_fh, fcntl.LOCK_UN)
        except OSError:
            pass
        lock_fh.close()


def cmd_cancel(_args: argparse.Namespace) -> int:
    try:
        pid = int(UPDATE_PID_PATH.read_text(encoding="utf-8").strip())
    except (OSError, ValueError):
        print(json.dumps({"ok": False, "error": "No active update process."}))
        return 1

    cmdline_path = Path(f"/proc/{pid}/cmdline")
    try:
        cmdline = cmdline_path.read_bytes().decode("utf-8", errors="ignore").replace("\x00", " ")
    except OSError:
        print(json.dumps({"ok": False, "error": "No active update process."}))
        return 1

    if "vacuited_updater.py" not in cmdline:
        print(json.dumps({"ok": False, "error": "No active update process."}))
        return 1

    try:
        os.kill(pid, 0)
        os.kill(pid, signal.SIGTERM)
    except OSError as e:
        print(json.dumps({"ok": False, "error": str(e)}))
        return 1

    print(json.dumps({"ok": True, "pid": pid}))
    return 0


def cmd_delete_backup(args: argparse.Namespace) -> int:
    name = args.backup_name
    if not BACKUP_NAME_RE.fullmatch(name):
        print(json.dumps({"ok": False, "error": f"Invalid backup name: {name}"}))
        return 1

    backup_dir = QS_DEST.parent / name
    if not backup_dir.exists() or backup_dir.is_symlink():
        print(json.dumps({"ok": False, "error": f"Backup '{name}' not found."}))
        return 1

    shutil.rmtree(backup_dir)
    meta = load_meta()
    print(json.dumps({"ok": True, "backups": list_backups(meta)}))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Vacuited Nexus Updater Backend")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("status", help="Return local install metadata and backups (offline)")
    sub.add_parser("clear-just-updated", help="Clear the post-restart toast marker")

    rec = sub.add_parser("record-install", help="Record an install from a git repo directory")
    rec.add_argument("--component", choices=("shell", "cli"), required=True)
    rec.add_argument("--repo-dir", required=True)
    rec.add_argument("--plugin-rebuilt", action="store_true")
    rec.add_argument("--version", default="")

    sync = sub.add_parser("mark-synced", help="Record remote main HEAD as current baseline")
    sync.add_argument("--component", choices=("all", "shell", "cli"), default="all")

    chk = sub.add_parser("check", help="Check remote commits for updates")
    chk.add_argument("--force", action="store_true")

    upd = sub.add_parser("update", help="Download, build, and install updates")
    upd.add_argument("--target", choices=("all", "shell", "cli"), default="all")
    upd.add_argument("--force-rebuild", action="store_true")
    upd.add_argument("--plugin-rebuild", choices=("auto", "yes", "no"), default="auto")
    upd.add_argument("--no-restart", action="store_true")

    sub.add_parser("sync-system", help="Install or refresh pacman ABI hook and login shim")

    rb = sub.add_parser("rollback", help="Restore a QML backup snapshot")
    rb.add_argument("backup_name")
    rb.add_argument("--no-restart", action="store_true")

    rmb = sub.add_parser("delete-backup", help="Delete a QML backup snapshot")
    rmb.add_argument("backup_name")

    sub.add_parser("cancel", help="Cancel a running update or rollback")

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    dispatch = {
        "status": cmd_status,
        "clear-just-updated": cmd_clear_just_updated,
        "record-install": cmd_record_install,
        "mark-synced": cmd_mark_synced,
        "check": cmd_check,
        "update": cmd_update,
        "sync-system": cmd_sync_system,
        "rollback": cmd_rollback,
        "delete-backup": cmd_delete_backup,
        "cancel": cmd_cancel,
    }
    return dispatch[args.command](args)


if __name__ == "__main__":
    sys.exit(main())

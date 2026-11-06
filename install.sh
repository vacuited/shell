#!/usr/bin/env bash
# install.sh — Build and install vacuited-shell (Caelestia Quickshell shell)
#
# What it does:
#   1. Checks dependencies (auto-installs missing ones on Arch-based distros)
#   2. Installs the vacuited CLI if `caelestia` is not in PATH
#   3. Builds the C++ QML plugin and installs it to /usr (needs sudo)
#   4. Copies the QML shell to ~/.config/quickshell/caelestia (backs up any changed copy)
#   5. Optionally installs the HP Victus hardware helper (auto-detected)
#
# Never touches ~/.config/caelestia/shell.json.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
QS_DEST="${CONFIG_HOME}/quickshell/caelestia"
BUILD_DIR="${CACHE_HOME}/vacuited/shell-build"
CLI_REPO_URL="https://github.com/vacuited/cli.git"
CLI_CLONE_DIR="${CACHE_HOME}/vacuited/cli"

# Items copied into the live Quickshell config (mirrors CMakeLists.txt install list)
QML_DIRS=(assets components daemons modules services utils)
QML_FILES=(shell.qml LICENSE)

# Arch packages. Official repos:
PAC_REQUIRED=(
    gcc make git cmake ninja pkgconf
    qt6-base qt6-declarative qt6-shadertools qt6-multimedia qt6-5compat qt6-svg qt6-imageformats qt6-wayland
    protobuf openssl libqalculate pipewire aubio lm_sensors
    hyprland fish brightnessctl ddcutil networkmanager power-profiles-daemon
    libsecret libxml2 unzip wl-clipboard cliphist swappy grim slurp
)
# AUR:
AUR_REQUIRED=(quickshell-git qt6-m3shapes-git libcava)
# Optional extras (offered, default no):
PAC_OPTIONAL=(hyprsunset gpu-screen-recorder papirus-icon-theme)
AUR_OPTIONAL=(linux-wallpaperengine-git papirus-folders)
# Fonts: "fc-list family pattern|official package|aur package"
FONTS=(
    "Material Symbols Rounded||ttf-material-symbols-variable-git"
    "Rubik||ttf-rubik-vf"
    "CaskaydiaCove NF|ttf-cascadia-code-nerd|"
)

ASSUME_YES=0
SKIP_DEPS=0
SKIP_CLI=0
DRY_RUN=0
HARDWARE=auto
SUDO=sudo

if [ -t 1 ]; then
    C_G=$'\033[1;32m'; C_Y=$'\033[1;33m'; C_R=$'\033[1;31m'; C_B=$'\033[1;34m'; C_0=$'\033[0m'
else
    C_G=''; C_Y=''; C_R=''; C_B=''; C_0=''
fi
log()  { printf '%s[+]%s %s\n' "$C_G" "$C_0" "$*"; }
info() { printf '%s[*]%s %s\n' "$C_B" "$C_0" "$*"; }
warn() { printf '%s[!]%s %s\n' "$C_Y" "$C_0" "$*" >&2; }
err()  { printf '%s[-]%s %s\n' "$C_R" "$C_0" "$*" >&2; }
die()  { err "$*"; exit 1; }

usage() {
    cat <<EOF
Usage: ./install.sh [options]

  -y, --yes          Non-interactive (answer yes, pass --noconfirm to package managers)
      --skip-deps    Do not check or install dependencies
      --skip-cli     Do not install the vacuited CLI when 'caelestia' is missing
      --hardware     Install the HP Victus hardware helper + polkit rule
      --no-hardware  Never install the hardware helper (default: auto-detect hp-wmi)
      --dry-run      Print what would run without changing anything
  -h, --help         Show this help

Supported for automatic dependency install: Arch Linux and derivatives (pacman + yay/paru).
Other distros: dependencies are verified and missing ones are reported.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes) ASSUME_YES=1 ;;
        --skip-deps) SKIP_DEPS=1 ;;
        --skip-cli) SKIP_CLI=1 ;;
        --hardware) HARDWARE=yes ;;
        --no-hardware) HARDWARE=no ;;
        --dry-run) DRY_RUN=1 ;;
        -h|--help) usage; exit 0 ;;
        *) err "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

[ "$(id -u)" -ne 0 ] || die "Do not run as root. The script calls sudo only where needed."

# Run a command, or just print it in dry-run mode
run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '%s[dry-run]%s %s\n' "$C_Y" "$C_0" "$*"
    else
        "$@"
    fi
}

# confirm "prompt" default(y|n)
confirm() {
    local prompt="$1" def="${2:-n}" reply hint
    [ "$ASSUME_YES" -eq 1 ] && return 0
    [ "$def" = y ] && hint="[Y/n]" || hint="[y/N]"
    if [ ! -r /dev/tty ]; then
        [ "$def" = y ]
        return
    fi
    read -r -p "$prompt $hint " reply </dev/tty || reply=""
    reply="${reply:-$def}"
    [[ "$reply" =~ ^[Yy] ]]
}

IS_ARCH=0
command -v pacman >/dev/null 2>&1 && IS_ARCH=1
AUR_HELPER=""
YES_FLAG=()
[ "$ASSUME_YES" -eq 1 ] && YES_FLAG=(--noconfirm)

echo "=== Installing vacuited-shell ==="
[ -f "$SCRIPT_DIR/shell.qml" ] && [ -f "$SCRIPT_DIR/CMakeLists.txt" ] || die "Run this script from inside the shell repository."

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------

pac_missing() { pacman -T "$@" 2>/dev/null || true; }

detect_aur_helper() {
    local h
    for h in paru yay; do
        if command -v "$h" >/dev/null 2>&1; then AUR_HELPER="$h"; return 0; fi
    done
    return 1
}

bootstrap_aur_helper() {
    warn "No AUR helper (paru/yay) found, but AUR packages are required."
    confirm "Build and install yay-bin from the AUR now?" y || die "Install an AUR helper (yay or paru) and re-run."
    run $SUDO pacman -S --needed "${YES_FLAG[@]}" git base-devel
    local tmp
    tmp="$(mktemp -d)"
    run git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    if [ "$DRY_RUN" -eq 1 ]; then
        info "[dry-run] would run makepkg -si in $tmp/yay-bin"
    else
        (cd "$tmp/yay-bin" && makepkg -si "${YES_FLAG[@]}")
    fi
    rm -rf "$tmp"
    AUR_HELPER=yay
}

font_missing_pkgs() {
    # Prints package names for fonts that fontconfig cannot find
    local entry fam pac aur families
    command -v fc-list >/dev/null 2>&1 || return 0
    families="$(fc-list -f '%{family}\n' 2>/dev/null || true)"
    for entry in "${FONTS[@]}"; do
        IFS='|' read -r fam pac aur <<<"$entry"
        if ! grep -qiF "$fam" <<<"$families"; then
            if [ "$IS_ARCH" -eq 1 ]; then
                [ -n "$pac" ] && echo "pac:$pac"
                [ -n "$aur" ] && echo "aur:$aur"
            else
                echo "font:$fam"
            fi
        fi
    done
}

install_deps_arch() {
    local pac_need=() aur_need=() item opt_pac=() opt_aur=()

    mapfile -t pac_need < <(pac_missing "${PAC_REQUIRED[@]}")
    mapfile -t aur_need < <(pac_missing "${AUR_REQUIRED[@]}")

    while IFS= read -r item; do
        case "$item" in
            pac:*) pac_need+=("${item#pac:}") ;;
            aur:*) aur_need+=("${item#aur:}") ;;
        esac
    done < <(font_missing_pkgs)

    # Drop empty entries from mapfile on empty output
    local clean=() p
    for p in "${pac_need[@]}"; do [ -n "$p" ] && clean+=("$p"); done
    pac_need=("${clean[@]+"${clean[@]}"}")
    clean=()
    for p in "${aur_need[@]}"; do [ -n "$p" ] && clean+=("$p"); done
    aur_need=("${clean[@]+"${clean[@]}"}")

    if [ ${#pac_need[@]} -eq 0 ] && [ ${#aur_need[@]} -eq 0 ]; then
        log "All required dependencies are installed."
    else
        if [ ${#pac_need[@]} -gt 0 ]; then
            info "Missing (official repos): ${pac_need[*]}"
        fi
        if [ ${#aur_need[@]} -gt 0 ]; then
            info "Missing (AUR): ${aur_need[*]}"
        fi
        confirm "Install the missing packages?" y || die "Cannot continue without required dependencies."

        if [ ${#pac_need[@]} -gt 0 ]; then
            run $SUDO pacman -S --needed "${YES_FLAG[@]}" "${pac_need[@]}"
        fi
        if [ ${#aur_need[@]} -gt 0 ]; then
            detect_aur_helper || bootstrap_aur_helper
            run "$AUR_HELPER" -S --needed "${YES_FLAG[@]}" "${aur_need[@]}"
        fi
    fi

    if ! pacman -Qq quickshell-git >/dev/null 2>&1; then
        warn "quickshell-git is not installed. This shell targets the git version of Quickshell; the stable package may lack features."
    fi

    # Optional extras
    mapfile -t opt_pac < <(pac_missing "${PAC_OPTIONAL[@]}")
    mapfile -t opt_aur < <(pac_missing "${AUR_OPTIONAL[@]}")
    clean=(); for p in "${opt_pac[@]}"; do [ -n "$p" ] && clean+=("$p"); done; opt_pac=("${clean[@]+"${clean[@]}"}")
    clean=(); for p in "${opt_aur[@]}"; do [ -n "$p" ] && clean+=("$p"); done; opt_aur=("${clean[@]+"${clean[@]}"}")

    if [ $(( ${#opt_pac[@]} + ${#opt_aur[@]} )) -gt 0 ]; then
        info "Optional extras not installed: ${opt_pac[*]-} ${opt_aur[*]-}"
        info "  hyprsunset: night light | gpu-screen-recorder: screen recording | papirus-*: folder tinting | linux-wallpaperengine-git: Wallpaper Engine"
        if [ "$ASSUME_YES" -eq 0 ] && confirm "Install optional extras too?" n; then
            if [ ${#opt_pac[@]} -gt 0 ]; then
                run $SUDO pacman -S --needed "${YES_FLAG[@]}" "${opt_pac[@]}"
            fi
            if [ ${#opt_aur[@]} -gt 0 ]; then
                detect_aur_helper || bootstrap_aur_helper
                run "$AUR_HELPER" -S --needed "${YES_FLAG[@]}" "${opt_aur[@]}"
            fi
        fi
    fi
}

# Distro-agnostic verification of what the build and shell actually need
verify_prereqs() {
    local missing=() c m
    for c in cmake ninja c++ git pkg-config qs fish hyprctl; do
        command -v "$c" >/dev/null 2>&1 || missing+=("command: $c")
    done
    for m in Qt6Core Qt6Qml Qt6Quick Qt6QuickControls2 Qt6ShaderTools Qt6Multimedia Qt6Sql Qt6Network Qt6DBus Qt6Concurrent \
             protobuf openssl libqalculate libpipewire-0.3 aubio; do
        pkg-config --exists "$m" 2>/dev/null || missing+=("pkg-config: $m")
    done
    pkg-config --exists libcava 2>/dev/null || pkg-config --exists cava 2>/dev/null || missing+=("pkg-config: libcava (or cava)")
    [ -e /usr/include/sensors/sensors.h ] || [ -e /usr/local/include/sensors/sensors.h ] || missing+=("header: sensors/sensors.h (lm_sensors)")

    if [ ${#missing[@]} -gt 0 ]; then
        err "Missing prerequisites:"
        printf '    - %s\n' "${missing[@]}" >&2
        [ "$IS_ARCH" -eq 1 ] || err "Install the equivalents for your distro (see README), then re-run."
        return 1
    fi

    local qtver
    qtver="$(pkg-config --modversion Qt6Core 2>/dev/null || echo 0)"
    if [ "$(printf '%s\n6.9.0\n' "$qtver" | sort -V | head -n1)" != "6.9.0" ]; then
        die "Qt $qtver found, but Qt >= 6.9 is required."
    fi
    log "Prerequisites OK (Qt $qtver)."
}

if [ "$SKIP_DEPS" -eq 1 ]; then
    warn "Skipping dependency installation (--skip-deps)."
else
    log "Checking dependencies..."
    if [ "$IS_ARCH" -eq 1 ]; then
        install_deps_arch
    else
        warn "Not an Arch-based system: cannot auto-install packages. Verifying instead."
    fi
fi

if [ "$DRY_RUN" -eq 1 ] && [ "$IS_ARCH" -eq 1 ] && [ "$SKIP_DEPS" -eq 0 ]; then
    verify_prereqs || warn "(dry-run) Prerequisites above would be installed by the steps shown."
else
    verify_prereqs || die "Fix the missing prerequisites and re-run."
fi

# ---------------------------------------------------------------------------
# CLI dependency
# ---------------------------------------------------------------------------

install_cli() {
    local cli_dir="" args=()
    [ "$ASSUME_YES" -eq 1 ] && args+=(--yes)
    [ "$SKIP_DEPS" -eq 1 ] && args+=(--skip-deps)
    [ "$DRY_RUN" -eq 1 ] && args+=(--dry-run)

    if [ -f "$SCRIPT_DIR/../cli/install.sh" ]; then
        cli_dir="$(cd "$SCRIPT_DIR/../cli" && pwd)"
    else
        info "Fetching the vacuited CLI into $CLI_CLONE_DIR..."
        if [ -d "$CLI_CLONE_DIR/.git" ]; then
            run git -C "$CLI_CLONE_DIR" pull --ff-only
        else
            run mkdir -p "$(dirname "$CLI_CLONE_DIR")"
            run git clone --depth 1 "$CLI_REPO_URL" "$CLI_CLONE_DIR"
        fi
        cli_dir="$CLI_CLONE_DIR"
    fi
    if [ "$DRY_RUN" -eq 1 ] && [ ! -f "$cli_dir/install.sh" ]; then
        run bash "$cli_dir/install.sh" "${args[@]+"${args[@]}"}"
    else
        bash "$cli_dir/install.sh" "${args[@]+"${args[@]}"}"
    fi
}

ORIG_PATH="$PATH"
export PATH="$HOME/.local/bin:$PATH"
if command -v caelestia >/dev/null 2>&1; then
    log "caelestia CLI found: $(command -v caelestia)"
elif [ "$SKIP_CLI" -eq 1 ]; then
    warn "caelestia CLI missing and --skip-cli given. The shell needs it for schemes, wallpapers and toggles."
else
    warn "caelestia CLI not found. The shell depends on it."
    if confirm "Install the vacuited CLI now?" y; then
        install_cli
    else
        warn "Skipped. Install it later from https://github.com/vacuited/cli"
    fi
fi

# ---------------------------------------------------------------------------
# Build + install the C++ plugin
# ---------------------------------------------------------------------------

detect_version() {
    local v
    v="$(git -C "$SCRIPT_DIR" describe --tags --abbrev=0 2>/dev/null || true)"
    v="${v#v}"
    if [[ "$v" =~ ^[0-9]+(\.[0-9]+){1,3}$ ]]; then echo "$v"; else echo "1.0.0"; fi
}

VERSION="$(detect_version)"
GIT_REV="$(git -C "$SCRIPT_DIR" rev-parse HEAD 2>/dev/null || echo unknown)"

# Obsolete per-module libraries from older layouts
LEGACY_LIBS=(
    /usr/lib/qt6/qml/Caelestia/Components/libcaelestia-components.so
    /usr/lib/qt6/qml/Caelestia/Config/libcaelestia-config.so
    /usr/lib/qt6/qml/Caelestia/Internal/libcaelestia-internal.so
    /usr/lib/qt6/qml/Caelestia/Models/libcaelestia-models.so
    /usr/lib/qt6/qml/Caelestia/Services/libcaelestia-services.so
    /usr/lib/qt6/qml/Caelestia/Blobs/libcaelestia-blobs.so
    /usr/lib/qt6/qml/Caelestia/Images/libcaelestia-images.so
    /usr/lib/qt6/qml/Caelestia/libcaelestia.so
)

log "Building the plugin (version $VERSION, revision ${GIT_REV:0:9})..."
if [ -f "$BUILD_DIR/CMakeCache.txt" ] && ! grep -qx "CMAKE_HOME_DIRECTORY:INTERNAL=$SCRIPT_DIR" "$BUILD_DIR/CMakeCache.txt"; then
    run rm -rf "$BUILD_DIR"
fi
run mkdir -p "$BUILD_DIR"
run cmake -S "$SCRIPT_DIR" -B "$BUILD_DIR" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    "-DENABLE_MODULES=extras;plugin" \
    -DVERSION="$VERSION" \
    -DGIT_REVISION="$GIT_REV" \
    -DDISTRIBUTOR=vacuited
run cmake --build "$BUILD_DIR" -j "$(nproc)"

log "Installing the plugin to /usr (sudo)..."
for lib in "${LEGACY_LIBS[@]}"; do
    if [ -e "$lib" ]; then run $SUDO rm -f "$lib"; fi
done
run $SUDO cmake --install "$BUILD_DIR"

# ---------------------------------------------------------------------------
# Deploy QML shell
# ---------------------------------------------------------------------------

log "Deploying the QML shell to $QS_DEST..."
if [ -d "$QS_DEST" ]; then
    changed=0
    for item in "${QML_DIRS[@]}" "${QML_FILES[@]}"; do
        if [ -e "$QS_DEST/$item" ] && ! diff -rq "$SCRIPT_DIR/$item" "$QS_DEST/$item" >/dev/null 2>&1; then
            changed=1
            break
        fi
    done
    if [ "$changed" -eq 1 ]; then
        backup="${QS_DEST}.bak.$(date +%Y%m%d-%H%M%S)"
        warn "Existing config differs from this repo. Backing up to $backup"
        run cp -a "$QS_DEST" "$backup"
    fi
fi
run mkdir -p "$QS_DEST"
for item in "${QML_DIRS[@]}"; do
    run rm -rf "$QS_DEST/$item"
    run mkdir -p "$QS_DEST/$item"
    run cp -a "$SCRIPT_DIR/$item/." "$QS_DEST/$item/"
done
for item in "${QML_FILES[@]}"; do
    run cp -a "$SCRIPT_DIR/$item" "$QS_DEST/$item"
done

# ---------------------------------------------------------------------------
# HP Victus hardware helper (optional)
# ---------------------------------------------------------------------------

if [ "$HARDWARE" = auto ]; then
    if [ -d /sys/devices/platform/hp-wmi ]; then HARDWARE=yes; else HARDWARE=no; fi
fi
if [ "$HARDWARE" = yes ]; then
    log "Installing the HP hardware helper and polkit rule (sudo)..."
    run $SUDO install -Dm755 "$SCRIPT_DIR/scripts/caelestia-hardware-helper" /usr/local/bin/caelestia-hardware-helper
    run $SUDO install -Dm644 "$SCRIPT_DIR/scripts/50-caelestia-hardware.rules" /etc/polkit-1/rules.d/50-caelestia-hardware.rules
else
    info "Skipping the hardware helper (no hp-wmi detected; use --hardware to force)."
fi

# ---------------------------------------------------------------------------
# Verify + next steps
# ---------------------------------------------------------------------------

if [ "$DRY_RUN" -eq 0 ]; then
    [ -f /usr/lib/qt6/qml/Caelestia/qmldir ] || die "Plugin install check failed: /usr/lib/qt6/qml/Caelestia/qmldir missing."
    [ -f "$QS_DEST/shell.qml" ] || die "Deploy check failed: $QS_DEST/shell.qml missing."
    log "Install verified."
fi

cat <<EOF

=== Done ===
Start the shell (fish or bash):
    caelestia shell -d

If it was already running, reload it:
    caelestia shell -d -r

Bind keys in your Hyprland config, e.g.:
    bind = SUPER, SPACE, global, caelestia:launcher
(see the README for the full shortcut list)
EOF
case ":$ORIG_PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) warn "Add ~/.local/bin to your PATH so the 'caelestia' command is found." ;;
esac

#!/usr/bin/env bash
# install.sh — Build and install vacuited-shell (Caelestia Quickshell shell)
#
# What it does:
#   1. Checks dependencies (auto-installs missing ones on Arch-based distros)
#   2. Installs the vacuited CLI if `caelestia` is missing or upstream
#   3. Builds the C++ QML plugin and installs it to $QT_QML_DIR (needs sudo/doas)
#   4. Deploys the QML shell to ~/.config/quickshell/caelestia (pruned backups)
#   5. Optionally installs the HP Victus hardware helper (auto-detected)
#
# Never touches ~/.config/caelestia/shell.json.

set -Eeuo pipefail

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

CLEANUP_PATHS=()
cleanup() {
    local p
    for p in "${CLEANUP_PATHS[@]+"${CLEANUP_PATHS[@]}"}"; do
        [ -n "$p" ] && rm -rf "$p" 2>/dev/null || true
    done
}
trap cleanup EXIT

SCRIPT_PATH="${BASH_SOURCE[0]:-}"
[ -n "$SCRIPT_PATH" ] && [ -e "$SCRIPT_PATH" ] || die "Do not pipe this script into bash. Clone the repo and run ./install.sh."
SCRIPT_PATH="$(readlink -f "$SCRIPT_PATH" 2>/dev/null || printf '%s' "$SCRIPT_PATH")"
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd -P)"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
QS_DEST="${CONFIG_HOME}/quickshell/caelestia"
BUILD_DIR="${CACHE_HOME}/vacuited/shell-build"
CLI_REPO_URL="https://github.com/vacuited/cli.git"
CLI_CLONE_DIR="${CACHE_HOME}/vacuited/cli"

# Items copied into the live Quickshell config (mirrors CMakeLists.txt install list)
QML_DIRS=(assets components daemons modules services utils)
QML_FILES=(shell.qml LICENSE)

# Arch packages. Official repos:
PAC_REQUIRED=(
    gcc git cmake ninja pkgconf
    qt6-base qt6-declarative qt6-shadertools qt6-multimedia qt6-multimedia-ffmpeg qt6-svg qt6-imageformats qt6-wayland
    protobuf openssl libqalculate pipewire aubio lm_sensors
    hyprland fish python ffmpeg curl jq libnotify upower pciutils xdg-utils fontconfig xkeyboard-config
    brightnessctl ddcutil networkmanager power-profiles-daemon
    libsecret libxml2 unzip wl-clipboard cliphist swappy grim slurp
)
# AUR:
AUR_REQUIRED=(quickshell-git qt6-m3shapes-git libcava)
# Optional extras:
PAC_OPTIONAL=(
    hyprsunset hyprshutdown gpu-screen-recorder mpv avahi bluez bluez-utils
    imagemagick playerctl lua papirus-icon-theme
)
AUR_OPTIONAL=(papirus-folders)
AUR_WE=(skwd-paper-bin skwd-deck-bin skwd-deck-steamworks-bin)
# Fonts: "fc-list family pattern|official package|aur package"
FONTS=(
    "Material Symbols Rounded||ttf-material-symbols-variable-git"
    "Rubik||ttf-rubik-vf"
    "CaskaydiaCove NF|ttf-cascadia-code-nerd|"
)

ASSUME_YES=0
SKIP_DEPS=0
SKIP_CLI=0
UPDATE_CLI=0
WITH_OPTIONAL=0
WITH_WE=0
NO_BACKUP=0
CLEAN_BUILD=0
QML_ONLY=0
UNINSTALL=0
DRY_RUN=0
HARDWARE=auto
SUDO=""

usage() {
    cat <<EOF
Usage: ./install.sh [options]

  -y, --yes                   Non-interactive (answer yes, pass --noconfirm to package managers)
      --skip-deps             Do not check or install dependencies
      --skip-cli              Do not install the vacuited CLI when 'caelestia' is missing
      --update-cli            Force rebuild and update of the vacuited CLI
      --with-optional         Install optional runtime packages automatically (Arch)
      --with-wallpaper-engine Install Wallpaper Engine backend + Steam Workshop (Arch AUR)
      --qml-only              Deploy QML files and shaders only (skip deps, CLI, C++ plugin, hardware)
      --clean                 Wipe the CMake build directory before configuring
      --no-backup             Do not create a backup of existing QML config before overwriting
      --hardware              Install the HP Victus hardware helper + polkit rule
      --no-hardware           Skip hardware helper install (never removes an existing working helper)
      --uninstall             Remove installed shell config, QML plugin, and hardware helper
      --dry-run               Print what would run without changing anything
  -h, --help                  Show this help

Supported for automatic dependency install: Arch Linux and derivatives (pacman + yay/paru).
Other distros: dependencies are verified and missing ones are reported.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes) ASSUME_YES=1 ;;
        --skip-deps) SKIP_DEPS=1 ;;
        --skip-cli) SKIP_CLI=1 ;;
        --update-cli) UPDATE_CLI=1 ;;
        --with-optional) WITH_OPTIONAL=1 ;;
        --with-wallpaper-engine) WITH_WE=1 ;;
        --qml-only) QML_ONLY=1 ;;
        --clean) CLEAN_BUILD=1 ;;
        --no-backup) NO_BACKUP=1 ;;
        --hardware) HARDWARE=yes ;;
        --no-hardware) HARDWARE=no ;;
        --uninstall) UNINSTALL=1 ;;
        --dry-run) DRY_RUN=1 ;;
        -h|--help) usage; exit 0 ;;
        *) err "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

[ "${EUID:-$(id -u)}" -ne 0 ] || die "Do not run as root. The script uses sudo/doas only where needed."

detect_priv_exec() {
    if command -v sudo >/dev/null 2>&1; then
        SUDO=sudo
    elif command -v doas >/dev/null 2>&1; then
        SUDO=doas
    else
        SUDO=""
    fi
}
detect_priv_exec

# Run a command, or just print it in dry-run mode
run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '%s[dry-run]%s %s\n' "$C_Y" "$C_0" "$*"
    else
        "$@"
    fi
}

run_priv() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '%s[dry-run]%s %s %s\n' "$C_Y" "$C_0" "${SUDO:-sudo}" "$*"
    else
        [ -n "$SUDO" ] || die "Neither sudo nor doas is installed; cannot execute privileged command: $*"
        "$SUDO" "$@"
    fi
}

# confirm "prompt" default(y|n)
confirm() {
    local prompt="$1" def="${2:-n}" reply hint
    [ "$ASSUME_YES" -eq 1 ] && return 0
    [ "$def" = y ] && hint="[Y/n]" || hint="[y/N]"
    if ! (: </dev/tty) 2>/dev/null; then
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

find_qtpaths6() {
    local p
    for p in qtpaths6 qtpaths-qt6 /usr/lib/qt6/bin/qtpaths6 /usr/lib64/qt6/bin/qtpaths6; do
        if command -v "$p" >/dev/null 2>&1; then
            command -v "$p"
            return 0
        elif [ -x "$p" ]; then
            printf '%s\n' "$p"
            return 0
        fi
    done
    return 1
}

find_qsb() {
    local p
    for p in qsb qsb-qt6 /usr/lib/qt6/bin/qsb /usr/lib64/qt6/bin/qsb; do
        if command -v "$p" >/dev/null 2>&1; then
            command -v "$p"
            return 0
        elif [ -x "$p" ]; then
            printf '%s\n' "$p"
            return 0
        fi
    done
    return 1
}

detect_qt_qml_dir() {
    local qtp dir=""
    if qtp="$(find_qtpaths6)"; then
        dir="$("$qtp" --query QT_INSTALL_QML 2>/dev/null || true)"
    fi
    [ -n "$dir" ] || dir="/usr/lib/qt6/qml"
    printf '%s\n' "$dir"
}

QT_QML_DIR="$(detect_qt_qml_dir)"

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------

do_uninstall() {
    echo "=== Uninstalling vacuited-shell ==="
    confirm "Remove vacuited-shell files from $QS_DEST, $QT_QML_DIR/Caelestia, and hardware helper?" y || exit 0

    if [ -L "$QS_DEST" ]; then
        info "Removing symlink $QS_DEST (target untouched)"
        run rm -f "$QS_DEST"
    elif [ -e "$QS_DEST" ]; then
        info "Removing $QS_DEST"
        run rm -rf "$QS_DEST"
    fi

    if [ -e "$QT_QML_DIR/Caelestia" ]; then
        info "Removing $QT_QML_DIR/Caelestia (privileged)"
        run_priv rm -rf "$QT_QML_DIR/Caelestia"
    fi
    local libdir
    for libdir in /usr/lib/caelestia /usr/lib64/caelestia /etc/xdg/quickshell/caelestia; do
        if [ -e "$libdir" ]; then
            info "Removing $libdir (privileged)"
            run_priv rm -rf "$libdir"
        fi
    done

    info "Removing hardware helper and polkit rule if present (privileged)"
    run_priv rm -f /usr/local/bin/caelestia-hardware-helper /etc/polkit-1/rules.d/50-caelestia-hardware.rules

    if [ -d "$BUILD_DIR" ]; then
        info "Removing build directory $BUILD_DIR"
        run rm -rf "$BUILD_DIR"
    fi

    log "vacuited-shell uninstalled."
    exit 0
}

if [ "$UNINSTALL" -eq 1 ]; then
    do_uninstall
fi

echo "=== Installing vacuited-shell ==="
[ -f "$SCRIPT_DIR/shell.qml" ] && [ -f "$SCRIPT_DIR/CMakeLists.txt" ] || die "Run this script from inside the shell repository."

# ---------------------------------------------------------------------------
# Dependencies & Arch conflict resolution
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
    run_priv pacman -S --needed "${YES_FLAG[@]}" git base-devel
    if [ "$DRY_RUN" -eq 1 ]; then
        run git clone --depth 1 https://aur.archlinux.org/yay-bin.git "<tmp>/yay-bin"
        info "[dry-run] would build and install yay-bin via makepkg -si"
    else
        local tmp
        tmp="$(mktemp -d)"
        CLEANUP_PATHS+=("$tmp")
        git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
        (cd "$tmp/yay-bin" && makepkg -si "${YES_FLAG[@]}")
    fi
    AUR_HELPER=yay
}

font_missing_pkgs() {
    # Prints package/font names for fonts that fontconfig cannot find.
    # Treats missing fc-list as all fonts missing so minimal installs still pull them.
    local entry fam pac aur families="" have_fclist=0
    if command -v fc-list >/dev/null 2>&1; then
        have_fclist=1
        families="$(fc-list -f '%{family}\n' 2>/dev/null | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)"
    fi
    for entry in "${FONTS[@]}"; do
        IFS='|' read -r fam pac aur <<<"$entry"
        if [ "$have_fclist" -eq 0 ] || ! grep -qiFx "$fam" <<<"$families"; then
            if [ "$IS_ARCH" -eq 1 ]; then
                [ -n "$pac" ] && echo "pac:$pac"
                [ -n "$aur" ] && echo "aur:$aur"
            else
                echo "font:$fam"
            fi
        fi
    done
}

resolve_arch_conflicts() {
    [ "$IS_ARCH" -eq 1 ] || return 0
    local pkg
    for pkg in caelestia-shell caelestia-shell-git; do
        if pacman -Qq "$pkg" >/dev/null 2>&1; then
            warn "System package '$pkg' is installed and conflicts with vacuited-shell."
            if confirm "Remove conflicting package '$pkg' now?" y; then
                run_priv pacman -Rdd "${YES_FLAG[@]}" "$pkg"
            fi
        fi
    done

    if [ "$SKIP_DEPS" -eq 0 ]; then
        if pacman -Qq quickshell >/dev/null 2>&1 && ! pacman -Qq quickshell-git >/dev/null 2>&1; then
            warn "Package 'quickshell' conflicts with required AUR package 'quickshell-git'."
            if confirm "Remove 'quickshell' before installing 'quickshell-git'?" y; then
                run_priv pacman -Rdd "${YES_FLAG[@]}" quickshell
            fi
        fi
        if pacman -Qq qt6-m3shapes >/dev/null 2>&1 && ! pacman -Qq qt6-m3shapes-git >/dev/null 2>&1; then
            warn "Package 'qt6-m3shapes' conflicts with required AUR package 'qt6-m3shapes-git'."
            if confirm "Remove 'qt6-m3shapes' before installing 'qt6-m3shapes-git'?" y; then
                run_priv pacman -Rdd "${YES_FLAG[@]}" qt6-m3shapes
            fi
        fi
    fi
}

install_deps_arch() {
    local pac_need=() aur_need=() item opt_pac=() opt_aur=() had_fclist=0
    command -v fc-list >/dev/null 2>&1 && had_fclist=1

    mapfile -t pac_need < <(pac_missing "${PAC_REQUIRED[@]}")
    mapfile -t aur_need < <(pac_missing "${AUR_REQUIRED[@]}")

    # Drop empty entries from mapfile on empty output
    local clean=() p
    for p in "${pac_need[@]}"; do [ -n "$p" ] && clean+=("$p"); done
    pac_need=("${clean[@]+"${clean[@]}"}")
    clean=()
    for p in "${aur_need[@]}"; do [ -n "$p" ] && clean+=("$p"); done
    aur_need=("${clean[@]+"${clean[@]}"}")

    if [ ${#pac_need[@]} -gt 0 ]; then
        info "Missing (official repos): ${pac_need[*]}"
        if confirm "Install missing official repo packages now?" y; then
            run_priv pacman -S --needed "${YES_FLAG[@]}" "${pac_need[@]}"
        else
            die "Cannot continue without required dependencies."
        fi
    fi

    if [ "$had_fclist" -eq 0 ] && [ "$DRY_RUN" -eq 0 ] && command -v fc-list >/dev/null 2>&1; then
        fc-cache -f >/dev/null 2>&1 || true
    fi

    # Check fonts AFTER fontconfig is available (or treat all as missing under dry-run if fc-list absent)
    local font_pac=()
    while IFS= read -r item; do
        case "$item" in
            pac:*) font_pac+=("${item#pac:}") ;;
            aur:*) aur_need+=("${item#aur:}") ;;
        esac
    done < <(font_missing_pkgs)

    if [ ${#font_pac[@]} -gt 0 ]; then
        info "Missing font packages (official repos): ${font_pac[*]}"
        if confirm "Install missing official font packages?" y; then
            run_priv pacman -S --needed "${YES_FLAG[@]}" "${font_pac[@]}"
        fi
    fi

    clean=()
    for p in "${aur_need[@]}"; do [ -n "$p" ] && clean+=("$p"); done
    aur_need=("${clean[@]+"${clean[@]}"}")

    if [ ${#aur_need[@]} -gt 0 ]; then
        info "Missing (AUR): ${aur_need[*]}"
        confirm "Install missing AUR packages now?" y || die "Cannot continue without required AUR dependencies."
        detect_aur_helper || bootstrap_aur_helper
        run "$AUR_HELPER" -S --needed "${YES_FLAG[@]}" "${aur_need[@]}"
    elif [ ${#pac_need[@]} -eq 0 ] && [ ${#font_pac[@]} -eq 0 ]; then
        log "All required dependencies are installed."
    fi

    if ! pacman -Qq quickshell-git >/dev/null 2>&1 && [ "$DRY_RUN" -eq 0 ]; then
        warn "quickshell-git is not installed. This shell targets the git version of Quickshell; the stable package may lack features."
    fi

    # Optional extras
    mapfile -t opt_pac < <(pac_missing "${PAC_OPTIONAL[@]}")
    mapfile -t opt_aur < <(pac_missing "${AUR_OPTIONAL[@]}")
    clean=(); for p in "${opt_pac[@]}"; do [ -n "$p" ] && clean+=("$p"); done; opt_pac=("${clean[@]+"${clean[@]}"}")
    clean=(); for p in "${opt_aur[@]}"; do [ -n "$p" ] && clean+=("$p"); done; opt_aur=("${clean[@]+"${clean[@]}"}")

    if [ $(( ${#opt_pac[@]} + ${#opt_aur[@]} )) -gt 0 ]; then
        info "Optional extras not installed: ${opt_pac[*]-} ${opt_aur[*]-}"
        info "  hyprsunset/hyprshutdown: night light & logout UI | gpu-screen-recorder/mpv: capture & playback"
        info "  avahi/bluez/playerctl/imagemagick/lua/papirus-*: network, bluetooth, media & folder tinting"
        local do_opt=0
        if [ "$WITH_OPTIONAL" -eq 1 ]; then
            do_opt=1
        elif [ "$ASSUME_YES" -eq 0 ] && confirm "Install optional extras too?" n; then
            do_opt=1
        fi
        if [ "$do_opt" -eq 1 ]; then
            if [ ${#opt_pac[@]} -gt 0 ]; then
                run_priv pacman -S --needed "${YES_FLAG[@]}" "${opt_pac[@]}"
            fi
            if [ ${#opt_aur[@]} -gt 0 ]; then
                detect_aur_helper || bootstrap_aur_helper
                run "$AUR_HELPER" -S --needed "${YES_FLAG[@]}" "${opt_aur[@]}"
            fi
        fi
    fi

    # Optional Wallpaper Engine backend (skwd-paper-v2 + Steam Workshop)
    if ! (command -v skwd-paper-v2 >/dev/null 2>&1 && command -v skwd-helm >/dev/null 2>&1 && command -v skwd-steam >/dev/null 2>&1); then
        local we_aur=()
        mapfile -t we_aur < <(pac_missing "${AUR_WE[@]}")
        clean=(); for p in "${we_aur[@]}"; do [ -n "$p" ] && clean+=("$p"); done; we_aur=("${clean[@]+"${clean[@]}"}")
        if [ ${#we_aur[@]} -gt 0 ]; then
            info "Optional Wallpaper Engine backend not installed: ${we_aur[*]}"
            local do_we=0
            if [ "$WITH_WE" -eq 1 ]; then
                do_we=1
            elif [ "$ASSUME_YES" -eq 0 ] && confirm "Install Wallpaper Engine support (skwd-paper-bin + Steam Workshop)?" n; then
                do_we=1
            fi
            if [ "$do_we" -eq 1 ]; then
                detect_aur_helper || bootstrap_aur_helper
                run "$AUR_HELPER" -S --needed "${YES_FLAG[@]}" "${we_aur[@]}"
            fi
        fi
    fi
}

find_m3shapes_qmldir() {
    local dirs=() d
    dirs+=("$QT_QML_DIR")
    if [ -n "${QML_IMPORT_PATH:-}" ]; then
        IFS=':' read -ra extra <<<"$QML_IMPORT_PATH"
        dirs+=("${extra[@]}")
    fi
    if [ -n "${QML2_IMPORT_PATH:-}" ]; then
        IFS=':' read -ra extra <<<"$QML2_IMPORT_PATH"
        dirs+=("${extra[@]}")
    fi
    dirs+=(/usr/lib/qt6/qml /usr/lib64/qt6/qml)
    for d in "${dirs[@]}"; do
        [ -f "$d/M3Shapes/qmldir" ] && return 0
    done
    return 1
}

# Distro-agnostic verification of what the build and shell actually need
verify_prereqs() {
    local missing=() c m
    for c in cmake ninja c++ git pkg-config fish hyprctl protoc python3; do
        command -v "$c" >/dev/null 2>&1 || missing+=("command: $c")
    done
    command -v qs >/dev/null 2>&1 || command -v quickshell >/dev/null 2>&1 || missing+=("command: qs (quickshell)")
    for m in Qt6Core Qt6Gui Qt6Qml Qt6Quick Qt6QuickControls2 Qt6ShaderTools Qt6Multimedia Qt6Sql Qt6Network Qt6DBus Qt6Concurrent \
             protobuf openssl libqalculate libpipewire-0.3 aubio; do
        pkg-config --exists "$m" 2>/dev/null || missing+=("pkg-config: $m")
    done
    pkg-config --exists libcava 2>/dev/null || pkg-config --exists cava 2>/dev/null || missing+=("pkg-config: libcava (or cava)")

    if command -v c++ >/dev/null 2>&1; then
        if ! printf '#include <sensors/sensors.h>\n' | c++ -E -x c++ - >/dev/null 2>&1; then
            missing+=("header: sensors/sensors.h (lm_sensors)")
        fi
    elif [ ! -e /usr/include/sensors/sensors.h ] && [ ! -e /usr/local/include/sensors/sensors.h ]; then
        missing+=("header: sensors/sensors.h (lm_sensors)")
    fi

    find_m3shapes_qmldir || missing+=("qml module: M3Shapes/qmldir (qt6-m3shapes-git)")

    if [ ${#missing[@]} -gt 0 ]; then
        err "Missing prerequisites:"
        printf '    - %s\n' "${missing[@]}" >&2
        [ "$IS_ARCH" -eq 1 ] || err "Install the equivalents for your distro (see README), then re-run."
        return 1
    fi

    local qtver
    qtver="$(pkg-config --modversion Qt6Core 2>/dev/null || echo 0)"
    if [ "$(printf '%s\n6.9\n' "$qtver" | sort -V | head -n1)" != "6.9" ]; then
        die "Qt $qtver found, but Qt >= 6.9 is required."
    fi

    find_qsb >/dev/null 2>&1 || warn "Qt 'qsb' tool not found; stale standalone .frag shaders cannot be recompiled."

    if [ "$IS_ARCH" -eq 0 ] || [ "$SKIP_DEPS" -eq 1 ]; then
        local rt_missing=() rt
        for rt in ffmpeg curl jq notify-send upower lspci xdg-open fc-list brightnessctl ddcutil nmcli powerprofilesctl wl-copy cliphist swappy grim slurp unzip; do
            command -v "$rt" >/dev/null 2>&1 || rt_missing+=("$rt")
        done
        if [ ${#rt_missing[@]} -gt 0 ]; then
            warn "Missing runtime tools (some shell widgets/actions may degrade): ${rt_missing[*]}"
        fi
        local font_missing=() item
        while IFS= read -r item; do
            case "$item" in
                font:*) font_missing+=("${item#font:}") ;;
                pac:*|aur:*) font_missing+=("${item#*:}") ;;
            esac
        done < <(font_missing_pkgs)
        if [ ${#font_missing[@]} -gt 0 ]; then
            warn "Missing recommended fonts: ${font_missing[*]}"
        fi
    fi

    log "Prerequisites OK (Qt $qtver, QML dir: $QT_QML_DIR)."
}

if [ "$QML_ONLY" -eq 0 ]; then
    resolve_arch_conflicts

    if [ "$SKIP_DEPS" -eq 1 ]; then
        warn "Skipping dependency installation (--skip-deps)."
    else
        log "Checking dependencies..."
        if [ "$IS_ARCH" -eq 1 ]; then
            install_deps_arch
            QT_QML_DIR="$(detect_qt_qml_dir)"
        else
            warn "Not an Arch-based system: cannot auto-install packages. Verifying instead."
        fi
    fi

    if [ "$DRY_RUN" -eq 1 ] && [ "$IS_ARCH" -eq 1 ] && [ "$SKIP_DEPS" -eq 0 ]; then
        verify_prereqs || warn "(dry-run) Prerequisites above would be installed by the steps shown."
    else
        verify_prereqs || die "Fix the missing prerequisites and re-run."
    fi
else
    info "QML-only mode (--qml-only): skipping dependencies, CLI, C++ plugin, and hardware helper."
fi

# ---------------------------------------------------------------------------
# CLI dependency
# ---------------------------------------------------------------------------

install_cli() {
    local cli_dir="" args=()
    [ "$ASSUME_YES" -eq 1 ] && args+=(--yes)
    [ "$SKIP_DEPS" -eq 1 ] && args+=(--skip-deps)
    [ "$WITH_OPTIONAL" -eq 1 ] && args+=(--with-optional)
    [ "$DRY_RUN" -eq 1 ] && args+=(--dry-run)

    if [ -f "$SCRIPT_DIR/../cli/install.sh" ]; then
        cli_dir="$(cd -P "$SCRIPT_DIR/../cli" && pwd -P)"
    else
        info "Fetching the vacuited CLI into $CLI_CLONE_DIR..."
        if [ -d "$CLI_CLONE_DIR/.git" ]; then
            run git -C "$CLI_CLONE_DIR" pull --ff-only || warn "Could not update cached CLI clone; using existing checkout."
        else
            run mkdir -p "$(dirname "$CLI_CLONE_DIR")"
            run git clone "$CLI_REPO_URL" "$CLI_CLONE_DIR"
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
if [ "$QML_ONLY" -eq 0 ]; then
    if [ "$SKIP_CLI" -eq 1 ]; then
        if ! command -v caelestia >/dev/null 2>&1; then
            warn "caelestia CLI missing and --skip-cli given. The shell needs it for schemes, wallpapers and toggles."
        fi
    elif [ "$UPDATE_CLI" -eq 1 ]; then
        info "Updating vacuited CLI (--update-cli)..."
        install_cli
    elif command -v caelestia >/dev/null 2>&1; then
        if caelestia hardware -h >/dev/null 2>&1; then
            log "vacuited CLI found: $(command -v caelestia)"
        elif caelestia -h >/dev/null 2>&1; then
            warn "Found upstream 'caelestia' ($(command -v caelestia)), not vacuited-cli."
            if confirm "Install vacuited-cli to ~/.local/bin/caelestia now?" y; then
                install_cli
            fi
        else
            warn "Found broken 'caelestia' ($(command -v caelestia)) that failed '-h'."
            if confirm "Reinstall vacuited-cli to ~/.local/bin/caelestia now?" y; then
                install_cli
            fi
        fi
    else
        warn "caelestia CLI not found. The shell depends on it."
        if confirm "Install the vacuited CLI now?" y; then
            install_cli
        else
            warn "Skipped. Install it later from https://github.com/vacuited/cli"
        fi
    fi

    if [ -x "$HOME/.local/bin/caelestia" ] || [ "$DRY_RUN" -eq 1 ]; then
        _env_dir="$CONFIG_HOME/environment.d"
        _env_file="$_env_dir/10-vacuited-path.conf"
        if [ ! -f "$_env_file" ]; then
            if [ "$DRY_RUN" -eq 1 ]; then
                info "[dry-run] would write $_env_file (PATH=$HOME/.local/bin:\$PATH)"
            else
                mkdir -p "$_env_dir"
                printf '# Managed by vacuited-cli install.sh\nPATH=%s:$PATH\n' "$HOME/.local/bin" > "$_env_file"
                info "Configured systemd user environment PATH in $_env_file"
            fi
        fi

        _shim_path="/usr/local/bin/caelestia"
        _shim_needed=0
        if [ ! -e "$_shim_path" ] && [ ! -L "$_shim_path" ]; then
            _shim_needed=1
        elif [ -f "$_shim_path" ] && grep -qF '# vacuited-cli-shim' "$_shim_path" 2>/dev/null; then
            _shim_needed=1
        fi
        if [ "$_shim_needed" -eq 1 ] && [ -n "$SUDO" ]; then
            _tmp_shim="$(mktemp)"
            CLEANUP_PATHS+=("$_tmp_shim")
            cat <<'EOF' > "$_tmp_shim"
#!/bin/sh
# vacuited-cli-shim — dispatches to the invoking user's vacuited-cli install
case ":${PATH:-}:" in
    *:"${HOME}/.local/bin":*) ;;
    *) export PATH="${HOME}/.local/bin${PATH:+:${PATH}}" ;;
esac
if [ -x "${HOME}/.local/bin/caelestia" ]; then
    exec "${HOME}/.local/bin/caelestia" "$@"
fi
printf '%s\n' "caelestia: not installed for ${USER:-user} (${HOME}/.local/bin/caelestia missing)" >&2
exit 127
EOF
            if [ ! -f "$_shim_path" ] || ! cmp -s "$_tmp_shim" "$_shim_path" 2>/dev/null; then
                if [ "$DRY_RUN" -eq 1 ]; then
                    if confirm "Install /usr/local/bin/caelestia shim so display managers and Hyprland always find 'caelestia' on boot?" y; then
                        run_priv install -Dm755 "<tmp>/caelestia" "$_shim_path"
                    fi
                elif (: </dev/tty) 2>/dev/null || "$SUDO" -n true 2>/dev/null; then
                    if confirm "Install /usr/local/bin/caelestia shim so display managers and Hyprland always find 'caelestia' on boot?" y; then
                        run_priv install -Dm755 "$_tmp_shim" "$_shim_path"
                        log "Installed system-wide login shim at $_shim_path"
                    fi
                fi
            fi
        fi
    fi
fi

# ---------------------------------------------------------------------------
# Build + install the C++ plugin
# ---------------------------------------------------------------------------

VERSION="1.0.0"
GIT_REV="unknown"

detect_git_meta() {
    local git_top=""
    git_top="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$git_top" ]; then
        git_top="$(readlink -f "$git_top" 2>/dev/null || printf '%s' "$git_top")"
    fi
    if [ "$git_top" = "$SCRIPT_DIR" ]; then
        local v
        v="$(git -C "$SCRIPT_DIR" describe --tags --abbrev=0 2>/dev/null || true)"
        v="${v#v}"
        if [[ "$v" =~ ^[0-9]+(\.[0-9]+){1,3}$ ]]; then
            VERSION="$v"
        fi
        GIT_REV="$(git -C "$SCRIPT_DIR" rev-parse HEAD 2>/dev/null || echo unknown)"
    fi
}

if [ "$QML_ONLY" -eq 0 ]; then
    detect_git_meta

    # Obsolete per-module libraries from older layouts
    LEGACY_LIBS=(
        "$QT_QML_DIR/Caelestia/Components/libcaelestia-components.so"
        "$QT_QML_DIR/Caelestia/Config/libcaelestia-config.so"
        "$QT_QML_DIR/Caelestia/Internal/libcaelestia-internal.so"
        "$QT_QML_DIR/Caelestia/Models/libcaelestia-models.so"
        "$QT_QML_DIR/Caelestia/Services/libcaelestia-services.so"
        "$QT_QML_DIR/Caelestia/Blobs/libcaelestia-blobs.so"
        "$QT_QML_DIR/Caelestia/Images/libcaelestia-images.so"
        "$QT_QML_DIR/Caelestia/libcaelestia.so"
    )

    log "Building the plugin (version $VERSION, revision ${GIT_REV:0:9})..."
    if [ "$CLEAN_BUILD" -eq 1 ] && [ -d "$BUILD_DIR" ]; then
        info "Cleaning build directory (--clean)..."
        run rm -rf "$BUILD_DIR"
    elif [ -f "$BUILD_DIR/CMakeCache.txt" ] && ! grep -qx "CMAKE_HOME_DIRECTORY:INTERNAL=$SCRIPT_DIR" "$BUILD_DIR/CMakeCache.txt"; then
        run rm -rf "$BUILD_DIR"
    fi
    run mkdir -p "$BUILD_DIR"
    run cmake -S "$SCRIPT_DIR" -B "$BUILD_DIR" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DINSTALL_LIBDIR=/usr/lib/caelestia \
        -DINSTALL_QMLDIR="$QT_QML_DIR" \
        "-DENABLE_MODULES=extras;plugin" \
        -DVERSION="$VERSION" \
        -DGIT_REVISION="$GIT_REV" \
        -DDISTRIBUTOR=vacuited
    run cmake --build "$BUILD_DIR" -j "$(nproc)"

    log "Installing the plugin to $QT_QML_DIR (privileged)..."
    for lib in "${LEGACY_LIBS[@]}"; do
        if [ -e "$lib" ]; then run_priv rm -f "$lib"; fi
    done
    run_priv cmake --install "$BUILD_DIR"
fi

# ---------------------------------------------------------------------------
# Compile standalone asset shaders if stale/missing
# ---------------------------------------------------------------------------

compile_standalone_shaders() {
    local frag base qsb_out qsb_bin=""
    qsb_bin="$(find_qsb 2>/dev/null || true)"
    shopt -s nullglob
    for frag in "$SCRIPT_DIR/assets/shaders/frag/"*.frag; do
        base="$(basename "$frag")"
        qsb_out="$SCRIPT_DIR/assets/shaders/${base}.qsb"
        if [ ! -f "$qsb_out" ] || [ "$frag" -nt "$qsb_out" ]; then
            if [ -n "$qsb_bin" ]; then
                info "Recompiling shader ${base}.qsb..."
                run "$qsb_bin" --qt6 -o "$qsb_out" "$frag"
            elif [ ! -f "$qsb_out" ]; then
                warn "Missing ${base}.qsb and 'qsb' tool was not found."
            else
                warn "${base} is newer than ${base}.qsb, but 'qsb' tool was not found."
            fi
        fi
    done
    shopt -u nullglob
}

compile_standalone_shaders

# ---------------------------------------------------------------------------
# Deploy QML shell
# ---------------------------------------------------------------------------

prune_backups() {
    local old_bak
    shopt -s nullglob
    local backups=("${QS_DEST}".bak.*)
    shopt -u nullglob
    [ ${#backups[@]} -gt 2 ] || return 0
    while IFS= read -r old_bak; do
        [ -n "$old_bak" ] && [ -e "$old_bak" ] || continue
        info "Pruning old backup: $(basename "$old_bak")"
        run rm -rf "$old_bak"
    done < <(printf '%s\n' "${backups[@]}" | sort -r | tail -n +3)
}

deploy_qml_shell() {
    local dest_real="" skip_copy=0

    if [ -e "$QS_DEST" ] || [ -L "$QS_DEST" ]; then
        dest_real="$(readlink -f "$QS_DEST" 2>/dev/null || true)"
        if [ -n "$dest_real" ] && [ "$dest_real" = "$SCRIPT_DIR" ]; then
            info "$QS_DEST already resolves to $SCRIPT_DIR; skipping copy."
            skip_copy=1
        elif [ -L "$QS_DEST" ]; then
            warn "$QS_DEST is a symlink to ${dest_real:-unknown}; removing symlink (target untouched) before deploying."
            run rm -f "$QS_DEST"
        elif [ -d "$QS_DEST" ]; then
            local changed=0 item
            for item in "${QML_DIRS[@]}" "${QML_FILES[@]}"; do
                if [ -e "$QS_DEST/$item" ] && ! diff -rq -x '__pycache__' -x '*.pyc' -x '*.orig' -x '*.bak' "$SCRIPT_DIR/$item" "$QS_DEST/$item" >/dev/null 2>&1; then
                    changed=1
                    break
                fi
            done
            if [ "$changed" -eq 1 ]; then
                if [ "$NO_BACKUP" -eq 1 ]; then
                    info "Existing config differs; skipping backup (--no-backup)."
                else
                    local backup="${QS_DEST}.bak.$(date +%Y%m%d-%H%M%S)"
                    warn "Existing config differs from this repo. Backing up to $backup"
                    run cp -a "$QS_DEST" "$backup"
                    prune_backups
                fi
            fi
        fi
    fi

    if [ "$skip_copy" -eq 0 ]; then
        log "Deploying the QML shell to $QS_DEST..."
        run mkdir -p "$QS_DEST"
        local has_rsync=0
        command -v rsync >/dev/null 2>&1 && has_rsync=1
        for item in "${QML_DIRS[@]}"; do
            if [ "$has_rsync" -eq 1 ]; then
                run mkdir -p "$QS_DEST/$item"
                run rsync -a --delete \
                    --exclude='__pycache__' \
                    --exclude='*.pyc' \
                    --exclude='*.orig' \
                    --exclude='*.bak' \
                    "$SCRIPT_DIR/$item/" "$QS_DEST/$item/"
            else
                run rm -rf "$QS_DEST/$item"
                run mkdir -p "$QS_DEST/$item"
                run cp -a "$SCRIPT_DIR/$item/." "$QS_DEST/$item/"
                if [ "$DRY_RUN" -eq 0 ]; then
                    find "$QS_DEST/$item" \( -name '__pycache__' -o -name '*.pyc' -o -name '*.orig' -o -name '*.bak' \) -exec rm -rf {} + 2>/dev/null || true
                fi
            fi
        done
        for item in "${QML_FILES[@]}"; do
            run cp -a "$SCRIPT_DIR/$item" "$QS_DEST/$item"
        done
    fi

    # Enforce executable permissions on runtime helper scripts
    local deploy_target="$QS_DEST"
    [ "$DRY_RUN" -eq 1 ] && [ ! -d "$QS_DEST/assets" ] && deploy_target="$SCRIPT_DIR"
    if [ -f "$deploy_target/assets/wrap_term_launch.sh" ]; then
        run chmod +x "$QS_DEST/assets/wrap_term_launch.sh"
    fi
    shopt -s nullglob
    local py
    for py in "$deploy_target/assets/scripts/"*.py; do
        run chmod +x "$QS_DEST/assets/scripts/$(basename "$py")"
    done
    shopt -u nullglob
}

deploy_qml_shell

# ---------------------------------------------------------------------------
# HP Victus hardware helper (optional)
# ---------------------------------------------------------------------------

HARDWARE_STATUS="skipped"
if [ "$QML_ONLY" -eq 0 ]; then
    if [ "$HARDWARE" = auto ]; then
        if compgen -G "/sys/devices/platform/hp-wmi/hwmon/hwmon*/pwm1_enable" >/dev/null; then
            HARDWARE=yes
        else
            HARDWARE=no
        fi
    fi
    if [ "$HARDWARE" = yes ]; then
        log "Installing the HP hardware helper and polkit rule (privileged)..."
        run_priv install -Dm755 "$SCRIPT_DIR/scripts/caelestia-hardware-helper" /usr/local/bin/caelestia-hardware-helper
        run_priv install -Dm644 "$SCRIPT_DIR/scripts/50-caelestia-hardware.rules" /etc/polkit-1/rules.d/50-caelestia-hardware.rules
        if ! id -nG | tr ' ' '\n' | grep -qx 'wheel'; then
            warn "User '$USER' is not in the 'wheel' group. Polkit rule 50-caelestia-hardware.rules requires 'wheel' membership."
        fi
        local_hw_missing=()
        command -v wlr-randr >/dev/null 2>&1 || local_hw_missing+=(wlr-randr)
        command -v jq >/dev/null 2>&1 || local_hw_missing+=(jq)
        if [ ${#local_hw_missing[@]} -gt 0 ]; then
            if [ "$IS_ARCH" -eq 1 ] && [ "$SKIP_DEPS" -eq 0 ]; then
                run_priv pacman -S --needed "${YES_FLAG[@]}" "${local_hw_missing[@]}"
            else
                warn "Hardware controls need: ${local_hw_missing[*]}"
            fi
        fi
        HARDWARE_STATUS="installed"
    else
        info "Skipping the hardware helper (no HP Victus hp-wmi fan controller detected; use --hardware to force)."
        if [ -x /usr/local/bin/caelestia-hardware-helper ]; then
            HARDWARE_STATUS="kept existing"
        fi
    fi
fi

# ---------------------------------------------------------------------------
# Initial Scheme
# ---------------------------------------------------------------------------

if [ ! -f "$STATE_HOME/caelestia/scheme.json" ] && command -v caelestia >/dev/null 2>&1; then
    info "Initializing default Caelestia color scheme..."
    if [ "$DRY_RUN" -eq 1 ]; then
        run caelestia scheme set -n catppuccin -m dark
    else
        caelestia scheme set -n catppuccin -m dark >/dev/null 2>&1 || true
    fi
fi

# ---------------------------------------------------------------------------
# Verify + Health Hints + Summary
# ---------------------------------------------------------------------------

if [ "$DRY_RUN" -eq 0 ]; then
    if [ "$QML_ONLY" -eq 0 ]; then
        local_sub=""
        for local_sub in "" Config Services Multimedia Shaders; do
            qmldir="$QT_QML_DIR/Caelestia/${local_sub:+$local_sub/}qmldir"
            [ -f "$qmldir" ] || die "Plugin install check failed: $qmldir missing."
        done
    fi
    [ -f "$QS_DEST/shell.qml" ] || die "Deploy check failed: $QS_DEST/shell.qml missing."
    log "Install verified."

    if [ "$GIT_REV" = "unknown" ]; then
        detect_git_meta
    fi
    if [ "$GIT_REV" != "unknown" ] && command -v python3 >/dev/null 2>&1; then
        _rec_args=(--component shell --repo-dir "$SCRIPT_DIR" --version "$VERSION")
        [ "$QML_ONLY" -eq 0 ] && _rec_args+=(--plugin-rebuilt)
        python3 "$SCRIPT_DIR/assets/scripts/vacuited_updater.py" record-install "${_rec_args[@]}" >/dev/null 2>&1 || true
    fi
fi

if command -v systemctl >/dev/null 2>&1; then
    for svc in power-profiles-daemon.service NetworkManager.service; do
        if systemctl list-unit-files "$svc" >/dev/null 2>&1 && ! systemctl is-active --quiet "$svc" 2>/dev/null; then
            warn "System service '$svc' is not active (enable with: sudo systemctl enable --now $svc)."
        fi
    done
fi

if [ -d "$CONFIG_HOME/hypr" ]; then
    if ! grep -rqsE 'caelestia[[:space:]]+shell|qs[[:space:]]+-c[[:space:]]+caelestia' --exclude-dir=.git "$CONFIG_HOME/hypr" 2>/dev/null; then
        warn "No 'caelestia shell -d' autostart found in $CONFIG_HOME/hypr. Add 'exec-once = caelestia shell -d' to your Hyprland config so the shell starts on login."
    fi
fi

if ! command -v skwd-paper-v2 >/dev/null 2>&1; then
    info "Wallpaper Engine (optional): run ./install.sh --with-wallpaper-engine (or install from https://github.com/liixini/skwd-wall)"
fi

cat <<EOF

=== Done ===
  Mode:            $([ "$QML_ONLY" -eq 1 ] && echo "QML-only" || echo "Full (${VERSION}, ${GIT_REV:0:9})")
  QML Target:      $QS_DEST
  Plugin QML Dir:  $([ "$QML_ONLY" -eq 1 ] && echo "skipped" || echo "$QT_QML_DIR/Caelestia")
  Wallpaper Eng.:  $(command -v skwd-paper-v2 >/dev/null 2>&1 && echo "installed" || echo "not installed (optional)")
  Hardware Helper: $HARDWARE_STATUS

Start the shell (fish or bash):
    caelestia shell -d

If it was already running, reload it:
    caelestia shell -d -r

Add autostart + keybinds in your Hyprland config, e.g.:
    exec-once = caelestia shell -d
    bind = SUPER, SPACE, global, caelestia:launcher
(see the README for the full shortcut list)
EOF

case ":$ORIG_PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *)
        if ! ([ -f /usr/local/bin/caelestia ] && grep -qF '# vacuited-cli-shim' /usr/local/bin/caelestia 2>/dev/null); then
            warn "Add ~/.local/bin to your PATH so the 'caelestia' command is found."
        fi
        ;;
esac

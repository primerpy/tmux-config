#!/usr/bin/env bash
#
# Installs the tmux configuration from github.com/primerpy/tmux-config.
# Supports macOS (Homebrew) and Debian/Ubuntu, Fedora, Arch based Linux.
#
# Works two ways:
#   1. From a clone of the repo:   ./install.sh
#   2. Standalone (no clone):      curl -fsSL https://raw.githubusercontent.com/primerpy/tmux-config/main/install.sh | bash
#
# Idempotent: safe to re-run. Existing configs are backed up, never deleted.
# Pass -y / --yes to skip confirmation prompts.

set -euo pipefail

RAW_URL="https://raw.githubusercontent.com/primerpy/tmux-config/main"
TMUX_DIR="$HOME/.config/tmux"
CONF="$TMUX_DIR/tmux.conf"
PLUGIN_DIR="$TMUX_DIR/plugins"
THEME_DIR="$TMUX_DIR/tmux-onedark-theme"
STAMP="$(date +%Y%m%d-%H%M%S)"
ASSUME_YES=0

for arg in "$@"; do
  case "$arg" in
    -y|--yes) ASSUME_YES=1 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//' | head -10
      exit 0
      ;;
    *) echo "Unknown option: $arg (try --help)" >&2; exit 1 ;;
  esac
done

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33mwarning:\033[0m %s\n' "$*"; }
die()   { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

confirm() {
  [ "$ASSUME_YES" -eq 1 ] && return 0
  # No TTY (e.g. curl | bash): default to yes so the one-liner works.
  [ -t 0 ] || return 0
  printf '%s [Y/n] ' "$1"
  read -r reply
  case "$reply" in n|N|no|NO) return 1 ;; *) return 0 ;; esac
}

SUDO=""
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
fi

pkg_install() {
  # Installs package $1 with whichever supported package manager is present.
  local pkg="$1"
  if command -v brew >/dev/null 2>&1; then
    confirm "Install $pkg with Homebrew?" && brew install "$pkg"
  elif command -v apt-get >/dev/null 2>&1; then
    confirm "Install $pkg with apt?" && $SUDO apt-get update -qq && $SUDO apt-get install -y "$pkg"
  elif command -v dnf >/dev/null 2>&1; then
    confirm "Install $pkg with dnf?" && $SUDO dnf install -y "$pkg"
  elif command -v pacman >/dev/null 2>&1; then
    confirm "Install $pkg with pacman?" && $SUDO pacman -Sy --noconfirm --needed "$pkg"
  else
    warn "No supported package manager found (brew/apt/dnf/pacman)."
    return 1
  fi
}

fetch() {
  # fetch <url> <dest> using curl or wget, whichever exists.
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$2" "$1"
  else
    return 1
  fi
}

# --- Dependencies -----------------------------------------------------------

# git is preferred, but locked-down servers (no sudo, no git) still work:
# plugins are then downloaded as GitHub tarballs with curl/wget.
HAVE_GIT=1
if ! command -v git >/dev/null 2>&1; then
  info "git is not installed"
  pkg_install git || true
  if ! command -v git >/dev/null 2>&1; then
    HAVE_GIT=0
    if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
      warn "Proceeding without git: plugins will be downloaded as tarballs ('prefix I' plugin updates won't work)."
    else
      die "Need git, or curl/wget, to fetch plugins (macOS: xcode-select --install, Debian: apt install git, Fedora: dnf install git, Arch: pacman -S git)."
    fi
  fi
fi

if ! command -v tmux >/dev/null 2>&1; then
  info "tmux is not installed"
  pkg_install tmux || true
  command -v tmux >/dev/null 2>&1 || die "tmux is still missing; install it manually and re-run."
fi
info "Using $(tmux -V)"

# tmux-yank needs a clipboard helper on Linux (macOS ships pbcopy). Only
# relevant on machines with a display; over SSH/headless, OSC 52
# (set-clipboard on) handles copying through the terminal instead.
if [ "$(uname -s)" = "Linux" ] && { [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; }; then
  if ! command -v xsel >/dev/null 2>&1 && ! command -v xclip >/dev/null 2>&1 \
     && ! command -v wl-copy >/dev/null 2>&1; then
    if [ -n "${WAYLAND_DISPLAY:-}" ]; then clip_pkg="wl-clipboard"; else clip_pkg="xsel"; fi
    warn "No clipboard tool found; tmux-yank needs one on Linux desktops"
    pkg_install "$clip_pkg" || warn "Install $clip_pkg manually for clipboard copy to work."
  fi
fi

# --- Back up anything that would conflict ------------------------------------

# ~/.tmux.conf takes precedence over ~/.config/tmux/tmux.conf, so move it aside.
if [ -f "$HOME/.tmux.conf" ] || [ -L "$HOME/.tmux.conf" ]; then
  warn "~/.tmux.conf exists and would shadow this config"
  confirm "Move it to ~/.tmux.conf.backup-$STAMP?" || die "Aborted: remove ~/.tmux.conf and re-run."
  mv "$HOME/.tmux.conf" "$HOME/.tmux.conf.backup-$STAMP"
  info "Moved ~/.tmux.conf -> ~/.tmux.conf.backup-$STAMP"
fi

if [ -f "$CONF" ]; then
  cp "$CONF" "$CONF.backup-$STAMP"
  info "Backed up existing tmux.conf -> $CONF.backup-$STAMP"
fi

# --- Install the config -------------------------------------------------------

mkdir -p "$TMUX_DIR"

# If run from a clone of the repo, use the local tmux.conf; otherwise download it.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd || true)"
if [ -n "$script_dir" ] && [ -f "$script_dir/tmux.conf" ]; then
  cp "$script_dir/tmux.conf" "$CONF"
  info "Installed tmux.conf from local repo"
else
  fetch "$RAW_URL/tmux.conf" "$CONF" || die "Could not download tmux.conf (need curl or wget)."
  info "Installed tmux.conf from GitHub"
fi

# Keep a local copy of the uninstaller so removal never needs the repo,
# even when installed via curl | bash.
if [ -n "$script_dir" ] && [ -f "$script_dir/uninstall.sh" ]; then
  cp "$script_dir/uninstall.sh" "$TMUX_DIR/uninstall.sh"
else
  fetch "$RAW_URL/uninstall.sh" "$TMUX_DIR/uninstall.sh" \
    || warn "Could not download uninstall.sh; get it from the repo if you ever need it."
fi
if [ -f "$TMUX_DIR/uninstall.sh" ]; then
  chmod +x "$TMUX_DIR/uninstall.sh"
  info "Uninstaller saved to ~/.config/tmux/uninstall.sh"
fi

# --- Plugins ------------------------------------------------------------------

fetch_repo() {
  # fetch_repo <owner/repo> <dest>: clone or update with git; without git,
  # fall back to downloading a tarball of the repo's default branch.
  local repo="$1" dest="$2" name tmp
  name="$(basename "$dest")"
  if [ -d "$dest/.git" ]; then
    info "$name already present, updating"
    git -C "$dest" pull --ff-only --quiet || warn "could not update $name"
  elif [ -d "$dest" ]; then
    info "$name already present"
  elif [ "$HAVE_GIT" -eq 1 ]; then
    git clone --quiet --depth 1 "https://github.com/$repo" "$dest"
    info "Cloned $name"
  else
    tmp="$(mktemp -d)"
    fetch "https://codeload.github.com/$repo/tar.gz/HEAD" "$tmp/repo.tgz" || die "Could not download $repo"
    mkdir -p "$dest"
    tar -xzf "$tmp/repo.tgz" -C "$dest" --strip-components=1
    rm -rf "$tmp"
    info "Downloaded $name (tarball)"
  fi
}

fetch_repo "odedlaz/tmux-onedark-theme" "$THEME_DIR"

# Fetch every plugin declared in tmux.conf (includes tpm itself), so the
# install never depends on a running tmux server.
grep -E "^set -g @plugin '" "$CONF" | cut -d"'" -f2 | while read -r spec; do
  fetch_repo "$spec" "$PLUGIN_DIR/${spec##*/}"
done
info "Plugins installed: $(ls "$PLUGIN_DIR" | tr '\n' ' ')"

# --- Shell alias --------------------------------------------------------------

ALIAS_LINE="alias t='tmux new-session -A -s main'"

add_alias() {
  local rc="$1"
  if grep -qsF "$ALIAS_LINE" "$rc"; then
    info "Alias 't' already present in ${rc/#$HOME/~}"
  else
    printf '\n# >>> tmux-config >>>\n# tmux: create or attach to a "main" session\n%s\n# <<< tmux-config <<<\n' \
      "$ALIAS_LINE" >> "$rc"
    info "Added alias 't' (attach/create session \"main\") to ${rc/#$HOME/~}"
  fi
}

rc_found=0
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [ -f "$rc" ] && { add_alias "$rc"; rc_found=1; }
done
if [ "$rc_found" -eq 0 ]; then
  case "$(basename "${SHELL:-bash}")" in
    zsh) add_alias "$HOME/.zshrc" ;;
    *)   add_alias "$HOME/.bashrc" ;;
  esac
fi

# --- Activate -----------------------------------------------------------------

# If a tmux server is already running (e.g. migrating an existing machine),
# apply the config to it live. Running sessions and programs are untouched;
# the new prefix and bindings take effect immediately. Only quirk: options and
# bindings from a previous config that this one doesn't override stay active
# until the server restarts.
if [ -n "${TMUX:-}" ] || tmux list-sessions >/dev/null 2>&1; then
  tmux source-file "$CONF"
  info "Applied config to the running tmux server (sessions preserved, prefix is now Ctrl-f)"
  cat <<'EOF'

  Migrating from an old config? It's now backed up, and the new one is live.
  For a completely clean slate while keeping your layout, when convenient:
    Ctrl-f Ctrl-s        save sessions (resurrect)
    tmux kill-server     note: running programs in panes will exit
    t                    restart; windows, panes, paths and pane text return
EOF
fi

cat <<'EOF'

Done! Quick reference (prefix is Ctrl-f):
  Ctrl-f C-s        save session          Ctrl-f C-r   restore session
  Ctrl-f h / v      split keeping path    Ctrl-f c     new window keeping path
  Alt-arrows        switch panes          Shift-arrows switch windows
  Ctrl-f r          reload config         Ctrl-f I     (re)install plugins
  t                 attach or create the "main" session (new shells)

Sessions auto-save every 15 min and auto-restore when tmux starts (continuum).
Uninstall anytime: ~/.config/tmux/uninstall.sh
EOF

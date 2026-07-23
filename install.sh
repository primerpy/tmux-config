#!/usr/bin/env bash
#
# Installs the tmux configuration from github.com/primerpy/tmux-config.
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
      grep '^#' "$0" | sed 's/^# \{0,1\}//' | head -9
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

# --- Dependencies -----------------------------------------------------------

command -v git >/dev/null 2>&1 || die "git is required. Install it first (macOS: xcode-select --install, Debian/Ubuntu: sudo apt install git)."

if ! command -v tmux >/dev/null 2>&1; then
  info "tmux is not installed"
  if command -v brew >/dev/null 2>&1; then
    confirm "Install tmux with Homebrew?" && brew install tmux
  elif command -v apt-get >/dev/null 2>&1; then
    confirm "Install tmux with apt?" && sudo apt-get update -qq && sudo apt-get install -y tmux
  elif command -v dnf >/dev/null 2>&1; then
    confirm "Install tmux with dnf?" && sudo dnf install -y tmux
  elif command -v pacman >/dev/null 2>&1; then
    confirm "Install tmux with pacman?" && sudo pacman -S --noconfirm tmux
  fi
  command -v tmux >/dev/null 2>&1 || die "tmux is still missing; install it manually and re-run."
fi
info "Using $(tmux -V)"

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
  curl -fsSL "$RAW_URL/tmux.conf" -o "$CONF" || die "Could not download tmux.conf"
  info "Installed tmux.conf from GitHub"
fi

# --- Plugins ------------------------------------------------------------------

clone_if_missing() {
  local url="$1" dest="$2"
  if [ -d "$dest/.git" ]; then
    info "$(basename "$dest") already present, updating"
    git -C "$dest" pull --ff-only --quiet || warn "could not update $(basename "$dest")"
  else
    git clone --quiet --depth 1 "$url" "$dest"
    info "Cloned $(basename "$dest")"
  fi
}

clone_if_missing "https://github.com/odedlaz/tmux-onedark-theme" "$THEME_DIR"

# Clone every plugin declared in tmux.conf (includes tpm itself), so the
# install never depends on a running tmux server.
grep -E "^set -g @plugin '" "$CONF" | cut -d"'" -f2 | while read -r spec; do
  clone_if_missing "https://github.com/$spec" "$PLUGIN_DIR/${spec##*/}"
done
info "Plugins installed: $(ls "$PLUGIN_DIR" | tr '\n' ' ')"

# --- Activate -----------------------------------------------------------------

if [ -n "${TMUX:-}" ]; then
  tmux source-file "$CONF"
  info "Reloaded config in the current tmux session"
elif tmux list-sessions >/dev/null 2>&1; then
  tmux source-file "$CONF"
  warn "A tmux server is already running; config was re-sourced, but restart tmux for a fully clean state."
fi

cat <<'EOF'

Done! Quick reference (prefix is Ctrl-f):
  Ctrl-f C-s        save session          Ctrl-f C-r   restore session
  Ctrl-f h / v      split keeping path    Ctrl-f c     new window keeping path
  Alt-arrows        switch panes          Shift-arrows switch windows
  Ctrl-f r          reload config         Ctrl-f I     (re)install plugins

Sessions auto-save every 15 min and auto-restore when tmux starts (continuum).
EOF

#!/usr/bin/env bash
#
# Removes the tmux configuration installed by github.com/primerpy/tmux-config.
#
# Usage:
#   ./uninstall.sh            interactive
#   ./uninstall.sh -y         non-interactive (keeps saved sessions and backups)
#
# Removes ~/.config/tmux (config, plugins, theme). Saved resurrect sessions in
# ~/.local/share/tmux are only removed if you say so. Backups made by
# install.sh are offered for restore.

set -euo pipefail

TMUX_DIR="$HOME/.config/tmux"
RESURRECT_DIRS=("$HOME/.local/share/tmux/resurrect" "$HOME/.tmux/resurrect")
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

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*"; }

confirm() {
  # $2 = default answer when non-interactive ("y" or "n")
  local default="${2:-y}"
  if [ "$ASSUME_YES" -eq 1 ] || [ ! -t 0 ]; then
    [ "$default" = "y" ] && return 0 || return 1
  fi
  printf '%s [y/N] ' "$1"
  read -r reply
  case "$reply" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

if [ ! -d "$TMUX_DIR" ]; then
  info "Nothing to do: $TMUX_DIR does not exist."
  exit 0
fi

echo "This removes the tmux config, plugins and theme in $TMUX_DIR."
confirm "Continue?" y || { echo "Aborted."; exit 1; }

# A running server keeps the old config in memory; offer to stop it.
if tmux list-sessions >/dev/null 2>&1; then
  warn "A tmux server is running. Killing it closes all sessions."
  if [ "$ASSUME_YES" -eq 1 ]; then
    warn "Leaving it running (-y never kills sessions); restart tmux to see the change."
  elif confirm "Kill the tmux server now?" n; then
    tmux kill-server
    info "tmux server stopped"
  fi
fi

rm -rf "$TMUX_DIR"
info "Removed $TMUX_DIR"

# Saved sessions are kept unless explicitly discarded.
for dir in "${RESURRECT_DIRS[@]}"; do
  if [ -d "$dir" ]; then
    if confirm "Also delete saved sessions in $dir?" n; then
      rm -rf "$dir"
      info "Removed $dir"
    else
      info "Kept saved sessions in $dir"
    fi
  fi
done

# Remove the alias block install.sh added to shell rc files. Pre-existing
# unmarked aliases are left alone.
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  if [ -f "$rc" ] && grep -q '# >>> tmux-config >>>' "$rc"; then
    sed -i.bak '/# >>> tmux-config >>>/,/# <<< tmux-config <<</d' "$rc" && rm -f "$rc.bak"
    info "Removed 't' alias block from ${rc/#$HOME/~}"
  fi
done

# Offer to restore the most recent backups made by install.sh.
latest_conf_backup="$(ls -t "$HOME"/.tmux.conf.backup-* 2>/dev/null | head -1 || true)"
if [ -n "$latest_conf_backup" ]; then
  if confirm "Restore previous ~/.tmux.conf from $(basename "$latest_conf_backup")?" n; then
    mv "$latest_conf_backup" "$HOME/.tmux.conf"
    info "Restored ~/.tmux.conf"
  fi
fi

info "Uninstalled. tmux itself was not removed."

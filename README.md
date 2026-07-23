# tmux-config

My tmux setup: onedark theme, session save/restore with resurrect + continuum, vi mode, `Ctrl-f` prefix. One command to install on a new machine, one command to remove.

Works on **macOS** (Homebrew) and **Debian/Ubuntu**, **Fedora**, and **Arch** based Linux (tested via the full install → boot → uninstall cycle on each).

## Install

On a fresh machine (downloads everything it needs):

```sh
curl -fsSL https://raw.githubusercontent.com/primerpy/tmux-config/main/install.sh | bash
```

Or from a clone:

```sh
git clone https://github.com/primerpy/tmux-config.git
cd tmux-config
./install.sh
```

(`wget -qO- <url> | bash` works too if you don't have curl.)

The installer:

- offers to install git and tmux via your package manager (brew / apt / dnf / pacman) if missing
- on Linux desktops, offers a clipboard helper for tmux-yank (`xsel` on X11, `wl-clipboard` on Wayland); macOS uses the built-in `pbcopy`, and headless/SSH machines fall back to OSC 52
- backs up any existing `~/.tmux.conf` or `~/.config/tmux/tmux.conf` (timestamped, never deleted)
- installs the config to `~/.config/tmux/tmux.conf`
- clones [TPM](https://github.com/tmux-plugins/tpm) and the [onedark theme](https://github.com/odedlaz/tmux-onedark-theme), then installs all plugins headlessly
- appends a `t` alias (`tmux new-session -A -s main` — attach or create the "main" session) to the end of `~/.zshrc` and/or `~/.bashrc`, in a marked block that uninstall removes; skipped if you already have it
- reloads the config if tmux is already running

Re-running it is safe (it updates plugins in place). Pass `-y` to skip prompts.

## Machines already running tmux

Run the same one-liner — it's designed to migrate a live server safely:

- **Running sessions and programs are never killed.** The installer applies the new config to the running server with `source-file`; the `Ctrl-f` prefix, bindings, theme and autosave are active immediately in your existing sessions.
- Your old config is backed up first (`~/.tmux.conf` → `~/.tmux.conf.backup-<timestamp>`, same for an old `~/.config/tmux/tmux.conf`), so `uninstall.sh` can put things back exactly as they were.
- One caveat of a live swap: bindings/options from the old config that this one doesn't override linger until the server restarts. To finish with a completely clean state *and* keep your layout: `Ctrl-f Ctrl-s` (save), `tmux kill-server` (running programs in panes will exit), then `t` — windows, panes, working dirs and pane contents are restored by resurrect.
- If your old setup used TPM in `~/.tmux/plugins`, that directory is now unused; delete it whenever you like.

## Minimal / locked-down servers

No root, no sudo, no git? Still works — everything installs into `$HOME` only:

- If tmux is already installed, no package manager is ever touched.
- Without git, plugins are downloaded as GitHub tarballs using curl or wget (only `prefix I` plugin updates need git).
- No clipboard tool is needed over SSH: `set-clipboard on` copies through your terminal via OSC 52.
- Autosave + auto-restore means server reboots bring your sessions' layout back: just type `t`.

## Uninstall

```sh
./uninstall.sh
```

or without a clone:

```sh
curl -fsSL https://raw.githubusercontent.com/primerpy/tmux-config/main/uninstall.sh | bash
```

Removes `~/.config/tmux` (config, plugins, theme) and the `t` alias block from your shell rc files. Saved resurrect sessions and the backups made by the installer are kept unless you opt in to deleting/restoring them. tmux itself is never uninstalled.

## What's inside

| Plugin | Purpose |
|---|---|
| [tpm](https://github.com/tmux-plugins/tpm) | plugin manager |
| [tmux-sensible](https://github.com/tmux-plugins/tmux-sensible) | sane defaults |
| [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) | save/restore sessions (incl. pane contents) |
| [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum) | auto-save every 15 min, auto-restore on start |
| [tmux-yank](https://github.com/tmux-plugins/tmux-yank) | copy to system clipboard (mouse selection too) |
| [tmux-onedark-theme](https://github.com/odedlaz/tmux-onedark-theme) | status bar theme |

## Key bindings

Prefix is **`Ctrl-f`** (not the default `Ctrl-b`).

| Binding | Action |
|---|---|
| `t` (shell alias) | attach to or create the "main" session |
| `prefix C-s` | save session |
| `prefix C-r` | restore session |
| `prefix h` | split horizontally, keep current path |
| `prefix v` | split vertically, keep current path |
| `prefix c` | new window, keep current path |
| `Alt` + arrows | switch panes (no prefix) |
| `Shift` + arrows | switch windows (no prefix) |
| `prefix r` | reload config |
| `prefix I` | install/update plugins (TPM) |

Also on: vi copy mode, mouse support, windows numbered from 1, zero escape delay (for neovim).

## Files on disk after install

```
~/.config/tmux/
├── tmux.conf              # the config in this repo
├── plugins/               # TPM + plugins (cloned, not tracked here)
└── tmux-onedark-theme/    # theme (cloned, not tracked here)

~/.local/share/tmux/resurrect/   # saved session state
```

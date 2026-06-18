# tmux-harpoon

Fast window bookmarking for tmux, inspired by [ThePrimeagen/harpoon](https://github.com/ThePrimeagen/harpoon).

Mark tmux windows into numbered slots (1-9) and jump to them instantly. Persists across tmux restarts. Supports per-session, per-project (git root), or global namespacing.

## Installation

### With TPM (recommended)

Add to your `tmux.conf`:

```bash
set -g @plugin 'kon-angelo/tmux-harpoon'
```

Then press `prefix + I` to install.

### From dotfiles (local)

```bash
set -g @plugin 'path/to/dotfiles/tmux-harpoon'
```

Or source directly:

```bash
run-shell '/path/to/tmux-harpoon/tmux-harpoon.tmux'
```

## Usage

| Keybinding | Action |
|---|---|
| `prefix + H` | Harpoon (bookmark) current window to next free slot |
| `prefix + M-1` to `prefix + M-9` | Jump to slot 1–9 |
| `prefix + C-f` | Open fzf picker in a floating popup |
| `prefix + C-h` | Clear all harpoons |

### Quick Keys (no prefix required)

These are enabled by default (`@harpoon-quick-jump on`) for slots 1–9:

| Keybinding | Action |
|---|---|
| `Alt+1` to `Alt+9` | Jump to slot 1–9 |
| `Shift+Alt+1` to `Shift+Alt+9` | Pin current window to slot 1–9 |

### Picker Controls

The picker (`prefix + C-f`) opens fzf inside a floating tmux popup:

- `Enter` — jump to selected entry
- `Alt-1` … `Alt-9` — quick-pick: jump to the Nth visible entry without moving the cursor
- `Ctrl-D` — delete selected entry
- `Ctrl-A` — add current window to next free slot
- `Ctrl-K` / `Ctrl-J` — move selected entry up / down
- `Esc` — close picker

## Configuration

All options are set via tmux options (before TPM loads the plugin):

```bash
# Key bindings (prefix-based)
set -g @harpoon-add-key 'H'         # Key to add current window
set -g @harpoon-picker-key 'C-f'    # Key to open fzf popup picker
set -g @harpoon-clear-key 'C-h'     # Key to clear all
set -g @harpoon-jump-prefix 'M-'    # Prefix for slot keys (M-1..M-9)

# Quick keys (no prefix, on by default)
set -g @harpoon-quick-jump 'on'     # Enable M-1..9 jump, M-S-1..9 pin
set -g @harpoon-quick-slots '9'     # Number of quick slots (1-9)

# Picker popup dimensions
set -g @harpoon-picker-width '60%'  # Popup width (default: 60%)
set -g @harpoon-picker-height '40%' # Popup height (default: 40%)

# Namespacing: "session" (default), "git" (per git repo), or "global"
set -g @harpoon-namespace 'session'

# Data directory (default: ~/.local/share/tmux-harpoon)
set -g @harpoon-data-dir "$HOME/.local/share/tmux-harpoon"

# Status bar integration (off by default)
set -g @harpoon-status 'on'
```

### Status Bar Integration

When `@harpoon-status` is `on`, a format string is available at `#{@harpoon-status-format}`. Add it to your status bar:

```bash
set -g status-right "#{@harpoon-status-format} | %H:%M"
```

This displays something like: `[1:vim 2:logs 3:tests]`

### Namespace Modes

- **session** (default): Each tmux session gets its own harpoon list. Best for workflows where sessions represent distinct contexts.
- **git**: Harpooned windows are grouped by git repository root. All sessions working in the same repo share the same list.
- **global**: One list shared across everything.

## How It Works

- State is stored as plain text files in `~/.local/share/tmux-harpoon/`
- Each file is one entry per line: `session_name:window_index:window_name`
- Stale entries (windows that no longer exist) are detected on jump and auto-removed
- The list is capped at 9 slots

## Dependencies

- `tmux` >= 3.2 (for `display-popup`)
- `fzf` >= 0.49 (for the picker UI; `pos()` action used for cursor positioning)
- `bash` >= 4 (uses `mapfile`)
- Standard POSIX tools: `sed`, `grep`, `cut`, `wc`

## File Structure

```
tmux-harpoon/
├── tmux-harpoon.tmux          # TPM entry point
├── scripts/
│   ├── helpers.sh             # Shared utility functions
│   ├── harpoon_add.sh         # Add current window to list
│   ├── harpoon_jump.sh        # Jump to slot N
│   ├── harpoon_picker.sh      # fzf popup picker (jump/add/delete/reorder)
│   ├── harpoon_clear.sh       # Clear all entries
│   └── harpoon_status.sh      # Status bar segment
└── README.md
```

## License

MIT — see [LICENSE](LICENSE).

#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 kon-angelo
# ==============================================================================
# tmux-harpoon — fast window bookmarking for tmux (harpoon-inspired)
# TPM entry point: sets keybindings and initializes state directory
# ==============================================================================

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$CURRENT_DIR/scripts"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

get_tmux_option() {
    local option="$1"
    local default_value="$2"
    local option_value
    option_value=$(tmux show-option -gqv "$option")
    if [ -z "$option_value" ]; then
        echo "$default_value"
    else
        echo "$option_value"
    fi
}

# ---------------------------------------------------------------------------
# Configuration (all customizable via tmux options)
# ---------------------------------------------------------------------------

# Key bindings
HARPOON_ADD_KEY=$(get_tmux_option "@harpoon-add-key" "H")
HARPOON_CLEAR_KEY=$(get_tmux_option "@harpoon-clear-key" "C-h")
HARPOON_PICKER_KEY=$(get_tmux_option "@harpoon-picker-key" "C-f")

# Jump keys (with prefix): prefix + Alt-1..9 (default) — avoids conflicting with tmux's prefix+1..9 window select
HARPOON_JUMP_PREFIX=$(get_tmux_option "@harpoon-jump-prefix" "M-")

# No-prefix quick keys: M-1..M-9 to jump, M-S-1..M-S-9 (M-! etc.) to pin
HARPOON_QUICK_JUMP=$(get_tmux_option "@harpoon-quick-jump" "on")
HARPOON_QUICK_SLOTS=$(get_tmux_option "@harpoon-quick-slots" "9")

# Data directory
HARPOON_DATA_DIR=$(get_tmux_option "@harpoon-data-dir" "$HOME/.local/share/tmux-harpoon")

# Status bar integration (on/off)
HARPOON_STATUS=$(get_tmux_option "@harpoon-status" "off")

# ---------------------------------------------------------------------------
# Ensure data directory exists
# ---------------------------------------------------------------------------
mkdir -p "$HARPOON_DATA_DIR"

# ---------------------------------------------------------------------------
# Bind keys
# ---------------------------------------------------------------------------

# Add current window to harpoon list
tmux bind-key "$HARPOON_ADD_KEY" run-shell "$SCRIPTS_DIR/harpoon_add.sh"

# Jump to slots 1–9
for i in $(seq 1 9); do
    tmux bind-key "${HARPOON_JUMP_PREFIX}${i}" run-shell "$SCRIPTS_DIR/harpoon_jump.sh $i"
done

# Open interactive fzf picker in a floating popup
tmux bind-key "$HARPOON_PICKER_KEY" run-shell "$SCRIPTS_DIR/harpoon_picker.sh"

# Clear all harpoons
tmux bind-key "$HARPOON_CLEAR_KEY" run-shell "$SCRIPTS_DIR/harpoon_clear.sh"

# ---------------------------------------------------------------------------
# No-prefix quick keys (M-1..9 to jump, M-S-1..9 to pin)
# ---------------------------------------------------------------------------
if [ "$HARPOON_QUICK_JUMP" = "on" ]; then
    # Shift+Alt+digit produces three different canonical names depending on
    # how tmux negotiates with the terminal (extended-keys, CSI-u, etc):
    #
    #   - extended-keys off   → tmux sees the shifted glyph:    M-!   M-@ …
    #   - extended-keys on    → shifted glyph + Shift modifier: M-S-! M-S-@ …
    #   - CSI-u from terminal → digit + Shift modifier:         M-S-1 M-S-2 …
    #
    # The canonical form depends on the terminal's protocol response, not on
    # the user's tmux setting alone, so we bind all three forms and let
    # whichever one tmux actually receives match. Same action either way.
    # Layout-dependent: works for US/QWERTY and DE/QWERTZ where Shift+1..5
    # produce !@#$%; will need adjustment for layouts with different shifted
    # glyphs.
    SHIFTED_GLYPHS=('!' '@' '#' '$' '%' '^' '&' '*' '(')

    for i in $(seq 1 "$HARPOON_QUICK_SLOTS"); do
        # M-1..M-N (no prefix) → jump to slot
        tmux bind-key -n "M-${i}" run-shell "$SCRIPTS_DIR/harpoon_jump.sh $i"

        idx=$((i - 1))
        glyph="${SHIFTED_GLYPHS[$idx]}"

        # Pin current window to slot N. Bind all three encodings.
        tmux bind-key -n "M-${glyph}"   run-shell "$SCRIPTS_DIR/harpoon_add.sh $i"
        tmux bind-key -n "M-S-${glyph}" run-shell "$SCRIPTS_DIR/harpoon_add.sh $i"
        tmux bind-key -n "M-S-${i}"     run-shell "$SCRIPTS_DIR/harpoon_add.sh $i"
    done
fi

# ---------------------------------------------------------------------------
# Status bar format string (if enabled)
# ---------------------------------------------------------------------------
if [ "$HARPOON_STATUS" = "on" ]; then
    tmux set-option -g @harpoon-status-format "#($SCRIPTS_DIR/harpoon_status.sh)"
fi

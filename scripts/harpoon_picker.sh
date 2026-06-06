#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 kon-angelo
# ==============================================================================
# tmux-harpoon — fzf popup picker
#
# Opens a tmux display-popup with fzf listing all harpooned windows.
# Supports jump (Enter), delete (Ctrl-D), and pin current window (Ctrl-A).
#
# This script is the entry point bound to a key. It launches the popup.
# The actual fzf selection runs inside the popup via --inner mode.
# ==============================================================================

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Inner mode: runs INSIDE the popup (called by display-popup)
# ---------------------------------------------------------------------------
if [ "$1" = "--inner" ]; then
    source "$CURRENT_DIR/helpers.sh"

    list_file=$(get_list_file)

    if [ ! -f "$list_file" ] || [ ! -s "$list_file" ]; then
        echo "Harpoon: no entries. Press Esc to close."
        read -r
        exit 0
    fi

    # Build display list
    display_list=""
    i=0
    while IFS= read -r line; do
        i=$((i + 1))
        if [ -z "$line" ]; then
            display_list="${display_list}${i}: (empty)\n"
            continue
        fi

        session=$(echo "$line" | cut -d: -f1)
        window_index=$(echo "$line" | cut -d: -f2)
        window_name=$(echo "$line" | cut -d: -f3)

        if validate_entry "$line"; then
            status_indicator=""
        else
            status_indicator=" [stale]"
        fi

        display_list="${display_list}${i}: ${session}:${window_index} (${window_name})${status_indicator}\n"
    done < "$list_file"

    # Run fzf
    selected=$(printf '%b' "$display_list" | grep -v '^$' | fzf \
        --reverse \
        --ansi \
        --header="Harpoon | Enter=jump  Ctrl-D=delete  Ctrl-A=add  Esc=close" \
        --prompt="  " \
        --expect="ctrl-d,ctrl-a" \
        --no-multi \
        --color="header:italic")

    if [ -z "$selected" ]; then
        exit 0
    fi

    # Parse fzf --expect output: line 1 = key pressed, line 2 = selection
    key=$(echo "$selected" | head -1)
    choice=$(echo "$selected" | tail -1)
    slot_num=$(echo "$choice" | cut -d: -f1 | tr -d ' ')

    case "$key" in
        ctrl-d)
            # Delete the selected slot
            if [ -n "$slot_num" ]; then
                if [[ "$OSTYPE" == darwin* ]]; then
                    sed -i '' "${slot_num}s|.*||" "$list_file"
                else
                    sed -i "${slot_num}s|.*||" "$list_file"
                fi
                tmux display-message "Harpoon: removed slot $slot_num"
            fi
            ;;
        ctrl-a)
            # Add current window to next free slot
            exec "$CURRENT_DIR/harpoon_add.sh"
            ;;
        *)
            # Jump to the selected slot
            if [ -n "$slot_num" ]; then
                exec "$CURRENT_DIR/harpoon_jump.sh" "$slot_num"
            fi
            ;;
    esac

    exit 0
fi

# ---------------------------------------------------------------------------
# Outer mode: launches the tmux popup
# ---------------------------------------------------------------------------

# Read popup dimensions from tmux options
PICKER_WIDTH=$(tmux show-option -gqv "@harpoon-picker-width")
PICKER_WIDTH="${PICKER_WIDTH:-60%}"

PICKER_HEIGHT=$(tmux show-option -gqv "@harpoon-picker-height")
PICKER_HEIGHT="${PICKER_HEIGHT:-40%}"

# Check if fzf is available
if ! command -v fzf &>/dev/null; then
    tmux display-message "Harpoon: fzf not found. Install fzf for the picker."
    exit 1
fi

# Check if tmux supports display-popup (tmux >= 3.2)
if ! tmux display-popup -h 2>&1 | grep -q "usage"; then
    # Fallback: run inline (no popup support)
    tmux display-message "Harpoon: tmux display-popup not available (need tmux >= 3.2). Falling back to menu."
    exec "$CURRENT_DIR/harpoon_menu.sh"
fi

# Launch the popup with this script in --inner mode
tmux display-popup \
    -w "$PICKER_WIDTH" \
    -h "$PICKER_HEIGHT" \
    -E \
    "$CURRENT_DIR/harpoon_picker.sh --inner"

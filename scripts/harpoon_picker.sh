#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 kon-angelo
# ==============================================================================
# tmux-harpoon — fzf popup picker
#
# Opens a tmux display-popup with fzf listing all harpooned windows.
# Supports jump (Enter), delete (Ctrl-D), add (Ctrl-A), and
# move up/down (Ctrl-K/Ctrl-J) to reorder slots.
#
# This script is the entry point bound to a key. It launches the popup.
# The actual fzf selection runs inside the popup via --inner mode.
# ==============================================================================

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers.sh"

# ---------------------------------------------------------------------------
# Swap mode: swap two adjacent lines in the list file
# Usage: harpoon_picker.sh --swap <slot> <direction: up|down>
# ---------------------------------------------------------------------------
if [ "$1" = "--swap" ]; then
    resolve_harpoon_context
    list_file="$H_LIST_FILE"
    slot="$2"
    direction="$3"

    total_lines=$(wc -l < "$list_file" | tr -d ' ')

    if [ "$direction" = "up" ] && [ "$slot" -gt 1 ]; then
        target=$((slot - 1))
    elif [ "$direction" = "down" ] && [ "$slot" -lt "$total_lines" ]; then
        target=$((slot + 1))
    else
        exit 0
    fi

    # Swap lines using mapfile (portable, no sed -i issues between GNU/BSD)
    mapfile -t all_lines < "$list_file"
    tmp="${all_lines[$((slot - 1))]}"
    all_lines[$((slot - 1))]="${all_lines[$((target - 1))]}"
    all_lines[$((target - 1))]="$tmp"
    printf '%s\n' "${all_lines[@]}" > "$list_file"
    exit 0
fi

# ---------------------------------------------------------------------------
# Inner mode: runs INSIDE the popup (called by display-popup)
# Optional: --inner [initial_slot] to pre-select a line after swap
# ---------------------------------------------------------------------------
if [ "$1" = "--inner" ]; then
    resolve_harpoon_context
    list_file="$H_LIST_FILE"
    initial_slot="${2:-}"

    if [ ! -f "$list_file" ] || [ ! -s "$list_file" ]; then
        echo "Harpoon: no entries. Press Esc to close."
        read -r
        exit 0
    fi

    # Loop: re-render after swaps so user sees the updated order
    while true; do
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
            window_name=$(echo "$line" | cut -d: -f3-)

            if validate_entry "$line"; then
                status_indicator=""
            else
                status_indicator=" [stale]"
            fi

            display_list="${display_list}${i}: ${session}:${window_name}${status_indicator}\n"
        done < "$list_file"

        fzf_opts=(
            --reverse
            --ansi
            --header="Enter=jump  C-d=delete  C-a=add  C-k/C-j=move up/down  Esc=close"
            --prompt="  "
            --expect="ctrl-d,ctrl-a,ctrl-k,ctrl-j"
            --no-multi
            --color="header:italic"
        )

        # After a swap, position the cursor on the moved entry so the user can
        # see where it landed and chain another move. fzf's `pos(N)` action
        # (available since v0.49) sets the initial cursor line; on older fzf
        # versions this binding is silently ignored, which is harmless.
        if [ -n "$initial_slot" ]; then
            fzf_opts+=(--bind="start:pos($initial_slot)")
        fi

        selected=$(printf '%b' "$display_list" | grep -v '^$' | fzf "${fzf_opts[@]}")

        if [ -z "$selected" ]; then
            exit 0
        fi

        # Parse fzf --expect output: line 1 = key pressed, line 2 = selection
        key=$(echo "$selected" | head -1)
        choice=$(echo "$selected" | tail -1)
        slot_num=$(echo "$choice" | cut -d: -f1 | tr -d ' ')

        case "$key" in
            ctrl-k)
                if [ -n "$slot_num" ] && [ "$slot_num" -gt 1 ]; then
                    "$CURRENT_DIR/harpoon_picker.sh" --swap "$slot_num" up
                    initial_slot=$((slot_num - 1))
                fi
                continue
                ;;
            ctrl-j)
                total_lines=$(wc -l < "$list_file" | tr -d ' ')
                if [ -n "$slot_num" ] && [ "$slot_num" -lt "$total_lines" ]; then
                    "$CURRENT_DIR/harpoon_picker.sh" --swap "$slot_num" down
                    initial_slot=$((slot_num + 1))
                fi
                continue
                ;;
            ctrl-d)
                if [ -n "$slot_num" ]; then
                    sed_inplace "${slot_num}s|.*||" "$list_file"
                    tmux display-message "Harpoon: removed slot $slot_num"
                fi
                exit 0
                ;;
            ctrl-a)
                exec "$CURRENT_DIR/harpoon_add.sh"
                ;;
            *)
                if [ -n "$slot_num" ]; then
                    exec "$CURRENT_DIR/harpoon_jump.sh" "$slot_num"
                fi
                exit 0
                ;;
        esac
    done
fi

# ---------------------------------------------------------------------------
# Outer mode: launches the tmux popup
# ---------------------------------------------------------------------------

# Read popup dimensions from tmux options
PICKER_WIDTH=$(tmux show-option -gqv "@harpoon-picker-width")
PICKER_WIDTH="${PICKER_WIDTH:-60%}"

PICKER_HEIGHT=$(tmux show-option -gqv "@harpoon-picker-height")
PICKER_HEIGHT="${PICKER_HEIGHT:-40%}"

# Check if fzf is available (hard dependency — see README)
if ! command -v fzf &>/dev/null; then
    tmux display-message "Harpoon: fzf not found. fzf is a required dependency."
    exit 1
fi

# Launch the popup with this script in --inner mode
tmux display-popup \
    -w "$PICKER_WIDTH" \
    -h "$PICKER_HEIGHT" \
    -E \
    "$CURRENT_DIR/harpoon_picker.sh --inner"

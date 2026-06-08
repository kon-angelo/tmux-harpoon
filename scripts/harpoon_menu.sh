#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 kon-angelo
# ==============================================================================
# tmux-harpoon — interactive harpoon menu
#
# Shows all harpooned entries in an fzf popup (or tmux choose-tree fallback).
# Allows jumping to, removing, or reordering entries.
# ==============================================================================

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers.sh"

list_file=$(get_list_file)

if [ ! -f "$list_file" ] || [ ! -s "$list_file" ]; then
    display_message "Harpoon: no entries"
    exit 0
fi

# Build display list: "slot: session:window_name [valid/stale]"
build_display_list() {
    local i=0
    while IFS= read -r line; do
        i=$((i + 1))
        if [ -z "$line" ]; then
            echo "$i: (empty)"
            continue
        fi

        local session window_index window_name status_indicator
        session=$(echo "$line" | cut -d: -f1)
        window_index=$(echo "$line" | cut -d: -f2)
        window_name=$(echo "$line" | cut -d: -f3-)

        if validate_entry "$line"; then
            status_indicator=""
        else
            status_indicator=" [stale]"
        fi

        echo "$i: ${session}:${window_index} (${window_name})${status_indicator}"
    done < "$list_file"
}

# Check if fzf is available
if command -v fzf &>/dev/null; then
    # Use fzf in a tmux popup
    selected=$(build_display_list | fzf \
        --reverse \
        --header="Harpoon — Enter=jump, Ctrl-D=delete, Esc=close" \
        --prompt="Jump to > " \
        --bind="ctrl-d:execute-silent(echo {1} | tr -d ':' > /tmp/harpoon_delete)+abort" \
        --expect="ctrl-d" \
        --no-multi)

    if [ -z "$selected" ]; then
        # Check if a deletion was requested
        if [ -f /tmp/harpoon_delete ]; then
            delete_slot=$(cat /tmp/harpoon_delete)
            rm -f /tmp/harpoon_delete
            if [ -n "$delete_slot" ]; then
                if [[ "$OSTYPE" == darwin* ]]; then
                    sed -i '' "${delete_slot}s|.*||" "$list_file"
                else
                    sed -i "${delete_slot}s|.*||" "$list_file"
                fi
                display_message "Harpoon: removed slot $delete_slot"
            fi
        fi
        exit 0
    fi

    # Parse the selected slot number (first field before ":")
    # fzf --expect puts the key on line 1 and the selection on line 2
    key=$(echo "$selected" | head -1)
    choice=$(echo "$selected" | tail -1)

    if [ "$key" = "ctrl-d" ]; then
        slot_num=$(echo "$choice" | cut -d: -f1 | tr -d ' ')
        if [[ "$OSTYPE" == darwin* ]]; then
            sed -i '' "${slot_num}s|.*||" "$list_file"
        else
            sed -i "${slot_num}s|.*||" "$list_file"
        fi
        display_message "Harpoon: removed slot $slot_num"
        exit 0
    fi

    slot_num=$(echo "$choice" | cut -d: -f1 | tr -d ' ')
    if [ -n "$slot_num" ]; then
        exec "$CURRENT_DIR/harpoon_jump.sh" "$slot_num"
    fi
else
    # Fallback: tmux display-menu
    menu_items=()
    i=0
    while IFS= read -r line; do
        i=$((i + 1))
        if [ -z "$line" ]; then
            continue
        fi
        window_name=$(echo "$line" | cut -d: -f3-)
        menu_items+=("$i: $window_name" "" "run-shell '$CURRENT_DIR/harpoon_jump.sh $i'")
    done < "$list_file"

    if [ ${#menu_items[@]} -eq 0 ]; then
        display_message "Harpoon: no valid entries"
        exit 0
    fi

    tmux display-menu -T "Harpoon" "${menu_items[@]}"
fi

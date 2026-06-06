#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 kon-angelo
# ==============================================================================
# tmux-harpoon — jump to a harpooned slot
#
# Usage: harpoon_jump.sh <slot_number>
# ==============================================================================

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers.sh"

slot="$1"

if [ -z "$slot" ]; then
    display_message "Harpoon: no slot specified"
    exit 1
fi

list_file=$(get_list_file)

if [ ! -f "$list_file" ]; then
    display_message "Harpoon: no entries (slot $slot is empty)"
    exit 1
fi

# Read the entry at slot N (1-indexed line)
entry=$(sed -n "${slot}p" "$list_file")

if [ -z "$entry" ]; then
    display_message "Harpoon: slot $slot is empty"
    exit 1
fi

session=$(echo "$entry" | cut -d: -f1)
window_index=$(echo "$entry" | cut -d: -f2)
window_name=$(echo "$entry" | cut -d: -f3)

# Validate that the target still exists
if ! validate_entry "$entry"; then
    display_message "Harpoon: slot $slot stale (${session}:${window_name} gone) — removing"
    # Remove the stale entry (replace with empty line to preserve slot numbering)
    if [[ "$OSTYPE" == darwin* ]]; then
        sed -i '' "${slot}s|.*||" "$list_file"
    else
        sed -i "${slot}s|.*||" "$list_file"
    fi
    exit 1
fi

# Jump to the target
current_session=$(tmux display-message -p '#S')

if [ "$session" = "$current_session" ]; then
    # Same session: just select the window
    tmux select-window -t "${session}:${window_index}"
else
    # Different session: switch client then select window
    tmux switch-client -t "${session}:${window_index}"
fi

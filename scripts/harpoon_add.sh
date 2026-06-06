#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 kon-angelo
# ==============================================================================
# tmux-harpoon — add current window to the harpoon list
#
# Usage: harpoon_add.sh [slot_number]
#   If slot_number is given, replaces that slot. Otherwise appends to the list.
# ==============================================================================

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers.sh"

slot="$1"
list_file=$(ensure_list_file)
entry=$(current_window_entry)

# Check if this window is already in the list
if grep -qF "$entry" "$list_file" 2>/dev/null; then
    local_slot=$(grep -nF "$entry" "$list_file" | head -1 | cut -d: -f1)
    display_message "Harpoon: already at slot $local_slot — $(echo "$entry" | cut -d: -f3)"
    exit 0
fi

if [ -n "$slot" ] && [ "$slot" -ge 1 ] 2>/dev/null; then
    # Replace specific slot
    total_lines=$(wc -l < "$list_file" | tr -d ' ')

    # Pad file if needed
    while [ "$total_lines" -lt "$slot" ]; do
        echo "" >> "$list_file"
        total_lines=$((total_lines + 1))
    done

    # Replace the line at the given slot (1-indexed)
    if [[ "$OSTYPE" == darwin* ]]; then
        sed -i '' "${slot}s|.*|${entry}|" "$list_file"
    else
        sed -i "${slot}s|.*|${entry}|" "$list_file"
    fi

    display_message "Harpoon: set slot $slot → $(echo "$entry" | cut -d: -f3)"
else
    # Append to next available slot (max 9)
    count=$(get_entry_count)
    if [ "$count" -ge 9 ]; then
        display_message "Harpoon: list full (9 slots). Use prefix+C-h to clear."
        exit 1
    fi

    echo "$entry" >> "$list_file"
    new_slot=$((count + 1))
    display_message "Harpoon: added slot $new_slot → $(echo "$entry" | cut -d: -f3)"
fi

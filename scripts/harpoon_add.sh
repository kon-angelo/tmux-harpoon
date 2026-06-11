#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 kon-angelo
# ==============================================================================
# tmux-harpoon — add current window to the harpoon list
#
# Entry format: session_name:@window_id:window_name
# The window_id (@N) is a stable tmux identifier immune to renumber-windows.
#
# Usage: harpoon_add.sh [slot_number]
#   If slot_number is given, replaces (and possibly swaps) that slot.
#   Otherwise appends to the next free slot (max 9).
# ==============================================================================

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers.sh"

slot="$1"

resolve_harpoon_context
ensure_list_file

list_file="$H_LIST_FILE"
entry="$H_ENTRY"
window_name="$H_WINDOW_NAME"
entry_prefix="${H_SESSION}:${H_WINDOW_ID}:"

# When appending (no explicit slot): if this window is already pinned, either
# no-op (same name) or update its name in place.
if [ -z "$slot" ]; then
    existing_line=$(grep -n "^${entry_prefix}" "$list_file" 2>/dev/null | head -1)
    if [ -n "$existing_line" ]; then
        local_slot="${existing_line%%:*}"
        existing_entry="${existing_line#*:}"
        if [ "$existing_entry" = "$entry" ]; then
            tmux display-message "Harpoon: already at slot $local_slot — ${window_name}"
            exit 0
        fi
        # Same session:window_id but different name — update in place
        mapfile -t all_lines < "$list_file"
        all_lines[$((local_slot - 1))]="$entry"
        printf '%s\n' "${all_lines[@]}" > "$list_file"
        old_name="${existing_entry#*:*:}"
        tmux display-message "Harpoon: updated slot $local_slot — ${old_name} → ${window_name}"
        exit 0
    fi
fi

if [ -n "$slot" ] && [ "$slot" -ge 1 ] 2>/dev/null; then
    # Pin to a specific slot. Pad the file with blank lines so the slot exists.
    total_lines=$(wc -l < "$list_file" | tr -d ' ')
    while [ "$total_lines" -lt "$slot" ]; do
        echo "" >> "$list_file"
        total_lines=$((total_lines + 1))
    done

    # Does this window already occupy a different slot?
    existing_slot=$(grep -n "^${entry_prefix}" "$list_file" 2>/dev/null | head -1 | cut -d: -f1)

    mapfile -t all_lines < "$list_file"
    target_entry="${all_lines[$((slot - 1))]}"

    if [ -n "$target_entry" ] && [ "$target_entry" != "$entry" ]; then
        # Slot occupied. Take it; if we were already pinned, swap; else discard.
        all_lines[$((slot - 1))]="$entry"
        if [ -n "$existing_slot" ]; then
            all_lines[$((existing_slot - 1))]="$target_entry"
            displaced_name=$(echo "$target_entry" | cut -d: -f3-)
            tmux display-message "Harpoon: slot $slot → ${window_name} (swapped with ${displaced_name})"
        else
            tmux display-message "Harpoon: slot $slot → ${window_name} (replaced)"
        fi
        printf '%s\n' "${all_lines[@]}" > "$list_file"
    else
        # Slot empty (or same entry). Just write.
        all_lines[$((slot - 1))]="$entry"
        if [ -n "$existing_slot" ] && [ "$existing_slot" -ne "$slot" ]; then
            all_lines[$((existing_slot - 1))]=""
        fi
        printf '%s\n' "${all_lines[@]}" > "$list_file"
        tmux display-message "Harpoon: set slot $slot → ${window_name}"
    fi
else
    # Append to next available slot (max 9).
    count=$(wc -l < "$list_file" | tr -d ' ')
    if [ "$count" -ge 9 ]; then
        tmux display-message "Harpoon: list full (9 slots). Clear with prefix+M-x."
        exit 1
    fi
    echo "$entry" >> "$list_file"
    tmux display-message "Harpoon: added slot $((count + 1)) → ${window_name}"
fi

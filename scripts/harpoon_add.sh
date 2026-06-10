#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 kon-angelo
# ==============================================================================
# tmux-harpoon — add current window to the harpoon list (optimized)
#
# Usage: harpoon_add.sh [slot_number]
#   If slot_number is given, replaces that slot. Otherwise appends to the list.
# ==============================================================================

slot="$1"

# Batch: get session, window index, window name, namespace, data-dir in ONE call
_info=$(tmux display-message -p '#S|#I|#W|#{@harpoon-namespace}|#{@harpoon-data-dir}')
IFS='|' read -r current_session window_index window_name ns data_dir <<< "$_info"
ns="${ns:-session}"
data_dir="${data_dir:-$HOME/.local/share/tmux-harpoon}"

# Resolve list file path
case "$ns" in
    git)
        pane_path=$(tmux display-message -p '#{pane_current_path}')
        git_root=$(cd "$pane_path" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)
        if [ -n "$git_root" ]; then
            ns_key=$(echo "$git_root" | tr '/' '_' | sed 's/^_//')
        else
            ns_key="$current_session"
        fi
        ;;
    global)
        ns_key="global"
        ;;
    *)
        ns_key="$current_session"
        ;;
esac
ns_key=$(echo "$ns_key" | tr ' /:' '___')
list_file="${data_dir}/${ns_key}.list"

# Ensure list file exists
mkdir -p "$(dirname "$list_file")"
touch "$list_file"

entry="${current_session}:${window_index}:${window_name}"
entry_prefix="${current_session}:${window_index}:"

# Check if this session:window_index is already in the list (match by prefix, not exact name)
# This catches both exact duplicates AND stale entries where window name changed (index reuse)
if [ -z "$slot" ]; then
    existing_line=$(grep -n "^${entry_prefix}" "$list_file" 2>/dev/null | head -1)
    if [ -n "$existing_line" ]; then
        local_slot="${existing_line%%:*}"
        existing_entry="${existing_line#*:}"
        if [ "$existing_entry" = "$entry" ]; then
            # Exact match — already pinned
            tmux display-message "Harpoon: already at slot $local_slot — ${window_name}"
            exit 0
        else
            # Same session:window_index but different name — update in place
            mapfile -t all_lines < "$list_file"
            all_lines[$((local_slot - 1))]="$entry"
            printf '%s\n' "${all_lines[@]}" > "$list_file"
            old_name="${existing_entry#*:*:}"
            tmux display-message "Harpoon: updated slot $local_slot — ${old_name} → ${window_name}"
            exit 0
        fi
    fi
fi

if [ -n "$slot" ] && [ "$slot" -ge 1 ] 2>/dev/null; then
    # Pin to specific slot
    total_lines=$(wc -l < "$list_file" | tr -d ' ')

    # Pad file if needed
    while [ "$total_lines" -lt "$slot" ]; do
        echo "" >> "$list_file"
        total_lines=$((total_lines + 1))
    done

    # Check if current window (session:window_index) already occupies a different slot
    # Use prefix match to catch entries with stale names for same window
    existing_slot=$(grep -n "^${entry_prefix}" "$list_file" 2>/dev/null | head -1 | cut -d: -f1)

    # Read what's currently in the target slot
    mapfile -t all_lines < "$list_file"
    target_entry="${all_lines[$((slot - 1))]}"

    if [ -n "$target_entry" ] && [ "$target_entry" != "$entry" ]; then
        # Slot is occupied — take it, swap if we had an old slot, otherwise discard displaced
        all_lines[$((slot - 1))]="$entry"
        if [ -n "$existing_slot" ]; then
            # We were already pinned elsewhere — put displaced entry in our old slot
            all_lines[$((existing_slot - 1))]="$target_entry"
            displaced_name=$(echo "$target_entry" | cut -d: -f3-)
            tmux display-message "Harpoon: slot $slot → ${window_name} (swapped with ${displaced_name})"
        else
            # We weren't pinned — discard the displaced entry
            tmux display-message "Harpoon: slot $slot → ${window_name} (replaced)"
        fi
        printf '%s\n' "${all_lines[@]}" > "$list_file"
    else
        # Slot is empty (or same entry) — just write
        all_lines[$((slot - 1))]="$entry"
        # If we were in another slot, clear it
        if [ -n "$existing_slot" ] && [ "$existing_slot" -ne "$slot" ]; then
            all_lines[$((existing_slot - 1))]=""
        fi
        printf '%s\n' "${all_lines[@]}" > "$list_file"
        tmux display-message "Harpoon: set slot $slot → ${window_name}"
    fi
else
    # Append to next available slot (max 9)
    count=$(wc -l < "$list_file" | tr -d ' ')
    if [ "$count" -ge 9 ]; then
        tmux display-message "Harpoon: list full (9 slots). Clear with prefix+M-x."
        exit 1
    fi

    echo "$entry" >> "$list_file"
    new_slot=$((count + 1))
    tmux display-message "Harpoon: added slot $new_slot → ${window_name}"
fi

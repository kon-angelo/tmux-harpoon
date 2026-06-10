#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 kon-angelo
# ==============================================================================
# tmux-harpoon — jump to a harpooned slot (optimized: minimal tmux calls)
#
# Usage: harpoon_jump.sh <slot_number>
# ==============================================================================

slot="$1"

if [ -z "$slot" ]; then
    tmux display-message "Harpoon: no slot specified"
    exit 1
fi

# Batch: get session, namespace, data-dir in ONE tmux call using a separator
_info=$(tmux display-message -p '#S|#{@harpoon-namespace}|#{@harpoon-data-dir}')
current_session="${_info%%|*}"; _rest="${_info#*|}"
ns="${_rest%%|*}"; ns="${ns:-session}"
data_dir="${_rest#*|}"; data_dir="${data_dir:-$HOME/.local/share/tmux-harpoon}"

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

if [ ! -f "$list_file" ]; then
    tmux display-message "Harpoon: slot $slot is empty"
    exit 1
fi

# Read the entry at slot N (1-indexed line)
entry=$(sed -n "${slot}p" "$list_file")

if [ -z "$entry" ]; then
    tmux display-message "Harpoon: slot $slot is empty"
    exit 1
fi

session="${entry%%:*}"; _rest="${entry#*:}"
window_index="${_rest%%:*}"
window_name="${_rest#*:}"

# Validate: check if window exists (single tmux call, skip has-session)
_windows=$(tmux list-windows -t "$session" -F '#I:#W' 2>/dev/null)
if ! echo "$_windows" | grep -q "^${window_index}:"; then
    tmux display-message "Harpoon: slot $slot stale (${session}:${window_name} gone) — removing"
    if [[ "$OSTYPE" == darwin* ]]; then
        sed -i '' "${slot}s|.*||" "$list_file"
    else
        sed -i "${slot}s|.*||" "$list_file"
    fi
    exit 1
fi

# Validate: check if window name still matches (detect index reuse after close)
_actual_name=$(echo "$_windows" | grep "^${window_index}:" | cut -d: -f2-)
if [ "$_actual_name" != "$window_name" ]; then
    tmux display-message "Harpoon: slot $slot stale (window ${window_index} is now '${_actual_name}', expected '${window_name}') — removing"
    if [[ "$OSTYPE" == darwin* ]]; then
        sed -i '' "${slot}s|.*||" "$list_file"
    else
        sed -i "${slot}s|.*||" "$list_file"
    fi
    exit 1
fi

# Jump to the target
if [ "$session" = "$current_session" ]; then
    tmux select-window -t "${session}:${window_index}"
else
    tmux switch-client -t "${session}:${window_index}"
fi

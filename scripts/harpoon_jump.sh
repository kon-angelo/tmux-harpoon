#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 kon-angelo
# ==============================================================================
# tmux-harpoon — jump to a harpooned slot
#
# Entry format: session_name:@window_id:window_name
# The window_id (@N) is a stable tmux identifier immune to renumber-windows.
#
# Usage: harpoon_jump.sh <slot_number>
# ==============================================================================

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers.sh"

slot="$1"

if [ -z "$slot" ]; then
    tmux display-message "Harpoon: no slot specified"
    exit 1
fi

resolve_harpoon_context

if [ ! -f "$H_LIST_FILE" ]; then
    tmux display-message "Harpoon: slot $slot is empty"
    exit 1
fi

# Read the entry at slot N (1-indexed line)
entry=$(sed -n "${slot}p" "$H_LIST_FILE")

if [ -z "$entry" ]; then
    tmux display-message "Harpoon: slot $slot is empty"
    exit 1
fi

session="${entry%%:*}"; _rest="${entry#*:}"
window_id="${_rest%%:*}"
window_name="${_rest#*:}"

# Validate: window_id must still exist. If not, blank the slot and bail.
if ! tmux list-windows -t "$session" -F '#{window_id}' 2>/dev/null | grep -q "^${window_id}$"; then
    tmux display-message "Harpoon: slot $slot stale (${session}:${window_name} gone) — removing"
    sed_inplace "${slot}s|.*||" "$H_LIST_FILE"
    exit 1
fi

# Jump to the target using the stable window_id
if [ "$session" = "$H_SESSION" ]; then
    tmux select-window -t "${window_id}"
else
    tmux switch-client -t "${session}:${window_id}"
fi

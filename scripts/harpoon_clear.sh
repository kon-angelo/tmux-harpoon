#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 kon-angelo
# ==============================================================================
# tmux-harpoon — clear all harpooned entries
# ==============================================================================

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers.sh"

resolve_harpoon_context

if [ -f "$H_LIST_FILE" ]; then
    count=$(get_entry_count)
    : > "$H_LIST_FILE"
    display_message "Harpoon: cleared $count entries"
else
    display_message "Harpoon: nothing to clear"
fi

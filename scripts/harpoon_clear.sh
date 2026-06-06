#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 kon-angelo
# ==============================================================================
# tmux-harpoon — clear all harpooned entries
# ==============================================================================

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers.sh"

list_file=$(get_list_file)

if [ -f "$list_file" ]; then
    count=$(get_entry_count)
    : > "$list_file"
    display_message "Harpoon: cleared $count entries"
else
    display_message "Harpoon: nothing to clear"
fi

#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 kon-angelo
# ==============================================================================
# tmux-harpoon — status bar segment
#
# Entry format: session_name:@window_id:window_name
#
# Outputs a condensed view of harpoon slots for embedding in tmux status bar.
# Example output: "[1:vim 2:logs 3:tests]"
#
# Usage in tmux.conf:
#   set -g status-right "... #{@harpoon-status-format} ..."
# ==============================================================================

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers.sh"

resolve_harpoon_context

if [ ! -f "$H_LIST_FILE" ] || [ ! -s "$H_LIST_FILE" ]; then
    exit 0
fi

# Build compact display
output=""
i=0
while IFS= read -r line; do
    i=$((i + 1))
    if [ -z "$line" ]; then
        continue
    fi

    window_name=$(echo "$line" | cut -d: -f3)
    # Truncate long names
    if [ ${#window_name} -gt 8 ]; then
        window_name="${window_name:0:7}…"
    fi

    if [ -n "$output" ]; then
        output="${output} "
    fi
    output="${output}${i}:${window_name}"
done < "$H_LIST_FILE"

if [ -n "$output" ]; then
    echo "[${output}]"
fi

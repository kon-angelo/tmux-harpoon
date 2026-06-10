#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 kon-angelo
# ==============================================================================
# tmux-harpoon — shared helpers (sourced by all scripts)
#
# Entry format: session_name:@window_id:window_name
# The window_id (@N) is a stable tmux identifier immune to renumber-windows.
# ==============================================================================

# Resolve the data directory
HARPOON_DATA_DIR=$(tmux show-option -gqv "@harpoon-data-dir")
HARPOON_DATA_DIR="${HARPOON_DATA_DIR:-$HOME/.local/share/tmux-harpoon}"

# Resolve namespace mode: "git", "session", or "global"
HARPOON_NAMESPACE=$(tmux show-option -gqv "@harpoon-namespace")
HARPOON_NAMESPACE="${HARPOON_NAMESPACE:-session}"

# ---------------------------------------------------------------------------
# get_list_file — returns the path to the current harpoon list file
# ---------------------------------------------------------------------------
get_list_file() {
    local ns_key

    case "$HARPOON_NAMESPACE" in
        git)
            # Use git repo root as namespace key (sanitized)
            local pane_path
            pane_path=$(tmux display-message -p '#{pane_current_path}')
            local git_root
            git_root=$(cd "$pane_path" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)
            if [ -n "$git_root" ]; then
                ns_key=$(echo "$git_root" | tr '/' '_' | sed 's/^_//')
            else
                # Fallback to session name if not in a git repo
                ns_key=$(tmux display-message -p '#S')
            fi
            ;;
        global)
            ns_key="global"
            ;;
        session|*)
            ns_key=$(tmux display-message -p '#S')
            ;;
    esac

    # Sanitize: replace problematic characters
    ns_key=$(echo "$ns_key" | tr ' /:' '___')

    echo "${HARPOON_DATA_DIR}/${ns_key}.list"
}

# ---------------------------------------------------------------------------
# ensure_list_file — create the list file if it doesn't exist
# ---------------------------------------------------------------------------
ensure_list_file() {
    local list_file
    list_file=$(get_list_file)
    mkdir -p "$(dirname "$list_file")"
    touch "$list_file"
    echo "$list_file"
}

# ---------------------------------------------------------------------------
# get_entry_count — returns the number of entries in the list
# ---------------------------------------------------------------------------
get_entry_count() {
    local list_file
    list_file=$(get_list_file)
    if [ -f "$list_file" ]; then
        wc -l < "$list_file" | tr -d ' '
    else
        echo "0"
    fi
}

# ---------------------------------------------------------------------------
# current_window_entry — returns the entry for the current window
# Format: session_name:@window_id:window_name
# ---------------------------------------------------------------------------
current_window_entry() {
    local session window_id window_name
    session=$(tmux display-message -p '#S')
    window_id=$(tmux display-message -p '#{window_id}')
    window_name=$(tmux display-message -p '#W')
    echo "${session}:${window_id}:${window_name}"
}

# ---------------------------------------------------------------------------
# validate_entry — check if a harpooned entry still exists
# Returns 0 if valid, 1 if stale
# Validates session exists and window_id exists in that session.
# Window IDs are stable — if the ID exists, the window is the same one.
# ---------------------------------------------------------------------------
validate_entry() {
    local entry="$1"
    local session window_id

    session=$(echo "$entry" | cut -d: -f1)
    window_id=$(echo "$entry" | cut -d: -f2)

    # Check if the session exists
    if ! tmux has-session -t "$session" 2>/dev/null; then
        return 1
    fi

    # Check if the window_id exists in that session
    if ! tmux list-windows -t "$session" -F '#{window_id}' 2>/dev/null | grep -q "^${window_id}$"; then
        return 1
    fi

    return 0
}

# ---------------------------------------------------------------------------
# display_message — show a message to the user via tmux
# ---------------------------------------------------------------------------
display_message() {
    tmux display-message "$1"
}

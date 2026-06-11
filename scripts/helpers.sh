#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 kon-angelo
# ==============================================================================
# tmux-harpoon — shared helpers (sourced by all scripts)
#
# Entry format: session_name:@window_id:window_name
# The window_id (@N) is a stable tmux identifier immune to renumber-windows.
# ==============================================================================

# ---------------------------------------------------------------------------
# resolve_harpoon_context — batched lookup of everything we need from tmux
#
# Sets the following globals in one `tmux display-message` call:
#   H_SESSION        current session name
#   H_WINDOW_ID      stable window id (@N)
#   H_WINDOW_NAME    current window name
#   H_PANE_PATH      cwd of the current pane
#   H_NAMESPACE      session | git | global  (defaults to "session")
#   H_DATA_DIR       data dir (defaults to ~/.local/share/tmux-harpoon)
#   H_LIST_FILE      resolved list file for the active namespace
#   H_ENTRY          "session:@window_id:window_name" for the current window
#
# Every script needs at least H_LIST_FILE; add/jump need H_ENTRY too. Batching
# saves 3-5 separate tmux roundtrips per keypress.
# ---------------------------------------------------------------------------
resolve_harpoon_context() {
    local _info
    _info=$(tmux display-message -p \
        '#S|#{window_id}|#W|#{pane_current_path}|#{@harpoon-namespace}|#{@harpoon-data-dir}')
    IFS='|' read -r H_SESSION H_WINDOW_ID H_WINDOW_NAME H_PANE_PATH H_NAMESPACE H_DATA_DIR <<< "$_info"

    H_NAMESPACE="${H_NAMESPACE:-session}"
    H_DATA_DIR="${H_DATA_DIR:-$HOME/.local/share/tmux-harpoon}"
    H_ENTRY="${H_SESSION}:${H_WINDOW_ID}:${H_WINDOW_NAME}"

    local ns_key
    case "$H_NAMESPACE" in
        git)
            local git_root
            git_root=$(cd "$H_PANE_PATH" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)
            if [ -n "$git_root" ]; then
                ns_key=$(echo "$git_root" | tr '/' '_' | sed 's/^_//')
            else
                ns_key="$H_SESSION"
            fi
            ;;
        global)
            ns_key="global"
            ;;
        session|*)
            ns_key="$H_SESSION"
            ;;
    esac

    # Sanitize: replace problematic characters
    ns_key=$(echo "$ns_key" | tr ' /:' '___')
    H_LIST_FILE="${H_DATA_DIR}/${ns_key}.list"
}

# ---------------------------------------------------------------------------
# ensure_list_file — create the list file (and its parent dir) if missing
# Requires resolve_harpoon_context to have run.
# ---------------------------------------------------------------------------
ensure_list_file() {
    mkdir -p "$(dirname "$H_LIST_FILE")"
    [ -f "$H_LIST_FILE" ] || touch "$H_LIST_FILE"
}

# ---------------------------------------------------------------------------
# get_entry_count — number of entries in the active list
# ---------------------------------------------------------------------------
get_entry_count() {
    if [ -f "$H_LIST_FILE" ]; then
        wc -l < "$H_LIST_FILE" | tr -d ' '
    else
        echo "0"
    fi
}

# ---------------------------------------------------------------------------
# validate_entry — check if a harpooned entry still exists
# Returns 0 if valid, 1 if stale.
# Validates that the session exists and window_id exists in that session.
# Window IDs are stable — if the ID exists, the window is the same one.
# ---------------------------------------------------------------------------
validate_entry() {
    local entry="$1"
    local session window_id

    session=$(echo "$entry" | cut -d: -f1)
    window_id=$(echo "$entry" | cut -d: -f2)

    if ! tmux has-session -t "$session" 2>/dev/null; then
        return 1
    fi

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

# ---------------------------------------------------------------------------
# sed_inplace — portable in-place sed (BSD vs GNU)
# Usage: sed_inplace <expression> <file>
# ---------------------------------------------------------------------------
sed_inplace() {
    if [[ "$OSTYPE" == darwin* ]]; then
        sed -i '' "$1" "$2"
    else
        sed -i "$1" "$2"
    fi
}

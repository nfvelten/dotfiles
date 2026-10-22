#!/usr/bin/env bash
# Started by tmux-resurrect in place of a saved Claude pane: resume the session that pane had.
# The SessionStart hook (claude-pane-session.sh) keeps the pane -> session id map.
set -u

map="${XDG_STATE_HOME:-$HOME/.local/state}/claude-tmux-sessions.json"
where=$(tmux display -p -t "${TMUX_PANE:-}" '#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null)
id=$(jq -r --arg w "$where" '.[$w] // empty' "$map" 2>/dev/null)
if [ -n "$id" ]; then
    exec claude --resume "$id"
fi
exec claude

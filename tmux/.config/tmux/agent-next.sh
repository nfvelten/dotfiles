#!/usr/bin/env bash
# Jump to the next Claude pane that needs you: one waiting on a permission first, then one
# that finished (idle). Cycles through matches after the current pane. Bound to prefix + a.
set -u

current=$(tmux display -p '#{pane_id}')
panes=$(tmux list-panes -a -F '#{pane_id} #{@agent} #{pane_current_command}' | awk '$3 == "claude"')

# First pane in state $1 after the current one, wrapping around; never the current pane.
pick() {
    awk -v s="$1" '$2 == s { print $1 }' <<<"$panes" |
        awk -v cur="$current" '{ ids[NR] = $1; if ($1 == cur) at = NR }
            END { for (i = 1; i <= NR; i++) { j = (at + i - 1) % NR + 1; if (ids[j] != cur) { print ids[j]; exit } } }'
}

target=$(pick waiting)
[ -n "$target" ] || target=$(pick idle)
if [ -z "$target" ]; then
    tmux display-message "No agent waiting"
    exit 0
fi
tmux switch-client -t "$target"
tmux select-window -t "$target"
tmux select-pane -t "$target"

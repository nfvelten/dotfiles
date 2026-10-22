#!/usr/bin/env bash
# prefix + C: pick a project, open a tmux window there running Claude with the vault attached.
#   Enter   start Claude in the project
#   Ctrl-W  same, in a new git worktree (claude -w), for checkouts other sessions also use
# Every project shares the vault's Claude memory and loads ~/org/CLAUDE.md through --add-dir.
set -u

vault="$HOME/org"
history="${XDG_STATE_HOME:-$HOME/.local/state}/claude-here-history"
projects="$HOME/.claude/projects"
touch "$history"

# Recently used first, then every git repo under ~/code (two levels deep).
candidates() {
    tac "$history"
    echo "$vault"
    fd -H -t d -d 3 '^\.git$' "$HOME/code" -x dirname {} | grep -v '/\.' | sort
}
out=$(candidates | awk '!seen[$0]++ && system("test -d \"" $0 "\"") == 0' | sed "s|^$HOME|~|" |
    fzf --prompt 'claude> ' --expect ctrl-w --header 'Enter: here · Ctrl-W: new worktree') || exit 0
key=$(sed -n 1p <<<"$out")
pick=$(sed -n 2p <<<"$out")
[ -n "$pick" ] || exit 0
dir="${pick/#\~/$HOME}"
name=$(basename "$dir")
echo "$dir" >>"$history"
tail -n 50 "$history" >"$history.tmp" && mv "$history.tmp" "$history"

# Claude keeps memory per start folder; point new projects at the vault's so they share it.
link_memory() {
    local slug="$projects/${1//[^A-Za-z0-9]/-}"
    [ -e "$slug/memory" ] && return 0
    mkdir -p "$slug"
    ln -s "$projects/${vault//[^A-Za-z0-9]/-}/memory" "$slug/memory"
}

args=(claude)
[ "$dir" != "$vault" ] && args+=(--add-dir "$vault")
if [ "$key" = ctrl-w ]; then
    tree="$name-$(date +%m%d-%H%M)"
    args+=(-w "$tree")
    link_memory "$dir/.claude/worktrees/$tree"
    name="$name:wt"
fi
link_memory "$dir"

tmux new-window -c "$dir" -n "$name" -e CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1 "${args[@]}"

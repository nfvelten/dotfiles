#!/usr/bin/env python3
"""Render agent indicators for every pane in a tmux window."""
import re
import subprocess
import sys


def tmux(*args):
    return subprocess.check_output(['tmux', *args], text=True, stderr=subprocess.DEVNULL)


def indicator(screen, title):
    if re.search(r'(?i)press enter to confirm|do you want to proceed|would you like to|permission required|allow .*\?', screen):
        return '#[fg=yellow]!'
    if re.search(r'(?i)esc to interrupt|ctrl\+c to interrupt|esc to cancel', screen) or re.match(r'^[\u2800-\u28ff]', title):
        return '#[fg=yellow]●'
    return '#[fg=green]○'


def main():
    labels = []
    for line in tmux('list-panes', '-t', sys.argv[1], '-F', '#{pane_id}\t#{pane_current_command}\t#{pane_title}').splitlines():
        pane, command, title = line.split('\t', 2)
        if command not in ('claude', 'codex'):
            continue
        screen = tmux('capture-pane', '-p', '-t', pane).rstrip()
        # Only the footer: old approval prompts may remain above the current turn.
        screen = '\n'.join(screen.splitlines()[-12:])
        labels.append(f'{indicator(screen, title)}#[default]')
    print(' '.join(labels))


if __name__ == '__main__':
    try:
        main()
    except (subprocess.CalledProcessError, IndexError, ValueError):
        pass

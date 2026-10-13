#!/usr/bin/env python3
"""Render agent indicators for every pane in a tmux window."""
import re
import subprocess
import sys
import glob
import json
import os

def dot(color, glyph='○'):
    return f'#[fg={color}]{glyph}'


HOOK_STATES = {
    'working': lambda: dot('#b57614', '●'),
    'waiting': lambda: dot('#cc241d', '●'),
    'idle': lambda: dot('#928374'),
}


def tmux(*args):
    return subprocess.check_output(['tmux', *args], text=True, stderr=subprocess.DEVNULL)


def codex_session_title():
    """Read the current Codex thread name from its open rollout file."""
    try:
        pids = subprocess.check_output(['pgrep', '-x', 'codex'], text=True).split()
        thread_id = None
        for pid in pids:
            for fd in glob.glob(f'/proc/{pid}/fd/*'):
                try:
                    target = os.readlink(fd)
                except OSError:
                    continue
                match = re.search(r'rollout-[^/]*-([0-9a-f-]{36})\.jsonl$', target)
                if match:
                    thread_id = match.group(1)
                    break
            if thread_id:
                break
        if not thread_id:
            return ''
        with open(os.path.expanduser('~/.codex/session_index.jsonl'), encoding='utf-8') as index:
            for line in reversed(index.readlines()):
                row = json.loads(line)
                if row.get('id') == thread_id:
                    return row.get('thread_name', '').strip()
    except (OSError, subprocess.CalledProcessError, json.JSONDecodeError):
        pass
    return ''


def indicator(screen, title):
    if re.search(r'(?i)press enter to confirm|do you want to proceed|would you like to|permission required|allow .*\?', screen):
        return dot('#cc241d', '●')
    if re.search(r'(?i)esc to interrupt|ctrl\+c to interrupt|esc to cancel|\bworking\b', screen) or re.match(r'^[\u2800-\u28ff]', title):
        return dot('#b57614', '●')
    return dot('#928374')


def main():
    labels = []
    for line in tmux('list-panes', '-t', sys.argv[1], '-F', '#{pane_id}\t#{pane_current_command}\t#{@agent}\t#{pane_title}').splitlines():
        pane, command, state, title = line.split('\t', 3)
        if command not in ('claude', 'codex'):
            continue
        if command == 'codex':
            session_title = codex_session_title()
            if session_title:
                session_title = re.sub(r'^\[[^]]+\]\s*', '', session_title)
                tmux('set-window-option', '-t', pane, 'automatic-rename', 'off')
                tmux('rename-window', '-t', pane, session_title[:80])
                title = session_title
        # Claude Code hooks report state directly; screen scraping is the fallback (codex).
        # Claude reports hook state through @agent. Codex does not, so its
        # current screen is always used to avoid a stale idle attribute.
        if command == 'claude' and state in HOOK_STATES:
            labels.append(f'{HOOK_STATES[state]()}#[default]')
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

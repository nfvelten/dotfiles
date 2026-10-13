#!/usr/bin/env python3
"""List and resume tmux contexts, reusing a compositor terminal when possible."""
import hashlib
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

SEP = '\x1f'
AGENTS = {'claude', 'codex', 'aider', 'gemini', 'opencode'}
WAITING = re.compile(r'do you want|would you like|\(y/n\)|\[y/n\]|allow .*\?|press enter', re.I)
WORKING = re.compile(r'\bworking\b|kerfuffling|thinking|running|esc to interrupt|ctrl\+c to interrupt|esc to cancel', re.I)
FINISHED = re.compile(r'worked for|baked for|cooked for|cogitated for|done\s+(?:\d|now)', re.I)
# Rodapés e molduras das TUIs de agente que não dizem o que está acontecendo.
NOISE = re.compile(r'^[\s─━╌═│╭╮╰╯-]*$|^\s*[❯>›]|shift\+tab|for shortcuts|esc to interrupt|auto mode|\[caveman\]|update available|ctrl\s*\+|⏎|^\s*\S\s+\w+…\s*\(', re.I)

def run(args):
    return subprocess.run(args, capture_output=True, text=True, timeout=5)

def tmux(*args):
    result = run(['tmux', *args])
    if result.returncode:
        raise ValueError(result.stderr.strip() or 'Could not reach tmux')
    return result.stdout

def activity(target):
    text = run(['tmux', 'capture-pane', '-p', '-t', target]).stdout
    lines = [l.rstrip() for l in text.splitlines()]
    footer = '\n'.join(lines[-12:])
    question = next((l for l in reversed(lines[-12:]) if WAITING.search(l)), None)
    line = question or next((l for l in reversed(lines) if not NOISE.search(l)), '')
    # Ignore animated/clock-like footer lines when tracking real activity.
    stable = '\n'.join(l for l in lines if not re.search(r'Working \(|Ask Codex to do anything|Update available!', l, re.I))
    working = question is None and bool(WORKING.search(footer)) and not FINISHED.search(footer)
    return dict(waiting=question is not None, working=working, line=line.strip(' ⎿●✻✳*·│')[:160], digest=hashlib.md5(stable.encode()).hexdigest())

def listing():
    fields = ['session_id', 'session_name', 'window_id', 'window_index', 'window_name', 'window_active', 'pane_title', 'pane_current_command', 'pane_current_path', '@agent']
    result = run(['tmux', 'list-windows', '-a', '-F', SEP.join('#{' + f + '}' for f in fields)])
    if result.returncode:
        if 'no server running' in result.stderr or 'No such file' in result.stderr:
            return []
        raise ValueError(result.stderr.strip())
    rows = []
    for line in result.stdout.splitlines():
        values = line.split(SEP)
        if len(values) != len(fields):
            continue
        d = dict(zip(fields, values))
        title = d['window_name'] if d['pane_current_command'] == 'codex' else (d['pane_title'] or d['window_name'])
        subtitle = d['session_name'] + ' · ' + d['window_index'] + ': ' + d['window_name'] + ' · ' + d['pane_current_command'] + ' · ' + d['pane_current_path']
        row = dict(title=title[:180], subtitle=subtitle[:400], keywords=subtitle[:400], tmuxSession=d['session_id'], tmuxWindow=d['window_id'], sessionName=d['session_name'], active=d['window_active'] == '1', paneCommand=d['pane_current_command'], panePath=d['pane_current_path'], icon='utilities-terminal')
        if d['pane_current_command'] in AGENTS:
            details = activity(d['session_id'] + ':' + d['window_id'])
            row.update(agent=d['pane_current_command'], agentState=d['@agent'], **details)
        rows.append(row)
    return rows

def terminal_for(clients, windows, parents, session):
    candidates = sorted(clients, key=lambda c: c['session'] != session)
    for client in candidates:
        pid = client['pid']
        seen = set()
        while pid and pid not in seen:
            seen.add(pid)
            window = next((w for w in windows if w['pid'] == pid), None)
            if window:
                return client, window
            pid = parents.get(pid)
    return None

def resume(session, window, mode=''):
    if mode == '--no-anim':
        # The dock already morphed into the scratchpad: hypr-toggle-special shows it without the
        # slide (and doesn't hand it back to the dock, which is still open).
        os.environ['YERBA_SPECIAL_NOANIM'] = '1'
    if not re.fullmatch(r'\$\d+', session) or not re.fullmatch(r'@\d+', window):
        raise ValueError('Invalid tmux target')
    if not any(r['tmuxSession'] == session and r['tmuxWindow'] == window for r in listing()):
        raise ValueError('That window is gone; refresh the list')
    clients = []
    for line in tmux('list-clients', '-F', '#{client_pid}' + SEP + '#{client_tty}' + SEP + '#{session_id}').splitlines():
        pid, tty, sid = line.split(SEP)
        clients.append(dict(pid=int(pid), tty=tty, session=sid))
    result = run(['hyprctl', 'clients', '-j'])
    if result.returncode:
        raise ValueError('Could not query desktop terminals')
    windows = json.loads(result.stdout)
    if not any(w.get('title') == '__scratchtmux' for w in windows):
        subprocess.run([str(Path.home()/'.local/bin/scratchtmux'), '--show', session], check=True, timeout=8)
        for _ in range(30):
            windows = json.loads(run(['hyprctl', 'clients', '-j']).stdout)
            clients = []
            for line in tmux('list-clients', '-F', '#{client_pid}' + SEP + '#{client_tty}' + SEP + '#{session_id}').splitlines():
                pid, tty, sid = line.split(SEP)
                clients.append(dict(pid=int(pid), tty=tty, session=sid))
            if any(w.get('title') == '__scratchtmux' for w in windows) and clients:
                break
            time.sleep(0.1)
    windows = [w for w in windows if w.get('title') == '__scratchtmux']
    parents = {}
    for line in run(['ps', '-eo', 'pid=,ppid=']).stdout.splitlines():
        pid, parent = line.split()
        parents[int(pid)] = int(parent)
    match = terminal_for(clients, windows, parents, session)
    tmux('select-window', '-t', session + ':' + window)
    if match:
        client, terminal = match
        tmux('switch-client', '-c', client['tty'], '-t', session)
        workspace = terminal.get('workspace', {}).get('name', '')
        if workspace.startswith('special:'):
            name = workspace.split(':', 1)[1]
            monitors = json.loads(run(['hyprctl', 'monitors', '-j']).stdout)
            if not any(m.get('specialWorkspace', {}).get('name') == workspace for m in monitors):
                result = run([str(Path.home()/'.local/bin/scratchtmux'), '--show', session])
                if result.returncode:
                    raise ValueError(result.stderr or result.stdout)
        result = run(['hyprctl', 'eval', 'hl.dispatch(hl.dsp.focus({window=' + json.dumps('address:' + terminal['address']) + '}))'])
        if result.returncode:
            raise ValueError(result.stderr or result.stdout)
    else:
        raise ValueError('The Super + C terminal is not ready yet; try again')
    return dict(ok=True)

if __name__ == '__main__':
    try:
        print(json.dumps(listing() if sys.argv[1] == 'list' else resume(*sys.argv[2:]), ensure_ascii=False))
    except Exception as exc:
        print(json.dumps(dict(error=str(exc)), ensure_ascii=False))
        sys.exit(1)

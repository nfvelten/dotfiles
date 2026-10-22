#!/usr/bin/env python3
"""Bounded, read-only Org search; all note mutations go through live Emacs."""
import datetime as dt
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import unicodedata

ROOT = Path(os.environ.get('YERBA_ORG_ROOT', str(Path.home() / 'org'))).resolve()
MONTHS = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro']

# Combining diacritics (U+0300–U+036F) cover Portuguese accents; translate is far faster than a per-char filter.
COMBINING = dict.fromkeys(range(0x300, 0x370))

def fold(s):
    return unicodedata.normalize('NFD', s.casefold()).translate(COMBINING)

def today_path():
    d = dt.date.today()
    return ROOT / 'Daily Notes' / str(d.year) / MONTHS[d.month - 1] / (d.strftime('%d-%m-%Y') + '.org')

def documents():
    if not ROOT.is_dir():
        raise ValueError('Org vault not found')
    for base, dirs, files in os.walk(ROOT):
        dirs[:] = sorted(d for d in dirs if not d.startswith('.') and not Path(base, d).is_symlink())
        for name in sorted(files):
            path = Path(base, name)
            if not name.endswith('.org') or path.is_symlink():
                continue
            try:
                if path.stat().st_size > 2_000_000:
                    continue
                yield path, path.read_text(encoding='utf-8'), path.stat().st_mtime
            except (OSError, UnicodeError):
                continue

def row(path, title, line=1, subtitle=''):
    return dict(title=title[:180], subtitle=subtitle[:240], keywords=subtitle[:240], orgPath=str(path), orgLine=line, icon='text-x-generic', kind='Note')

class SearchIndex:
    """Process-local index; stat each query, reread only changed Org files."""
    def __init__(self):
        self.cache = {}

    def records(self):
        if not ROOT.is_dir():
            self.cache.clear()
            raise ValueError('Org vault not found')
        live = set()
        for base, dirs, files in os.walk(ROOT):
            dirs[:] = sorted(d for d in dirs if not d.startswith('.') and not Path(base, d).is_symlink())
            for name in sorted(files):
                path = Path(base, name)
                if not name.endswith('.org') or path.is_symlink():
                    continue
                try:
                    stat = path.stat()
                    if stat.st_size > 2_000_000:
                        continue
                    stamp = (stat.st_mtime_ns, stat.st_ctime_ns, stat.st_size, stat.st_ino)
                    cached = self.cache.get(path)
                    if cached is None or cached[0] != stamp:
                        body = path.read_text(encoding='utf-8')
                        lines = body.splitlines()
                        title = next((s.split(':', 1)[1].strip() for s in lines if s.lower().startswith('#+title:')), path.stem)
                        tags = ' '.join(s for s in lines if s.lower().startswith('#+filetags:'))
                        rel = str(path.relative_to(ROOT))
                        cached = (stamp, (path, lines, title, rel, fold(title + ' ' + rel + ' ' + tags), fold(body)))
                        self.cache[path] = cached
                    live.add(path)
                    yield cached[1]
                except (OSError, UnicodeError):
                    continue
        self.cache = {path: value for path, value in self.cache.items() if path in live}


def search(query, index=None):
    terms = fold(query).split()
    if not terms:
        return []
    index = index if index is not None else SearchIndex()
    found = []
    for path, lines, title, rel, meta, folded in index.records():
        if all(t in meta for t in terms):
            score = 0 if fold(title) == fold(query) else 1
            found.append((score, row(path, title, 1, rel)))
            continue
        # Folding every line is the slow part; skip documents that can't match at all.
        if not all(t in meta or t in folded for t in terms):
            continue
        heading, heading_line = title, 1
        matches = 0
        seen = set()
        for n, line in enumerate(lines, 1):
            if re.match(r'^\*+ ', line):
                heading, heading_line = re.sub(r'^\*+ ', '', line), n
            text = fold(meta + ' ' + heading + ' ' + line)
            if all(t in text for t in terms) and heading_line not in seen:
                seen.add(heading_line)
                found.append((2 if n == heading_line else 3, row(path, heading, heading_line, title + ' · ' + line.strip())))
                matches += 1
                if matches >= 2:
                    break
    return [r for _, r in sorted(found, key=lambda x: (x[0], fold(x[1]['title'])))[:40]]

def recent_paths():
    """Same files and filters as documents(), newest first, from stat alone (no reads)."""
    if not ROOT.is_dir():
        raise ValueError('Org vault not found')
    found = []
    for base, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if not d.startswith('.') and not Path(base, d).is_symlink()]
        for name in files:
            path = Path(base, name)
            if not name.endswith('.org') or path.is_symlink():
                continue
            try:
                info = path.stat()
            except OSError:
                continue
            if info.st_size <= 2_000_000:
                found.append((info.st_mtime, path))
    return sorted(found, key=lambda x: x[0], reverse=True)

def home():
    # The dock shows 3 recent notes and today's tasks: read only those files, not the whole vault.
    today = today_path()
    recent = []
    tasks = []
    wanted = []
    for mtime, path in recent_paths():
        if len(wanted) >= 3 and path != today:
            continue
        try:
            body = path.read_text(encoding='utf-8')
        except (OSError, UnicodeError):
            continue
        if len(wanted) < 3:
            wanted.append((path, body, mtime))
        elif path == today:
            wanted.append((path, body, mtime))
    for path, body, mtime in wanted:
        title = next((s.split(':', 1)[1].strip() for s in body.splitlines() if s.lower().startswith('#+title:')), path.stem)
        item = row(path, title, 1, str(path.relative_to(ROOT)))
        preview = [line for line in body.splitlines() if line.strip() and not line.startswith('#+')][:14]
        clean = []
        for line in preview:
            line = re.sub(r'\[\[[^]\n]+\]\[([^]\n]+)\]\]', r'\1', line)
            line = re.sub(r'^\*+ ', '', line)
            line = re.sub(r'\*([^*\n]+)\*', r'\1', line)
            line = line.replace('- [ ] ', '□ ').replace('- [X] ', '☑ ')
            if not line.startswith(':'):
                clean.append(line)
        item['preview'] = '\n'.join(clean)[:1600]
        recent.append((mtime, item))
        if path == today:
            for n, line in enumerate(body.splitlines(), 1):
                match = re.match(r'^\s*- \[ \] (\S.*)', line)
                if match:
                    tasks.append(row(path, match[1], n, "Today's note"))
    return dict(today=str(today), tasks=tasks[:8], taskCount=len(tasks), recent=[r for _, r in sorted(recent, key=lambda x: x[0], reverse=True)[:3]])

def elisp(value):
    return json.dumps(value, ensure_ascii=False)

def panel_tty():
    def query(what):
        return json.loads(subprocess.check_output(['hyprctl', what, '-j'], text=True, timeout=3))
    windows = query('clients')
    panel = next((w for w in windows if w.get('title') == '__emacsnote'), None)
    shown = any(m.get('specialWorkspace', {}).get('name') == 'special:emacsnote' for m in query('monitors'))
    if not panel or not shown:
        subprocess.run([str(Path.home() / '.local/bin/scratchematic')], check=True, timeout=8)
    for _ in range(40):
        panel = next((w for w in query('clients') if w.get('title') == '__emacsnote'), None)
        if panel:
            processes = subprocess.check_output(['ps', '-eo', 'pid=,ppid=,tty=,comm='], text=True, timeout=3)
            tree = [line.split(None, 3) for line in processes.splitlines() if len(line.split(None, 3)) == 4]
            descendants = {str(panel['pid'])}
            for _depth in range(8):
                descendants.update(pid for pid, parent, tty, comm in tree if parent in descendants)
            for pid, parent, tty, comm in tree:
                if pid in descendants and comm == 'emacsclient' and tty != '?':
                    subprocess.run(['hyprctl', 'eval', 'hl.dispatch(hl.dsp.focus({window=' + json.dumps('address:' + panel['address']) + '}))'], capture_output=True, timeout=3)
                    return '/dev/' + tty
        time.sleep(0.1)
    raise ValueError('Emacs side panel did not become ready')

def emacs(form):
    bridge = str(Path(__file__).with_name('org-bridge.el'))
    opening = form.startswith('(yerba-org-open ') or form.startswith('(yerba-elfeed-open-url ') or form == '(yerba-org-today)'
    tty = panel_tty() if opening else None
    body = '(progn (load ' + elisp(bridge) + ' nil t) ' + form + ')'
    if tty:
        body = '(let ((frame (seq-find (lambda (f) (equal (frame-parameter f (quote tty)) ' + elisp(tty) + ')) (frame-list)))) (unless frame (error "Emacs panel unavailable")) (with-selected-frame frame ' + body + '))'
    result = subprocess.run(['emacsclient', '--socket-name=default', '--eval', body], capture_output=True, text=True, timeout=20)
    if result.returncode:
        raise ValueError(result.stderr.strip()[-500:] or 'Could not reach Emacs')
    return dict(ok=True)

def main(args):
    action = args[0]
    if action == 'search':
        return search(args[1][:300])
    if action == 'home':
        return home()
    if action == 'today':
        return emacs('(yerba-org-today)')
    if action == 'capture':
        text = args[1].strip()
        if not text or len(text) > 2000 or '\n' in text or '\r' in text:
            raise ValueError('Write a single-line task of up to 2000 characters')
        return emacs('(yerba-org-capture ' + elisp(text) + ')')
    if action in ('open', 'link'):
        path = Path(args[1]).resolve()
        if not path.is_relative_to(ROOT) or path.suffix != '.org' or not path.is_file():
            raise ValueError('Note is invalid or was removed')
        line = max(1, int(args[2]))
        if action == 'link':
            link = '[[file:' + str(path) + '::' + str(line) + '][' + path.stem + ']]'
            subprocess.run(['wl-copy', '--type', 'text/plain'], input=link, text=True, check=True, timeout=5)
            return dict(ok=True)
        return emacs('(yerba-org-open ' + elisp(str(path)) + ' ' + str(line) + ')')
    if action == 'open-elfeed':
        url = args[1].strip()
        if not re.match(r'^https?://', url, re.I):
            raise ValueError('URL is invalid')
        return emacs('(yerba-elfeed-open-url ' + elisp(url) + ')')
    raise ValueError('Unknown action')

def serve_search(stream, output):
    index = SearchIndex()
    for line in stream:
        query = ""
        try:
            query = json.loads(line)
            if not isinstance(query, str):
                raise ValueError('Search query must be a string')
            result = dict(query=query, entries=search(query[:300], index))
        except Exception as exc:
            result = dict(query=query, entries=[], error=str(exc))
        print(json.dumps(result, ensure_ascii=False), file=output, flush=True)


if __name__ == '__main__':
    try:
        if sys.argv[1:] == ['serve-search']:
            serve_search(sys.stdin, sys.stdout)
        else:
            print(json.dumps(main(sys.argv[1:]), ensure_ascii=False))
    except Exception as exc:
        print(json.dumps(dict(error=str(exc)), ensure_ascii=False))
        sys.exit(1)

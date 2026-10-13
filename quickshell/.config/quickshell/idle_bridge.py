#!/usr/bin/env python3
"""Off-work suggestions for the dashboard: the book open in zathura, a Radiola episode, fresh RSS."""
import json
import os
import re
import sqlite3
import subprocess
import sys
import time
import urllib.request
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.parse import urlparse

HOME = Path.home()
ZATHURA = HOME / '.local/share/zathura/bookmarks.sqlite'
RADIOLA = HOME / '.local/share/radiola/db.sqlite'
FEEDS = Path(os.environ.get('YERBA_ORG_ROOT', str(HOME / 'org'))) / 'elfeed.org'
CACHE = Path(os.environ.get('XDG_CACHE_HOME', str(HOME / '.cache'))) / 'yerba' / 'rss.json'
WEEK = 7 * 86400

def query(db, sql):
    if not db.exists():
        return []
    # Read-only and immutable-safe: the owning apps may hold the database open.
    with sqlite3.connect(f'file:{db}?mode=ro', uri=True, timeout=1) as conn:
        return conn.execute(sql).fetchall()

def book():
    for path, page in query(ZATHURA, 'select file, page from fileinfo order by time desc limit 20'):
        if path.startswith('/tmp/') or not Path(path).exists() or not path.lower().endswith(('.pdf', '.epub', '.djvu')):
            continue
        return dict(file=path, title=Path(path).stem, page=page + 1)
    return None

def podcast():
    rows = query(RADIOLA, """
        select e.id, e.title, f.title, e.pos, e.duration from episodes e join feeds f on f.id = e.feed_id
        where e.played = 0 order by (e.pos > 0) desc, e.published desc limit 1""")
    if not rows:
        return None
    eid, title, feed, pos, duration = rows[0]
    return dict(id=eid, title=title, feed=feed, resume=pos > 0, pos=pos, duration=duration)

def feed_urls(text):
    """Feed URLs from elfeed.org, skipping the podcast section (Radiola owns podcasts)."""
    urls, skip_level = [], None
    for line in text.splitlines():
        heading = re.match(r'^(\*+)\s+(.*)$', line)
        if not heading:
            continue
        level, body = len(heading[1]), heading[2]
        if skip_level is not None and level <= skip_level:
            skip_level = None
        if ':podcast:' in body:
            skip_level = level
            continue
        url = re.search(r'https?://[^\s\]]+', body)
        if url and skip_level is None:
            urls.append(url[0])
    return urls

def parse(url, data):
    root = ET.fromstring(data)
    strip = lambda tag: tag.rsplit('}', 1)[-1]
    channel = next((c for c in root.iter() if strip(c.tag) in ('channel', 'feed')), root)
    source = next((c.text for c in channel if strip(c.tag) == 'title' and c.text), url)
    items = []
    for node in root.iter():
        if strip(node.tag) not in ('item', 'entry'):
            continue
        fields = {strip(c.tag): c for c in node}
        title = (fields.get('title').text or '').strip() if 'title' in fields else ''
        link = fields.get('link')
        href = (link.get('href') or link.text or '').strip() if link is not None else ''
        stamp = next((fields[k].text for k in ('published', 'updated', 'pubDate', 'date') if k in fields and fields[k].text), '')
        if title and href:
            items.append(dict(title=title, link=href, source=source.strip(), date=stamp.strip()))
    return items[:10]

def to_epoch(stamp):
    from email.utils import parsedate_to_datetime
    from datetime import datetime
    for parse_date in (parsedate_to_datetime, lambda s: datetime.fromisoformat(s.replace('Z', '+00:00'))):
        try:
            return parse_date(stamp).timestamp()
        except (TypeError, ValueError):
            continue
    return 0

def fetch(url):
    request = urllib.request.Request(url, headers={'User-Agent': 'yerba-shell/1.0'})
    try:
        with urllib.request.urlopen(request, timeout=8) as response:
            return parse(url, response.read())
    except Exception:
        return []

def load_cache():
    try:
        return json.loads(CACHE.read_text())
    except (OSError, ValueError):
        return dict(updated=0, items=[], opened=[])

def refresh_rss():
    if not FEEDS.exists():
        return dict(items=0)
    with ThreadPoolExecutor(max_workers=8) as pool:
        items = [item for batch in pool.map(fetch, feed_urls(FEEDS.read_text())) for item in batch]
    for item in items:
        item['epoch'] = to_epoch(item['date'])
    cache = load_cache()
    cache.update(updated=time.time(), items=sorted(items, key=lambda i: i['epoch'], reverse=True)[:60])
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    CACHE.write_text(json.dumps(cache))
    return dict(items=len(cache['items']))

def rss(now=None):
    cache, now = load_cache(), now or time.time()
    opened = set(cache.get('opened', []))
    fresh = [i for i in cache['items'] if i['link'] not in opened and now - i.get('epoch', 0) < WEEK]
    # One per source first, so a high-volume feed (TechCrunch) doesn't crowd out the rest.
    picked, sources = [], set()
    for item in fresh:
        if item.get('source') not in sources:
            picked.append(item)
            sources.add(item.get('source'))
    return dict(items=picked[:4], stale=now - cache.get('updated', 0) > 1800)

def rss_target(link):
    """Choose the reader for a feed item."""
    host = (urlparse(link).hostname or '').lower().removeprefix('www.')
    if host == 'youtu.be' or host == 'youtube.com' or host.endswith('.youtube.com'):
        return 'mpv'
    return 'emacs'

def open_rss(link):
    cache = load_cache()
    cache['opened'] = ([link] + [l for l in cache.get('opened', []) if l != link])[:300]
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    CACHE.write_text(json.dumps(cache))
    if rss_target(link) == 'mpv':
        command = ['uwsm', 'app', '--', 'mpv', link]
    else:
        command = [sys.executable, str(Path(__file__).with_name('org_bridge.py')), 'open-elfeed', link]
    subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    return dict(ok=True)

if __name__ == '__main__':
    try:
        command = sys.argv[1] if len(sys.argv) > 1 else 'idle'
        if command == 'idle':
            result = dict(book=book(), podcast=podcast(), rss=rss())
        elif command == 'refresh-rss':
            result = refresh_rss()
        elif command == 'open-rss':
            result = open_rss(sys.argv[2])
        else:
            raise ValueError('Unknown command')
        print(json.dumps(result, ensure_ascii=False))
    except Exception as exc:
        print(json.dumps(dict(error=str(exc)), ensure_ascii=False))
        sys.exit(1)

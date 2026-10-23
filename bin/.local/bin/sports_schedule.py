"""NBA/MLB imports with explicit failures, atomic ICS writes and safe reconciliation."""
from datetime import date, datetime, timedelta, timezone
import json
from pathlib import Path
import re
import sys
from urllib.request import Request, urlopen

HEADERS = {'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) CalendarSync'}

def fetch(url):
    with urlopen(Request(url, headers=HEADERS), timeout=10) as response:
        return json.load(response)

def text(value):
    return str(value).replace('\\', '\\\\').replace('\r', '').replace('\n', '\\n').replace(';', '\\;').replace(',', '\\,')

def normalize(league, game):
    uid = str(game['id'] if league == 'nba' else game['gamePk'])
    if not uid.isdigit():
        raise ValueError('Invalid game id')
    if league == 'nba':
        comp = game['competitions'][0]
        status = game.get('status', {}).get('type', {})
        label = status.get('description', '')
        uncertain = comp.get('timeValid') is False or 'TBD' in status.get('name', '')
        competitors = comp['competitors']
        away = next(c['team'] for c in competitors if c.get('homeAway') == 'away')
        home = next(c['team'] for c in competitors if c.get('homeAway') == 'home')
        tv = ', '.join(n for b in comp.get('broadcasts', []) for n in b.get('names', []))
        start_raw = game['date']
        duration = 150
        icon = '🏀'
    else:
        status = game.get('status', {})
        label = status.get('detailedState', '')
        uncertain = bool(status.get('startTimeTBD'))
        away, home = game['teams']['away']['team'], game['teams']['home']['team']
        tv = ', '.join(dict.fromkeys(b['name'] for b in game.get('broadcasts', []) if b.get('type') == 'TV'))
        start_raw = game['gameDate']
        duration = 180
        icon = '⚾'
    start = datetime.fromisoformat(start_raw.replace('Z', '+00:00'))
    if start.tzinfo is None:
        raise ValueError('Game has no timezone')
    start = start.astimezone(timezone.utc)
    cancelled = bool(re.search('cancel|postpon|suspend', label, re.I))
    summary = f"{icon} {away.get('abbreviation', away.get('name', '?'))} @ {home.get('abbreviation', home.get('name', '?'))}"
    description = ' | '.join(filter(None, [tv, label, f"{away.get('name', '')} at {home.get('name', '')}"]))
    return dict(uid=uid, start=start, end=start+timedelta(minutes=duration), summary=summary,
                description=description, cancelled=cancelled, uncertain=uncertain)

def write_event(directory, league, event):
    path = directory / (event['uid'] + '.ics')
    if event['uncertain']:
        path.unlink(missing_ok=True)
        return
    def fmt(dt): return dt.strftime('%Y%m%dT%H%M%SZ')
    suffix = 'nba-espn' if league == 'nba' else 'mlb-statsapi'
    lines = ['BEGIN:VCALENDAR', 'VERSION:2.0', f'PRODID:-//{league}-schedule-sync//EN', 'BEGIN:VEVENT',
             f"UID:{event['uid']}@{suffix}", f"DTSTART:{fmt(event['start'])}", f"DTEND:{fmt(event['end'])}",
             'SUMMARY:' + text(event['summary']), 'DESCRIPTION:' + text(event['description']),
             'STATUS:' + ('CANCELLED' if event['cancelled'] else 'CONFIRMED'), 'END:VEVENT', 'END:VCALENDAR']
    temporary = path.with_suffix('.tmp')
    temporary.write_text('\r\n'.join(lines) + '\r\n')
    temporary.replace(path)

def reconcile(directory, league, ids, first, last):
    suffix = '@nba-espn' if league == 'nba' else '@mlb-statsapi'
    for path in directory.glob('*.ics'):
        if path.stem in ids:
            continue
        content = path.read_text()
        start = re.search(r'^DTSTART:(\d{8})T', content, re.M)
        if suffix in content and start and first.strftime('%Y%m%d') <= start[1] <= last.strftime('%Y%m%d'):
            path.unlink()

def main(league):
    directory = Path.home() / '.local/share/khal/calendars' / ('sports_' + league)
    directory.mkdir(parents=True, exist_ok=True)
    first = date.today() - timedelta(days=1)
    last = date.today() + timedelta(days=90)
    ids, failures = set(), 0
    days = [first + timedelta(days=i) for i in range((last-first).days+1)] if league == 'nba' else [first]
    for day in days:
        try:
            if league == 'nba':
                payload = fetch(f'https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard?dates={day:%Y%m%d}&limit=20')
                games = payload['events']
            else:
                payload = fetch(f'https://statsapi.mlb.com/api/v1/schedule?sportId=1&startDate={first}&endDate={last}&hydrate=team,broadcasts(all)')
                games = [g for entry in payload['dates'] for g in entry['games']]
            if not isinstance(games, list):
                raise ValueError('Invalid schedule')
            for game in games:
                event = normalize(league, game)
                write_event(directory, league, event)
                ids.add(event['uid'])
        except Exception as exc:
            failures += 1
            print(f'{league}: {day}: {type(exc).__name__}', file=sys.stderr)
    if not failures:
        reconcile(directory, league, ids, first, last)
    print(f'{league}: {len(ids)} games, {failures} failed requests; previous data retained on failure')
    return 1 if failures else 0

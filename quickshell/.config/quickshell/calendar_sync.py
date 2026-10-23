#!/usr/bin/env python3
"""Independent calendar sources, bounded retries, and atomic status for the dock."""
import concurrent.futures
import configparser
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import time

LABELS = {'nba': 'NBA', 'mlb': 'MLB', 'chess': 'Chess', 'esports': 'Esports',
          'annual': 'Annual sports', 'prefix': 'Football names'}
SCRIPTS = {'nba':'nba-schedule-sync', 'mlb':'mlb-schedule-sync', 'chess':'chess-cal-sync',
           'esports':'esports-cal-sync', 'annual':'sports-annual-sync'}

def read_state(path):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return {'sources': {}}

def write_state(path, state):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(state, ensure_ascii=False))
    os.chmod(temporary, 0o600)
    temporary.replace(path)

def run_job(command):
    try:
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, timeout=240)
        # Source output stays in the journal; status never copies URLs/credentials.
        if result.stdout:
            print(result.stdout[-4000:], flush=True)
        return '' if result.returncode == 0 else f'Failed (exit {result.returncode}); see the journal'
    except subprocess.TimeoutExpired:
        return 'Tempo limite de quatro minutos'
    except OSError:
        return 'Command not found'

def jobs_for(home):
    config_path = Path(os.environ.get('VDIRSYNCER_CONFIG', home / '.config/vdirsyncer/config'))
    config = configparser.ConfigParser(interpolation=None)
    config.read(config_path)
    pairs = [section[5:] for section in config.sections() if section.startswith('pair ')]
    jobs = {pair: ['vdirsyncer', 'sync', pair] for pair in pairs}
    if not jobs:
        jobs['vdirsyncer'] = ['vdirsyncer', 'sync']
    jobs.update({key:[str(home / '.local/bin' / script)] for key, script in SCRIPTS.items()})
    return jobs

def sync(jobs, path, runner=run_job, force=False, after=None):
    state = read_state(path)
    sources = state.setdefault('sources', {})
    now = int(time.time()*1000)
    # On automatic retry, avoid downloading successful sources again for six hours.
    retry = state.get('partial', False) and not force
    pending = {k: v for k, v in jobs.items() if not (retry and not sources.get(k, {}).get('error')
               and now - sources.get(k, {}).get('lastSuccess', 0) < 6*3600000)}
    state.update(running=True, startedAt=now, partial=False)
    for key in pending:
        source = sources.setdefault(key, {})
        source.update(label=LABELS.get(key, key.removesuffix('_pair').replace('_', ' ')),
                      lastAttempt=now, running=True)
    write_state(path, state)
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        futures = {pool.submit(runner, cmd): key for key, cmd in pending.items()}
        for future in concurrent.futures.as_completed(futures):
            key = futures[future]
            try:
                error = future.result()
            except Exception:
                error = 'Falha inesperada na fonte'
            source = sources[key]
            source.update(running=False, error=error)
            if not error:
                source['lastSuccess'] = int(time.time()*1000)
            write_state(path, state)
    for key, command in (after or {}).items():
        source = sources.setdefault(key, {})
        source.update(label=LABELS.get(key,key),lastAttempt=int(time.time()*1000),running=True)
        write_state(path,state)
        error=runner(command)
        source.update(running=False,error=error)
        if not error: source['lastSuccess']=int(time.time()*1000)
    state.update(running=False, finishedAt=int(time.time()*1000),
                 partial=any(sources.get(k, {}).get('error') for k in list(jobs) + list(after or {})))
    write_state(path, state)
    return 1 if state['partial'] else 0

def main():
    home = Path.home()
    directory = Path(os.environ.get('XDG_STATE_HOME', home / '.local/state')) / 'yerba'
    directory.mkdir(parents=True, exist_ok=True)
    with (directory / 'calendar-sync.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return 0
        return sync(jobs_for(home), directory / 'calendar-sync.json', force='--force' in sys.argv,
                    after={'prefix':[str(home / '.local/bin/football-calendar-prefix')]})


if __name__ == '__main__':
    sys.exit(main())

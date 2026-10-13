#!/usr/bin/env python3
"""On-demand cliphist adapter. Never send clipboard payloads through QML or a shell."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time


def run(argv, **kwargs):
    return subprocess.run(argv, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10, **kwargs)


def entries():
    raw = run(['cliphist', 'list']).stdout.decode('utf-8', errors='replace')
    result = []
    for line in raw.splitlines():
        key, sep, preview = line.partition('\t')
        if not sep or not key.isdecimal():
            continue
        binary = preview.startswith('[[ binary data ')
        image = binary and re.search(r'\b(png|jpe?g|gif|webp|bmp|tiff?)\b', preview, re.I)
        kind = 'Image' if image else 'File' if binary else 'Text'
        result.append(dict(clipboardId=key, title=(kind + ' · ' + image.group(1).upper()) if image else preview,
                           subtitle=preview.strip('[] ') if binary else 'Copy text to clipboard',
                           keywords=preview, kind=kind,
                           icon='image-x-generic' if image else 'text-x-generic'))
    return result


def preview(key):
    if not re.fullmatch(r'[0-9]+', key):
        raise ValueError('Invalid clipboard entry')
    data = run(['cliphist', 'decode'], input=(key + '\t\n').encode()).stdout
    mime = run(['file', '--brief', '--mime-type', '-'], input=data).stdout.decode().strip()
    runtime = Path(os.environ['XDG_RUNTIME_DIR']) / 'yerba-clipboard'
    runtime.mkdir(mode=0o700, exist_ok=True)
    for old in runtime.glob('preview-*'):
        old.unlink(missing_ok=True)
    if mime.startswith('image/'):
        path = runtime / ('preview-' + key)
        path.write_bytes(data)
        path.chmod(0o600)
        return {'id': key, 'image': path.as_uri(), 'text': '', 'mime': mime}
    try:
        text = data.decode('utf-8')
    except UnicodeDecodeError:
        text = 'Binary content · ' + str(len(data)) + ' bytes'
    return {'id': key, 'image': '', 'text': text, 'mime': mime}


def copy(key):
    if not re.fullmatch(r'[0-9]+', key):
        raise ValueError('Invalid clipboard entry')
    data = run(['cliphist', 'decode'], input=(key + '\t\n').encode()).stdout
    if not data:
        raise ValueError('Clipboard entry is empty or no longer available')
    mime = run(['file', '--brief', '--mime-type', '-'], input=data).stdout.decode().strip()
    if not mime.startswith('image/'):
        try:
            data.decode('utf-8')
            mime = 'text/plain;charset=utf-8'
        except UnicodeDecodeError:
            pass
    runtime = Path(os.environ['XDG_RUNTIME_DIR']) / 'yerba-clipboard'
    runtime.mkdir(mode=0o700, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=runtime) as content:
        content.write(data)
        content.flush()
        # Only this clipboard owner is replaced. Screenshot ownership is untouched.
        subprocess.run(['systemctl', '--user', 'stop', 'yerba-clipboard-owner.service'],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
        command = ['systemd-run', '--user', '--quiet', '--collect', '--service-type=exec',
                   '--unit=yerba-clipboard-owner', '--property=StandardInput=file:' + content.name,
                   '--property=StandardOutput=null', '--property=StandardError=null']
        for name in ('WAYLAND_DISPLAY', 'XDG_RUNTIME_DIR', 'DISPLAY'):
            if name in os.environ:
                command.append('--setenv=' + name + '=' + os.environ[name])
        run(command + ['/usr/bin/wl-copy', '--foreground', '--type', mime])
        # Verify bytes, not just an advertised MIME type, before closing the dock.
        for _ in range(20):
            pasted = subprocess.run(['wl-paste', '--no-newline', '--type', mime],
                                    stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=2)
            if pasted.returncode == 0 and pasted.stdout == data:
                return {'ok': True, 'mime': mime}
            time.sleep(0.05)
        raise RuntimeError('Could not verify clipboard contents')


if __name__ == '__main__':
    try:
        if sys.argv[1:] == ['list']:
            result = entries()
        elif len(sys.argv) == 3 and sys.argv[1] == 'preview':
            result = preview(sys.argv[2])
        elif len(sys.argv) == 3 and sys.argv[1] == 'copy':
            result = copy(sys.argv[2])
        else:
            raise ValueError('Usage: clipboard.py list | copy ID')
        print(json.dumps(result, ensure_ascii=False))
    except (ValueError, RuntimeError, OSError, subprocess.SubprocessError) as exc:
        # Do not expose clipboard content or subprocess arguments in notifications/logs.
        print(json.dumps({'error': 'Clipboard operation failed. Please try again.'}))
        sys.exit(1)

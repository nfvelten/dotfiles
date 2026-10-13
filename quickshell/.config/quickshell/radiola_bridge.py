#!/usr/bin/env python3
"""Small read/control bridge for the Radiola player card."""
import json
import os
import socket
import sqlite3
import sys
from pathlib import Path

HOME = Path.home()
DB = Path(os.environ.get("RADIOLA_DATA", HOME / ".local/share/radiola")) / "db.sqlite"
SOCKET = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "radiola-mpv.sock"


def mpv(command, request_id):
    if not SOCKET.exists():
        return None
    try:
        with socket.socket(socket.AF_UNIX) as sock:
            sock.settimeout(0.35)
            sock.connect(str(SOCKET))
            sock.sendall((json.dumps({"command": command, "request_id": request_id}) + "\n").encode())
            data = b""
            while b"\n" not in data:
                data += sock.recv(4096)
            return json.loads(data.splitlines()[0])
    except (OSError, ValueError, json.JSONDecodeError):
        return None


def value(name, request_id):
    response = mpv(["get_property", name], request_id) or {}
    return response.get("data")


def episode_for(path):
    if not path or not DB.exists():
        return None
    with sqlite3.connect(DB) as db:
        return db.execute(
            "select id,title,url,file,feed_id,pos from episodes where url = ? or file = ? limit 1",
            (path, path),
        ).fetchone()


def current():
    if value("idle-active", 5) is True:
        return {"available": False}
    path = value("path", 1)
    episode = episode_for(path)
    if not episode:
        return {"available": False}
    episode_id, title, url, file, feed_id, stored_pos = episode
    with sqlite3.connect(DB) as db:
        feed = db.execute("select title from feeds where id = ?", (feed_id,)).fetchone()
    position = value("time-pos", 2)
    duration = value("duration", 3)
    paused = value("pause", 4)
    return {
        "available": True,
        "id": episode_id,
        "title": title,
        "feed": feed[0] if feed else "Podcast",
        "position": float(position if isinstance(position, (int, float)) else stored_pos or 0),
        "duration": float(duration if isinstance(duration, (int, float)) else 0),
        "playing": not bool(paused),
    }


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "current"
    if action == "current":
        result = current()
    elif action == "toggle":
        result = {"ok": mpv(["cycle", "pause"], 10) is not None}
    elif action == "stop":
        result = {"ok": mpv(["stop"], 11) is not None}
    else:
        raise SystemExit(f"unknown action: {action}")
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()

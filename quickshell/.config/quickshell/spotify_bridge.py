#!/usr/bin/env python3
"""Small Spotify Web API bridge for the Quickshell media page."""
import datetime as dt
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import hashlib
import time
import urllib.error
import urllib.parse
import urllib.request

CONFIG = Path(os.environ.get("SPOTIFY_PLAYER_CONFIG", str(Path.home() / ".config/spotify-player/app.toml")))
CACHE = Path(os.environ.get("SPOTIFY_PLAYER_CACHE", str(Path.home() / ".cache/spotify-player")))
CLIENT_ID = "541049711e1c434fb4e14425de0aae7a"

ART_CACHE = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "yerba" / "spotify-art"

def cache_art(url):
    if not url:
        return ""
    path = ART_CACHE / (hashlib.sha256(url.encode()).hexdigest() + ".png")
    try:
        if not path.exists():
            ART_CACHE.mkdir(parents=True, exist_ok=True)
            request = urllib.request.Request(url, headers={"User-Agent": "yerba-shell"})
            raw = urllib.request.urlopen(request, timeout=8).read(8 * 1024 * 1024)
            from PIL import Image  # only on a cache miss: importing PIL costs ~260 ms per call
            image = Image.open(io.BytesIO(raw)).convert("RGB")
            image.thumbnail((1200, 1200))
            image.save(path, format="PNG", optimize=True)
        return path.as_uri()
    except Exception:
        return url

def token_file():
    return next(CACHE.glob("*_token.json"), None)

def token():
    path = token_file()
    if not path:
        raise ValueError("Spotify player não está autenticado")
    data = json.loads(path.read_text())
    expires = data.get("expires_at", "")
    if expires:
        try:
            if dt.datetime.fromisoformat(expires.replace("Z", "+00:00")) <= dt.datetime.now(dt.timezone.utc):
                form = urllib.parse.urlencode({"grant_type": "refresh_token", "refresh_token": data["refresh_token"], "client_id": CLIENT_ID}).encode()
                request = urllib.request.Request("https://accounts.spotify.com/api/token", data=form, method="POST")
                fresh = json.loads(urllib.request.urlopen(request, timeout=8).read())
                data.update(fresh)
                data["expires_at"] = (dt.datetime.now(dt.timezone.utc) + dt.timedelta(seconds=int(fresh.get("expires_in", 3600)))).isoformat().replace("+00:00", "Z")
                path.write_text(json.dumps(data))
        except (KeyError, ValueError, urllib.error.URLError, urllib.error.HTTPError):
            pass
    return data["access_token"]

def api(path, params):
    limit_file = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "yerba" / "spotify-rate-limit.json"
    if limit_file.exists():
        try:
            remaining = int(json.loads(limit_file.read_text()).get("until", 0) - time.time())
        except (ValueError, TypeError):
            remaining = 0
        if remaining > 0:
            raise ValueError(f"Spotify API em cooldown local; aguarde {remaining}s")
    query = urllib.parse.urlencode(params)
    request = urllib.request.Request("https://api.spotify.com/v1/" + path + "?" + query, headers={"Authorization": "Bearer " + token()})
    for attempt in range(3):
        try:
            return json.loads(urllib.request.urlopen(request, timeout=10).read())
        except urllib.error.HTTPError as error:
            if error.code == 429:
                retry = error.headers.get("Retry-After", "alguns")
                try:
                    limit_file.parent.mkdir(parents=True, exist_ok=True)
                    limit_file.write_text(json.dumps({"until": time.time() + int(retry)}))
                except (TypeError, ValueError, OSError):
                    pass
                raise ValueError(f"Spotify API está limitando este cliente; aguarde {retry}s")
            if error.code == 403:
                raise ValueError("Spotify recusou esta operação (HTTP 403); autentique novamente no spotify_player")
            raise ValueError("Spotify API respondeu HTTP " + str(error.code))
        except urllib.error.URLError as error:
            if attempt == 2:
                raise ValueError("Spotify indisponível: falha de rede/DNS")
            time.sleep(1 + attempt)

def search(query):
    query = query.strip()
    cache_dir = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "yerba"
    cache_dir.mkdir(parents=True, exist_ok=True)
    cache_file = cache_dir / ("spotify-search-" + hashlib.sha256(query.casefold().encode()).hexdigest()[:16] + ".json")
    # Keep keyboard-driven searches from repeatedly consuming the API quota.
    if cache_file.exists() and time.time() - cache_file.stat().st_mtime < 90:
        return json.loads(cache_file.read_text())
    # Spotify's current API contract accepts at most 10 results per search.
    data = api("search", {"q": query[:160], "type": "track", "limit": 10})
    result = [dict(id=item["id"], title=item["name"], subtitle=" · ".join(a["name"] for a in item["artists"]) + " · " + item["album"]["name"], art=(item["album"].get("images") or [{}])[0].get("url", ""), duration=item.get("duration_ms", 0)) for item in data.get("tracks", {}).get("items", [])]
    cache_file.write_text(json.dumps(result, ensure_ascii=False))
    return result

def playlists():
    current_user = api("me", {}).get("id", "")
    result = []
    offset = 0
    while True:
        data = api("me/playlists", {"limit": 50, "offset": offset})
        for item in data.get("items", []):
            owner_id = (item.get("owner") or {}).get("id", "")
            if current_user and owner_id != current_user:
                continue
            count = item.get("items", item.get("tracks", {})).get("total", 0)
            result.append(dict(id=item["id"], title=item["name"], subtitle=f"Playlist · {count} faixas", art=(item.get("images") or [{}])[0].get("url", ""), kind="playlist", owned=True))
        if not data.get("next") or not data.get("items"):
            break
        offset += len(data["items"])
    return result

def playlist_tracks(playlist_id):
    result, offset = [], 0
    try:
        while True:
            data = api(f"playlists/{urllib.parse.quote(playlist_id, safe='')}/items", {"limit": 50, "offset": offset})
            rows = data.get("items", [])
            for row in rows:
                item = row.get("item") or row.get("track") or {}
                if not item.get("id"):
                    continue
                result.append(dict(id=item["id"], title=item.get("name", "Faixa"), subtitle=" · ".join(a["name"] for a in item.get("artists", [])) + " · " + item.get("album", {}).get("name", ""), art=(item.get("album", {}).get("images") or [{}])[0].get("url", ""), duration=item.get("duration_ms", 0), kind="track"))
            if not rows or not data.get("next") or len(result) >= 2000:
                break
            offset += len(rows)
    except ValueError as error:
        if "HTTP 403" in str(error):
            return {"error": "Spotify não permite ler as faixas desta playlist com o token atual; tente uma playlist própria ou reautentique."}
        raise
    return result

def local_play(command):
    """Wake the lightweight Spotify device before using its local playback CLI."""
    connect = ["spotify_player", "connect", "--name", "spotify-player"]
    woke = subprocess.run(connect, capture_output=True, text=True, timeout=12)
    if "No device" in woke.stderr:
        # The daemon stays alive but loses its Connect device after a failed
        # session renewal (e.g. DNS outage), so only a restart brings it back.
        subprocess.run(["systemctl", "--user", "restart", "spotify-player.service"], timeout=15)
        for _ in range(15):
            time.sleep(1)
            if subprocess.run(connect, capture_output=True, text=True, timeout=12).returncode == 0:
                break
    local =subprocess.run(command, capture_output=True, text=True, timeout=15)
    if local.returncode != 0:
        raise ValueError(local.stderr.strip() or "Não foi possível iniciar a faixa no daemon local")

def play(track_id):
    body = json.dumps({"uris": [f"spotify:track:{track_id}"]}).encode()
    request = urllib.request.Request(
        "https://api.spotify.com/v1/me/player/play",
        data=body,
        headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"},
        method="PUT",
    )
    try:
        urllib.request.urlopen(request, timeout=10).read()
    except urllib.error.HTTPError as error:
        if error.code in (404, 429):
            local_play(["spotify_player", "playback", "start", "track", "--id", track_id])
            return {"ok": True, "local": True}
        if error.code == 403:
            raise ValueError("Spotify não permitiu controlar a reprodução; autentique novamente")
        raise ValueError("Spotify playback respondeu HTTP " + str(error.code))
    return {"ok": True}

def play_playlist(playlist_id, position):
    body = json.dumps({
        "context_uri": "spotify:playlist:" + playlist_id,
        "offset": {"position": max(0, int(position))},
        "position_ms": 0,
    }).encode()
    request = urllib.request.Request(
        "https://api.spotify.com/v1/me/player/play",
        data=body,
        headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"},
        method="PUT",
    )
    try:
        urllib.request.urlopen(request, timeout=10).read()
    except urllib.error.HTTPError as error:
        if error.code in (404, 429):
            local_play(["spotify_player", "playback", "start", "context", "--id", playlist_id, "playlist"])
            return {"ok": True, "local": True}
        if error.code == 403:
            raise ValueError("Spotify não permitiu controlar a reprodução; autentique novamente")
        raise ValueError("Spotify playback respondeu HTTP " + str(error.code))
    return {"ok": True}

def current():
    def mpris_current():
        """Use the local player when Spotify Web API has no Connect device."""
        command = ["playerctl", "-p", "spotify_player", "metadata", "--format",
                   "{{status}}\t{{title}}\t{{artist}}\t{{album}}\t{{mpris:artUrl}}\t{{position}}\t{{mpris:length}}\t{{shuffle}}"]
        result = subprocess.run(command, capture_output=True, text=True, timeout=3)
        if result.returncode != 0 or not result.stdout.strip():
            return {"available": False}
        fields = result.stdout.rstrip("\n").split("\t")
        if len(fields) < 7 or not fields[1]:
            return {"available": False}
        def micros(value):
            try:
                return int(float(value) / 1000)
            except (TypeError, ValueError):
                return 0
        return {"available": True, "playing": fields[0].lower() == "playing", "shuffle": len(fields) > 7 and fields[7].lower() == "true",
                "title": fields[1], "artist": fields[2], "album": fields[3],
                "art": fields[4], "position": micros(fields[5]), "duration": micros(fields[6])}

    request = urllib.request.Request(
        "https://api.spotify.com/v1/me/player",
        headers={"Authorization": "Bearer " + token()},
    )
    try:
        response = urllib.request.urlopen(request, timeout=8)
        if response.status == 204:
            return mpris_current()
        data = json.loads(response.read())
    except urllib.error.HTTPError as error:
        if error.code == 204:
            return mpris_current()
        if error.code == 429:
            return mpris_current()
        raise ValueError("Spotify player respondeu HTTP " + str(error.code))
    item = data.get("item") or {}
    artists = item.get("artists") or []
    images = item.get("album", {}).get("images") or []
    if not item.get("id"):
        return {"available": False}
    return {"available": True, "playing": bool(data.get("is_playing")),
            "shuffle": bool(data.get("shuffle_state")),
            "title": item.get("name", ""),
            "artist": " · ".join(a.get("name", "") for a in artists),
            "album": item.get("album", {}).get("name", ""),
            "art": cache_art(images[0].get("url", "")) if images else "",
            "position": data.get("progress_ms", 0),
            "duration": item.get("duration_ms", 0)}

def queue():
    data = api("me/player/queue", {})
    result = []
    for item in data.get("queue", [])[:50]:
        result.append(dict(id=item.get("id", ""), title=item.get("name", "Faixa"),
                           subtitle=" · ".join(a.get("name", "") for a in item.get("artists", [])),
                           art=cache_art((item.get("album", {}).get("images") or [{}])[0].get("url", ""))))
    return result

def recent():
    data = api("me/player/recently-played", {"limit": 20})
    result = []
    for row in data.get("items", []):
        item = row.get("track") or {}
        result.append(dict(id=item.get("id", ""), title=item.get("name", "Faixa"),
                           subtitle=" · ".join(a.get("name", "") for a in item.get("artists", [])),
                           art=cache_art((item.get("album", {}).get("images") or [{}])[0].get("url", ""))))
    return result

def seek(position_ms):
    request = urllib.request.Request(
        "https://api.spotify.com/v1/me/player/seek?position_ms=" + str(max(0, int(position_ms))),
        headers={"Authorization": "Bearer " + token()}, method="PUT")
    try:
        urllib.request.urlopen(request, timeout=8).read()
    except urllib.error.HTTPError as error:
        raise ValueError("Spotify seek respondeu HTTP " + str(error.code))
    return {"ok": True}

def shuffle():
    # Toggle the current player state in place. The spotify_player `playback shuffle`
    # command starts the playlist context again, which unexpectedly jumps to track 1.
    data = api("me/player", {})
    state = "false" if data.get("shuffle_state") else "true"
    request = urllib.request.Request(
        "https://api.spotify.com/v1/me/player/shuffle?state=" + state,
        headers={"Authorization": "Bearer " + token()},
        method="PUT",
    )
    try:
        urllib.request.urlopen(request, timeout=8).read()
    except urllib.error.HTTPError as error:
        raise ValueError("Spotify shuffle respondeu HTTP " + str(error.code))
    return {"ok": True}

if __name__ == "__main__":
    try:
        action = sys.argv[1]
        argument = sys.argv[2] if len(sys.argv) > 2 else ""
        result = search(argument) if action == "search" and argument.strip() else playlists() if action == "playlists" else playlist_tracks(argument) if action == "playlist" and argument else play(argument) if action == "play" and argument else current() if action == "current" else play_playlist(argument, sys.argv[3]) if action == "play-playlist" and argument and len(sys.argv) > 3 else queue() if action == "queue" else recent() if action == "recent" else seek(argument) if action == "seek" and argument else shuffle() if action == "shuffle" else {"error": "Ação inválida"}
        print(json.dumps(result, ensure_ascii=False))
    except Exception as error:
        print(json.dumps({"error": str(error)}, ensure_ascii=False))
        sys.exit(1)

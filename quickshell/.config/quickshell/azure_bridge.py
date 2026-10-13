#!/usr/bin/env python3
"""Read-only adapter for the user's existing air-boards CLI."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

CACHE = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "yerba" / "azure-boards.json"
MAX_AGE = 300
ITEM_RE = re.compile(r"^\s*\[(\d+)\]\s+([^|]+)\|\s*([^|]+)\|\s*(.*?)\s*$")


def parse(text):
    rows = []
    lines = text.splitlines()
    for index, line in enumerate(lines):
        match = ITEM_RE.match(line)
        if not match:
            continue
        item_id, kind, state, assigned = match.groups()
        title = lines[index + 1].strip() if index + 1 < len(lines) else ""
        rows.append({
            "id": item_id,
            "title": title,
            "subtitle": f"{kind.strip()} · {state.strip()}",
            "state": state.strip(),
            "assigned": assigned.strip(),
            "url": f"https://dev.azure.com/ORG/PROJECT/_workitems/edit/{item_id}",
        })
    return rows


def parse_detail(text):
    values = {}
    description = []
    in_description = False
    for line in text.splitlines():
        if line.startswith("Description:"):
            in_description = True
            continue
        if in_description:
            description.append(line.strip())
            continue
        if ":" in line:
            key, value = line.split(":", 1)
            values[key.strip().lower()] = value.strip()
    fields = {}
    for line in text.splitlines():
        match = re.match(r"^\s+(\S+)\s{2,}(.+)$", line)
        if match:
            fields[match.group(1)] = match.group(2).strip()
    return {
        "id": values.get("id", "") or fields.get("System.Id", ""),
        "type": values.get("type", "") or fields.get("System.WorkItemType", ""),
        "title": values.get("title", "") or fields.get("System.Title", ""),
        "state": values.get("state", "") or fields.get("System.State", ""),
        "assigned": values.get("assigned", "") or fields.get("System.AssignedTo", ""),
        "area": values.get("area", "") or fields.get("System.AreaPath", ""),
        "iteration": values.get("iteration", "") or fields.get("System.IterationPath", ""),
        "description": "\n".join(description).strip() or fields.get("System.Description", ""),
        "acceptance": fields.get("Microsoft.VSTS.Common.AcceptanceCriteria", ""),
        "tags": fields.get("System.Tags", ""),
        "priority": fields.get("Microsoft.VSTS.Common.Priority", ""),
    }


def parse_comments(text):
    comments = []
    current = None
    for line in text.splitlines():
        match = re.match(r"^\[(\d{4}-\d{2}-\d{2})\]\s+(.+):$", line.strip())
        if match:
            if current:
                current["text"] = "\n".join(current.pop("_lines")).strip()
                comments.append(current)
            current = {"date": match.group(1), "author": match.group(2), "_lines": []}
        elif current and line.strip():
            current["_lines"].append(line.strip())
    if current:
        current["text"] = "\n".join(current.pop("_lines")).strip()
        comments.append(current)
    return comments


def read_cache():
    try:
        data = json.loads(CACHE.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) and isinstance(data.get("items"), list) else None
    except (OSError, ValueError):
        return None


def write_cache(payload):
    try:
        CACHE.parent.mkdir(parents=True, exist_ok=True)
        CACHE.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
    except OSError:
        pass


def main(action):
    cached = read_cache()
    if action == "cache":
        return cached or {"savedAt": 0, "items": []}
    if action.startswith("detail:"):
        item_id = action.split(":", 1)[1]
        if cached:
            details = cached.get("details", {}).get(item_id)
            if details and details.get("title") and "comments" in details and time.time() - float(details.get("savedAt", 0)) < MAX_AGE:
                return details
        cli = shutil.which("air-boards") or str(Path.home() / ".local/bin/air-boards")
        try:
            result = subprocess.run([cli, "show", item_id, "--all"], capture_output=True, text=True, timeout=15, check=False)
            if result.returncode != 0:
                raise RuntimeError(result.stderr.strip() or "air-boards show failed")
            detail = parse_detail(result.stdout)
            comments = subprocess.run([cli, "comments", item_id], capture_output=True, text=True, timeout=15, check=False)
            detail["comments"] = parse_comments(comments.stdout) if comments.returncode == 0 else []
            detail["savedAt"] = time.time()
            payload = cached or {"savedAt": 0, "items": []}
            payload.setdefault("details", {})[item_id] = detail
            write_cache(payload)
            return detail
        except (OSError, subprocess.TimeoutExpired, RuntimeError) as exc:
            return {"id": item_id, "error": str(exc)}
    if action != "mine":
        raise ValueError("Unknown action")
    if cached and time.time() - float(cached.get("savedAt", 0)) < MAX_AGE:
        return cached
    cli = shutil.which("air-boards") or str(Path.home() / ".local/bin/air-boards")
    try:
        result = subprocess.run([cli, "mine"], capture_output=True, text=True, timeout=15, check=False)
        if result.returncode != 0:
            raise RuntimeError(result.stderr.strip() or "air-boards failed")
        items = parse(result.stdout)
        payload = {"savedAt": time.time(), "items": items}
        write_cache(payload)
        return payload
    except (OSError, subprocess.TimeoutExpired, RuntimeError) as exc:
        if cached:
            cached["stale"] = True
            cached["error"] = str(exc)
            return cached
        return {"savedAt": 0, "items": [], "error": str(exc)}


if __name__ == "__main__":
    try:
        print(json.dumps(main(sys.argv[1] if len(sys.argv) > 1 else "mine"), ensure_ascii=False))
    except Exception as exc:
        print(json.dumps({"items": [], "error": str(exc)}, ensure_ascii=False))
        raise SystemExit(1)

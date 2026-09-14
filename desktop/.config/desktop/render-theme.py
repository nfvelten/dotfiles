#!/usr/bin/env python3
"""Aplica a paleta aos arquivos do desktop."""
from pathlib import Path
from string import Template
import tomllib

root = Path(__file__).resolve().parent
config = Path.home() / ".config"
mode = __import__("sys").argv[1] if len(__import__("sys").argv) > 1 else "dark"
theme = tomllib.loads((root / f"theme-{mode}.toml").read_text())
targets = {
    "quickshell.qml": "quickshell/Theme.qml",
    "hyprlock.conf": "hypr/hyprlock.conf",
    "ghostty.conf": "../.local/state/desktop/ghostty.conf",
    "btop.theme": "btop/themes/current.theme",
}

for template, destination in targets.items():
    source = (root / "templates" / template).read_text()
    target = config / destination
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(Template(source).substitute(theme))
    print(target)

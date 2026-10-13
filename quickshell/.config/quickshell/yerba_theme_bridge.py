#!/usr/bin/env python3
"""Importa paletas Omarchy sem instalar o Omarchy."""
from __future__ import annotations

import json
import os
import re
import signal
import subprocess
import sys
import tomllib
from pathlib import Path

HOME = Path.home()
THEME_FILE = HOME / ".config/quickshell/Theme.qml"
ROOTS = [
    HOME / ".local/share/yerba/themes",
    HOME / ".config/omarchy/themes",
    Path("/usr/share/omarchy/themes"),
]


def palette(path: Path) -> dict[str, str]:
    data = tomllib.loads(path.read_text())
    aliases = {
        "background": ("background", "bg", "dark_background"),
        "foreground": ("foreground", "fg", "light_foreground"),
        "accent": ("accent", "color4", "blue"),
        "muted": ("muted", "dark_foreground", "color8", "bright_black"),
    }
    def value(names: tuple[str, ...], fallback: str) -> str:
        for name in names:
            raw = data.get(name)
            if isinstance(raw, str) and raw:
                return raw.removeprefix("#")
        return fallback
    out = {key: value(names, fallback) for key, names in aliases.items()
           for fallback in ({"background": "2a2e1e", "foreground": "dce0d9", "accent": "a67c52", "muted": "4f5b4a"}[key],)}
    out.update({key: value((key,), fallback) for key, fallback in {
        "black": "1d2118", "red": "c25d44", "green": "8f9f52", "yellow": "c49a5a",
        "blue": "7797b5", "magenta": "a67c91", "cyan": "78a9a0", "white": "dce0d9",
        "bright_black": "4f5b4a", "bright_red": "d8785f", "bright_green": "b0bd68",
        "bright_yellow": "d8b878", "bright_blue": "98b4d0", "bright_magenta": "c39bb2",
        "bright_cyan": "9ccdc2", "bright_white": "f4f1e8",
    }.items()})
    out["surface"] = out["muted"]
    out["surfaceHover"] = out["accent"]
    out["border"] = out["accent"]
    return out


def themes() -> list[dict[str, str]]:
    found: dict[str, dict[str, str]] = {}
    for root in ROOTS:
        if not root.is_dir():
            continue
        for colors in root.glob("*/colors.toml"):
            name = colors.parent.name
            sample = palette(colors)
            found.setdefault(name, {"name": name, "path": str(colors), "preview": str(colors.parent / "preview.png") if (colors.parent / "preview.png").exists() else "", "colors": [sample[key] for key in ("background", "surface", "accent", "foreground", "muted")]})
    for mode in ("dark", "light"):
        colors = HOME / f".config/desktop/theme-{mode}.toml"
        if colors.exists():
            sample = palette(colors)
            found.setdefault("Yerba " + mode, {"name": "Yerba " + mode, "path": str(colors), "preview": "", "colors": [sample[key] for key in ("background", "surface", "accent", "foreground", "muted")]})
    return sorted(found.values(), key=lambda item: item["name"].lower())


def render(colors: Path) -> None:
    colors_data = palette(colors)
    colors_data["error"] = colors_data["red"]
    colors_data["font"] = "JetBrainsMono Nerd Font"
    ansi = [colors_data[name] for name in ("black", "red", "green", "yellow", "blue", "magenta", "cyan", "white", "bright_black", "bright_red", "bright_green", "bright_yellow", "bright_blue", "bright_magenta", "bright_cyan", "bright_white")]
    qml = """import QtQuick\nQtObject {{\n    readonly property color background: \"#{background}\"\n    readonly property color surface: \"#{surface}\"\n    readonly property color surfaceHover: \"#{surfaceHover}\"\n    readonly property color foreground: \"#{foreground}\"\n    readonly property color muted: \"#{muted}\"\n    readonly property color border: \"#{border}\"\n    readonly property color accent: \"#{accent}\"\n    readonly property int radius: 12\n    readonly property string font: \"JetBrainsMono Nerd Font\"\n    readonly property var ansi: [{ansi}]\n}}\n""".format(**colors_data, ansi=", ".join(f'\"#{color}\"' for color in ansi))
    THEME_FILE.write_text(qml)
    state_dir = HOME / ".local/state/desktop"
    state_dir.mkdir(parents=True, exist_ok=True)
    theme_toml = state_dir / "yerba-imported-theme.toml"
    lines = [f'{key} = "{value}"' for key, value in colors_data.items() if key not in {"surface", "surfaceHover", "border"}]
    theme_toml.write_text("\n".join(lines) + "\n")
    renderer = HOME / "code/personal/dotfiles/desktop/.config/desktop/render-theme.py"
    env = os.environ.copy()
    env["YERBA_THEME_FILE"] = str(theme_toml)
    subprocess.run(["python3", str(renderer), "dark"], check=True, env=env)
    subprocess.run(["tmux", "source-file", str(HOME / ".config/tmux/tmux.conf")], check=False)
    emacs_theme = "terere" if colors_data["background"].lower() in {"fbf1c7", "f9f5d7"} else "yerba-mate"
    subprocess.run(["emacsclient", "--socket-name=default", "--eval", f"(progn (mapc #'disable-theme custom-enabled-themes) (load-theme '{emacs_theme} t))"], check=False)
    # Recarrega as instâncias Ghostty já abertas dos scratchpads para que elas
    # consumam o novo ghostty.conf sem fechar o tmux nem o Emacs.
    try:
        clients = json.loads(subprocess.check_output(["hyprctl", "clients", "-j"], text=True))
        for client in clients:
            if client.get("title") in {"__scratchtmux", "__emacsnote"} and client.get("pid"):
                os.kill(int(client["pid"]), signal.SIGUSR2)
    except (OSError, ValueError, subprocess.SubprocessError, json.JSONDecodeError):
        pass


def import_repo(url: str) -> None:
    slug = re.sub(r"[^a-z0-9-]+", "-", url.rstrip("/").rsplit("/", 1)[-1].removesuffix(".git").lower()).strip("-")
    if not slug:
        raise SystemExit("invalid theme URL")
    destination = HOME / ".local/share/yerba/themes" / slug
    destination.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["git", "clone", "--depth", "1", url, str(destination)], check=True)


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] == "list":
        print(json.dumps(themes(), ensure_ascii=False))
    elif sys.argv[1] == "apply":
        render(Path(sys.argv[2]).expanduser())
        print("ok")
    elif sys.argv[1] == "import" and len(sys.argv) > 2:
        import_repo(sys.argv[2])
        print("ok")

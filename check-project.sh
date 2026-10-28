#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
for script in "$ROOT/build.sh" "$ROOT/scripts/build-in-container.sh" "$ROOT/scripts/punksway-live-login.sh" "$ROOT/scripts/punksway-polkit-agent.sh" "$ROOT/scripts/install-caelestia.sh"; do
    bash -n "$script"
    echo "shell syntax OK: ${script#"$ROOT"/}"
done
python3 - "$ROOT" <<'PYTEST'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
json.load((root / "config/waybar/config.jsonc").open(encoding="utf-8"))
print("JSON syntax OK: config/waybar/config.jsonc")
required = [
    "assets/render_wallpaper.py",
    "config/calamares/settings.conf",
    "config/calamares/modules/unpackfs.conf",
    "config/calamares/branding/punk/branding.desc",
    "config/calamares/branding/punk/show.html",
    "config/punksway-installer.desktop",
    "packages.txt",
    "config/sway/config",
    "config/hypr/hyprland.conf",
    "config/hypr/README.md",
    "scripts/install-caelestia.sh",
    "config/waybar/style.css",
    "config/wofi/style.css",
    "config/foot/foot.ini",
    "config/mako/config",
    "config/xdg-desktop-portal/portals.conf",
    "config/punksway-quickstart.desktop",
    "QUICKSTART.txt",
]
missing = [name for name in required if not (root / name).is_file()]
if missing:
    raise SystemExit("Missing required files: " + ", ".join(missing))
print(f"required assets OK: {len(required)} files")
packages = [line.split('#', 1)[0].strip() for line in (root / "packages.txt").read_text().splitlines()]
packages = [line for line in packages if line]
if len(packages) != len(set(packages)):
    raise SystemExit("Duplicate package names in packages.txt")
print(f"package list OK: {len(packages)} packages")
PYTEST
file "$ROOT/assets/neon-punk.png"
#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
for script in "$ROOT/build.sh" "$ROOT/scripts/build-in-container.sh" "$ROOT/scripts/punksway-polkit-agent.sh" "$ROOT/scripts/install-caelestia.sh"; do
    bash -n "$script"
    echo "shell syntax OK: ${script#"$ROOT"/}"
done
python3 - "$ROOT" <<'PYTEST'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
required = [
    "assets/render_wallpaper.py",
    "config/calamares/settings.conf",
    "config/calamares/modules/unpackfs.conf",
    "config/calamares/branding/punk/branding.desc",
    "config/calamares/branding/punk/show.html",
    "config/punksway-installer.desktop",
    "packages.txt",
    "config/hypr/hyprland.conf",
    "config/hypr/hypridle.conf",
    "config/hypr/hyprpaper.conf",
    "config/waybar/dock.jsonc",
    "config/waybar/dock.css",
    "config/zsh/.zshrc",
    "config/fastfetch/config.jsonc",
    "config/fastfetch/fastfetch-logo.txt",
    "config/caelestia/shell.json",
    "config/hypr/README.md",
    "scripts/install-caelestia.sh",
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
if "linux-generic" not in packages:
    raise SystemExit("Missing linux-generic metapackage; Ubuntu 26.10 kernel updates may not be pulled in")
build_script = (root / "build.sh").read_text()
container_script = (root / "scripts/build-in-container.sh").read_text()
if "ubuntu:26.10" not in build_script or "26\\.10" not in container_script:
    raise SystemExit("Build scripts do not consistently target Ubuntu 26.10")
if "linux-image-7\\\\.3" not in container_script:
    raise SystemExit("Build script is missing Linux 7.3 kernel package validation")
print(f"package list and Ubuntu 26.10 kernel requirement OK: {len(packages)} packages")
# The current Waybar config is JSON-compatible JSONC; parse it to catch syntax errors.
waybar_config = root / "config/waybar/config.jsonc"
try:
    json.loads(waybar_config.read_text())
except json.JSONDecodeError as exc:
    raise SystemExit(f"Invalid Waybar config at line {exc.lineno}, column {exc.colno}: {exc.msg}")
dock_config = root / "config/waybar/dock.jsonc"
try:
    json.loads(dock_config.read_text())
except json.JSONDecodeError as exc:
    raise SystemExit(f"Invalid Waybar dock config at line {exc.lineno}, column {exc.colno}: {exc.msg}")
fastfetch_config = root / "config/fastfetch/config.jsonc"
try:
    json.loads(fastfetch_config.read_text())
except json.JSONDecodeError as exc:
    raise SystemExit(f"Invalid Fastfetch config at line {exc.lineno}, column {exc.colno}: {exc.msg}")
if not (root / "config/fastfetch/fastfetch-logo.txt").read_text().strip():
    raise SystemExit("Fastfetch ASCII logo is empty")
caelestia_config = root / "config/caelestia/shell.json"
try:
    json.loads(caelestia_config.read_text())
except json.JSONDecodeError as exc:
    raise SystemExit(f"Invalid Caelestia config at line {exc.lineno}, column {exc.colno}: {exc.msg}")
print("Waybar, Fastfetch and Caelestia JSON syntax OK")
PYTEST
python3 -m py_compile "$ROOT/assets/render_wallpaper.py"
echo "Python syntax OK: assets/render_wallpaper.py"
if [[ -f "$ROOT/assets/neon-punk.png" ]]; then
    file "$ROOT/assets/neon-punk.png"
else
    echo "Wallpaper PNG not present yet; build.sh generates it before building the ISO."
fi
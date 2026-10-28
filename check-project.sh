#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

for script in "$ROOT/build.sh" "$ROOT/scripts/build-in-container.sh" "$ROOT/scripts/punksway-polkit-agent.sh" "$ROOT/scripts/install-caelestia.sh"; do
    bash -n "$script"
    echo "shell syntax OK: ${script#"$ROOT"/}"
done

python3 - "$ROOT" <<'PYTEST'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
required = [
    "assets/render_wallpaper.py",
    "assets/render_plymouth.py",
    "config/plymouth/tomos.plymouth",
    "config/plymouth/tomos.script",
    "config/calamares/settings.conf",
    "config/calamares/modules/unpackfs.conf",
    "config/calamares/branding/punk/branding.desc",
    "config/calamares/branding/punk/show.html",
    "config/punksway-installer.desktop",
    "packages.txt",
    "config/hypr/hyprland.conf",
    "config/hypr/hypridle.conf",
    "config/hypr/hyprpaper.conf",
    "config/waybar/config.jsonc",
    "config/waybar/style.css",
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

packages = [
    line.split("#", 1)[0].strip()
    for line in (root / "packages.txt").read_text().splitlines()
]
packages = [line for line in packages if line]
if len(packages) != len(set(packages)):
    raise SystemExit("Duplicate package names in packages.txt")
for package in ("linux-generic", "plymouth", "plymouth-themes"):
    if package not in packages:
        raise SystemExit(f"Missing required package: {package}")

build_script = (root / "build.sh").read_text()
container_script = (root / "scripts/build-in-container.sh").read_text()
if "ubuntu:26.10" not in build_script or r"26\.10" not in container_script:
    raise SystemExit("Build scripts do not consistently target Ubuntu 26.10")
if r"linux-image-7\.3" not in container_script:
    raise SystemExit("Build script is missing Linux 7.3 kernel validation")
if 'python3 "$PROJECT/assets/render_plymouth.py"' not in container_script:
    raise SystemExit("Build script does not generate the Plymouth splash assets")
if "update-initramfs -u -k all" not in container_script:
    raise SystemExit("Build script does not regenerate initramfs after selecting Plymouth theme")
print(f"package and build requirements OK: {len(packages)} packages")

for rel in (
    "config/waybar/config.jsonc",
    "config/waybar/dock.jsonc",
    "config/fastfetch/config.jsonc",
    "config/caelestia/shell.json",
):
    try:
        json.loads((root / rel).read_text())
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON in {rel}, line {exc.lineno}, column {exc.colno}: {exc.msg}")
print("Waybar, Fastfetch and Caelestia JSON syntax OK")

logo = root / "config/fastfetch/fastfetch-logo.txt"
if not logo.read_text().strip():
    raise SystemExit("Fastfetch ASCII logo is empty")

plymouth_script = (root / "config/plymouth/tomos.script").read_text()
if "Plymouth.SetBootProgressFunction(update_progress)" not in plymouth_script:
    raise SystemExit("Plymouth theme has no boot-progress callback")
if "fill_image.Scale(width, 12)" not in plymouth_script:
    raise SystemExit("Plymouth progress fill does not resize with progress")
if "ModuleName=script" not in (root / "config/plymouth/tomos.plymouth").read_text():
    raise SystemExit("Plymouth theme is not configured to use the script plugin")
print("Plymouth theme and progress callback checks OK")
PYTEST

python3 -m py_compile "$ROOT/assets/render_wallpaper.py" "$ROOT/assets/render_plymouth.py"
echo "Python syntax OK: wallpaper and Plymouth renderers"
if [[ -f "$ROOT/assets/neon-punk.png" ]]; then
    file "$ROOT/assets/neon-punk.png"
else
    echo "Wallpaper PNG not present yet; build.sh generates it before building the ISO."
fi

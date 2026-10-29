#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

for script in "$ROOT/build.sh" "$ROOT/scripts/build-in-container.sh" "$ROOT/scripts/build-tomphone-deb.sh" "$ROOT/scripts/install-tomphone.sh" "$ROOT/scripts/fix-display-manager.sh" "$ROOT/scripts/enable-sddm.sh" "$ROOT/scripts/build-punksway-iso.sh" "$ROOT/scripts/punksway-polkit-agent.sh" "$ROOT/scripts/install-caelestia.sh"; do
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
    "apps/tomphone/tomphone.pro",
    "apps/tomphone/src/Main.qml",
    "apps/tomphone/src/backend.cpp",
    "apps/tomphone/src/backend.h",
    "apps/tomphone/src/theme.cpp",
    "apps/tomphone/src/theme.h",
    "apps/tomphone/src/resources.qrc",
    "apps/tomphone/debian/control",
    "apps/tomphone/share/applications/tomphone.desktop",
    "apps/tomphone/share/icons/hicolor/scalable/apps/tomphone.svg",
    "scripts/build-tomphone-deb.sh",
    "scripts/fix-display-manager.sh",
    "scripts/enable-sddm.sh",
    "scripts/install-tomphone.sh",
    "scripts/build-punksway-iso.sh",
    "config/plymouth/tomos.plymouth",
    "config/plymouth/tomos.script",
    "config/calamares/settings.conf",
    "config/calamares/modules/unpackfs.conf",
    "config/calamares/modules/displaymanager.conf",
    "config/calamares/modules/services-systemd.conf",
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
for package in ("linux-generic", "plymouth", "plymouth-themes", "sddm", "baresip", "libpulse0", "qml6-module-qtquick-controls", "qml6-module-qtquick-layouts", "qml6-module-qtquick-templates", "qml6-module-qtquick-window", "qml6-module-qtquick"):
    if package not in packages:
        raise SystemExit(f"Missing required package: {package}")

build_script = (root / "build.sh").read_text()
container_script = (root / "scripts/build-in-container.sh").read_text()
if "ubuntu:26.10" not in build_script or r"26\.10" not in container_script:
    raise SystemExit("Build scripts do not consistently target Ubuntu 26.10")
if r"linux-image-7\.3" not in container_script:
    raise SystemExit("Build script is missing Linux 7.3 kernel validation")
if "sddm.service" not in container_script or "select sddm" not in container_script:
    raise SystemExit("Build script must configure the installed SDDM display manager")
if 'python3 "$PROJECT/assets/render_plymouth.py"' not in container_script:
    raise SystemExit("Build script does not generate the Plymouth splash assets")
if "update-initramfs -u -k all" not in container_script:
    raise SystemExit("Build script does not regenerate initramfs after selecting Plymouth theme")
print(f"package and build requirements OK: {len(packages)} packages")

package_builder = (root / "scripts/build-in-container.sh").read_text()
if "scripts/build-tomphone-deb.sh" not in package_builder or "tomphone_0.1.0_amd64.deb" not in package_builder:
    raise SystemExit("Tomphone .deb is not built and installed by the ISO build")
installer = (root / "scripts/install-tomphone.sh").read_text()
if "https://codeload.github.com/Spruhantom/tomos-ubuntu" not in installer or "apt-get install -y" not in installer:
    raise SystemExit("Tomphone one-line installer is missing source download or dependency installation")
print("Tomphone curl installer checks OK")
if "dpkg-deb --root-owner-group --build" not in (root / "scripts/build-tomphone-deb.sh").read_text():
    raise SystemExit("Tomphone package builder does not create a Debian package")
print("Tomphone Ubuntu package integration checks OK")
if "systemctl --root=\"$ROOT\" set-default graphical.target" not in container_script:
    raise SystemExit("Build script does not set graphical.target as the default")
if "display-manager.service" not in container_script or "sddm.service" not in container_script:
    raise SystemExit("Build script does not configure and verify SDDM as the display manager")
if "[Autologin]" not in container_script or "User=ubuntu" not in container_script or "Session=hyprland.desktop" not in container_script:
    raise SystemExit("Live ISO SDDM autologin is not configured for the Ubuntu user and Hyprland")
if "10-punksway-live-autologin.conf" not in container_script:
    raise SystemExit("Live ISO SDDM autologin must use an explicitly live-only configuration file")
if "systemctl --root=\"$ROOT\" enable sddm.service" not in container_script:
    raise SystemExit("Build script does not enable SDDM in the live filesystem")
if "fix-display-manager.sh" not in container_script:
    raise SystemExit("Display-manager recovery helper is not installed")
for rel in ("config/calamares/modules/displaymanager.conf", "config/calamares/modules/services-systemd.conf"):
    text = (root / rel).read_text()
    if "  - sddm" not in text or "lightdm" in text:
        raise SystemExit(f"{rel} must select SDDM and must not reference LightDM")
services_config = (root / "config/calamares/modules/services-systemd.conf").read_text()
if "  - sddm" not in services_config:
    raise SystemExit("Calamares will not enable SDDM on the freshly installed system")
unpackfs = (root / "config/calamares/modules/unpackfs.conf").read_text()
if "/etc/sddm.conf.d/10-punksway-live-autologin.conf" not in unpackfs:
    raise SystemExit("Calamares must exclude live-only SDDM autologin from installed systems")
if "/cdrom/casper/filesystem.squashfs" not in unpackfs:
    raise SystemExit("Calamares unpackfs default source should be the standard filesystem.squashfs name")
if "UNPACKFS_CONFIG" not in container_script or "SQUASHFS_NAME" not in container_script[container_script.find("Match Calamares"):container_script.find("Match Calamares") + 700]:
    raise SystemExit("Build script does not align Calamares unpackfs source with the ISO squashfs filename")
print("Display-manager and Calamares source checks OK")

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

hypr = (root / "config/hypr/hyprland.conf").read_text()
if "else waybar & waybar -c ~/.config/waybar/dock.jsonc" not in hypr:
    raise SystemExit("Waybar fallback must launch the top bar in the background before launching the dock")
if "bind = $mainMod SHIFT, L, movewindow, r" in hypr:
    raise SystemExit("Hyprland Super+Shift+L is assigned to both lock and move-window actions")

qml = (root / "apps/tomphone/src/Main.qml").read_text()
for shortcut in ('sequence: "Q"', 'sequence: "Space"'):
    line = next((line for line in qml.splitlines() if shortcut in line), "")
    if "enabled: !accountDialog.visible && !number.activeFocus" not in line:
        raise SystemExit(f"Tomphone {shortcut} shortcut must be disabled while editing text or account settings")
if "onClosed: win.settingsOpen = false" not in qml:
    raise SystemExit("Tomphone account popup must reset settingsOpen when it closes")
print("Hyprland startup/keybinding and Tomphone UI regression checks OK")
PYTEST

python3 -m py_compile "$ROOT/assets/render_wallpaper.py" "$ROOT/assets/render_plymouth.py"
echo "Python syntax OK: wallpaper and Plymouth renderers"
if [[ -f "$ROOT/assets/neon-punk.png" ]]; then
    file "$ROOT/assets/neon-punk.png"
else
    echo "Wallpaper PNG not present yet; build.sh generates it before building the ISO."
fi

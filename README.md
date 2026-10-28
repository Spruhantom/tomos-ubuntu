# PunkSway 26.04 LTS

**An Ubuntu-based live OS concept with a blue-neon punk aesthetic and Sway/Wayland as the default desktop.** The project is designed to build on an Omarchy Linux host by running the image-customisation tools inside an Ubuntu 26.04 Podman container.

> This repository contains the build project, not a prebuilt multi-gigabyte ISO. Supply the official Ubuntu base ISO; the scripts generate `dist/PunkSway-26.04-amd64.iso` locally. The source ISO is never changed.

## What's included

- Sway window manager, Waybar panel, Wofi app launcher and Foot terminal.
- Custom neon-blue wallpaper, cyan focus borders, violet accents and matching Waybar, Wofi, Foot and Mako styles.
- LightDM with a Sway-first session choice.
- NetworkManager tray applet, PipeWire tools, screenshots, clipboard tools, idle locking and a quick-start guide.
- Build scripts to customise the live filesystem and preserve the source ISO's boot setup.

## Build on Omarchy Linux

Install Podman:

```bash
sudo pacman -S podman
```

Download the **Ubuntu 26.04 LTS Desktop amd64** ISO from <https://releases.ubuntu.com/26.04/>.

Run the project checks:

```bash
./check-project.sh
```

Build the ISO:

```bash
./build.sh /path/to/ubuntu-26.04-desktop-amd64.iso
```

The output and checksum are:

```text
dist/PunkSway-26.04-amd64.iso
dist/PunkSway-26.04-amd64.iso.sha256
```

**Build requirements:** x86_64 Omarchy Linux, internet access, Podman, and approximately 25–35 GB of free scratch space. The first build downloads the Ubuntu container image and installs the required tools inside it.

## Default shortcuts

| Shortcut | Action |
|---|---|
| `Super + Enter` | Terminal |
| `Super + D` or `Super + Space` | App launcher |
| `Super + Q` | Close window |
| `Super + F` | Fullscreen |
| `Super + H/J/K/L` | Move focus |
| `Super + Shift + L` | Lock screen |
| `Print` | Select a screenshot region |

## Test before installing

Boot the generated ISO in a virtual machine before installing it on physical hardware. Verify that the live Sway session, networking, audio and installer work. This project has not yet been verified by booting a generated ISO on real hardware; treat the first build as a test image and keep backups.

## Customisation

- `config/sway/config`: compositor settings and shortcuts.
- `config/waybar/`: panel layout and styles.
- `config/wofi/style.css`, `config/foot/foot.ini`, `config/mako/config`: application styling.
- `assets/render_wallpaper.py`: wallpaper generator.
- `packages.txt`: Ubuntu packages included in the image.

Ubuntu and its logos/trademarks belong to Canonical. This is an independent remix, not an official Ubuntu product. Do not redistribute the original Ubuntu ISO with this project. Configuration and original artwork are provided under the MIT License; included third-party software remains under its own licences.

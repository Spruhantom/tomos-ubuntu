# PunkSway 26.04 LTS

**An Ubuntu-based live OS concept with a blue-neon punk aesthetic and Hyprland/Wayland as the intended desktop, with no Sway components.** The project is designed to build on an Omarchy Linux host by running the image-customisation tools inside an Ubuntu 26.04 Podman container.

> This repository contains the build project, not a prebuilt multi-gigabyte ISO. Supply the official Ubuntu base ISO; the scripts generate `dist/PunkSway-26.04-amd64.iso` locally. The source ISO is never changed.

## What's included

- Hyprland/Wayland as the only supported window manager session.
- Caelestia Shell integration notes and an optional source checkout helper. Caelestia itself is not automatically built into the ISO because its Quickshell/Qt dependency versions need validation on Ubuntu 26.04.
- Custom neon-blue wallpaper, cyan focus borders, violet accents and matching Waybar, Wofi, Foot and Mako styles.
- Ly TTY display/login manager; choose the Hyprland session at login. Hyprland is the sole supported window manager.
- A custom-branded Calamares installer configuration and launch icon, plus partitioning tools. The installer configuration is experimental until tested in a VM on both UEFI and BIOS systems.
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

## Hyprland and Caelestia status

The project now includes `config/hypr/hyprland.conf` and `scripts/install-caelestia.sh`. The helper only checks out Caelestia Shell source; it does not install dependencies or compile it. Follow the current upstream requirements at <https://github.com/caelestia-dots/shell>, including the required git version of Quickshell and `caelestia-cli`. Ubuntu 26.04 compatibility is experimental and unverified. The ISO build does not yet include a working, prebuilt Caelestia Shell.

Sway has been removed from the package list and build configuration. Test the Hyprland session in a VM before using the image on hardware.

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

- `config/hypr/hyprland.conf`: experimental Hyprland session settings.
- `config/waybar/`: panel layout and styles.
- `config/wofi/style.css`, `config/foot/foot.ini`, `config/mako/config`: application styling.
- `assets/render_wallpaper.py`: wallpaper generator.
- `packages.txt`: Ubuntu packages included in the image.

Ubuntu and its logos/trademarks belong to Canonical. This is an independent remix, not an official Ubuntu product. Do not redistribute the original Ubuntu ISO with this project. Configuration and original artwork are provided under the MIT License; included third-party software remains under its own licences.

#!/usr/bin/env bash
# Recover the graphical login configuration on a running Tom OS installation.
set -Eeuo pipefail
if [[ "$EUID" -ne 0 ]]; then
    echo "Run with sudo: sudo /usr/local/sbin/fix-display-manager" >&2
    exit 1
fi
if ! command -v sddm >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y sddm xserver-xorg-core
fi
if [[ ! -f /usr/share/wayland-sessions/hyprland.desktop ]]; then
    echo "Hyprland session file is missing: /usr/share/wayland-sessions/hyprland.desktop" >&2
    echo "Check that the hyprland package is installed." >&2
    exit 1
fi
systemctl disable gdm3.service lightdm.service ly.service 2>/dev/null || true
systemctl set-default graphical.target
systemctl enable sddm.service
systemctl daemon-reload
if [[ -L /etc/systemd/system/display-manager.service ]]; then
    echo "Display-manager alias: $(readlink /etc/systemd/system/display-manager.service)"
else
    echo "Warning: display-manager.service alias was not created; enabling SDDM again."
    ln -sfn /lib/systemd/system/sddm.service /etc/systemd/system/display-manager.service
    systemctl daemon-reload
fi
systemctl restart sddm.service
echo "SDDM restart requested. If the login screen still does not appear, inspect:"
echo "  systemctl status sddm --no-pager -l"
echo "  journalctl -b -u sddm --no-pager -n 100"

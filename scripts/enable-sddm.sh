#!/usr/bin/env bash
# Ensure SDDM is enabled and selected as the display manager after installation.
set -Eeuo pipefail
if [[ "$EUID" -ne 0 ]]; then
    echo "Run with sudo: sudo /usr/local/sbin/enable-sddm" >&2
    exit 1
fi
if ! command -v sddm >/dev/null 2>&1; then
    echo "SDDM is not installed; refusing to configure a missing display manager." >&2
    exit 1
fi
systemctl set-default graphical.target
systemctl enable sddm.service
mkdir -p /etc/systemd/system
if [[ ! -L /etc/systemd/system/display-manager.service ]]; then
    ln -sfn /lib/systemd/system/sddm.service /etc/systemd/system/display-manager.service
fi
systemctl daemon-reload
systemctl is-enabled --quiet sddm.service || {
    echo "Failed to enable sddm.service." >&2
    exit 1
}
echo "SDDM is enabled for startup. Reboot to use the graphical login."

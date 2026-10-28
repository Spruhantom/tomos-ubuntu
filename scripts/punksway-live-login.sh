#!/usr/bin/env bash
set -euo pipefail
# The generated drop-in lives only in the live ISO's volatile overlay.
# Installed systems do not have boot=casper, so they keep a normal login screen.
if ! grep -Eq '(^|[[:space:]])boot=casper([[:space:]]|$)' /proc/cmdline; then
    exit 0
fi
install -d -m 0755 /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/99-punksway-live-autologin.conf <<'CONF'
[Seat:*]
autologin-user=ubuntu
autologin-user-timeout=0
autologin-session=hyprland
CONF
chmod 0644 /etc/lightdm/lightdm.conf.d/99-punksway-live-autologin.conf
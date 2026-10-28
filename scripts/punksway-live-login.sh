#!/usr/bin/env bash
set -euo pipefail
# Ly uses a TTY login interface and does not use LightDM's autologin drop-in.
# Keep this compatibility hook intentionally inert so the live ISO never writes
# a LightDM-only configuration when ly is the selected display manager.
exit 0

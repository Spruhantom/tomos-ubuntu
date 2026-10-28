#!/usr/bin/env bash
# Experimental source installer for Caelestia Shell on Ubuntu-based PunkSway.
# Review upstream instructions and package versions before running.
set -Eeuo pipefail
die() { echo "ERROR: $*" >&2; exit 1; }
command -v apt-get >/dev/null || die "This helper is for Ubuntu/Debian-based systems."
command -v git >/dev/null || die "Install git first."
command -v cmake >/dev/null || die "Install cmake first."
command -v ninja >/dev/null || die "Install ninja-build first."
command -v qmake6 >/dev/null || true

ROOT="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
DEST="$ROOT/caelestia"
if [[ -e "$DEST" ]]; then
    die "$DEST already exists. Back it up or move it before retrying."
fi
mkdir -p "$ROOT"
git clone --depth 1 https://github.com/caelestia-dots/shell.git "$DEST"
cd "$DEST"

echo "Caelestia source downloaded to $DEST"
echo "This script deliberately does not guess Ubuntu Qt/Quickshell package names."
echo "Follow the current upstream dependency list at:"
echo "https://github.com/caelestia-dots/shell"
echo
echo "Required upstream build steps after installing compatible dependencies:"
echo "  cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/"
echo "  cmake --build build"
echo "  sudo cmake --install build"
echo
echo "The upstream shell also requires the matching git version of Quickshell"
echo "and caelestia-cli for full functionality. Verify compatibility before"
echo "installing; this helper has not been tested on Ubuntu 26.04."

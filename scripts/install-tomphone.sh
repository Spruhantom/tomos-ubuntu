#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ARCHIVE="https://codeload.github.com/Spruhantom/tomos-ubuntu/tar.gz/refs/heads/main"
WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

if [[ "${EUID}" -ne 0 ]]; then
    echo "Run this installer as root, for example: curl -fsSL https://raw.githubusercontent.com/Spruhantom/tomos-ubuntu/main/scripts/install-tomphone.sh | sudo bash" >&2
    exit 1
fi
if [[ ! -r /etc/os-release ]] || ! . /etc/os-release || [[ "${ID:-}" != ubuntu ]]; then
    echo "Tomphone installer currently supports Ubuntu-based systems only." >&2
    exit 1
fi
if [[ "$(dpkg --print-architecture)" != amd64 ]]; then
    echo "This build currently supports amd64 only." >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
echo "[1/4] Installing build tools and Tomphone runtime dependencies..."
apt-get update
apt-get install -y --no-install-recommends \
    ca-certificates curl tar build-essential dpkg-dev qmake6 \
    qt6-base-dev qt6-declarative-dev \
    baresip libpulse0 \
    qml6-module-qtquick-controls \
    qml6-module-qtquick-layouts \
    qml6-module-qtquick-templates \
    qml6-module-qtquick-window \
    qml6-module-qtquick

echo "[2/4] Downloading Tomphone source from GitHub..."
curl --fail --location --silent --show-error "$REPO_ARCHIVE" -o "$WORK/source.tar.gz"
mkdir -p "$WORK/source"
tar -xzf "$WORK/source.tar.gz" --strip-components=1 -C "$WORK/source"

echo "[3/4] Building the Ubuntu .deb package..."
PROJECT="$WORK/source" BUILD_JOBS="$(nproc)" bash "$WORK/source/scripts/build-tomphone-deb.sh"

echo "[4/4] Installing Tomphone..."
apt-get install -y "$WORK/source/build/tomphone_0.1.0_amd64.deb"
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/share/applications || true
fi
echo "Tomphone installed. Find it in your application launcher, or run: tomphone"

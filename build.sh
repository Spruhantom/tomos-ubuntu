#!/usr/bin/env bash
# Host-side entrypoint. Run this on Omarchy Linux with Podman installed.
set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_ISO="${1:-}"

usage() {
    cat <<'USAGE'
PunkSway ISO builder (Omarchy Linux host)

Usage:
  ./build.sh /path/to/ubuntu-26.10-desktop-amd64.iso

Optional:
  KEEP_BUILD=1 ./build.sh /path/to/ubuntu-26.10-desktop-amd64.iso

The ISO build runs inside an Ubuntu 26.10 Podman container. The original ISO is
not modified. Output: dist/PunkSway-26.10-amd64.iso
USAGE
}

if [[ -z "$BASE_ISO" || "$BASE_ISO" == "-h" || "$BASE_ISO" == "--help" ]]; then usage; exit 0; fi
[[ -f "$BASE_ISO" ]] || { echo "Base ISO not found: $BASE_ISO" >&2; exit 2; }
BASE_ISO="$(realpath "$BASE_ISO")"
command -v podman >/dev/null 2>&1 || {
    echo "Podman is required on Omarchy Linux. Install it with: sudo pacman -S podman" >&2
    exit 2
}

if [[ "$EUID" -eq 0 ]]; then
    PODMAN=(podman)
    HOST_UID="${SUDO_UID:-0}"
    HOST_GID="${SUDO_GID:-0}"
else
    command -v sudo >/dev/null 2>&1 || { echo "sudo is required to run the privileged image builder." >&2; exit 2; }
    sudo -v
    PODMAN=(sudo podman)
    HOST_UID="$(id -u)"
    HOST_GID="$(id -g)"
fi

mkdir -p "$PROJECT_DIR/build" "$PROJECT_DIR/dist"
echo "PunkSway builder: Omarchy Linux host → Ubuntu 26.10 container"
echo "Base ISO: $BASE_ISO"
echo "Scratch space: $PROJECT_DIR/build (allow about 25–35 GB free)"
echo "The first build downloads the Ubuntu container image and packages."

"${PODMAN[@]}" run --rm --privileged \
    -v "$PROJECT_DIR:/work" \
    -v "$BASE_ISO:/base.iso:ro" \
    -e "KEEP_BUILD=${KEEP_BUILD:-0}" \
    -e "BUILD_JOBS=${BUILD_JOBS:-0}" \
    -w /work \
    docker.io/library/ubuntu:26.10 \
    /bin/bash /work/scripts/build-in-container.sh /base.iso

if [[ "$HOST_UID" != 0 && -f "$PROJECT_DIR/dist/PunkSway-26.10-amd64.iso" ]]; then
    if [[ "$EUID" -eq 0 ]]; then
        chown "$HOST_UID:$HOST_GID" \
            "$PROJECT_DIR/dist/PunkSway-26.10-amd64.iso" \
            "$PROJECT_DIR/dist/PunkSway-26.10-amd64.iso.sha256"
    else
        sudo chown "$HOST_UID:$HOST_GID" \
            "$PROJECT_DIR/dist/PunkSway-26.10-amd64.iso" \
            "$PROJECT_DIR/dist/PunkSway-26.10-amd64.iso.sha256"
    fi
fi
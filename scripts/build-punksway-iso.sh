#!/usr/bin/env bash
# End-to-end PunkSway ISO builder for Ubuntu/Debian or Arch-based Linux hosts.
# Downloads the project and official Ubuntu base ISO, then builds a custom ISO.
set -Eeuo pipefail

REPO_ARCHIVE="https://codeload.github.com/Spruhantom/tomos-ubuntu/tar.gz/refs/heads/main"
UBUNTU_BASE="https://releases.ubuntu.com/26.10"
ISO_NAME="ubuntu-26.10-desktop-amd64.iso"
WORK="${PUNKSWAY_WORKDIR:-/var/tmp/punksway-iso-build}"

if [[ "${EUID}" -ne 0 ]]; then
    echo "Run as root, for example: curl -fsSL https://raw.githubusercontent.com/Spruhantom/tomos-ubuntu/main/scripts/build-punksway-iso.sh | sudo bash" >&2
    exit 1
fi

if [[ ! -r /etc/os-release ]]; then
    echo "Cannot identify host OS: /etc/os-release is missing." >&2
    exit 1
fi
. /etc/os-release
case "${ID:-}" in
    ubuntu|debian|linuxmint|pop)
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y --no-install-recommends ca-certificates curl tar xz-utils coreutils podman
        ;;
    arch|endeavouros|omarchy|manjaro)
        pacman -Sy --needed --noconfirm ca-certificates curl tar xz coreutils podman
        ;;
    *)
        echo "Unsupported host OS: ${PRETTY_NAME:-unknown}. Use Ubuntu/Debian or Arch-based Linux." >&2
        exit 1
        ;;
esac

if [[ "$(uname -m)" != x86_64 ]]; then
    echo "PunkSway currently builds amd64 images only; host architecture must be x86_64." >&2
    exit 1
fi
command -v podman >/dev/null || { echo "Podman could not be installed." >&2; exit 1; }

mkdir -p "$WORK"
WORK="$(cd "$WORK" && pwd)"
echo "PunkSway full-project ISO build"
echo "Work directory: $WORK"
echo "This downloads a multi-gigabyte Ubuntu ISO and needs approximately 25–35 GB of free disk space."

echo "[1/4] Downloading the project source..."
curl --fail --location --retry 3 --silent --show-error "$REPO_ARCHIVE" -o "$WORK/project.tar.gz"
mkdir -p "$WORK/project"
tar -xzf "$WORK/project.tar.gz" --strip-components=1 -C "$WORK/project"

echo "[2/4] Downloading the official Ubuntu 26.10 Desktop amd64 ISO and checksums..."
curl --fail --location --retry 3 --silent --show-error "$UBUNTU_BASE/SHA256SUMS" -o "$WORK/SHA256SUMS"
curl --fail --location --retry 3 --silent --show-error "$UBUNTU_BASE/$ISO_NAME" -o "$WORK/$ISO_NAME"
(
    cd "$WORK"
    grep -F "  $ISO_NAME" SHA256SUMS | sha256sum --check -
)

echo "[3/4] Building the complete PunkSway ISO inside Ubuntu 26.10..."
chmod -R u+rwX "$WORK/project"
KEEP_BUILD="${KEEP_BUILD:-0}" BUILD_JOBS="${BUILD_JOBS:-0}" \
    bash "$WORK/project/build.sh" "$WORK/$ISO_NAME"

echo "[4/4] Build finished."
echo "ISO:      $WORK/project/dist/PunkSway-26.10-amd64.iso"
echo "Checksum: $WORK/project/dist/PunkSway-26.10-amd64.iso.sha256"
echo
echo "This creates a bootable ISO; it does not install or replace the OS on this computer."
echo "Test the ISO in a virtual machine before installing it on hardware."

#!/usr/bin/env bash
# End-to-end PunkSway ISO builder for Fedora, Ubuntu/Debian, or Arch-based Linux hosts.
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

if [[ "$(uname -m)" != x86_64 ]]; then
    echo "PunkSway currently builds amd64 images only; host architecture must be x86_64." >&2
    exit 1
fi
if [[ ! -r /etc/os-release ]]; then
    echo "Cannot identify host OS: /etc/os-release is missing." >&2
    exit 1
fi
. /etc/os-release
case "${ID:-}" in
    ubuntu|debian|linuxmint|pop)
        if ! command -v apt-get >/dev/null 2>&1; then
            echo "This host identifies as ${ID:-unknown}, but apt-get is unavailable." >&2
            exit 1
        fi
        if [[ "${ID:-}" == debian ]]; then
            case "${VERSION_ID:-}" in
                12|13) echo "Detected Debian ${VERSION_ID}; installing build dependencies with APT." ;;
                *) echo "Debian ${VERSION_ID:-unknown} detected. Debian 12 and 13 are the intended targets; continuing best-effort." >&2 ;;
            esac
        fi
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y --no-install-recommends ca-certificates curl tar xz-utils coreutils findutils gawk grep podman
        ;;
    fedora)
        dnf install -y ca-certificates curl tar xz coreutils findutils gawk grep podman
        ;;
    arch|endeavouros|omarchy|manjaro|garuda)
        # Avoid a partial Arch upgrade (-Sy). Require Podman and host tools to already be installed.
        if ! command -v podman >/dev/null 2>&1; then
            echo "Podman is required on Arch-based hosts. Install it with 'sudo pacman -Syu podman', then rerun this command." >&2
            exit 1
        fi
        for tool in curl tar sha256sum df awk realpath chmod grep; do
            command -v "$tool" >/dev/null 2>&1 || {
                echo "Missing required tool '$tool'. Install it using your distribution's package manager." >&2
                exit 1
            }
        done
        ;;
    *)
        echo "Unsupported host OS: ${PRETTY_NAME:-unknown}. Use Fedora, Debian 12/13, Ubuntu, or an Arch-based Linux system." >&2
        exit 1
        ;;
esac
for tool in curl tar sha256sum df awk realpath chmod grep; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "Required command '$tool' is missing." >&2
        exit 1
    }
done
command -v podman >/dev/null 2>&1 || { echo "Podman could not be installed." >&2; exit 1; }

mkdir -p "$WORK"
WORK="$(cd "$WORK" && pwd -P)"
if [[ "$WORK" == "/" || -z "$WORK" ]]; then
    echo "Unsafe work directory: $WORK" >&2
    exit 1
fi
available_kb="$(df -Pk "$WORK" | awk 'NR == 2 {print $4}')"
if [[ ! "$available_kb" =~ ^[0-9]+$ ]] || (( available_kb < 31457280 )); then
    echo "At least 30 GiB of free space is recommended on the filesystem containing $WORK." >&2
    exit 1
fi

echo "PunkSway full-project ISO build"
echo "Work directory: $WORK"
echo "Free space: $((available_kb / 1024 / 1024)) GiB"
echo "The official Ubuntu ISO will be reused when it already exists and passes checksum verification."

echo "[1/4] Downloading the project source..."
curl --fail --location --retry 3 --silent --show-error "$REPO_ARCHIVE" -o "$WORK/project.tar.gz"
# Clear any old checkout first so removed/renamed files cannot survive from a previous run.
rm -rf "$WORK/project"
mkdir -p "$WORK/project"
tar -xzf "$WORK/project.tar.gz" --strip-components=1 -C "$WORK/project"
[[ -f "$WORK/project/build.sh" && -f "$WORK/project/scripts/build-in-container.sh" ]] || {
    echo "Downloaded project archive is missing the expected build scripts." >&2
    exit 1
}

echo "[2/4] Checking for a cached Ubuntu 26.10 Desktop amd64 ISO..."
curl --fail --location --retry 3 --silent --show-error "$UBUNTU_BASE/SHA256SUMS" -o "$WORK/SHA256SUMS"
checksum_line="$(awk -v name="$ISO_NAME" '{
    filename = $2
    sub(/^[*]/, "", filename)
    if (filename == name) { print; count++ }
} END { if (count != 1) exit 1 }' "$WORK/SHA256SUMS")" || {
    echo "Could not find exactly one checksum entry for $ISO_NAME in the official SHA256SUMS file." >&2
    exit 1
}
if [[ -s "$WORK/$ISO_NAME" ]] && printf '%s\n' "$checksum_line" | (cd "$WORK" && sha256sum --check --status -); then
    echo "Cached ISO found and checksum verified; skipping download."
else
    if [[ -e "$WORK/$ISO_NAME" ]]; then
        echo "Cached ISO is missing or failed checksum verification; downloading a fresh copy."
        rm -f "$WORK/$ISO_NAME"
    else
        echo "No cached ISO found; downloading it now."
    fi
    curl --fail --location --retry 3 --progress-bar --show-error "$UBUNTU_BASE/$ISO_NAME" -o "$WORK/$ISO_NAME"
    printf '%s\n' "$checksum_line" | (cd "$WORK" && sha256sum --check -)
fi

echo "[3/4] Building the complete PunkSway ISO inside Ubuntu 26.10..."
chmod -R u+rwX "$WORK/project"
KEEP_BUILD="${KEEP_BUILD:-0}" BUILD_JOBS="${BUILD_JOBS:-0}" \
    bash "$WORK/project/build.sh" "$WORK/$ISO_NAME"

OUTPUT="$WORK/project/dist/PunkSway-26.10-amd64.iso"
[[ -s "$OUTPUT" && -s "$OUTPUT.sha256" ]] || {
    echo "Build command returned, but the expected ISO or checksum file is missing/empty." >&2
    exit 1
}

echo "[4/4] Build finished."
echo "ISO:      $OUTPUT"
echo "Checksum: $OUTPUT.sha256"
echo
echo "This creates a bootable ISO; it does not install or replace the OS on this computer."
echo "Test the ISO in a virtual machine before installing it on hardware."

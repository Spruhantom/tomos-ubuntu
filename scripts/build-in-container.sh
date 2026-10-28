#!/usr/bin/env bash
# Run inside the privileged Ubuntu 26.10 container launched by build.sh.
set -Eeuo pipefail

BASE_ISO="${1:-/base.iso}"
PROJECT=/work
WORK="$PROJECT/build/work"
TREE="$WORK/iso-tree"
ROOT="$WORK/rootfs"
OUTPUT="$PROJECT/dist/PunkSway-26.10-amd64.iso"
LOG="$PROJECT/build/build.log"

mkdir -p "$PROJECT/build" "$PROJECT/dist"
exec > >(tee -a "$LOG") 2>&1
fail() { echo "ERROR: $*" >&2; exit 1; }
cleanup_mounts() {
    set +e
    for target in "$ROOT/run" "$ROOT/sys" "$ROOT/proc" "$ROOT/dev"; do
        if mountpoint -q "$target"; then umount -R "$target" 2>/dev/null || true; fi
    done
}
restore_chroot_files() {
    set +e
    if [[ -n "${POLICY_BACKUP:-}" && -e "$POLICY_BACKUP" ]]; then
        cp -a "$POLICY_BACKUP" "$ROOT/usr/sbin/policy-rc.d"
    elif [[ "${POLICY_WAS_PRESENT:-0}" == 0 && -e "$ROOT/usr/sbin/policy-rc.d" ]]; then
        rm -f "$ROOT/usr/sbin/policy-rc.d"
    fi
    if [[ "${RESOLV_KIND:-}" == link ]]; then
        rm -f "$ROOT/etc/resolv.conf"
        ln -s "$RESOLV_TARGET" "$ROOT/etc/resolv.conf"
    elif [[ "${RESOLV_KIND:-}" == file ]]; then
        cp -a "$WORK/resolv.conf.saved" "$ROOT/etc/resolv.conf"
    elif [[ "${RESOLV_KIND:-}" == missing ]]; then
        rm -f "$ROOT/etc/resolv.conf"
    fi
}
cleanup_all() { cleanup_mounts; restore_chroot_files; }
trap cleanup_all EXIT

[[ -f "$BASE_ISO" ]] || fail "Base ISO not found: $BASE_ISO"
if ! command -v xorriso >/dev/null || ! command -v unsquashfs >/dev/null || ! command -v mksquashfs >/dev/null || ! command -v systemctl >/dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    if [[ -f /etc/apt/sources.list.d/ubuntu.sources ]]; then
        sed -i -E 's/^Components:.*/Components: main restricted universe multiverse/' /etc/apt/sources.list.d/ubuntu.sources
    fi
    if ! apt-get -o Acquire::Retries=3 update; then
        fail "APT could not reach Ubuntu package mirrors. Check host internet/DNS and rerun the builder; Podman host networking is enabled by build.sh."
    fi
    apt-get install -y --no-install-recommends ca-certificates xorriso squashfs-tools rsync systemd util-linux coreutils findutils gawk python3-pil build-essential qt6-base-dev qt6-declarative-dev qmake6 dpkg-dev
fi

if [[ ! -f "$PROJECT/assets/neon-punk.png" ]]; then
    python3 "$PROJECT/assets/render_wallpaper.py"
fi
python3 "$PROJECT/assets/render_plymouth.py"
ISO_INFO="$(xorriso -indev "$BASE_ISO" -pvd_info 2>&1 || true)"
printf '%s\n' "$ISO_INFO" | grep -E 'Volume Id|Volume id|PVD' | head -n 8 || true
printf '%s\n' "$ISO_INFO" | grep -qi 'Ubuntu' || fail "Use the official Ubuntu Desktop ISO."
rm -rf "$WORK"
mkdir -p "$TREE"
echo "[1/8] Extracting original ISO tree..."
xorriso -osirrox on -indev "$BASE_ISO" -extract / "$TREE"
# Ubuntu 26.10 Desktop renamed the live root filesystem to minimal.squashfs.
# Keep compatibility with releases that still use filesystem.squashfs.
if [[ -f "$TREE/casper/filesystem.squashfs" ]]; then
    SQUASHFS_NAME=filesystem.squashfs
elif [[ -f "$TREE/casper/minimal.squashfs" ]]; then
    SQUASHFS_NAME=minimal.squashfs
else
    echo "Available files in casper:" >&2
    find "$TREE/casper" -maxdepth 1 -type f -printf '%f\n' >&2 || true
    fail "No supported live root filesystem found (expected casper/filesystem.squashfs or casper/minimal.squashfs)."
fi
ORIGINAL_SQ="$TREE/casper/$SQUASHFS_NAME"
[[ -f "$TREE/.disk/info" ]] || fail "No .disk/info found."
SOURCE_INFO="$(cat "$TREE/.disk/info")"
printf 'Source image: %s\n' "$SOURCE_INFO"
printf '%s' "$SOURCE_INFO" | grep -q '26\.10' || fail "Expected Ubuntu 26.10."
printf '%s' "$SOURCE_INFO" | grep -qi 'amd64' || fail "Expected Ubuntu Desktop amd64."

echo "[2/8] Unpacking the live filesystem..."
BUILD_JOBS="${BUILD_JOBS:-$(nproc)}"
[[ "$BUILD_JOBS" =~ ^[0-9]+$ ]] && (( BUILD_JOBS > 0 )) || BUILD_JOBS="$(nproc)"
(( BUILD_JOBS > 8 )) && BUILD_JOBS=8
unsquashfs -processors "$BUILD_JOBS" -d "$ROOT" "$ORIGINAL_SQ"
grep -qE '^VERSION_ID="?26\.10"?$' "$ROOT/usr/lib/os-release" || fail "Live filesystem is not Ubuntu 26.10."

if [[ -L "$ROOT/etc/resolv.conf" ]]; then
    RESOLV_KIND=link; RESOLV_TARGET="$(readlink "$ROOT/etc/resolv.conf")"
elif [[ -f "$ROOT/etc/resolv.conf" ]]; then
    RESOLV_KIND=file; cp -a "$ROOT/etc/resolv.conf" "$WORK/resolv.conf.saved"
else RESOLV_KIND=missing; fi
rm -f "$ROOT/etc/resolv.conf"; cp -L /etc/resolv.conf "$ROOT/etc/resolv.conf"
if [[ -e "$ROOT/usr/sbin/policy-rc.d" ]]; then
    POLICY_WAS_PRESENT=1; POLICY_BACKUP="$WORK/policy-rc.d.saved"; cp -a "$ROOT/usr/sbin/policy-rc.d" "$POLICY_BACKUP"
else POLICY_WAS_PRESENT=0; POLICY_BACKUP=""; fi
cat > "$ROOT/usr/sbin/policy-rc.d" <<'POLICY'
#!/bin/sh
exit 101
POLICY
chmod 0755 "$ROOT/usr/sbin/policy-rc.d"
mount --rbind /dev "$ROOT/dev"; mount --make-rslave "$ROOT/dev"
mount -t proc proc "$ROOT/proc"; mount -t sysfs sysfs "$ROOT/sys"; mount -t tmpfs tmpfs "$ROOT/run"
# The live ISO can leave an installer-only file:/cdrom repository enabled.
# It is not mounted as an APT repository in this chroot, so disable those entries
# before updating package indexes. Keep the network repositories intact.
if [[ -f "$ROOT/etc/apt/sources.list" ]]; then
    sed -i -E '/^[[:space:]]*deb(-src)?[[:space:]].*(cdrom:|file:\/\/cdrom|file:\/cdrom)/Id' "$ROOT/etc/apt/sources.list"
fi
if [[ -d "$ROOT/etc/apt/sources.list.d" ]]; then
    while IFS= read -r -d '' apt_list; do
        sed -i -E '/^[[:space:]]*deb(-src)?[[:space:]].*(cdrom:|file:\/\/cdrom|file:\/cdrom)/Id' "$apt_list"
    done < <(find "$ROOT/etc/apt/sources.list.d" -maxdepth 1 -type f -name '*.list' -print0)
    # Ubuntu 26.10 may store the installer CD-ROM source in Deb822 .sources
    # format (URIs: file:/cdrom), which cannot be removed by editing .list files.
    while IFS= read -r -d '' apt_sources; do
        # Deb822 fields can wrap onto continuation lines, so inspect each whole
        # stanza for file:/cdrom rather than relying on the URIs line alone.
        if grep -qiE 'file:.*cdrom' "$apt_sources"; then
            echo "Disabling installer CD-ROM source stanza(s): ${apt_sources#"$ROOT"}"
            awk 'BEGIN { RS=""; ORS="\n\n" }
                tolower($0) ~ /file:.*cdrom/ { next }
                { print }' "$apt_sources" > "$apt_sources.tmp"
            cat "$apt_sources.tmp" > "$apt_sources"
            rm -f "$apt_sources.tmp"
        fi
    done < <(find "$ROOT/etc/apt/sources.list.d" -maxdepth 1 -type f -name '*.sources' -print0)
    # Fail early with a clear diagnostic if an installer-only source remains.
    if grep -RqiE '^[[:space:]]*URIs:.*file:.*cdrom|^[[:space:]]*deb(-src)?[[:space:]].*file:.*cdrom' \
        "$ROOT/etc/apt/sources.list" "$ROOT/etc/apt/sources.list.d" 2>/dev/null; then
        echo "ERROR: An installer CD-ROM APT source is still enabled:" >&2
        grep -RniE 'file:.*cdrom|cdrom:' "$ROOT/etc/apt/sources.list" "$ROOT/etc/apt/sources.list.d" 2>/dev/null >&2 || true
        fail "Could not disable the installer CD-ROM APT source."
    fi
fi
if [[ -f "$ROOT/etc/apt/sources.list.d/ubuntu.sources" ]]; then
    sed -i -E 's/^Components:.*/Components: main restricted universe multiverse/' "$ROOT/etc/apt/sources.list.d/ubuntu.sources"
fi
PACKAGES=()
while IFS= read -r line; do
    line="${line%%#*}"; line="$(printf '%s' "$line" | xargs)"
    [[ -n "$line" ]] && PACKAGES+=("$line")
done < "$PROJECT/packages.txt"
echo "[3/8] Building Tomphone Ubuntu package..."
PROJECT=/work BUILD_JOBS="${BUILD_JOBS:-$(nproc)}" bash "$PROJECT/scripts/build-tomphone-deb.sh"
install -D -m 0644 "$PROJECT/build/tomphone_0.1.0_amd64.deb" "$ROOT/tmp/tomphone_0.1.0_amd64.deb"
echo "[4/8] Installing desktop packages..."
printf 'shared shared/default-x-display-manager select sddm\n' | chroot "$ROOT" debconf-set-selections
if ! chroot "$ROOT" env DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::Retries=3 update; then
    fail "APT update failed inside the live filesystem. Installer CD-ROM sources have been removed; inspect the remaining repository errors above for network or mirror issues."
fi
chroot "$ROOT" env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${PACKAGES[@]}"
chroot "$ROOT" env DEBIAN_FRONTEND=noninteractive apt-get install -y /tmp/tomphone_0.1.0_amd64.deb
rm -f "$ROOT/tmp/tomphone_0.1.0_amd64.deb"
chroot "$ROOT" env DEBIAN_FRONTEND=noninteractive apt-get purge -y gdm3 lightdm lightdm-gtk-greeter || true
KERNEL_PACKAGES="$(chroot "$ROOT" dpkg-query -W -f='${binary:Package} ${Version}\n' 'linux-image-*-generic' 2>/dev/null || true)"
printf '%s\n' "$KERNEL_PACKAGES"
printf '%s\n' "$KERNEL_PACKAGES" | grep -Eq 'linux-image-7\.3\.[0-9]+-[0-9]+-generic' || fail "Ubuntu 26.10 kernel 7.3 image package was not installed."

echo "[5/8] Applying PunkSway configuration, Zsh/Fastfetch, and Calamares installer..."
install -D -m 0644 "$PROJECT/config/calamares/settings.conf" "$ROOT/etc/calamares/settings.conf"
if [[ -d "$PROJECT/config/calamares/modules" ]]; then cp -a "$PROJECT/config/calamares/modules/." "$ROOT/etc/calamares/modules/"; fi
install -D -m 0644 "$PROJECT/config/calamares/branding/punk/branding.desc" "$ROOT/usr/share/calamares/branding/punk/branding.desc"
install -D -m 0644 "$PROJECT/config/calamares/branding/punk/show.html" "$ROOT/usr/share/calamares/branding/punk/show.html"
install -D -m 0644 "$PROJECT/config/punksway-installer.desktop" "$ROOT/usr/share/applications/punksway-installer.desktop"
install -D -m 0644 "$PROJECT/assets/neon-punk.png" "$ROOT/usr/share/backgrounds/punksway/neon-punk.png"
install -D -m 0644 "$PROJECT/assets/tomos-splash.png" "$ROOT/usr/share/plymouth/themes/tomos/tomos-splash.png"
install -D -m 0644 "$PROJECT/assets/tomos-progress-track.png" "$ROOT/usr/share/plymouth/themes/tomos/tomos-progress-track.png"
install -D -m 0644 "$PROJECT/assets/tomos-progress-fill.png" "$ROOT/usr/share/plymouth/themes/tomos/tomos-progress-fill.png"
install -D -m 0644 "$PROJECT/config/plymouth/tomos.script" "$ROOT/usr/share/plymouth/themes/tomos/tomos.script"
install -D -m 0644 "$PROJECT/config/plymouth/tomos.plymouth" "$ROOT/usr/share/plymouth/themes/tomos/tomos.plymouth"
mkdir -p "$ROOT/etc/plymouth"
cat > "$ROOT/etc/plymouth/plymouthd.conf" <<'PLYMOUTH'
[Daemon]
Theme=tomos
ShowDelay=0
DeviceTimeout=8
PLYMOUTH
# Regenerate initramfs so the selected theme is included in the boot image.
chroot "$ROOT" update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/tomos/tomos.plymouth 100
chroot "$ROOT" update-alternatives --set default.plymouth /usr/share/plymouth/themes/tomos/tomos.plymouth
chroot "$ROOT" update-initramfs -u -k all
# The ISO boots from files in /casper, so keep them in sync with the kernel
# and initramfs installed in the compressed live filesystem.
KERNEL_FILE="$(find "$ROOT/boot" -maxdepth 1 -type f -name 'vmlinuz-*' -printf '%f\\n' | sort -V | tail -n 1)"
[[ -n "$KERNEL_FILE" ]] || fail "No installed kernel image found in the live filesystem."
KERNEL_VERSION="${KERNEL_FILE#vmlinuz-}"
INITRD_FILE="initrd.img-$KERNEL_VERSION"
[[ -s "$ROOT/boot/$INITRD_FILE" ]] || fail "Matching initramfs missing for kernel $KERNEL_VERSION."
install -m 0644 "$ROOT/boot/$KERNEL_FILE" "$TREE/casper/vmlinuz"
install -m 0644 "$ROOT/boot/$INITRD_FILE" "$TREE/casper/initrd"
echo "ISO boot kernel/initrd synchronized to kernel $KERNEL_VERSION."
install -D -m 0644 "$PROJECT/config/fastfetch/fastfetch-logo.txt" "$ROOT/usr/share/punksway/fastfetch-logo.txt"
install -D -m 0755 "$PROJECT/scripts/punksway-polkit-agent.sh" "$ROOT/usr/local/bin/punksway-polkit-agent"
copy_user_config() {
    local destination="$1"
    install -D -m 0644 "$PROJECT/config/hypr/hyprland.conf" "$destination/.config/hypr/hyprland.conf"
    install -D -m 0644 "$PROJECT/config/hypr/hypridle.conf" "$destination/.config/hypr/hypridle.conf"
    install -D -m 0644 "$PROJECT/config/hypr/hyprpaper.conf" "$destination/.config/hypr/hyprpaper.conf"
    install -D -m 0644 "$PROJECT/config/waybar/config.jsonc" "$destination/.config/waybar/config.jsonc"
    install -D -m 0644 "$PROJECT/config/waybar/style.css" "$destination/.config/waybar/style.css"
    install -D -m 0644 "$PROJECT/config/waybar/dock.jsonc" "$destination/.config/waybar/dock.jsonc"
    install -D -m 0644 "$PROJECT/config/waybar/dock.css" "$destination/.config/waybar/dock.css"
    install -D -m 0644 "$PROJECT/config/wofi/style.css" "$destination/.config/wofi/style.css"
    install -D -m 0644 "$PROJECT/config/foot/foot.ini" "$destination/.config/foot/foot.ini"
    install -D -m 0644 "$PROJECT/config/mako/config" "$destination/.config/mako/config"
    install -D -m 0644 "$PROJECT/config/gtk-3.0/settings.ini" "$destination/.config/gtk-3.0/settings.ini"
    install -D -m 0644 "$PROJECT/config/xdg-desktop-portal/portals.conf" "$destination/.config/xdg-desktop-portal/portals.conf"
    install -D -m 0644 "$PROJECT/config/zsh/.zshrc" "$destination/.zshrc"
    install -D -m 0644 "$PROJECT/config/fastfetch/config.jsonc" "$destination/.config/fastfetch/config.jsonc"
    install -D -m 0644 "$PROJECT/config/caelestia/shell.json" "$destination/.config/caelestia/shell.json"
}
copy_user_config "$ROOT/etc/skel"
# Set Zsh as the default for newly created accounts.
if [[ -f "$ROOT/etc/adduser.conf" ]]; then
    if grep -qE '^#?DSHELL=' "$ROOT/etc/adduser.conf"; then
        sed -i -E 's|^#?DSHELL=.*|DSHELL=/usr/bin/zsh|' "$ROOT/etc/adduser.conf"
    else
        printf '\nDSHELL=/usr/bin/zsh\n' >> "$ROOT/etc/adduser.conf"
    fi
fi
if grep -q '^ubuntu:' "$ROOT/etc/passwd"; then
    IFS=: read -r _ _ LIVE_UID LIVE_GID _ < <(grep '^ubuntu:' "$ROOT/etc/passwd")
    LIVE_HOME=/home/ubuntu; mkdir -p "$ROOT$LIVE_HOME"; copy_user_config "$ROOT$LIVE_HOME"
    chown -R "$LIVE_UID:$LIVE_GID" "$ROOT$LIVE_HOME/.config"
    chown "$LIVE_UID:$LIVE_GID" "$ROOT$LIVE_HOME/.zshrc"
    chroot "$ROOT" usermod -s /usr/bin/zsh ubuntu
fi
install -D -m 0644 "$PROJECT/config/punksway-quickstart.desktop" "$ROOT/usr/share/applications/punksway-quickstart.desktop"
install -D -m 0644 "$PROJECT/QUICKSTART.txt" "$ROOT/usr/share/doc/punksway/QUICKSTART.txt"
if [[ -f "$ROOT/usr/lib/os-release" ]]; then
    sed -i 's/^NAME=.*/NAME="PunkSway"/; s/^PRETTY_NAME=.*/PRETTY_NAME="PunkSway 26.10 (Ubuntu base)"/' "$ROOT/usr/lib/os-release"
fi
if [[ -f "$ROOT/etc/lsb-release" ]]; then sed -i 's/^DISTRIB_DESCRIPTION=.*/DISTRIB_DESCRIPTION="PunkSway 26.10 — Blue Neon Hyprland"/' "$ROOT/etc/lsb-release"; fi
cat > "$ROOT/etc/issue" <<'ISSUE'
\n\l
PunkSway 26.10 — Blue Neon Hyprland
Ubuntu-based live environment
ISSUE
mkdir -p "$ROOT/etc/systemd/system/graphical.target.wants"
systemctl --root="$ROOT" disable gdm3.service lightdm.service >/dev/null 2>&1 || true
rm -f "$ROOT/etc/systemd/system/display-manager.service"
# Configure the expected live-session autologin for the SDDM display manager.
[[ -f "$ROOT/usr/share/wayland-sessions/hyprland.desktop" ]] || fail "Hyprland Wayland session file is missing."
mkdir -p "$ROOT/etc/sddm.conf.d"
cat > "$ROOT/etc/sddm.conf.d/10-punksway-autologin.conf" <<'SDDM'
[Autologin]
User=ubuntu
Session=hyprland.desktop
Relogin=true
SDDM
systemctl --root="$ROOT" enable sddm.service
chroot "$ROOT" env DEBIAN_FRONTEND=noninteractive apt-get clean
rm -rf "$ROOT/var/lib/apt/lists"/*
cleanup_mounts; restore_chroot_files; RESOLV_KIND=missing; POLICY_WAS_PRESENT=0; POLICY_BACKUP=""
for cfg in "$TREE/boot/grub/grub.cfg" "$TREE/boot/grub/loopback.cfg"; do
    if [[ -f "$cfg" ]]; then sed -i -e 's/Try or Install Ubuntu/Try or Install PunkSway/g' -e 's/Install Ubuntu/Install PunkSway/g' -e 's/Ubuntu 26\.10 LTS/PunkSway 26.10/g' "$cfg"; fi
done
printf '%s\n' 'PunkSway 26.10 amd64 — Ubuntu-based Blue Neon Hyprland remix' > "$TREE/.disk/info"
echo "[6/8] Rebuilding compressed live filesystem..."
SQ_INFO="$(unsquashfs -s "$ORIGINAL_SQ" 2>&1 || true)"
SQ_COMP="$(printf '%s\n' "$SQ_INFO" | awk '$1 == "Compression" { print $2; exit }')"
SQ_BLOCK="$(printf '%s\n' "$SQ_INFO" | awk '$1 == "Block" && $2 == "size" { print $3; exit }')"
case "$SQ_COMP" in gzip|lzo|lz4|xz|zstd|lzma) ;; *) SQ_COMP=xz ;; esac
[[ "$SQ_BLOCK" =~ ^[0-9]+$ ]] || SQ_BLOCK=1048576
rm -f "$ORIGINAL_SQ"
mksquashfs "$ROOT" "$ORIGINAL_SQ" -comp "$SQ_COMP" -b "$SQ_BLOCK" -noappend -processors "$BUILD_JOBS"
du -sx --block-size=1 "$ROOT" | awk '{print $1}' > "$TREE/casper/filesystem.size"
(cd "$TREE"; find . -type f ! -name md5sum.txt -print0 | sort -z | xargs -0 -r md5sum > md5sum.txt)
rm -rf "$ROOT"
echo "[7/8] Rebuilding bootable ISO..."
rm -f "$OUTPUT"
XORRISO_ARGS=(-indev "$BASE_ISO" -outdev "$OUTPUT" -boot_image any replay
    -map "$ORIGINAL_SQ" "/casper/$SQUASHFS_NAME"
    -map "$TREE/casper/filesystem.size" /casper/filesystem.size
    -map "$TREE/md5sum.txt" /md5sum.txt
    -map "$TREE/.disk/info" /.disk/info
    -map "$TREE/boot/grub/grub.cfg" /boot/grub/grub.cfg)
if [[ -f "$TREE/boot/grub/loopback.cfg" ]]; then XORRISO_ARGS+=(-map "$TREE/boot/grub/loopback.cfg" /boot/grub/loopback.cfg); fi
XORRISO_ARGS+=(-commit -end)
xorriso "${XORRISO_ARGS[@]}"
echo "[8/8] Checking boot records and writing SHA-256..."
xorriso -indev "$OUTPUT" -report_el_torito plain > "$WORK/eltorito-report.txt" 2>&1
grep -qi 'El Torito' "$WORK/eltorito-report.txt" || { cat "$WORK/eltorito-report.txt"; fail "Could not verify boot records."; }
(cd "$(dirname "$OUTPUT")" && sha256sum "$(basename "$OUTPUT")" > "$(basename "$OUTPUT").sha256")
ls -lh "$OUTPUT" "$OUTPUT.sha256"
echo "Build complete: $OUTPUT"
if [[ "${KEEP_BUILD:-0}" != "1" ]]; then rm -rf "$WORK"; else echo "Temporary build files retained at $WORK"; fi
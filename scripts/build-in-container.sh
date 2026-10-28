#!/usr/bin/env bash
# Run inside the privileged Ubuntu 26.04 container launched by build.sh.
set -Eeuo pipefail

BASE_ISO="${1:-/base.iso}"
PROJECT=/work
WORK="$PROJECT/build/work"
TREE="$WORK/iso-tree"
ROOT="$WORK/rootfs"
OUTPUT="$PROJECT/dist/PunkSway-26.04-amd64.iso"
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
    apt-get update
    apt-get install -y --no-install-recommends ca-certificates xorriso squashfs-tools rsync systemd util-linux coreutils findutils gawk python3-pil
fi

if [[ ! -f "$PROJECT/assets/neon-punk.png" ]]; then
    python3 "$PROJECT/assets/render_wallpaper.py"
fi
ISO_INFO="$(xorriso -indev "$BASE_ISO" -pvd_info 2>&1 || true)"
printf '%s\n' "$ISO_INFO" | grep -E 'Volume Id|Volume id|PVD' | head -n 8 || true
printf '%s\n' "$ISO_INFO" | grep -qi 'Ubuntu' || fail "Use the official Ubuntu Desktop ISO."
rm -rf "$WORK"
mkdir -p "$TREE"
echo "[1/7] Extracting original ISO tree..."
xorriso -osirrox on -indev "$BASE_ISO" -extract / "$TREE"
[[ -f "$TREE/casper/filesystem.squashfs" ]] || fail "No casper/filesystem.squashfs found."
[[ -f "$TREE/.disk/info" ]] || fail "No .disk/info found."
SOURCE_INFO="$(cat "$TREE/.disk/info")"
printf 'Source image: %s\n' "$SOURCE_INFO"
printf '%s' "$SOURCE_INFO" | grep -q '26\.04' || fail "Expected Ubuntu 26.04 LTS."
printf '%s' "$SOURCE_INFO" | grep -qi 'amd64' || fail "Expected Ubuntu Desktop amd64."

echo "[2/7] Unpacking the live filesystem..."
BUILD_JOBS="${BUILD_JOBS:-$(nproc)}"
[[ "$BUILD_JOBS" =~ ^[0-9]+$ ]] && (( BUILD_JOBS > 0 )) || BUILD_JOBS="$(nproc)"
(( BUILD_JOBS > 8 )) && BUILD_JOBS=8
unsquashfs -processors "$BUILD_JOBS" -d "$ROOT" "$TREE/casper/filesystem.squashfs"
grep -qE '^VERSION_ID="?26\.04"?$' "$ROOT/usr/lib/os-release" || fail "Live filesystem is not Ubuntu 26.04."

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
if [[ -f "$ROOT/etc/apt/sources.list.d/ubuntu.sources" ]]; then
    sed -i -E 's/^Components:.*/Components: main restricted universe multiverse/' "$ROOT/etc/apt/sources.list.d/ubuntu.sources"
fi
PACKAGES=()
while IFS= read -r line; do
    line="${line%%#*}"; line="$(printf '%s' "$line" | xargs)"
    [[ -n "$line" ]] && PACKAGES+=("$line")
done < "$PROJECT/packages.txt"
echo "[3/7] Installing desktop packages..."
printf 'lightdm shared/default-x-display-manager select lightdm\n' | chroot "$ROOT" debconf-set-selections
chroot "$ROOT" env DEBIAN_FRONTEND=noninteractive apt-get update
chroot "$ROOT" env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${PACKAGES[@]}"
chroot "$ROOT" env DEBIAN_FRONTEND=noninteractive apt-get purge -y gdm3 || true

echo "[4/7] Applying PunkSway configuration and Calamares installer..."
install -D -m 0644 "$PROJECT/config/calamares/settings.conf" "$ROOT/etc/calamares/settings.conf"
if [[ -d "$PROJECT/config/calamares/modules" ]]; then cp -a "$PROJECT/config/calamares/modules/." "$ROOT/etc/calamares/modules/"; fi
install -D -m 0644 "$PROJECT/config/calamares/branding/punk/branding.desc" "$ROOT/usr/share/calamares/branding/punk/branding.desc"
install -D -m 0644 "$PROJECT/config/calamares/branding/punk/show.html" "$ROOT/usr/share/calamares/branding/punk/show.html"
install -D -m 0644 "$PROJECT/config/punksway-installer.desktop" "$ROOT/usr/share/applications/punksway-installer.desktop"
install -D -m 0644 "$PROJECT/assets/neon-punk.png" "$ROOT/usr/share/backgrounds/punksway/neon-punk.png"
install -D -m 0755 "$PROJECT/scripts/punksway-live-login.sh" "$ROOT/usr/local/sbin/punksway-live-login"
install -D -m 0755 "$PROJECT/scripts/punksway-polkit-agent.sh" "$ROOT/usr/local/bin/punksway-polkit-agent"
install -D -m 0644 "$PROJECT/config/systemd/punksway-live-login.service" "$ROOT/etc/systemd/system/punksway-live-login.service"
install -D -m 0644 "$PROJECT/config/lightdm/50-punksway.conf" "$ROOT/etc/lightdm/lightdm.conf.d/50-punksway.conf"
install -D -m 0644 "$PROJECT/config/lightdm/lightdm-gtk-greeter.conf" "$ROOT/etc/lightdm/lightdm-gtk-greeter.conf"
copy_user_config() {
    local destination="$1"
    install -D -m 0644 "$PROJECT/config/sway/config" "$destination/.config/sway/config"
    install -D -m 0644 "$PROJECT/config/waybar/config.jsonc" "$destination/.config/waybar/config.jsonc"
    install -D -m 0644 "$PROJECT/config/waybar/style.css" "$destination/.config/waybar/style.css"
    install -D -m 0644 "$PROJECT/config/wofi/style.css" "$destination/.config/wofi/style.css"
    install -D -m 0644 "$PROJECT/config/foot/foot.ini" "$destination/.config/foot/foot.ini"
    install -D -m 0644 "$PROJECT/config/mako/config" "$destination/.config/mako/config"
    install -D -m 0644 "$PROJECT/config/gtk-3.0/settings.ini" "$destination/.config/gtk-3.0/settings.ini"
    install -D -m 0644 "$PROJECT/config/xdg-desktop-portal/portals.conf" "$destination/.config/xdg-desktop-portal/portals.conf"
}
copy_user_config "$ROOT/etc/skel"
if grep -q '^ubuntu:' "$ROOT/etc/passwd"; then
    IFS=: read -r _ _ LIVE_UID LIVE_GID _ < <(grep '^ubuntu:' "$ROOT/etc/passwd")
    LIVE_HOME=/home/ubuntu; mkdir -p "$ROOT$LIVE_HOME"; copy_user_config "$ROOT$LIVE_HOME"
    chown -R "$LIVE_UID:$LIVE_GID" "$ROOT$LIVE_HOME/.config"
fi
install -D -m 0644 "$PROJECT/config/punksway-quickstart.desktop" "$ROOT/usr/share/applications/punksway-quickstart.desktop"
install -D -m 0644 "$PROJECT/QUICKSTART.txt" "$ROOT/usr/share/doc/punksway/QUICKSTART.txt"
if [[ -f "$ROOT/usr/lib/os-release" ]]; then
    sed -i 's/^NAME=.*/NAME="PunkSway"/; s/^PRETTY_NAME=.*/PRETTY_NAME="PunkSway 26.04 LTS (Ubuntu base)"/' "$ROOT/usr/lib/os-release"
fi
if [[ -f "$ROOT/etc/lsb-release" ]]; then sed -i 's/^DISTRIB_DESCRIPTION=.*/DISTRIB_DESCRIPTION="PunkSway 26.04 LTS — Blue Neon Sway"/' "$ROOT/etc/lsb-release"; fi
cat > "$ROOT/etc/issue" <<'ISSUE'
\n\l
PunkSway 26.04 LTS — Blue Neon Sway
Ubuntu-based live environment
ISSUE
mkdir -p "$ROOT/etc/lightdm/lightdm.conf.d" "$ROOT/etc/systemd/system/graphical.target.wants"
ln -sfn /etc/systemd/system/punksway-live-login.service "$ROOT/etc/systemd/system/graphical.target.wants/punksway-live-login.service"
systemctl --root="$ROOT" disable gdm3.service >/dev/null 2>&1 || true
rm -f "$ROOT/etc/systemd/system/display-manager.service"
systemctl --root="$ROOT" enable lightdm.service
chroot "$ROOT" env DEBIAN_FRONTEND=noninteractive apt-get clean
rm -rf "$ROOT/var/lib/apt/lists"/*
cleanup_mounts; restore_chroot_files; RESOLV_KIND=missing; POLICY_WAS_PRESENT=0; POLICY_BACKUP=""
for cfg in "$TREE/boot/grub/grub.cfg" "$TREE/boot/grub/loopback.cfg"; do
    if [[ -f "$cfg" ]]; then sed -i -e 's/Try or Install Ubuntu/Try or Install PunkSway/g' -e 's/Install Ubuntu/Install PunkSway/g' -e 's/Ubuntu 26\.04 LTS/PunkSway 26.04 LTS/g' "$cfg"; fi
done
printf '%s\n' 'PunkSway 26.04 LTS amd64 — Ubuntu-based Blue Neon Sway remix' > "$TREE/.disk/info"
echo "[5/7] Rebuilding compressed live filesystem..."
ORIGINAL_SQ="$TREE/casper/filesystem.squashfs"
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
echo "[6/7] Rebuilding bootable ISO..."
rm -f "$OUTPUT"
XORRISO_ARGS=(-indev "$BASE_ISO" -outdev "$OUTPUT" -boot_image any replay
    -map "$TREE/casper/filesystem.squashfs" /casper/filesystem.squashfs
    -map "$TREE/casper/filesystem.size" /casper/filesystem.size
    -map "$TREE/md5sum.txt" /md5sum.txt
    -map "$TREE/.disk/info" /.disk/info
    -map "$TREE/boot/grub/grub.cfg" /boot/grub/grub.cfg)
if [[ -f "$TREE/boot/grub/loopback.cfg" ]]; then XORRISO_ARGS+=(-map "$TREE/boot/grub/loopback.cfg" /boot/grub/loopback.cfg); fi
XORRISO_ARGS+=(-commit -end)
xorriso "${XORRISO_ARGS[@]}"
echo "[7/7] Checking boot records and writing SHA-256..."
xorriso -indev "$OUTPUT" -report_el_torito plain > "$WORK/eltorito-report.txt" 2>&1
grep -qi 'El Torito' "$WORK/eltorito-report.txt" || { cat "$WORK/eltorito-report.txt"; fail "Could not verify boot records."; }
(cd "$(dirname "$OUTPUT")" && sha256sum "$(basename "$OUTPUT")" > "$(basename "$OUTPUT").sha256")
ls -lh "$OUTPUT" "$OUTPUT.sha256"
echo "Build complete: $OUTPUT"
if [[ "${KEEP_BUILD:-0}" != "1" ]]; then rm -rf "$WORK"; else echo "Temporary build files retained at $WORK"; fi
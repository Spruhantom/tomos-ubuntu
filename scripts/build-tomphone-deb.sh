#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT="${PROJECT:-/work}"
APP="$PROJECT/apps/tomphone"
OUT="$PROJECT/build/tomphone_0.1.0_amd64.deb"
STAGE="$PROJECT/build/tomphone-package-root"
[[ -f "$APP/tomphone.pro" ]] || { echo "Tomphone source not found: $APP" >&2; exit 1; }
command -v qmake6 >/dev/null
command -v dpkg-deb >/dev/null
mkdir -p "$PROJECT/build"
JOBS="${BUILD_JOBS:-$(nproc)}"
if ! [[ "$JOBS" =~ ^[0-9]+$ ]] || (( JOBS < 1 )); then JOBS="$(nproc)"; fi
(( JOBS > 8 )) && JOBS=8
rm -rf "$APP/build" "$STAGE"
mkdir -p "$APP/build"
(
  cd "$APP/build"
  qmake6 "$APP/tomphone.pro"
  make -j"$JOBS"
)
install -D -m 0755 "$APP/build/tomphone" "$STAGE/usr/bin/tomphone"
install -D -m 0644 "$APP/share/applications/tomphone.desktop" "$STAGE/usr/share/applications/tomphone.desktop"
install -D -m 0644 "$APP/share/icons/hicolor/scalable/apps/tomphone.svg" "$STAGE/usr/share/icons/hicolor/scalable/apps/tomphone.svg"
install -D -m 0644 "$APP/LICENSE" "$STAGE/usr/share/doc/tomphone/copyright"
install -D -m 0644 "$APP/debian/control" "$STAGE/DEBIAN/control"
chmod 0755 "$STAGE/DEBIAN"
dpkg-deb --root-owner-group --build "$STAGE" "$OUT"
dpkg-deb --info "$OUT"
echo "Built Ubuntu package: $OUT"

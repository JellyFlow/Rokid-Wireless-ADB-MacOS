#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Rokid 无线投屏助手.app"
APP_PATH="$DIST_DIR/$APP_NAME"
DMG_PATH="$DIST_DIR/Rokid-Wireless-Projection-2.0.4.dmg"
VOLUME_NAME="Rokid 无线投屏助手 2.0.4"
BACKGROUND_PATH="$DIST_DIR/dmg-background.png"
GUIDE_PATH="$ROOT_DIR/Resources/安装说明.txt"
DMGBUILD_ENV="$ROOT_DIR/.codex/dmgbuild-venv"
MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/rokid-dmg-mount.XXXXXX")"

cleanup() {
  hdiutil detach "$MOUNT_DIR" -quiet >/dev/null 2>&1 || true
  rm -rf "$MOUNT_DIR"
}
trap cleanup EXIT

"$ROOT_DIR/script/build_and_run.sh" --build-only

if [[ ! -x "$DMGBUILD_ENV/bin/dmgbuild" ]]; then
  python3 -m venv "$DMGBUILD_ENV"
  "$DMGBUILD_ENV/bin/python" -m pip install --quiet 'dmgbuild==1.6.5'
fi

swift "$ROOT_DIR/script/create_dmg_background.swift" "$BACKGROUND_PATH"

rm -f "$DMG_PATH"
"$DMGBUILD_ENV/bin/python" "$DMGBUILD_ENV/bin/dmgbuild" \
  -s "$ROOT_DIR/script/dmg_settings.py" \
  -D "app=$APP_PATH" \
  -D "background=$BACKGROUND_PATH" \
  -D "guide=$GUIDE_PATH" \
  "$VOLUME_NAME" \
  "$DMG_PATH"

hdiutil verify "$DMG_PATH"
hdiutil attach "$DMG_PATH" -readonly -nobrowse -mountpoint "$MOUNT_DIR" -quiet

test -d "$MOUNT_DIR/$APP_NAME"
test -L "$MOUNT_DIR/Applications"
test "$(readlink "$MOUNT_DIR/Applications")" = "/Applications"
test -f "$MOUNT_DIR/安装说明.txt"
codesign --verify --deep --strict "$MOUNT_DIR/$APP_NAME"
for universal_binary in \
  "$MOUNT_DIR/$APP_NAME/Contents/MacOS/RokidNative" \
  "$MOUNT_DIR/$APP_NAME/Contents/Resources/bin/adb" \
  "$MOUNT_DIR/$APP_NAME/Contents/Resources/bin/scrcpy"; do
  lipo "$universal_binary" -verify_arch arm64 x86_64
done

hdiutil detach "$MOUNT_DIR" -quiet
shasum -a 256 "$DMG_PATH"

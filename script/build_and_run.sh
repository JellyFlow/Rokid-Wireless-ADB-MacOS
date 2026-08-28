#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="RokidNative"
BUNDLE_NAME="Rokid 无线投屏助手.app"
BUNDLE_ID="com.rokid.wireless-projection.native.v2"
ARM_TRIPLE="arm64-apple-macosx13.0"
INTEL_TRIPLE="x86_64-apple-macosx13.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$BUNDLE_NAME"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

"$ROOT_DIR/script/prepare_universal_scrcpy.sh"

swift build -c release --package-path "$ROOT_DIR" --triple "$ARM_TRIPLE"
swift build -c release --package-path "$ROOT_DIR" --triple "$INTEL_TRIPLE"
ARM_BUILD_BINARY="$(swift build -c release --package-path "$ROOT_DIR" --triple "$ARM_TRIPLE" --show-bin-path)/$APP_NAME"
INTEL_BUILD_BINARY="$(swift build -c release --package-path "$ROOT_DIR" --triple "$INTEL_TRIPLE" --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
lipo -create \
  "$ARM_BUILD_BINARY" \
  "$INTEL_BUILD_BINARY" \
  -output "$APP_MACOS/$APP_NAME"
chmod +x "$APP_MACOS/$APP_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_CONTENTS/Info.plist"
cp "$ROOT_DIR/Resources/icon.icns" "$APP_RESOURCES/icon.icns"
cp -R "$ROOT_DIR/Resources/assets" "$APP_RESOURCES/assets"
cp -R "$ROOT_DIR/Resources/bin" "$APP_RESOURCES/bin"
cp -R "$ROOT_DIR/Resources/en.lproj" "$APP_RESOURCES/en.lproj"
chmod +x "$APP_RESOURCES/bin/scrcpy" 2>/dev/null || true
chmod +x "$APP_RESOURCES/bin/adb" 2>/dev/null || true

for universal_binary in \
  "$APP_MACOS/$APP_NAME" \
  "$APP_RESOURCES/bin/adb" \
  "$APP_RESOURCES/bin/scrcpy"; do
  lipo "$universal_binary" -verify_arch arm64 x86_64
done

sign_with_stable_identity() {
  local sign_dir sign_keychain sign_password identity temporary_dir
  sign_dir="$ROOT_DIR/.codex/signing"
  sign_keychain="$sign_dir/signing.keychain-db"
  sign_password="rokid-local-build"
  identity="Rokid Local Code Signing"

  mkdir -p "$sign_dir"
  chmod 700 "$sign_dir"

  if [[ ! -f "$sign_keychain" ]]; then
    temporary_dir="$(mktemp -d "${TMPDIR:-/tmp}/rokid-native-sign.XXXXXX")"
    openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
      -subj '/CN=Rokid Local Code Signing/O=Rokid Local' \
      -addext 'keyUsage=digitalSignature' \
      -addext 'extendedKeyUsage=codeSigning' \
      -keyout "$temporary_dir/key.pem" \
      -out "$temporary_dir/cert.pem" >/dev/null 2>&1
    openssl pkcs12 -export -legacy \
      -inkey "$temporary_dir/key.pem" \
      -in "$temporary_dir/cert.pem" \
      -passout "pass:$sign_password" \
      -out "$temporary_dir/signing.p12" >/dev/null 2>&1

    security create-keychain -p "$sign_password" "$sign_keychain"
    security unlock-keychain -p "$sign_password" "$sign_keychain"
    security import "$temporary_dir/signing.p12" \
      -k "$sign_keychain" \
      -P "$sign_password" \
      -T /usr/bin/codesign >/dev/null
    rm -rf "$temporary_dir"
  fi

  security unlock-keychain -p "$sign_password" "$sign_keychain"
  security set-key-partition-list \
    -S apple-tool:,apple: \
    -s \
    -k "$sign_password" \
    "$sign_keychain" >/dev/null

  codesign --force --deep \
    --entitlements "$ROOT_DIR/Resources/RokidNative.entitlements" \
    --keychain "$sign_keychain" \
    --sign "$identity" \
    "$APP_BUNDLE"
}

sign_with_stable_identity

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  --build-only|build-only)
    codesign --verify --deep --strict "$APP_BUNDLE"
    ;;
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_MACOS/$APP_NAME"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    codesign --verify --deep --strict "$APP_BUNDLE"
    ;;
  *)
    echo "usage: $0 [run|--build-only|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac

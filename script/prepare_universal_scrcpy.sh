#!/usr/bin/env bash
set -euo pipefail

SCRCPY_VERSION="4.1"
ARM_ARCHIVE="scrcpy-macos-aarch64-v${SCRCPY_VERSION}.tar.gz"
INTEL_ARCHIVE="scrcpy-macos-x86_64-v${SCRCPY_VERSION}.tar.gz"
ARM_SHA256="20fd47c9014dd5e0fa77091f3cb7adbda8445a360c4584aeaa0150b5b3988ff3"
INTEL_SHA256="ee2a7223bc8dbdc4f482db1134bcf441178dafb833492b71ca4c22090c58ce72"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$ROOT_DIR/Resources/bin"
SCRCPY_PATH="$BIN_DIR/scrcpy"
DOWNLOAD_BASE="${SCRCPY_DOWNLOAD_BASE:-https://github.com/Genymobile/scrcpy/releases/download/v${SCRCPY_VERSION}}"

if [[ -x "$SCRCPY_PATH" ]] \
  && lipo "$SCRCPY_PATH" -verify_arch arm64 x86_64 >/dev/null 2>&1 \
  && "$SCRCPY_PATH" --version 2>/dev/null | head -1 | grep -Fq "scrcpy ${SCRCPY_VERSION}"; then
  exit 0
fi

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/rokid-scrcpy-universal.XXXXXX")"
cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

download_and_verify() {
  local archive="$1"
  local expected_sha="$2"

  curl -L --fail --show-error --retry 5 --retry-delay 2 \
    -o "$TEMP_DIR/$archive" \
    "$DOWNLOAD_BASE/$archive"

  local actual_sha
  actual_sha="$(shasum -a 256 "$TEMP_DIR/$archive" | awk '{print $1}')"
  if [[ "$actual_sha" != "$expected_sha" ]]; then
    echo "checksum mismatch for $archive" >&2
    exit 1
  fi
}

download_and_verify "$ARM_ARCHIVE" "$ARM_SHA256"
download_and_verify "$INTEL_ARCHIVE" "$INTEL_SHA256"

mkdir -p "$TEMP_DIR/arm" "$TEMP_DIR/intel" "$BIN_DIR"
tar -xzf "$TEMP_DIR/$ARM_ARCHIVE" -C "$TEMP_DIR/arm"
tar -xzf "$TEMP_DIR/$INTEL_ARCHIVE" -C "$TEMP_DIR/intel"

ARM_DIR="$TEMP_DIR/arm/scrcpy-macos-aarch64-v${SCRCPY_VERSION}"
INTEL_DIR="$TEMP_DIR/intel/scrcpy-macos-x86_64-v${SCRCPY_VERSION}"

cmp "$ARM_DIR/scrcpy-server" "$INTEL_DIR/scrcpy-server"
lipo -create "$ARM_DIR/scrcpy" "$INTEL_DIR/scrcpy" -output "$SCRCPY_PATH"
cp "$ARM_DIR/adb" "$BIN_DIR/adb"
cp "$ARM_DIR/scrcpy-server" "$BIN_DIR/scrcpy-server"
cp "$ARM_DIR/LICENSE" "$BIN_DIR/LICENSE.scrcpy"
rm -f "$BIN_DIR"/*.dylib

chmod +x "$BIN_DIR/adb" "$SCRCPY_PATH"
lipo "$BIN_DIR/adb" -verify_arch arm64 x86_64
lipo "$SCRCPY_PATH" -verify_arch arm64 x86_64

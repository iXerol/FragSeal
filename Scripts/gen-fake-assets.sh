#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESOURCE_DIR="$ROOT_DIR/FragSealCoreTests/Resources"
TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

mkdir -p "$RESOURCE_DIR"

find "$RESOURCE_DIR" -maxdepth 1 -type f ! -name '.gitkeep' -delete

python3 - <<'PY' > "$RESOURCE_DIR/legacy_plaintext.bin"
import sys
payload = bytes((i * 29) % 251 for i in range(4096))
sys.stdout.buffer.write(payload)
PY

dd if="$RESOURCE_DIR/legacy_plaintext.bin" of="$TMP_DIR/chunk0.bin" bs=2048 count=1 status=none
dd if="$RESOURCE_DIR/legacy_plaintext.bin" of="$TMP_DIR/chunk1.bin" bs=2048 skip=1 count=1 status=none

KEY_HEX="00112233445566778899aabbccddeeff"
IV0_HEX="1032547698badcfeefcdab8967452301"
IV1_HEX="0123456789abcdeffedcba9876543210"

openssl enc -aes-128-cbc -nosalt -K "$KEY_HEX" -iv "$IV0_HEX" \
  -in "$TMP_DIR/chunk0.bin" \
  -out "$RESOURCE_DIR/legacy_chunk_0.bin"

openssl enc -aes-128-cbc -nosalt -K "$KEY_HEX" -iv "$IV1_HEX" \
  -in "$TMP_DIR/chunk1.bin" \
  -out "$RESOURCE_DIR/legacy_chunk_1.bin"

if [[ ! -f "$RESOURCE_DIR/legacy_chunk_0.bin" ]] || [[ ! -f "$RESOURCE_DIR/legacy_chunk_1.bin" ]]; then
  echo "Failed to generate legacy encrypted fixtures" >&2
  exit 1
fi

echo "FragSeal fixtures generated in $RESOURCE_DIR"

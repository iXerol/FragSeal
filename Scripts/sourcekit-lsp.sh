#!/usr/bin/env bash
# Wrapper that resolves sourcekit-lsp for both macOS (Xcode toolchain)
# and Linux (Swift toolchain installs) so VS Code can launch it reliably.

set -euo pipefail

resolve_macos() {
  local toolchain
  if toolchain="$(xcrun --toolchain swift --find sourcekit-lsp 2>/dev/null)"; then
    printf '%s\n' "$toolchain"
    return 0
  fi
  if toolchain="$(xcrun --find sourcekit-lsp 2>/dev/null)"; then
    printf '%s\n' "$toolchain"
    return 0
  fi
  return 1
}

resolve_linux() {
  command -v sourcekit-lsp 2>/dev/null || return 1
}

if [[ "${OSTYPE:-}" == darwin* ]]; then
  if tool="$(resolve_macos)"; then
    exec "$tool" "$@"
  fi
else
  if tool="$(resolve_linux)"; then
    exec "$tool" "$@"
  fi
fi

echo "sourcekit-lsp not found on PATH or via xcrun" >&2
exit 127

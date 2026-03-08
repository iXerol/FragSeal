#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: resolve-swift-include-root.sh [--include-root|--swift-bridging-dir]

Resolves a Swift toolchain include root that contains swift/bridging.
EOF
}

mode="include-root"
if [[ $# -gt 0 ]]; then
  case "$1" in
    --include-root)
      mode="include-root"
      shift
      ;;
    --swift-bridging-dir)
      mode="swift-bridging-dir"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
fi

if [[ $# -ne 0 ]]; then
  usage >&2
  exit 2
fi

runtime_resource_path="$(swift -print-target-info | jq -r '.paths.runtimeResourcePath // empty')"
if [[ -z "${runtime_resource_path}" ]]; then
  echo "Failed to read Swift runtimeResourcePath." >&2
  exit 1
fi

swiftc_path="$(command -v swift || true)"
swift_bin_dir=""
if [[ -n "${swiftc_path}" ]]; then
  swift_bin_dir="$(cd "$(dirname "${swiftc_path}")" && pwd)"
fi

candidates=(
  "$(realpath "${runtime_resource_path}/../../include" 2>/dev/null || true)"
  "$(realpath "${runtime_resource_path}/../include" 2>/dev/null || true)"
  "$(realpath "${runtime_resource_path}/../../../include" 2>/dev/null || true)"
  "$(realpath "${swift_bin_dir}/../include" 2>/dev/null || true)"
  "/usr/include"
)

declare -A seen=()
for candidate in "${candidates[@]}"; do
  [[ -n "${candidate}" ]] || continue
  [[ -d "${candidate}" ]] || continue
  [[ -n "${seen[$candidate]+x}" ]] && continue
  seen["$candidate"]=1
  if [[ -f "${candidate}/swift/bridging" ]]; then
    if [[ "${mode}" == "include-root" ]]; then
      printf '%s\n' "${candidate}"
    else
      printf '%s\n' "${candidate}/swift"
    fi
    exit 0
  fi
done

echo "Could not find a Swift include root that provides swift/bridging." >&2
echo "runtimeResourcePath=${runtime_resource_path}" >&2
exit 1

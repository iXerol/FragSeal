def _swift_toolchain_include_repository_impl(ctx):
    include_result = ctx.execute([
        "bash",
        "-lc",
        """
set -euo pipefail

append_candidate() {
  local value="$1"
  [ -n "$value" ] || return 0
  CANDIDATES+=("$value")
}

resolve_candidate() {
  local value="$1"
  [ -n "$value" ] || return 0
  realpath "$value" 2>/dev/null || true
}

swift_bin="${SWIFT_BIN:-}"
swiftc_bin="${SWIFTC_BIN:-}"

if [ -z "$swift_bin" ] || [ ! -x "$swift_bin" ]; then
  swift_bin="$(command -v swift || true)"
fi
if [ -z "$swiftc_bin" ] || [ ! -x "$swiftc_bin" ]; then
  swiftc_bin="$(command -v swiftc || true)"
fi
if [ -z "$swift_bin" ] && [ -n "$swiftc_bin" ]; then
  swift_bin="$swiftc_bin"
fi

swift_toolchain_root="${SWIFT_TOOLCHAIN_ROOT:-}"
swift_toolchain_usr="${SWIFT_TOOLCHAIN_USR:-}"
if [ -z "$swift_bin" ] && [ -n "$swift_toolchain_root" ] && [ -x "$swift_toolchain_root/usr/bin/swift" ]; then
  swift_bin="$swift_toolchain_root/usr/bin/swift"
fi
if [ -z "$swiftc_bin" ] && [ -n "$swift_toolchain_root" ] && [ -x "$swift_toolchain_root/usr/bin/swiftc" ]; then
  swiftc_bin="$swift_toolchain_root/usr/bin/swiftc"
fi
if [ -z "$swift_toolchain_usr" ] && [ -n "$swift_toolchain_root" ]; then
  swift_toolchain_usr="$swift_toolchain_root/usr"
fi
if [ -z "$swift_toolchain_root" ] && [ -n "$swift_toolchain_usr" ]; then
  swift_toolchain_root="$(resolve_candidate "$swift_toolchain_usr/..")"
fi

swift_bin_dir=""
runtime_resource_path=""
if [ -n "$swift_bin" ]; then
  swift_bin_dir="$(cd "$(dirname "$swift_bin")" && pwd)"
  runtime_resource_path="$("$swift_bin" -print-target-info 2>/dev/null | sed -n 's/.*"runtimeResourcePath"[[:space:]]*:[[:space:]]*"\\([^"]*\\)".*/\\1/p' | head -n 1)"
fi
swiftly_root=""
if command -v swiftly >/dev/null 2>&1; then
  swiftly_root="$(swiftly use --print-location 2>/dev/null | grep '^/' | tail -n 1 || true)"
fi

CANDIDATES=()
append_candidate "$(resolve_candidate "$swift_toolchain_usr/include")"
append_candidate "$(resolve_candidate "$swift_toolchain_root/usr/include")"
append_candidate "$(resolve_candidate "$swift_bin_dir/../include")"
append_candidate "$(resolve_candidate "$runtime_resource_path/../../include")"
append_candidate "$(resolve_candidate "$runtime_resource_path/../include")"
append_candidate "$(resolve_candidate "$swiftly_root/usr/include")"
append_candidate "/usr/include"

for search_root in "$swift_toolchain_root" "$swift_toolchain_usr" "$swiftly_root" "$swift_bin_dir" "$runtime_resource_path"; do
  [ -n "$search_root" ] || continue
  [ -d "$search_root" ] || continue
  while IFS= read -r bridge_path; do
    include_root="$(dirname "$(dirname "$bridge_path")")"
    append_candidate "$include_root"
  done < <(find "$search_root" -maxdepth 8 -path "*/swift/bridging" 2>/dev/null | sort -u)
done

SEEN="|"
for candidate in "${CANDIDATES[@]}"; do
  [ -n "$candidate" ] || continue
  case "$SEEN" in
    *"|$candidate|"*) continue ;;
  esac
  SEEN="$SEEN$candidate|"
  [ -e "$candidate/swift/bridging" ] || continue
  printf '%s' "$candidate"
  exit 0
done

{
  echo "PATH=$PATH"
  echo "SWIFT_BIN=${SWIFT_BIN:-}"
  echo "SWIFTC_BIN=${SWIFTC_BIN:-}"
  echo "SWIFT_TOOLCHAIN_ROOT=${SWIFT_TOOLCHAIN_ROOT:-}"
  echo "SWIFT_TOOLCHAIN_USR=${SWIFT_TOOLCHAIN_USR:-}"
  echo "swift_bin=$swift_bin"
  echo "swiftc_bin=$swiftc_bin"
  echo "swift_bin_dir=$swift_bin_dir"
  echo "runtime_resource_path=$runtime_resource_path"
  echo "swiftly_root=$swiftly_root"
  echo "swift_toolchain_root=$swift_toolchain_root"
  echo "swift_toolchain_usr=$swift_toolchain_usr"
  echo "candidate_count=${#CANDIDATES[@]}"
  for candidate in "${CANDIDATES[@]}"; do
    [ -n "$candidate" ] || continue
    if [ -e "$candidate/swift/bridging" ]; then
      echo "candidate=$candidate (has swift/bridging)"
    else
      echo "candidate=$candidate (missing swift/bridging)"
    fi
  done
} >&2

exit 2
""",
    ])

    if include_result.return_code != 0:
        fail("""Failed to locate a Swift include root that provides swift/bridging
return_code: {return_code}
stdout:
{stdout}
stderr:
{stderr}
""".format(
            return_code = include_result.return_code,
            stdout = include_result.stdout,
            stderr = include_result.stderr,
        ))

    include_root = include_result.stdout.strip()
    if not include_root:
        fail("Could not find a Swift include root that provides swift/bridging")

    swift_to_cxx_result = ctx.execute([
        "bash",
        "-lc",
        """
set -euo pipefail

resolve_candidate() {
  local value="$1"
  [ -n "$value" ] || return 0
  realpath "$value" 2>/dev/null || true
}

swift_bin="${SWIFT_BIN:-}"
if [ -z "$swift_bin" ] || [ ! -x "$swift_bin" ]; then
  swift_bin="$(command -v swiftc || true)"
fi
if [ -z "$swift_bin" ] || [ ! -x "$swift_bin" ]; then
  swift_bin="$(command -v swift || true)"
fi

swift_bin_dir=""
runtime_resource_path=""
if [ -n "$swift_bin" ]; then
  swift_bin_dir="$(cd "$(dirname "$swift_bin")" && pwd)"
  runtime_resource_path="$("$swift_bin" -print-target-info 2>/dev/null | sed -n 's/.*"runtimeResourcePath"[[:space:]]*:[[:space:]]*"\\([^"]*\\)".*/\\1/p' | head -n 1)"
fi
include_root="%s"

candidates=(
  "$(resolve_candidate "$include_root/swiftToCxx")"
  "$(resolve_candidate "${SWIFT_TOOLCHAIN_USR:-}/lib/swift/swiftToCxx")"
  "$(resolve_candidate "${SWIFT_TOOLCHAIN_ROOT:-}/usr/lib/swift/swiftToCxx")"
  "$(resolve_candidate "$runtime_resource_path/swiftToCxx")"
  "$(resolve_candidate "$swift_bin_dir/../lib/swift/swiftToCxx")"
  "/usr/lib/swift/swiftToCxx"
)

for candidate in "${candidates[@]}"; do
  [ -n "$candidate" ] || continue
  [ -f "$candidate/_SwiftStdlibCxxOverlay.h" ] || continue
  printf '%%s' "$candidate"
  exit 0
done

exit 0
""" % include_root,
    ])

    ctx.symlink(include_root + "/swift", "swift")
    swift_to_cxx_root = swift_to_cxx_result.stdout.strip()
    if swift_to_cxx_root:
        ctx.symlink(swift_to_cxx_root, "swiftToCxx")
    swift_to_cxx_parent = ""
    if swift_to_cxx_root:
        swift_to_cxx_parent = swift_to_cxx_root.rsplit("/", 1)[0]
    ctx.file(
        "paths.bzl",
        """SWIFT_TOOLCHAIN_INCLUDE_ROOT = "{include_root}"
SWIFT_TOOLCHAIN_SWIFT_TO_CXX_PARENT = "{swift_to_cxx_parent}"
""".format(
            include_root = include_root.replace("\\", "\\\\").replace("\"", "\\\""),
            swift_to_cxx_parent = swift_to_cxx_parent.replace("\\", "\\\\").replace("\"", "\\\""),
        ),
    )
    ctx.file(
        "BUILD.bazel",
        """
package(default_visibility = [\"//visibility:public\"])

cc_library(
    name = "swift_bridging_headers",
    hdrs = glob([
        \"swift/**\",
        \"swiftToCxx/**\",
    ], allow_empty = True),
    includes = [\".\"],
)
""",
    )

swift_toolchain_include_repository = repository_rule(
    implementation = _swift_toolchain_include_repository_impl,
    environ = [
        "PATH",
        "SWIFT_BIN",
        "SWIFTC_BIN",
        "SWIFT_TOOLCHAIN_ROOT",
        "SWIFT_TOOLCHAIN_USR",
    ],
    local = True,
)

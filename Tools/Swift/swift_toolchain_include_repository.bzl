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

swift_bin="$(command -v swift || true)"
if [ -z "$swift_bin" ]; then
  swift_bin="$(command -v swiftc || true)"
fi
if [ -z "$swift_bin" ]; then
  exit 1
fi

swift_bin_dir="$(cd "$(dirname "$swift_bin")" && pwd)"
runtime_resource_path="$("$swift_bin" -print-target-info 2>/dev/null | sed -n 's/.*"runtimeResourcePath"[[:space:]]*:[[:space:]]*"\\([^"]*\\)".*/\\1/p' | head -n 1)"
swiftly_root=""
if command -v swiftly >/dev/null 2>&1; then
  swiftly_root="$(swiftly use --print-location 2>/dev/null | grep '^/' | tail -n 1 || true)"
fi

CANDIDATES=()
append_candidate "$(realpath "$swift_bin_dir/../include" 2>/dev/null || true)"
append_candidate "$(realpath "$runtime_resource_path/../../include" 2>/dev/null || true)"
append_candidate "$(realpath "$runtime_resource_path/../include" 2>/dev/null || true)"
append_candidate "$(realpath "$swiftly_root/usr/include" 2>/dev/null || true)"
append_candidate "/usr/include"

for search_root in "$swiftly_root" "$swift_bin_dir" "$runtime_resource_path"; do
  [ -n "$search_root" ] || continue
  [ -d "$search_root" ] || continue
  while IFS= read -r bridge_path; do
    include_root="$(dirname "$(dirname "$bridge_path")")"
    append_candidate "$include_root"
  done < <(find "$search_root" -maxdepth 6 -type f -path "*/swift/bridging" 2>/dev/null | sort -u)
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
  echo "swift_bin=$swift_bin"
  echo "swift_bin_dir=$swift_bin_dir"
  echo "runtime_resource_path=$runtime_resource_path"
  echo "swiftly_root=$swiftly_root"
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
stdout:
{stdout}
stderr:
{stderr}
""".format(
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

swift_bin="$(command -v swift || true)"
if [ -z "$swift_bin" ]; then
  swift_bin="$(command -v swiftc || true)"
fi
if [ -z "$swift_bin" ]; then
  exit 0
fi

swift_bin_dir="$(cd "$(dirname "$swift_bin")" && pwd)"
runtime_resource_path="$("$swift_bin" -print-target-info 2>/dev/null | sed -n 's/.*"runtimeResourcePath"[[:space:]]*:[[:space:]]*"\\([^"]*\\)".*/\\1/p' | head -n 1)"
include_root="%s"

candidates=(
  "$(realpath "$include_root/swiftToCxx" 2>/dev/null || true)"
  "$(realpath "$runtime_resource_path/swiftToCxx" 2>/dev/null || true)"
  "$(realpath "$swift_bin_dir/../lib/swift/swiftToCxx" 2>/dev/null || true)"
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
    local = True,
)

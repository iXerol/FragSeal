def _swift_toolchain_include_repository_impl(ctx):
    include_result = ctx.execute([
        "bash",
        "-lc",
        """
set -euo pipefail

swift_bin="$(command -v swift || true)"
if [ -z "$swift_bin" ]; then
  swift_bin="$(command -v swiftc || true)"
fi
if [ -z "$swift_bin" ]; then
  exit 1
fi

swift_bin_dir="$(cd "$(dirname "$swift_bin")" && pwd)"
runtime_resource_path="$("$swift_bin" -print-target-info 2>/dev/null | sed -n 's/.*"runtimeResourcePath"[[:space:]]*:[[:space:]]*"\\([^"]*\\)".*/\\1/p' | head -n 1)"

candidates=(
  "$(realpath "$swift_bin_dir/../include" 2>/dev/null || true)"
  "$(realpath "$runtime_resource_path/../../include" 2>/dev/null || true)"
  "$(realpath "$runtime_resource_path/../include" 2>/dev/null || true)"
  "/usr/include"
)

for candidate in "${candidates[@]}"; do
  [ -n "$candidate" ] || continue
  [ -f "$candidate/swift/bridging" ] || continue
  printf '%s' "$candidate"
  exit 0
done

exit 2
""",
    ])

    if include_result.return_code != 0:
        fail("Failed to locate a Swift include root that provides swift/bridging")

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

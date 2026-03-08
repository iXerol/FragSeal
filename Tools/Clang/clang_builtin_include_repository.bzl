def _clang_builtin_include_repository_impl(ctx):
    find_result = ctx.execute([
        "bash",
        "-lc",
        """
set -euo pipefail
clang_include="$(clang -print-resource-dir)/include"
if [ -f "$clang_include/lifetimebound.h" ]; then
  printf '%s/lifetimebound.h' "$clang_include"
  exit 0
fi
find /usr/lib/clang -type f -name lifetimebound.h 2>/dev/null | head -n 1
""",
    ])

    if find_result.return_code != 0:
        fail("Failed to locate lifetimebound.h using clang resource dir")

    header_path = find_result.stdout.strip()
    if not header_path:
        fail("Could not find lifetimebound.h in the host Clang installation")

    ctx.symlink(header_path, "lifetimebound.h")
    ctx.file(
        "BUILD.bazel",
        """
package(default_visibility = [\"//visibility:public\"])

cc_library(
    name = "lifetimebound_headers",
    hdrs = ["lifetimebound.h"],
    includes = ["."],
)
""",
    )

clang_builtin_include_repository = repository_rule(
    implementation = _clang_builtin_include_repository_impl,
    local = True,
)
